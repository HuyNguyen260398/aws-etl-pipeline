import unittest
from pathlib import Path


DATA_LAKE_MODULE = Path("terraform/modules/data_lake")


class DataLakeModuleTests(unittest.TestCase):
    def test_module_defines_data_lake_and_glue_asset_buckets(self):
        configuration = (DATA_LAKE_MODULE / "main.tf").read_text()

        self.assertIn('resource "aws_s3_bucket" "data_lake"', configuration)
        self.assertIn('resource "aws_s3_bucket" "glue_assets"', configuration)
        self.assertIn('resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake"', configuration)
        self.assertIn('bucket_key_enabled = true', configuration)

    def test_module_blocks_public_access_and_requires_tls(self):
        configuration = (DATA_LAKE_MODULE / "main.tf").read_text()

        self.assertIn('resource "aws_s3_bucket_public_access_block" "data_lake"', configuration)
        self.assertIn('aws:SecureTransport', configuration)
        self.assertIn('resource "aws_s3_bucket_ownership_controls" "data_lake"', configuration)

    def test_module_exposes_all_lake_zone_prefixes(self):
        outputs = (DATA_LAKE_MODULE / "outputs.tf").read_text()

        for prefix in ["raw/", "clean/", "analytics/", "quarantine/", "athena-results/", "glue-assets/"]:
            self.assertIn(prefix, outputs)

    def test_manifest_event_filter_is_scoped_to_raw_manifests(self):
        configuration = (DATA_LAKE_MODULE / "main.tf").read_text()

        self.assertIn('filter_prefix       = "raw/"', configuration)
        self.assertIn('filter_suffix       = "manifest.json"', configuration)


if __name__ == "__main__":
    unittest.main()
