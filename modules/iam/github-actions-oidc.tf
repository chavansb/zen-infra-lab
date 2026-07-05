# ─── GitHub Actions OIDC Federation ─────────────────────────────────────────
#
# Allows GitHub Actions workflows in your-github-username/zen-pharma-frontend and
# your-github-username/zen-pharma-backend to assume an IAM role without any long-lived
# AWS credentials stored in GitHub Secrets.
#
# How it works:
#   1. GitHub mints a short-lived OIDC token per workflow run.
#   2. The workflow calls aws-actions/configure-aws-credentials with
#      role-to-assume: <this role ARN>.
#   3. AWS validates the token against the registered OIDC provider and
#      issues temporary STS credentials (valid for 1 hour max).
#
# Usage in workflow:
#   - uses: aws-actions/configure-aws-credentials@v4
#     with:
#       role-to-assume: arn:aws:iam::ACCOUNT_ID:role/pharma-dev-github-actions-role
#       aws-region: us-east-1
# ─────────────────────────────────────────────────────────────────────────────
# ----------------------- How this works end-to-end ---------------------------
# Developer pushes code
#         │
#         ▼
# GitHub Actions workflow starts
#         │
#         ▼
# GitHub creates OIDC token
#         │
#         ▼
# aws-actions/configure-aws-credentials
#         │
#         ▼
# AWS checks:

# 1. Is token from GitHub?
# 2. Does SSL thumbprint match?
# 3. Is audience sts.amazonaws.com?
# 4. Is repository allowed?
# 5. Is branch allowed?

#         │
#         ▼
# If all checks pass

#         │
#         ▼
# AWS STS issues temporary credentials

#         │
#         ▼
# GitHub can:

# ✓ Login to ECR
# ✓ Push Docker images
# ✓ Read EKS cluster info

#         │
#         ▼
# Credentials automatically expire in 1 hour
# --------------------------------------------------------------------------------------------------------

#########################################################
# GITHUB ACTIONS OIDC PROVIDER
#
# This provider is account-wide — only ONE can exist per
# AWS account regardless of how many environments you have.
#
# How it works per environment:
#   create_github_oidc_provider = true  → dev CREATES it
#   create_github_oidc_provider = false → qa/prod READ it
#
# This way:
#   - destroy dev → recreate dev → provider gets recreated ✅
#   - qa/prod always just read whatever exists             ✅
#   - no EntityAlreadyExists 409 error                     ✅
#########################################################

# CREATES the provider — only runs when create_github_oidc_provider = true (dev only)
# This resource registers GitHub as a trusted Identity Provider in AWS.
# AWS will trust JWT tokens issued by GitHub Actions.
resource "aws_iam_openid_connect_provider" "github_actions" {
  # count = 1 → create it (dev)
  # count = 0 → skip it   (qa, prod)
  count = var.create_github_oidc_provider ? 1 : 0

  # GitHub's official OIDC endpoint.
  # Every GitHub Actions workflow gets its identity token from here.
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"] # GitHub workflows requesting AWS credentials use STS.

  # SSL certificate thumbprints of GitHub's OIDC endpoint.
  # AWS uses these to verify it is communicating with GitHub.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = {
    Name    = "github-action-oidc-provider"
    Project = var.project
  }
}

# READS the existing provider — only runs when create_github_oidc_provider = false (qa, prod)
# Provider was already created by dev — just look it up
data "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# Local value — gives us the ARN regardless of whether
# we created the provider (dev) or just read it (qa/prod)
locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? (
    aws_iam_openid_connect_provider.github_actions[0].arn
  ) : (
    data.aws_iam_openid_connect_provider.github_actions[0].arn
  )
}

#########################################################
# IAM TRUST POLICY
#########################################################
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type = "Federated"
      # Uses local value — works correctly for both create (dev) and read (qa/prod) cases
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # GitHub token contains:
    #
    # sub = repo:chavansb/zen-pharma-backend:ref:refs/heads/main
    #
    # AWS checks whether the token matches one of the values below.
    # FIX: changed "aud" → "sub" here — aud and sub are different claims.
    # aud = audience (who the token is for = sts.amazonaws.com)
    # sub = subject (which repo/branch the token is from) ← this is what restricts access
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/zen-pharma-frontend:ref:refs/heads/main",
        "repo:${var.github_org}/zen-pharma-frontend:ref:refs/heads/develop",
        "repo:${var.github_org}/zen-pharma-backend:ref:refs/heads/main",
        "repo:${var.github_org}/zen-pharma-backend:ref:refs/heads/develop",
      ]
    }
  }
}

#########################################################
# IAM ROLE FOR GITHUB ACTIONS
#########################################################

# This is the role that GitHub Actions will assume.

resource "aws_iam_role" "github_actions_ci" {
  name                 = "${var.project}-${var.env}-github-actions-role"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600

  tags = {
    Name    = "${var.project}-${var.env}-github-actions-role"
    Env     = var.env
    Project = var.project
  }
}

#########################################################
# PERMISSIONS POLICY
#########################################################

# This policy defines what GitHub Actions can do

resource "aws_iam_policy" "github_actions_ci_policy" {
  name        = "${var.project}-${var.env}-github-actions-policy"
  description = "Allow GitHub Actions to push Docker images and read EKS cluster info"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", # Check image layers
          "ecr:GetDownloadUrlForLayer",      # Download existing layers
          "ecr:BatchGetImage",               # Retrieve images
          "ecr:PutImage",                    # Push Docker image manifest
          "ecr:InitiateLayerUpload",         # Start upload process
          "ecr:UploadLayerPart",             # Upload Docker layers
          "ecr:CompleteLayerUpload",         # Complete upload
          "ecr:DescribeRepositories",        # Repository metadata
          "ecr:ListImages",                  # List images
          "ecr:DescribeImages"               # Describe images
        ]
        Resource = "arn:aws:ecr:*:${var.aws_account_id}:repository/*"
      },
      {
        Sid    = "EKSRead"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster", # View cluster details
          "eks:ListClusters",    # List clusters
        ]
        Resource = "*"
      },
    ]
  })
}

#########################################################
# ATTACH POLICY TO ROLE
#########################################################

# Finally attach the permissions policy to the role.

resource "aws_iam_role_policy_attachment" "github_actions_ci_policy_attachment" {

  # IAM Role name
  role = aws_iam_role.github_actions_ci.name

  # IAM Policy ARN
  policy_arn = aws_iam_policy.github_actions_ci_policy.arn
}