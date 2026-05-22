variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username allowed to assume the IAM role."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the IAM role."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN allowed for image push operations."
  type        = string
}
