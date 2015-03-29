terraform-azs
=============

Terraform module to get the AZs you have access to.

Reads a set of accounts from ~/.aws/credentials and queries
each region to find the AZs you can use in that region

Needs the aws cli installed to shell out to

Input variables:

  * region - E.g. eu-central-1
  * account - An account name from ~/.aws/credentials

Outputs:

  * primary
  * secondary
  * tertiary

Example use:

    module "az" {
      source = "github.com/bobtfish/terraform-as"
      region = "eu-central-1"
      account = "dev"
    }

    resource "aws_subnet" "primary-front" {
      availability_zone = "${module.az.primary}"
    }

