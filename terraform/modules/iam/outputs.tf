output "github_actions_ecr_push_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC to push images to ECR."
  value       = aws_iam_role.github_actions_ecr_push.arn
}

output "github_actions_terraform_plan_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC to run Terraform plan."
  value       = aws_iam_role.github_actions_terraform_plan.arn
}

output "github_actions_deploy_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC to deploy the Incident API to EKS."
  value       = aws_iam_role.github_actions_deploy.arn
}