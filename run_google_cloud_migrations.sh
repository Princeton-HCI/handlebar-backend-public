#!/bin/bash

# Check if environment argument is provided
if [ "$1" != "production" ] && [ "$1" != "staging" ]; then
  echo "Error: Please specify either 'production' or 'staging' as an argument"
  echo "Usage: $0 [production|staging]"
  exit 1
fi

# Set environment-specific variables
if [ "$1" = "production" ]; then
  export CLOUD_SQL_CONNECTION_ID="up-ist-wao:us-east1:handlebar-db"
  export DB_NAME="handlebar_db"
  read -p "Are you sure you want to run migrations on the **PRODUCTION** database? (y/n): " confirm
  if [ "$confirm" != "y" ]; then
    echo "Aborting..."
    exit 1
  fi
else
  echo "There is currently no staging database for Handlebar, please use the production environment".
  exit 1
fi

# --- Configuration ---
# All set based on your provided information
# ---------------------

# GCP Project ID
export PROJECT_ID="up-ist-wao"

# GCP Region where your Cloud Run Service and Cloud SQL instance are located
export REGION="us-east1"
echo
echo "Go to https://console.cloud.google.com/run?hl=en&project=up-ist-wao (with an authenticated GCP account),"
echo "click on the service you want to run migrations for, go to the 'Revisions' tab, and find the image path on the right panel."
echo 
read -p "Enter the full Docker image URL (including @sha256 digest): " FULL_IMAGE_URL

# Database Details
echo
echo "In the same panel as earlier, scroll down and find the 'Environment Variables' section."
echo 
read -s -p "Enter the environment variable DB_PASSWORD: " DB_PASSWORD; echo
export DB_USERNAME="postgres"

# Get SECRET_KEY_BASE
read -s -p "Enter the environment variable SECRET_KEY_BASE: " SECRET_KEY_BASE; echo

# No VPC Connector for this setup
export VPC_CONNECTOR="" # This will be an empty string, so the flag won't be added to the gcloud command.

# --- Script Logic ---
# You generally don't need to modify anything below this line
# --------------------

# Command to execute migrations within the Docker container
# This uses your simplified migration command via Elixir release
# The path is relative to the working directory in the container, usually /app
export MIGRATION_COMMAND="/app/bin/migrate"

echo
echo "--- Starting Elixir Migrations on Cloud Run ---"
echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Image: ${FULL_IMAGE_URL}"
echo "Cloud SQL Instance: ${CLOUD_SQL_CONNECTION_ID}"
echo "Database: ${DB_NAME} (User: ${DB_USERNAME})"
echo "Migration Command: ${MIGRATION_COMMAND}"
echo
echo "This is a three-step process where we verify gcloud authentication, create the migration job, and then execute it."
echo "-------------------------------------------------"

# 1. Verify gcloud authentication
echo
echo "1. Verifying gcloud authentication..."
gcloud auth print-access-token > /dev/null
if [ $? -ne 0 ]; then
  echo "Error: gcloud authentication is not active. Please run 'gcloud auth login'."
  exit 1
fi
echo "gcloud authenticated."

# Define the job name (a unique name for this one-off execution)
JOB_NAME="migrate-handlebar-backend-$(date +%Y%m%d%H%M%S)"

# Construct the gcloud command arguments as an array
# NOTE: Always pass --project; gcloud otherwise uses `gcloud config get-value project`,
# which may differ from PROJECT_ID above and will use that project's Cloud Run service agent.
GCLOUD_ARGS=(
  "--project=${PROJECT_ID}"
  "run" "jobs" "create" "${JOB_NAME}"
  "--image=${FULL_IMAGE_URL}"
  "--region=${REGION}"
  "--command=/bin/bash"
  "--args=-c,${MIGRATION_COMMAND}"
  "--set-cloudsql-instances=${CLOUD_SQL_CONNECTION_ID}"
  "--set-env-vars=DB_USERNAME=${DB_USERNAME},DB_PASSWORD=${DB_PASSWORD},DB_NAME=${DB_NAME},CLOUD_SQL_CONNECTION_ID=${CLOUD_SQL_CONNECTION_ID},SECRET_KEY_BASE=${SECRET_KEY_BASE}"
  "--cpu=1"
  "--memory=512Mi"
  "--max-retries=0"
)

# Add VPC connector if specified (though not needed for the current config)
if [ -n "${VPC_CONNECTOR}" ]; then
  GCLOUD_ARGS+=( "--vpc-connector=${VPC_CONNECTOR}" )
fi

# 2. Create and Execute the Cloud Run Job
echo
echo "2. Creating Cloud Run Job: ${JOB_NAME}..."
# Use "$GCLOUD_ARGS[@]" to correctly expand the array into separate arguments
echo "--- START GCLOUD OUTPUT ---"
gcloud "${GCLOUD_ARGS[@]}"
create_status=$?
echo "--- END GCLOUD OUTPUT ---"
if [ "$create_status" -ne 0 ]; then
  echo "Error: Cloud Run Job creation failed. Please check the command output and Cloud Logging for details."
  exit 1
else
  echo "Cloud Run Job '${JOB_NAME}' created successfully."
  echo
  echo "3. Executing Cloud Run Job and monitoring (Ctrl+C to stop waiting):"
  echo "--- START GCLOUD OUTPUT ---"

  if gcloud --project="${PROJECT_ID}" run jobs execute "${JOB_NAME}" --region "${REGION}" --wait; then
    echo "--- END GCLOUD OUTPUT ---"
    echo "Migration Job '${JOB_NAME}' completed successfully."
  else
    echo "--- END GCLOUD OUTPUT ---"
    echo "Migration Job '${JOB_NAME}' failed. Check Cloud Logging for errors."
  fi

  echo
  echo "You can check the detailed logs in the GCP Console under Cloud Run -> JOBS -> ${JOB_NAME} -> Logs tab."
  echo "This job definition will remain; you can delete it if no longer needed:"
  echo "  gcloud --project=${PROJECT_ID} run jobs delete ${JOB_NAME} --region ${REGION}"
fi

echo "--- Script Finished ---"