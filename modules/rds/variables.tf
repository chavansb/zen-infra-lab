variable "project" {
  description = "Project name"
  type        = string
}
variable "env" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}
variable "subnet_ids" {
  description = "List of subnet IDs for the RDS subnet group"
  type        = list(string)
}
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}
variable "eks_security_group_id" {
  description = "Security group ID of EKS worker nodes to allow RDS access"
  type        = string
}
variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "pharmadb"
}
variable "db_username" {
  description = "Master username for the database"
  type        = string
  sensitive   = true
}
variable "db_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}
variable "instance_class" {
  description = "RDS instance type (e.g. db.t3.micro for dev, db.r6g.large for prod)"
  type        = string
  default     = "db.t3.micro"
}
variable "allocated_storage" {
  description = "Allocated storage for the database in GB"
  type        = number
  default     = 20
}
variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.7"
}