output "github_actions_ecr_push_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC to push images to ECR."
  value       = aws_iam_role.github_actions_ecr_push.arn
}
