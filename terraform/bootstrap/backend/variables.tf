variable "aws_region" {
  description = "AWS region used for the Terraform backend resources."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile used to provision the backend resources."
  type        = string
}

variable "project_name" {
  description = "Project name used for naming and tagging backend resources."
  type        = string
}

variable "environment" {
  description = "Environment name used for tagging backend resources."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used to store Terraform state."
  type        = string
}