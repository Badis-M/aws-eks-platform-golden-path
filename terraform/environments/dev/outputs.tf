output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_name" {
  description = "ECR repository name."
  value       = module.ecr.repository_name
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = module.ecr.repository_url
}

output "github_actions_ecr_push_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC to push images to ECR."
  value       = module.iam.github_actions_ecr_push_role_arn
}

output "github_actions_terraform_plan_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC to run Terraform plan."
  value       = module.iam.github_actions_terraform_plan_role_arn
}

output "github_actions_deploy_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC to deploy the Incident API to EKS."
  value       = module.iam.github_actions_deploy_role_arn
}