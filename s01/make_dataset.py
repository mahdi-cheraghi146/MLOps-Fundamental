"""Generate a synthetic, reproducible customer-churn dataset.

--drift shifts the customer population (used in later sessions for data
versioning and drift detection demos).
"""

import argparse
import pathlib

import numpy as np
import pandas as pd


def make(rows: int, seed: int, drift: bool = False) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    contract = rng.choice(["month-to-month", "one-year", "two-year"], rows, p=[0.55, 0.25, 0.20])
    tenure = rng.gamma(2.0, 12.0, rows).clip(1, 72).round()
    charges = rng.normal(70, 20, rows).clip(18, 120).round(2)
    if drift:  # newer, more expensive, less loyal customers
        tenure = (tenure * 0.6).clip(1, 72).round()
        charges = (charges + 15).clip(18, 140).round(2)
    df = pd.DataFrame(
        {
            "tenure_months": tenure,
            "monthly_charges": charges,
            "contract": contract,
            "internet_service": rng.choice(["dsl", "fiber", "none"], rows, p=[0.4, 0.45, 0.15]),
            "payment_method": rng.choice(["card", "bank_transfer", "cash"], rows),
            "support_calls": rng.poisson(1.5, rows),
        }
    )
    logit = (
        -1.0
        - 0.05 * df.tenure_months
        + 0.03 * (df.monthly_charges - 70)
        + 1.2 * (df.contract == "month-to-month")
        + 0.35 * df.support_calls
        + 0.4 * (df.internet_service == "fiber")
    )
    df["churn"] = (rng.random(rows) < 1 / (1 + np.exp(-logit))).astype(int)
    return df


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows", type=int, default=5000)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--drift", action="store_true")
    ap.add_argument("--out", default="data/raw/churn.csv")
    a = ap.parse_args()
    pathlib.Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    df = make(a.rows, a.seed, a.drift)
    df.to_csv(a.out, index=False)
    print(f"wrote {len(df)} rows to {a.out} (churn rate {df.churn.mean():.1%})")
