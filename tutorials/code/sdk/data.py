import google.cloud.storage as gcs
from google.cloud import resourcemanager_v3
from google.auth import load_credentials_from_dict
from enum import Enum
import pandas as pd
from urllib.parse import urlparse
import os
import logging
import io
import boto3 # Added for S3 support

logger = logging.getLogger(__name__)

class Gcp():
    def __init__(self):
        self.project_id = ""
        self.pool_name = ""
        self.project_number = ""
        self.service_account = ""
        
    def init(self, project_id, pool_name, service_account):
        self.project_id = project_id
        self.pool_name = pool_name
        self.service_account = service_account
        # In a non-GCP environment, we might not be able to get this.
        try:
            self.project_number = self.get_project_number(project_id)
        except Exception:
            logger.warning("Could not get GCP project number. This is expected in a non-GCP environment.")
            self.project_number = ""

    def get_project_number(self, project_id):
        client = resourcemanager_v3.ProjectsClient()
        project = client.get_project(name=f"projects/{project_id}")
        return project.name.split('/')[1]

gcp = Gcp()

class Stage(Enum):
    UNKNOWN = 0
    STAGE1 = 1
    STAGE2 = 2

class DataRepo():
    def __init__(self, stage_1_bucket, stage_2_bucket):
        self.stage1 = RemoteStorage.init(Stage.STAGE1, stage_1_bucket)
        self.stage2 = RemoteStorage.init(Stage.STAGE2, stage_2_bucket)

    def get_data(self, filename):
        # EXECUTION_STAGE is set by the Manatee environment for stage-2 (secure) execution
        # For local testing in Jupyter, we assume stage-1
        stage_env = os.getenv('EXECUTION_STAGE', '1').strip('\'"')
        
        try:
            stage = int(stage_env)
        except (ValueError, TypeError):
            logger.warning(f"Invalid EXECUTION_STAGE: {stage_env}. Defaulting to stage 1.")
            stage = 1

        if stage == 1:
            return self.stage1.get_data(filename)
        elif stage == 2:
            return self.stage2.get_data(filename)
        else:
            logger.warning(f"Unknown stage: {stage}. Cannot get data.")
            return None
        
    def get_stage(self):
        # This method seems to be unused in the original code, but keeping it for compatibility
        stage_env = os.getenv('EXECUTION_STAGE', '1').strip('\'"')
        try:
            return int(stage_env)
        except (ValueError, TypeError):
            return 1


class RemoteStorage():
    def __init__(self):
        pass

    def get_data(self, filename):
        pass
    
    @staticmethod
    def init(stage, url):
        try:
            o = urlparse(url, allow_fragments=False)
        except Exception as e:
            raise ValueError("Invalid URL: " + url)
        
        if o.scheme == "gs":
            return RemoteStorageGCS(stage, o.netloc, o.path)
        elif o.scheme == "s3":
            # Now implemented for MinIO
            return RemoteStorageS3(stage, o.netloc, o.path)
        elif o.scheme == "https":
            raise NotImplementedError("HTTPS storage not implemented")
        else:
            # Support local file paths for testing
            logger.info(f"Scheme '{o.scheme}' not recognized, treating as a local file path.")
            return RemoteStorageLocal(stage, url)

# New class for S3/MinIO support
class RemoteStorageS3(RemoteStorage):
    def __init__(self, stage, bucket_name, path):
        super().__init__()
        self.bucket = bucket_name
        self.path = path

        # When running in a pod in the cluster, we can use the internal service name.
        # When running locally (e.g. in local Jupyter), you might need to port-forward
        # and change this to http://localhost:9000
        minio_endpoint = os.getenv("S3_ENDPOINT_URL", "http://minio-service.manatee.svc.cluster.local:9000")
        
        # Default credentials for the local MinIO deployment
        minio_access_key = "minioadmin"
        minio_secret_key = "minioadmin"

        self.client = boto3.client(
            's3',
            endpoint_url=minio_endpoint,
            aws_access_key_id=minio_access_key,
            aws_secret_access_key=minio_secret_key
        )

    def get_data(self, filename):
        full_path = os.path.join(self.path.lstrip('/'), filename).lstrip('/')
        logger.info(f"Getting data from S3: bucket={self.bucket}, key={full_path}")
        try:
            response = self.client.get_object(Bucket=self.bucket, Key=full_path)
            data = response['Body'].read().decode('utf-8')
            return data
        except Exception as e:
            logger.error(f"Error getting data from S3: {e}")
            raise

# Added for completeness, to handle local file paths if needed
class RemoteStorageLocal(RemoteStorage):
    def __init__(self, stage, path):
        super().__init__()
        self.path = path

    def get_data(self, filename):
        full_path = os.path.join(self.path, filename)
        logger.info(f"Getting data from local file: {full_path}")
        with open(full_path, 'r') as f:
            return f.read()

class RemoteStorageGCS(RemoteStorage):
    def __init__(self, stage, bucket_name, path):
        super().__init__()
        self.bucket = bucket_name
        self.path = path

        if stage == Stage.STAGE1:
            self.client = gcs.Client()
        elif stage == Stage.STAGE2:
            # This part is for the secure TEE environment on GCP
            credentials_dict = {
              "type": "external_account",
              "audience": f"//iam.googleapis.com/projects/{gcp.project_number}/locations/global/workloadIdentityPools/{gcp.pool_name}/providers/attestation-verifier",
              "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
              "token_url": "https://sts.googleapis.com/v1/token",
              "credential_source": {
                "file": "/run/container_launcher/attestation_verifier_claims_token"
              },
              "service_account_impersonation_url": f"https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{gcp.service_account}@{gcp.project_id}.iam.gserviceaccount.com:generateAccessToken",
            }
            credentials, _ = load_credentials_from_dict(credentials_dict)
            self.client = gcs.Client(credentials=credentials)

    def get_data(self, filename):
        full_path = os.path.join(self.path.lstrip('/'), filename).lstrip('/')
        logger.info(f"Getting data from GCS: bucket={self.bucket}, key={full_path}")
        try:
            blob = self.client.get_bucket(self.bucket).blob(full_path)
            data = blob.download_as_text()
            return data
        except Exception as e:
            logger.error(f"Error getting data from GCS: {e}")
            raise