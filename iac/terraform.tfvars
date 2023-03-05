# codecommit
source_repo_branch = "master"
project_name       = "pet-clinic-application"

# codebuild
s3_bucket_cache_name    = "pet-clinic-application-build-cache"
s3_bucket_artifact_name = "pet-clinic-application-build-artifact"

# VPC
cidr_block = "10.0.0.0/16" # Total 65,536 IPs
public_cidr = {
  "A" = ["10.0.0.0/24", 0]
  "B" = ["10.0.1.0/24", 1]
}
private_cidr = {              # If the private subnets increase then a manual change would require in vpc.tf for aws_vpc_endpoint_interface resource.
  "A" = ["10.0.20.0/24", 0]   # Also, another manual change would require in security-groups.tf for aws_security_group_endpoint resource.
  "B" = ["10.0.21.0/24", 1]
}
gateway_endpoint_services  = ["s3", "dynamodb"]
gateway_endpoint_interface = ["ecr.api", "ecr.dkr"]

endpoint_interface_ports = [443]