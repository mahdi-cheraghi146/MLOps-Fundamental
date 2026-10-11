"""Baseline training: logistic regression on the churn dataset."""

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

TARGET = "churn"


def build_model(X: pd.DataFrame, C: float, max_iter: int) -> Pipeline:
    num = X.select_dtypes("number").columns.tolist()
    cat = [c for c in X.columns if c not in num]
    pre = ColumnTransformer(
        [
            ("num", StandardScaler(), num),
            ("cat", OneHotEncoder(handle_unknown="ignore"), cat),
        ]
    )
    return Pipeline([("pre", pre), ("clf", LogisticRegression(C=C, max_iter=max_iter))])


def main(config: str) -> dict:
    p = yaml.safe_load(open(config))
    df = pd.read_csv(p["data"]["raw_path"])
    X, y = df.drop(columns=[TARGET]), df[TARGET]
    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=p["data"]["test_size"], random_state=p["data"]["seed"], stratify=y
    )

    model = build_model(X_tr, **p["train"]).fit(X_tr, y_tr)
    proba = model.predict_proba(X_te)[:, 1]
    metrics = {
        "roc_auc": round(roc_auc_score(y_te, proba), 4),
        "f1": round(f1_score(y_te, proba > 0.5), 4),
    }

    pathlib.Path("models").mkdir(exist_ok=True)
    joblib.dump(model, "models/model.joblib")
    pathlib.Path("metrics.json").write_text(json.dumps(metrics, indent=2))
    print(metrics)
    return metrics


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="configs/params.yaml")
    main(ap.parse_args().config)
