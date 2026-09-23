variable "aws_region" {
  description = "AWS region for the Terraform state backend resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Short name used to prefix backend resource names"
  type        = string
  default     = "contactform"
}
