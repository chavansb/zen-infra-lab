#############################################################
# External Secrets Operator (ESO) Trust Policy
#############################################################

# This policy defines WHO is allowed to assume the IAM Role.
#
# In our case:
# Only the External Secrets Kubernetes ServiceAccount
# should be allowed to use this IAM Role.
#
# AWS verifies:
#
# 1. OIDC Provider
# 2. ServiceAccount
# 3. Audience (STS)
#
# If all conditions match,
# AWS issues temporary credentials.

# FIX: changed "resource" → "data"
# aws_iam_policy_document is always a data source, never a resource.
# It just builds JSON in memory — it doesn't create anything in AWS.
data "aws_iam_policy_document" "eso_assume_role" {
  statement {
    # FIX: changed "action" → "actions" (plural)
    # aws_iam_policy_document always uses plural attribute names
    actions = ["sts:AssumeRoleWithWebIdentity"] # This action allows a kubernetes service account to exchange its OIDC token for temporary AWS credentials
    effect  = "Allow"

    # Condition 1
    # Verify Kubernetes ServiceAccount
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      # FIX: changed "value" → "values" (plural)
      values = ["system:serviceaccount:external-secrets:external-secrets"]
    }

    # Condition 2
    # Verify audience
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated" # Federated means external identity provider.
    }
  }
}

#############################################################
# IAM Role used by External Secrets Operator
#############################################################
resource "aws_iam_role" "eso_role" {
  name               = "${var.project}-${var.env}-eso-role"
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role.json

  tags = {
    Name    = "${var.project}-${var.env}-eso-role"
    Env     = var.env
    Project = var.project
  }
}

#############################################################
# Permissions for External Secrets Operator
#############################################################
resource "aws_iam_policy" "eso_secrets_policy" {
  name        = "${var.project}-${var.env}-eso-secrets-policy"
  description = "Allow External Secrets Operator to read secrets from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Only secrets inside the /pharma/ path can be accessed
        Resource = "arn:aws:secretsmanager:*:${var.aws_account_id}:secret:/pharma/*"
      }
    ]
  })
}

#############################################################
# Attach IAM Policy to IAM Role
#############################################################
resource "aws_iam_role_policy_attachment" "eso_secrets_attachment" {
  role       = aws_iam_role.eso_role.name
  policy_arn = aws_iam_policy.eso_secrets_policy.arn
}

#############################################################
# ArgoCD Trust Policy
#############################################################

# WHO is allowed to assume this IAM Role?
# Answer:
# Only the ArgoCD Application Controller ServiceAccount.

# FIX: changed "resource" → "data" (same reason as ESO above)
data "aws_iam_policy_document" "argocd_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:argocd:argocd-application-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

#############################################################
# IAM Role for ArgoCD
#############################################################
resource "aws_iam_role" "argocd_role" {
  name               = "${var.project}-${var.env}-argocd-role"
  assume_role_policy = data.aws_iam_policy_document.argocd_assume_role.json

  tags = {
    Name    = "${var.project}-${var.env}-argocd-role"
    Env     = var.env
    Project = var.project
  }
}

# NOTE: GitLab runner policy and attachment removed —
# that block referenced "aws_iam_role.gitlab_runner_role" which was
# never defined anywhere, causing a "Reference to undeclared resource" error.
# This project uses GitHub Actions, not GitLab Runner.