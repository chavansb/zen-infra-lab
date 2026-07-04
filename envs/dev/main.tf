# Fetches your AWS Account ID automatically at runtime.
# Used by IAM module to scope policies to your specific account.
# This avoids hardcoding account IDs anywhere in code.
data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../modules/vpc"

  project                  = "zen-pharma"
  env                      = "dev"
  vpc_cidr                 = "10.0.0.0/16"
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_eks_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  private_rds_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
}

module "eks" {
  source = "../../modules/eks"

  project            = "zen-pharma"
  env                = "dev"
  cluster_version    = "1.31"
  subnet_ids         = module.vpc.private_eks_subnet_ids
  vpc_id             = module.vpc.vpc_id
  node_instance_type = "t3.small"
  desired_capacity   = 2
  min_size           = 1
  max_size           = 3
}

module "rds" {
  source = "../../modules/rds"

  project               = "zen-pharma"
  env                   = "dev"
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_rds_subnet_ids
  eks_security_group_id = module.eks.cluster_security_group_id
  db_name               = "pharmadb"
  db_username           = "pharmaadmin"
  db_password           = var.db_password
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  engine_version        = "15.7"
  # FIX: removed multi_az and backup_retention_days —
  # RDS module now handles these internally using
  # var.env == "prod" ? true : false ternary logic
}

module "ecr" {
  source = "../../modules/ecr"

  project = "zen-pharma"
  env     = "dev"

  repositories = [
    "api-gateway",
    "auth-service",
    "drug-catalog-service",
    "inventory-service",
    "manufacturing-service",
    "notification-service",
    "pharma-ui",
    "supplier-service",
    "qc-service"
  ]
}

module "iam" {
  source = "../../modules/iam"

  project           = "zen-pharma"
  env               = "dev"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  github_org        = var.github_org
  # FIX: added aws_account_id — required by iam/variables.tf
  # data.aws_caller_identity.current fetches your real account ID
  # automatically — no hardcoding needed
  aws_account_id    = data.aws_caller_identity.current.account_id
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project     = "zen-pharma"
  env         = "dev"
  db_username = "pharmaadmin"
  db_password = var.db_password
  jwt_secret  = var.jwt_secret
}