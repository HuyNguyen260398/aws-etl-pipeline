import unittest
from pathlib import Path


IAM_MODULE = Path("terraform/modules/iam")
GOVERNANCE_MODULE = Path("terraform/modules/governance")


class GovernanceModuleTests(unittest.TestCase):
    def test_iam_module_defines_separate_service_roles(self):
        configuration = (IAM_MODULE / "main.tf").read_text()

        for role in ["lambda", "firehose", "glue", "redshift", "github_oidc", "analytics_reader"]:
            self.assertIn(f'resource "aws_iam_role" "{role}"', configuration)

    def test_governance_module_defines_lake_formation_databases_and_tags(self):
        configuration = (GOVERNANCE_MODULE / "main.tf").read_text()

        self.assertIn('resource "aws_glue_catalog_database" "raw"', configuration)
        self.assertIn('resource "aws_glue_catalog_database" "clean"', configuration)
        self.assertIn('resource "aws_glue_catalog_database" "analytics"', configuration)
        self.assertIn('resource "aws_lakeformation_lf_tag" "zone"', configuration)

    def test_analytics_reader_is_granted_only_analytics_database_access(self):
        configuration = (GOVERNANCE_MODULE / "main.tf").read_text()

        self.assertIn('resource "aws_lakeformation_permissions" "analytics_reader"', configuration)
        self.assertIn('database { name = aws_glue_catalog_database.analytics.name }', configuration)
        self.assertNotIn('aws_glue_catalog_database.raw.name }\n\n  permissions', configuration)
        self.assertNotIn('aws_glue_catalog_database.clean.name }\n\n  permissions', configuration)


if __name__ == "__main__":
    unittest.main()
