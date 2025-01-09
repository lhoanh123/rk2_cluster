helm repo add apache-airflow https://airflow.apache.org
helm repo update
helm upgrade --install airflow apache-airflow/airflow --namespace mlops --create-namespace

# helm uninstall airflow --namespace mlops