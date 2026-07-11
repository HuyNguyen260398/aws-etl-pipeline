import unittest
from pathlib import Path


OBSERVABILITY_MODULE = Path("terraform/modules/observability")


class ObservabilityModuleTests(unittest.TestCase):
    def test_lambda_and_glue_have_named_log_groups(self):
        configuration = (OBSERVABILITY_MODULE / "main.tf").read_text()

        for log_group in ("lambda", "raw_to_clean", "clean_to_analytics"):
            self.assertIn(f'resource "aws_cloudwatch_log_group" "{log_group}"', configuration)

    def test_every_alarm_declares_missing_data_behavior(self):
        configuration = (OBSERVABILITY_MODULE / "main.tf").read_text()

        alarm_count = configuration.count('resource "aws_cloudwatch_metric_alarm"')
        self.assertGreater(alarm_count, 0)
        self.assertEqual(alarm_count, configuration.count("treat_missing_data"))


if __name__ == "__main__":
    unittest.main()
