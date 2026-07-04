output "db_credentials_secret_arn" {
  description = "ARN of the DB credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Name/path of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret in Secrets Manager"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "jwt_secret_name" {
  description = "Name/path of the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.name
}