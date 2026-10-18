# This Makefile holds shortcuts: instead of a long command we type `make data` or `make train`.
# Warning: recipe lines (the commands) must start with a TAB character, not spaces.

# data and train are names of jobs, not files; .PHONY tells make to always run them.
.PHONY: data train

# Create the synthetic data in data/raw/churn.csv (the script defaults are used).
data:
	uv run python scripts/make_dataset.py

# Train the baseline model; writes models/model.joblib and metrics.json.
# Settings come from configs/params.yaml.
train:
	uv run python -m churn.train --config configs/params.yaml
