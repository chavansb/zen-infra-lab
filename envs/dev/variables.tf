variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Master password for RDS PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secret key used for JWT token signing"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "Your GitHub username - used in IAM trust policy"
  type        = string
}