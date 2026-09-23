variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Short name used to prefix/tag every resource"
  type        = string
  default     = "contactform"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across"
  type        = number
  default     = 2
}

variable "eks_cluster_name" {
  description = "Name the EKS cluster will use (subnets are pre-tagged for its auto-discovery, cluster itself created in a later step)"
  type        = string
  default     = "contactform-eks"
}