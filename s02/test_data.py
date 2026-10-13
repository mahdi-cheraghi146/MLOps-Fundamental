import pandas as pd

from make_dataset import make

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
    df = make(rows=200, seed=1)
    assert set(df.columns) == EXPECTED_COLUMNS
    assert len(df) == 200
    assert set(df["churn"].unique()) <= {0, 1}


def test_dataset_is_reproducible():
    pd.testing.assert_frame_equal(make(200, seed=42), make(200, seed=42))
