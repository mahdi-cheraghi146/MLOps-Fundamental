# Minimal MLflow tracking server with S3 (SeaweedFS) artifact support
ARG PYTHON_BASE_IMAGE=python:3.12-slim-bookworm
FROM ${PYTHON_BASE_IMAGE}
ARG MLFLOW_VERSION=3.16.0
ARG BOTO3_VERSION=1.43.95
# PIP_INDEX_URL / PIP_FIND_LINKS can point at the classroom mirror or a wheelhouse when offline
RUN pip install --no-cache-dir "mlflow==${MLFLOW_VERSION}" "boto3==${BOTO3_VERSION}" \
 && useradd --uid 1000 --create-home mlflow && mkdir /mlflow && chown mlflow /mlflow
USER mlflow
WORKDIR /mlflow
EXPOSE 5000
