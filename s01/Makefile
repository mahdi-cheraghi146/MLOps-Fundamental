.PHONY: data train

data:
	uv run python scripts/make_dataset.py

train:
	uv run python -m churn.train --config configs/params.yaml
