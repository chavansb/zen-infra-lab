terraform {
  backend "s3" {
    bucket = "zen-pharma-terraform-state-chavansb"
    key    = "envs/dev/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}