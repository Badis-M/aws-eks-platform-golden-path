variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used by the EKS cluster and node group."
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types used by the managed node group."
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
}

variable "admin_principal_arn" {
  description = "IAM principal ARN granted cluster admin access through EKS access entries."
  type        = string
}