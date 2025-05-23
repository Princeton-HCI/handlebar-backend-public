#!/bin/bash

# --- Configuration ---
# All set based on your provided information
# ---------------------

# GCP Project ID
export PROJECT_ID="princeton-hci-wao-dsc"

# GCP Region where your Cloud Run Service and Cloud SQL instance are located
export REGION="us-central1"

# Full Docker image URL (already built and pushed)
# Note: Using the @sha256 digest ensures you run the *exact* image version.
# export FULL_IMAGE_URL="us-central1-docker.pkg.dev/princeton-hci-wao-dsc/cloud-run-source-deploy/dsc-api/dsc-api-service@sha256:7c39ab1751fa135ebce3daa0eaba814f3628c67ac662c676bfa6f299999999f9"
read -p "Enter the full Docker image URL (including @sha256 digest): " FULL_IMAGE_URL

# Elixir Release Name (from your _build/prod/rel/dsc/bin/migrate)
export ELIXIR_RELEASE_NAME="dsc"

# Cloud SQL Connection ID
export CLOUD_SQL_CONNECTION_ID="princeton-hci-wao-dsc:us-central1:drivers-seat"

# Database Details
read -s -p "Enter your Cloud SQL Database Password for 'postgres' user: " DB_PASSWORD; echo
export DB_USERNAME="postgres"
export DB_NAME="drivers_seat_coop_prod"

# Get SECRET_KEY_BASE
read -s -p "Enter your SECRET_KEY_BASE: " SECRET_KEY_BASE; echo

# No VPC Connector for this setup
export VPC_CONNECTOR="" # This will be an empty string, so the flag won't be added to the gcloud command.

# --- Script Logic ---
# You generally don't need to modify anything below this line
# --------------------

# Command to execute migrations within the Docker container
# This uses your simplified migration command via Elixir release
# The path is relative to the working directory in the container, usually /app
export MIGRATION_COMMAND="/app/bin/migrate"

echo "--- Starting Elixir Migrations on Cloud Run ---"
echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Image: ${FULL_IMAGE_URL}"
echo "Cloud SQL Instance: ${CLOUD_SQL_CONNECTION_ID}"
echo "Database: ${DB_NAME} (User: ${DB_USERNAME})"
echo "Migration Command: ${MIGRATION_COMMAND}"
echo "-------------------------------------------------"

# 1. Verify gcloud authentication (important for subsequent commands)
echo "Verifying gcloud authentication..."
gcloud auth print-access-token > /dev/null
if [ $? -ne 0 ]; then
  echo "Error: gcloud authentication is not active. Please run 'gcloud auth login'."
  exit 1
fi
echo "gcloud authenticated."

# Define the job name (a unique name for this one-off execution)
JOB_NAME="migrate-dsc-api-$(date +%Y%m%d%H%M%S)"

# Construct the gcloud command arguments as an array
# This is generally safer for complex commands with spaces and quotes
GCLOUD_ARGS=(
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
  "--execute-now"
)

# Add VPC connector if specified (though not needed for your current config)
if [ -n "${VPC_CONNECTOR}" ]; then
  GCLOUD_ARGS+=( "--vpc-connector=${VPC_CONNECTOR}" )
fi

# 2. Create and Execute the Cloud Run Job
echo "Creating and executing Cloud Run Job: ${JOB_NAME}..."
# Use "$GCLOUD_ARGS[@]" to correctly expand the array into separate arguments
gcloud "${GCLOUD_ARGS[@]}"

if [ $? -ne 0 ]; then
  echo "Error: Cloud Run Job execution failed. Please check the command output and Cloud Logging for details."
  exit 1
else
  echo "Cloud Run Job '${JOB_NAME}' triggered successfully."
  echo "Monitoring Job Execution (Ctrl+C to stop waiting):"
  # Optional: Wait for the job to complete and show final status
  gcloud run jobs executions describe "${JOB_NAME}-0" \
    --region "${REGION}" \
    --format="value(status.completionStatus)"
  
  if [ $? -eq 0 ]; then
    echo "Migration Job '${JOB_NAME}' completed successfully."
  else
    echo "Migration Job '${JOB_NAME}' failed. Check Cloud Logging for errors."
  fi

  echo "You can check the detailed logs in the GCP Console under Cloud Run -> JOBS -> ${JOB_NAME} -> Logs tab."
  echo "This job definition will remain; you can delete it if no longer needed:"
  echo "  gcloud run jobs delete ${JOB_NAME} --region ${REGION}"
fi

echo "--- Script Finished ---"
