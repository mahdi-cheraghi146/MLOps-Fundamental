"""Tests for the model-building code (src/churn/train.py).

Session 2 file, copied into the project's `tests/` folder. It has one ready test; the
fourth test of the project (unseen category) is written by the student in the lab
(see the TODO at the bottom). Run: `uv run pytest -q`. Pipeline tests (Session 5) and
tracking tests (Session 6) are added next to these.
The explanation in Persian is in CODE.md.
"""

from churn.train import TARGET, build_model
from make_dataset import make


def _xy(rows=400, seed=1):
    """Helper (not a test, name starts with underscore): small X, y for the tests.

    pytest runs only functions whose names start with `test_`, so this helper is not
    collected as a test.

    Returns:
        The pair (X, y): the feature table and the target column.
    """
    df = make(rows, seed)
    return df.drop(columns=[TARGET]), df[TARGET]


def test_model_trains_and_predicts_probabilities():
    """The pipeline fits and `predict_proba` returns one valid probability per row.

    The minimum we expect from a model: it trains without errors and gives one probability
    per row. A probability must be between 0 and 1; if not, something in the pipeline is broken.
    """
    X, y = _xy()
    model = build_model(X, C=1.0, max_iter=200).fit(X, y)
    # The second column of predict_proba = probability that the customer churns.
    proba = model.predict_proba(X)[:, 1]
    assert len(proba) == len(X)
    # The condition is checked for every array element; .all() asks "are all of them True?"
    assert ((proba >= 0) & (proba <= 1)).all()


# TODO (Lab 2, step 3): write the 4th test yourself.
# Idea: a customer with a contract type the model never saw in training
# (e.g. "weekly") must not crash predict(). Name it test_unseen_category_does_not_crash.
