output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB, NAT Gateway)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (EKS nodes, RDS)"
  value       = aws_subnet.private[*].id
}

output "rds_endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "ecr_repository_url" {
  description = "ECR repository URL to push the app image to"
  value       = aws_ecr_repository.app.repository_url
}

# Read by ansible playbooks

output "lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account"
  value       = aws_iam_role.lb_controller.arn
}

output "alb_security_group_id" {
  description = "Security group to attach to the ALB via the Ingress annotation"
  value       = aws_security_group.alb.id
}

output "alb_certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener"
  value       = aws_acm_certificate.alb.arn
}