output "vpc_id" {
  description = "ID of the VPC created for dev environment"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS PostgreSQL database"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "ecr_repository_urls" {
  description = "URLs of all ECR repositories created"
  value       = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  description = "IAM role ARN that GitHub Actions assumes via OIDC"
  value       = module.iam.github_actions_role_arn
}