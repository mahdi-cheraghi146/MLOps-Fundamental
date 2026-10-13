from churn.train import TARGET, build_model
from make_dataset import make


def _xy(rows=400, seed=1):
    df = make(rows, seed)
    return df.drop(columns=[TARGET]), df[TARGET]


def test_model_trains_and_predicts_probabilities():
    X, y = _xy()
    model = build_model(X, C=1.0, max_iter=200).fit(X, y)
    proba = model.predict_proba(X)[:, 1]
    assert len(proba) == len(X)
    assert ((proba >= 0) & (proba <= 1)).all()


# TODO (Lab 2, step 3): write the 4th test yourself.
# Idea: a customer with a contract type the model never saw in training
# (e.g. "weekly") must not crash predict(). Name it test_unseen_category_does_not_crash.
