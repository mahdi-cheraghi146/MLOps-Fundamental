"""Generate a synthetic, reproducible customer-churn dataset.

--drift shifts the customer population (used in later sessions for data
versioning and drift detection demos).

Session 1 file. It creates fake customers of an internet/phone company. The target
column is `churn`: 1 means the customer left, 0 means the customer stayed.

Why synthetic data? There is no privacy problem, every student sees exactly the same
numbers (fixed seed), and we can create "drift" on purpose for later sessions.

How to run (from the project root, ~/work/churn-mlops):

    make data
    uv run python scripts/make_dataset.py --rows 8000 --seed 42 --out data/raw/churn.csv
    uv run python scripts/make_dataset.py --drift --out data/raw/churn_drift.csv

Input: command-line arguments only (--rows, --seed, --drift, --out).
Output: one CSV file (default data/raw/churn.csv). DVC versions it in Session 4 and the
`preprocess` stage reads it from Session 5 on. Tests import `make` from here
(pythonpath = ["scripts"] in pyproject.toml, Session 2).
The line-by-line explanation in Persian is in CODE.md.
"""

import argparse
import pathlib

import numpy as np
import pandas as pd


def make(rows: int, seed: int, drift: bool = False) -> pd.DataFrame:
    """Build the churn DataFrame in memory (no file is written here).

    Because nothing is written to disk, tests can call it fast and safely.

    Args:
        rows: number of customers (rows of the table).
        seed: start value of the random generator. Same seed = exactly the same data.
        drift: if True, create newer, more expensive, less loyal customers.

    Returns:
        A DataFrame with feature columns and the target column `churn` (0 or 1).
    """
    # Modern numpy random generator. A fixed seed always gives the same random numbers.
    rng = np.random.default_rng(seed)
    # Pick a contract type for every customer. p holds the probabilities (they sum to 1).
    contract = rng.choice(["month-to-month", "one-year", "two-year"], rows, p=[0.55, 0.25, 0.20])
    # Months as a customer: a gamma distribution is always positive and skewed to the right
    # (many new customers). clip keeps it between 1 and 72, round makes it a whole number.
    tenure = rng.gamma(2.0, 12.0, rows).clip(1, 72).round()
    # Monthly bill: normal distribution (mean 70, std 20), limited to 18..120, 2 decimals.
    charges = rng.normal(70, 20, rows).clip(18, 120).round(2)
    if drift:  # newer, more expensive, less loyal customers
        # With drift the tenure is 40% shorter and the bill is 15 units higher.
        tenure = (tenure * 0.6).clip(1, 72).round()
        charges = (charges + 15).clip(18, 140).round(2)
    df = pd.DataFrame(
        {
            "tenure_months": tenure,
            "monthly_charges": charges,
            "contract": contract,
            "internet_service": rng.choice(["dsl", "fiber", "none"], rows, p=[0.4, 0.45, 0.15]),
            # No p given: all three options are equally likely.
            "payment_method": rng.choice(["card", "bank_transfer", "cash"], rows),
            # Support calls: Poisson distribution (counts of events, mean 1.5).
            "support_calls": rng.poisson(1.5, rows),
        }
    )
    # The raw churn score (logit). Each line is one business rule:
    # longer tenure lowers the risk, a bill above 70 raises it, and a month-to-month
    # contract, more support calls and fiber internet also raise it.
    # (df.contract == "...") is a True/False column; in a product it acts like 1 or 0.
    logit = (
        -1.0
        - 0.05 * df.tenure_months
        + 0.03 * (df.monthly_charges - 70)
        + 1.2 * (df.contract == "month-to-month")
        + 0.35 * df.support_calls
        + 0.4 * (df.internet_service == "fiber")
    )
    # The sigmoid 1/(1+exp(-logit)) turns any number into a probability between 0 and 1.
    # Then we draw a random number in [0, 1): if it is smaller than the probability, the
    # customer churned (1). astype(int) converts True/False to 1/0.
    df["churn"] = (rng.random(rows) < 1 / (1 + np.exp(-logit))).astype(int)
    return df


# This block runs only when the file is executed directly with python, not when imported.
if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows", type=int, default=5000)
    ap.add_argument("--seed", type=int, default=42)
    # action="store_true": no value needed; writing --drift alone makes it True.
    ap.add_argument("--drift", action="store_true")
    ap.add_argument("--out", default="data/raw/churn.csv")
    a = ap.parse_args()
    # Create the target folder (for example data/raw) if missing; no error if it exists.
    pathlib.Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    df = make(a.rows, a.seed, a.drift)
    df.to_csv(a.out, index=False)  # index=False: do not write the row numbers to the file
    # In the f-string, :.1% prints the churn rate as a percentage with one decimal.
    print(f"wrote {len(df)} rows to {a.out} (churn rate {df.churn.mean():.1%})")
