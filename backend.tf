terraform {
  backend "s3" {
    bucket = "pod8s3bucket"
    key    = "Pod8/production/terraform.tfstate"
    region = "us-east-1"
  }
}