output "github_actions_role_arn" {
  description = "IAM role ARN that GitHub Actions assumes via OIDC to push to ECR"
  value       = aws_iam_role.github_actions_ci.arn
}

output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator IRSA"
  value       = aws_iam_role.eso_role.arn
}

output "argocd_role_arn" {
  description = "IAM role ARN for ArgoCD IRSA"
  value       = aws_iam_role.argocd_role.arn
}