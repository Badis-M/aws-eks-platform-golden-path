#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-west-3}"
AWS_PROFILE="${AWS_PROFILE:-tf-eks-golden-path}"
PROJECT_NAME="${PROJECT_NAME:-aws-eks-platform-golden-path}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
CLUSTER_NAME="${CLUSTER_NAME:-${PROJECT_NAME}-${ENVIRONMENT}-eks}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-incident-api}"
PROJECT_TAG_KEY="${PROJECT_TAG_KEY:-Project}"
ENVIRONMENT_TAG_KEY="${ENVIRONMENT_TAG_KEY:-Environment}"

export AWS_PAGER=""

info() {
  printf '[INFO] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  exit 1
}

aws_cli() {
  aws --region "$AWS_REGION" --profile "$AWS_PROFILE" "$@"
}

check_aws_identity() {
  info "Checking AWS identity"
  aws_cli sts get-caller-identity >/dev/null
  pass "AWS identity is valid for profile ${AWS_PROFILE}"
}

check_eks_cluster_deleted() {
  info "Checking EKS cluster deletion"

  if aws_cli eks describe-cluster --name "$CLUSTER_NAME" >/dev/null 2>&1; then
    fail "EKS cluster still exists: ${CLUSTER_NAME}"
  fi

  pass "EKS cluster not found: ${CLUSTER_NAME}"
}

check_load_balancers_absent() {
  info "Checking Elastic Load Balancers"

  local classic_count
  classic_count="$(aws_cli elb describe-load-balancers --query 'length(LoadBalancerDescriptions)' --output text)"

  local v2_count
  v2_count="$(aws_cli elbv2 describe-load-balancers --query 'length(LoadBalancers)' --output text)"

  if [ "$classic_count" != "0" ] || [ "$v2_count" != "0" ]; then
    warn "Load balancers still exist in ${AWS_REGION}"
    aws_cli elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName' --output table || true
    aws_cli elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output table || true
    fail "Delete remaining load balancers before considering cleanup complete"
  fi

  pass "No load balancers found"
}

check_nat_gateways_absent() {
  info "Checking NAT Gateways"

  local nat_count
  nat_count="$(aws_cli ec2 describe-nat-gateways \
    --filter Name=state,Values=pending,available \
    --query 'length(NatGateways)' \
    --output text)"

  if [ "$nat_count" != "0" ]; then
    warn "NAT Gateways still exist"
    aws_cli ec2 describe-nat-gateways \
      --filter Name=state,Values=pending,available \
      --query 'NatGateways[].{Id:NatGatewayId,State:State,VpcId:VpcId}' \
      --output table
    fail "Delete remaining NAT Gateways before considering cleanup complete"
  fi

  pass "No active NAT Gateways found"
}

check_ec2_instances_absent() {
  info "Checking EC2 instances"

  local instance_count
  instance_count="$(aws_cli ec2 describe-instances \
    --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'length(Reservations[].Instances[])' \
    --output text)"

  if [ "$instance_count" != "0" ]; then
    warn "EC2 instances still exist"
    aws_cli ec2 describe-instances \
      --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,Type:InstanceType}' \
      --output table
    fail "Delete remaining EC2 instances before considering cleanup complete"
  fi

  pass "No EC2 instances found"
}

check_unattached_ebs_volumes_absent() {
  info "Checking unattached EBS volumes"

  local volume_count
  volume_count="$(aws_cli ec2 describe-volumes \
    --filters Name=status,Values=available \
    --query 'length(Volumes)' \
    --output text)"

  if [ "$volume_count" != "0" ]; then
    warn "Unattached EBS volumes still exist"
    aws_cli ec2 describe-volumes \
      --filters Name=status,Values=available \
      --query 'Volumes[].{Id:VolumeId,Size:Size,Type:VolumeType,State:State}' \
      --output table
    fail "Delete unattached EBS volumes before considering cleanup complete"
  fi

  pass "No unattached EBS volumes found"
}

check_elastic_ips_absent() {
  info "Checking project Elastic IPs"

  local project_eip_count
  project_eip_count="$(aws_cli ec2 describe-addresses \
    --filters \
      "Name=tag:${PROJECT_TAG_KEY},Values=${PROJECT_NAME}" \
      "Name=tag:${ENVIRONMENT_TAG_KEY},Values=${ENVIRONMENT}" \
    --query 'length(Addresses)' \
    --output text)"

  if [ "$project_eip_count" != "0" ]; then
    warn "Project Elastic IPs still exist"
    aws_cli ec2 describe-addresses \
      --filters \
        "Name=tag:${PROJECT_TAG_KEY},Values=${PROJECT_NAME}" \
        "Name=tag:${ENVIRONMENT_TAG_KEY},Values=${ENVIRONMENT}" \
      --query 'Addresses[].{PublicIp:PublicIp,AllocationId:AllocationId,AssociationId:AssociationId,Tags:Tags}' \
      --output table
    fail "Release project Elastic IPs before considering cleanup complete"
  fi

  local account_eip_count
  account_eip_count="$(aws_cli ec2 describe-addresses --query 'length(Addresses)' --output text)"

  if [ "$account_eip_count" != "0" ]; then
    warn "Non-project Elastic IPs exist in ${AWS_REGION}; ignored by project cleanup check"
    aws_cli ec2 describe-addresses \
      --query 'Addresses[].{PublicIp:PublicIp,AllocationId:AllocationId,AssociationId:AssociationId}' \
      --output table
  fi

  pass "No project Elastic IPs found"
}

check_ecr_repository_state() {
  info "Checking ECR repository state"

  if ! aws_cli ecr describe-repositories --repository-names "$ECR_REPOSITORY_NAME" >/dev/null 2>&1; then
    pass "ECR repository not found: ${ECR_REPOSITORY_NAME}"
    return
  fi

  local image_count
  image_count="$(aws_cli ecr describe-images \
    --repository-name "$ECR_REPOSITORY_NAME" \
    --query 'length(imageDetails)' \
    --output text 2>/dev/null || echo 0)"

  if [ "$image_count" != "0" ]; then
    warn "ECR repository still contains ${image_count} image(s): ${ECR_REPOSITORY_NAME}"
    aws_cli ecr describe-images \
      --repository-name "$ECR_REPOSITORY_NAME" \
      --query 'imageDetails[].{Digest:imageDigest,Tags:imageTags,PushedAt:imagePushedAt}' \
      --output table || true
    fail "Delete old ECR images or destroy the repository if it is Terraform-managed"
  fi

  pass "ECR repository exists but contains no images: ${ECR_REPOSITORY_NAME}"
}

main() {
  info "AWS cleanup verification started"
  info "Region: ${AWS_REGION}"
  info "Profile: ${AWS_PROFILE}"
  info "Cluster: ${CLUSTER_NAME}"

  check_aws_identity
  check_eks_cluster_deleted
  check_load_balancers_absent
  check_nat_gateways_absent
  check_ec2_instances_absent
  check_unattached_ebs_volumes_absent
  check_elastic_ips_absent
  check_ecr_repository_state

  pass "AWS cleanup verification completed successfully"
}

main "$@"
