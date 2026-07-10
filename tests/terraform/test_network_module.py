import unittest
from pathlib import Path


NETWORK_MODULE = Path("terraform/modules/network")


class NetworkModuleTests(unittest.TestCase):
    def test_module_defines_private_network_and_s3_endpoint(self):
        configuration = (NETWORK_MODULE / "main.tf").read_text()

        self.assertIn('resource "aws_vpc" "this"', configuration)
        self.assertIn('resource "aws_subnet" "private"', configuration)
        self.assertIn('resource "aws_vpc_endpoint" "s3"', configuration)
        self.assertIn('service_name      = "com.amazonaws.${var.aws_region}.s3"', configuration)

    def test_nat_gateway_is_disabled_by_default(self):
        variables = (NETWORK_MODULE / "variables.tf").read_text()

        self.assertIn('variable "enable_nat_gateway"', variables)
        self.assertIn('default     = false', variables)

    def test_security_groups_do_not_allow_public_ingress(self):
        configuration = (NETWORK_MODULE / "main.tf").read_text()

        self.assertIn('resource "aws_security_group" "glue"', configuration)
        self.assertIn('resource "aws_security_group" "redshift"', configuration)
        self.assertNotIn('cidr_blocks = ["0.0.0.0/0"]', configuration)


if __name__ == "__main__":
    unittest.main()
