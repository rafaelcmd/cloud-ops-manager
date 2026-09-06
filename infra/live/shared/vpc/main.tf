# The platform's only network, and the first stack to apply. Everything else
# runs inside it and finds it through the /idp/shared/vpc/* parameters the
# module publishes.
#
# Values are literal rather than variables: there is one VPC, it is not
# parameterized per environment, and a second one would be a new stack.

module "vpc" {
  source = "../../../modules/aws/vpc"

  aws_region           = "us-east-1"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
  project              = "internal-developer-platform"
  environment          = "shared"
}
