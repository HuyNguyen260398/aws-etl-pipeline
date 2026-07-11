#!/usr/bin/env bash
set -euo pipefail

DATASET_SLUG="uditjain13/music-streaming-habits-2026"

if [[ -z "${KAGGLE_USERNAME:-}" ]]; then
  echo "KAGGLE_USERNAME must be set in the environment." >&2
  exit 1
fi

if [[ -z "${KAGGLE_KEY:-}" ]]; then
  echo "KAGGLE_KEY must be set in the environment." >&2
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <ignored-destination-directory>" >&2
  exit 1
fi

destination="$1"
if ! git check-ignore -q -- "$destination/"; then
  echo "Destination must be Git-ignored (for example, data/downloads/kaggle)." >&2
  exit 1
fi

mkdir -p "$destination"
kaggle datasets download --dataset "$DATASET_SLUG" --path "$destination" --unzip
