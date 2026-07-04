output "repository_urls" {
  description = "Map of repository name to its full ECR URL, used for docker push/pull"
  value       = { for name, repo in aws_ecr_repository.main : name => repo.repository_url }
}

output "repository_arns" {
  description = "Map of repository name to its ARN"
  value       = { for name, repo in aws_ecr_repository.main : name => repo.arn }
}