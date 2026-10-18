"""Baseline training: logistic regression on the churn dataset.

Session 1 file. It trains the first model of the project: a Logistic Regression that
predicts the probability that a customer leaves (churn). We call it the baseline: the
simplest reasonable model, which better models are compared with later.

How to run (from the project root, ~/work/churn-mlops):

    make train
    # same as: uv run python -m churn.train --config configs/params.yaml

Inputs:
  - configs/params.yaml (data path, test_size, seed, C, max_iter, threshold)
  - data/raw/churn.csv, created by scripts/make_dataset.py

Outputs:
  - models/model.joblib  the trained model (the whole pipeline, preprocessing included)
  - metrics.json         two evaluation numbers: roc_auc and f1
  - the metrics are also printed

Later sessions: in Session 5 this logic is split into three stages (preprocess, train,
evaluate) in src/churn/ and DVC runs them in order; in Session 6 the evaluation is logged
to MLflow. `build_model` stays unchanged until Session 8.
The line-by-line explanation in Persian is in CODE.md.
"""

import argparse
import json
import pathlib

import joblib
import pandas as pd
import yaml
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import f1_score, roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

# Name of the target column (what we want to predict). Defined once so it is the same everywhere.
TARGET = "churn"


def build_model(X: pd.DataFrame, C: float, max_iter: int) -> Pipeline:
    """Build (but do not train) the sklearn Pipeline: preprocessing + logistic regression.

    This function only builds the model; `fit` is called outside. A Pipeline has two steps
    in a row: first the column preprocessing, then the classifier. The preprocessing is saved
    together with the model, so at serving time the same transformations are applied to new
    data and "train/serve skew" cannot happen.

    Args:
        X: feature table (without the target). Used only to detect the column types.
        C: inverse of regularization strength. Smaller C = simpler, more careful model.
        max_iter: max optimizer steps; if too small you get a ConvergenceWarning.

    Returns:
        An untrained `Pipeline`; call `.fit(X, y)` to train it.
    """
    # Find numeric columns from the dtype; treat all other columns as categorical.
    num = X.select_dtypes("number").columns.tolist()
    cat = [c for c in X.columns if c not in num]
    # ColumnTransformer gives each group of columns its own transformation
    # (name, transformer, columns):
    #   numeric: StandardScaler makes the mean 0 and the std 1 (same scale for all).
    #   categorical: OneHotEncoder turns every category into a 0/1 column, because the
    #     model understands only numbers.
    #     handle_unknown="ignore": a category not seen in training does not raise an error;
    #     all its columns become zero (the Session 2 test checks exactly this).
    pre = ColumnTransformer(
        [
            ("num", StandardScaler(), num),
            ("cat", OneHotEncoder(handle_unknown="ignore"), cat),
        ]
    )
    # Pipeline: the output of step "pre" is the direct input of step "clf".
    return Pipeline([("pre", pre), ("clf", LogisticRegression(C=C, max_iter=max_iter))])


def main(config: str) -> dict:
    """Run the whole baseline: read data, split, train, score, save model and metrics.

    Everything happens in this one function (Session 5 splits it into three files).

    Args:
        config: path of the YAML settings file (for example `configs/params.yaml`).

    Returns:
        The metrics dict, for example `{"roc_auc": 0.802, "f1": 0.5969}`.
    """
    # Read the settings: yaml.safe_load turns the file into a Python dict (safe = it reads
    # plain data only and never runs code). No `with` is used because the program is short.
    p = yaml.safe_load(open(config))
    df = pd.read_csv(p["data"]["raw_path"])
    # X = features (all columns except the target), y = the right answer (0 or 1).
    X, y = df.drop(columns=[TARGET]), df[TARGET]
    # Hold out test data: never evaluate a model on data it was trained on.
    #   random_state: fixed seed, so the same split repeats and results can be compared.
    #   stratify=y: the 0/1 ratio stays about the same in train and test; without it the
    #   test set may randomly get too many or too few churned customers and bend the score.
    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=p["data"]["test_size"], random_state=p["data"]["seed"], stratify=y
    )

    # **p["train"] unpacks the dict {"C": 1.0, "max_iter": 500} into keyword arguments,
    # like build_model(X_tr, C=1.0, max_iter=500). fit is called on the training data only.
    model = build_model(X_tr, **p["train"]).fit(X_tr, y_tr)
    # predict_proba gives two columns per row: [probability of 0, probability of 1].
    # We want the second one (probability of churn), so [:, 1].
    proba = model.predict_proba(X_te)[:, 1]
    metrics = {
        # ROC-AUC works with the probabilities (no threshold): how well it separates
        # customers who left from those who stayed.
        "roc_auc": round(roc_auc_score(y_te, proba), 4),
        #"f1": round(f1_score(y_te, proba > 0.5), 4),
        # F1 needs a hard 0/1 prediction, so we compare the probability with a threshold:
        # proba > threshold means "we predict the customer leaves". It comes from params.yaml.
        "f1": round(f1_score(y_te, proba > p["eval"]["threshold"]), 4),
    }

    # exist_ok=True: no error if the models folder already exists.
    pathlib.Path("models").mkdir(exist_ok=True)
    # joblib saves the model to disk so it can be loaded later without retraining.
    joblib.dump(model, "models/model.joblib")
    # indent=2 writes the JSON file in a readable way.
    pathlib.Path("metrics.json").write_text(json.dumps(metrics, indent=2))
    print(metrics)
    return metrics


# Runs only when the file is executed directly (python -m churn.train), not when a test imports it.
if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="configs/params.yaml")
    main(ap.parse_args().config)
