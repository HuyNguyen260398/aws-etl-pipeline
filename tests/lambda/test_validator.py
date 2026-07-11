import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path("src/lambda/validator/app.py")


def load_module():
    spec = importlib.util.spec_from_file_location("validator", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ManifestValidationTests(unittest.TestCase):
    def test_valid_manifest_returns_glue_job_arguments(self):
        module = load_module()
        result = module.validate_manifest({
            "bucket": "music-etl-dev-data",
            "key": "raw/source=kaggle/ingest_date=2026-07-11/manifest.json",
        })

        self.assertEqual(result["raw_prefix"], "raw/source=kaggle/ingest_date=2026-07-11/")
        self.assertEqual(result["ingest_date"], "2026-07-11")

    def test_invalid_key_is_rejected(self):
        module = load_module()

        with self.assertRaises(ValueError):
            module.validate_manifest({"bucket": "bucket", "key": "raw/event.json"})


if __name__ == "__main__":
    unittest.main()
