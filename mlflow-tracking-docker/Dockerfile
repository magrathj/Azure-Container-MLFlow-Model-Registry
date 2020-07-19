FROM python:3.7.0-stretch

# Set the working directory to /
WORKDIR /
# Copy the directory contents into the container at /
COPY ./ /

# Install any needed packages specified in requirements.txt
RUN apt-get update && pip install -r requirements.txt && chmod +x /setup_mlflow.sh
RUN apt-get install -y sqlite3 libsqlite3-dev
RUN mkdir /db
RUN /usr/bin/sqlite3 /db/mlflow.db

# REQUIRED:
# ENV AZURE_STORAGE_ACCESS_KEY <access_key>
# ENV MLFLOW_SERVER_FILE_STORE
# ENV MLFLOW_SERVER_DEFAULT_ARTIFACT_ROOT

# OPTIONAL (if unset, will set to default):
ENV MLFLOW_SERVER_HOST 0.0.0.0
ENV MLFLOW_SERVER_PORT 5000
ENV MLFLOW_SERVER_WORKERS 4

CMD ["/setup_mlflow.sh"]