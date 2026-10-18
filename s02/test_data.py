"""Tests for the dataset generator (scripts/make_dataset.py).

Session 2 file, copied into the project's `tests/` folder. It checks two important
properties of the data automatically: (1) the table structure (schema) is correct,
(2) the data generation is reproducible.
Run: `make test` or `uv run pytest -q`. The same tests also run in pre-commit (on push) and
later in CI, so if someone breaks the `make` function it is found before the code is merged.

Why does `from make_dataset import make` work? Because pyproject.toml has the setting
`pythonpath = ["scripts"]`, so pytest adds the scripts folder to the import path.
The explanation in Persian is in CODE.md.
"""

import pandas as pd

from make_dataset import make

# The set of columns we expect. A set has no order, so the column order does not matter.
EXPECTED_COLUMNS = {
    "tenure_months",
    "monthly_charges",
    "contract",
    "internet_service",
    "payment_method",
    "support_calls",
    "churn",
}


def test_dataset_schema():
    """The generated table has exactly the expected columns, row count and 0/1 target.

    If someone removes or renames a column, the model and later services (which expect
    these names) break; this test tells us early. `<=` between two sets means "is a subset
    of": the target column may contain only 0 and 1.
    """
    df = make(rows=200, seed=1)
    assert set(df.columns) == EXPECTED_COLUMNS
    assert len(df) == 200
    assert set(df["churn"].unique()) <= {0, 1}


def test_dataset_is_reproducible():
    """Same seed -> identical DataFrame (the basis of reproducible ML).

    With the same seed the data must be exactly the same. Without this, two students (or
    two runs) get different numbers and comparing models is meaningless.
    `assert_frame_equal` compares two tables cell by cell and prints the exact difference
    (unlike `==`, which returns a table for a DataFrame, not one True/False).
    """
    pd.testing.assert_frame_equal(make(200, seed=42), make(200, seed=42))
