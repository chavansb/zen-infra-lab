#############################################################
# DB Credentials Secret
#############################################################

# This secret stores database connection credentials.
# External Secrets Operator will read this and inject
# it into pods as a Kubernetes Secret automatically.
#
# Secret path: /pharma/dev/db-credentials
# Secret value (JSON):
# {
#   "username": "pharmaadmin",
#   "password": "..."
# }
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "/pharma/${var.env}/db-credentials"
  description = "Database credentials for the pharma ${var.env} environment"

  # How long AWS keeps a deleted secret before permanently removing it.
  # 0 = delete immediately (good for dev so terraform destroy is clean)
  # For prod, use 30 days so you can recover accidental deletions
  recovery_window_in_days = 0

  tags = {
    Name    = "/pharma/${var.env}/db-credentials"
    Env     = var.env
    Project = var.project
  }
}

# The actual secret value stored inside the secret above.
# Stored as JSON so apps can extract individual fields.
# Separated from aws_secretsmanager_secret so the secret
# container and its value can be managed independently.
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # FIX: was jsondecode → changed to jsonencode
  # jsonencode converts HCL object INTO a JSON string (what we want for storing)
  # jsondecode does the opposite — it reads a JSON string back into HCL
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

#############################################################
# JWT Secret
#############################################################

# This secret stores the JWT signing key.
# Used by auth-service to sign and verify JWT tokens.
#
# Secret path: /pharma/dev/jwt-secret
# Secret value (JSON):
# {
#   "secret": "..."
# }

resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "/pharma/${var.env}/jwt-secret"
  description = "JWT signing secret for ${var.project} ${var.env} environment"

  # Same logic as db_credentials — immediate deletion in dev,
  # 30-day recovery window in prod
  recovery_window_in_days = var.env == "prod" ? 30 : 0

  tags = {
    Name    = "/pharma/${var.env}/jwt-secret"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id

  secret_string = jsonencode({
    secret = var.jwt_secret
  })
}