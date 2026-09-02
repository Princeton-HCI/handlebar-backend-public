#!/bin/bash
# Setup script for Cloud SQL instance and database configuration
# Run this after the Cloud SQL instance has been created

set -e

PROJECT_ID="up-ist-wao"
REGION="us-east1"
INSTANCE_NAME="handlebar-db"
DB_NAME="handlebar_db"
DB_USER="postgres"

echo "🔧 Setting up Cloud SQL for Handlebar Backend..."

# Step 1: Wait for instance to be ready (if just created)
echo "📋 Checking if instance is ready..."
gcloud sql instances describe $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --format="value(state)" || {
  echo "❌ Instance not found. Please create it first."
  exit 1
}

# Step 2: Set a password for the postgres user
echo "🔐 Setting postgres user password..."
echo "Please enter a password for the postgres user (it will be hidden):"
read -s DB_PASSWORD

gcloud sql users set-password $DB_USER \
  --instance=$INSTANCE_NAME \
  --project=$PROJECT_ID \
  --password=$DB_PASSWORD

# Step 3: Create the database
echo "📦 Creating database '$DB_NAME'..."
gcloud sql databases create $DB_NAME \
  --instance=$INSTANCE_NAME \
  --project=$PROJECT_ID \
  --charset=UTF8 || {
  echo "⚠️  Database may already exist, continuing..."
}

# Step 4: Enable PostGIS extension (requires Cloud SQL Proxy connection)
echo "🗺️  To enable PostGIS extension, we need to connect to the database..."
echo "Installing Cloud SQL Proxy if needed..."

# Download Cloud SQL Proxy if not already present
if [ ! -f "./cloud-sql-proxy" ]; then
  echo "Downloading Cloud SQL Proxy..."
  curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.darwin.arm64
  chmod +x cloud-sql-proxy
fi

# Get the connection name
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --format="value(connectionName)")

echo "📡 Connection name: $CONNECTION_NAME"

# Start proxy in background
echo "Starting Cloud SQL Proxy on port 5432..."
./cloud-sql-proxy $CONNECTION_NAME --port 5432 &
PROXY_PID=$!
# Ensure the proxy is stopped on any exit (including a psql failure under `set -e`).
trap 'kill $PROXY_PID 2>/dev/null || true' EXIT
sleep 3

# Enable PostGIS
echo "🗺️  Enabling PostGIS extension..."
PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS postgis;"
PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"

# Stop proxy
kill $PROXY_PID 2>/dev/null || true
trap - EXIT

echo ""
echo "✅ Cloud SQL setup complete!"
echo ""
echo "📋 Instance Details:"
echo "  Instance Name: $INSTANCE_NAME"
echo "  Connection Name: $CONNECTION_NAME"
echo "  Database: $DB_NAME"
echo "  Region: $REGION"
echo ""
echo "🔐 Save these environment variables for Cloud Run:"
echo "  CLOUD_SQL_CONNECTION_ID=$CONNECTION_NAME"
echo "  DB_NAME=$DB_NAME"
echo "  DB_PASSWORD=(the password you just set)"
echo ""
echo "🚀 Next steps:"
echo "  1. Update Cloud Run environment variables"
echo "  2. Run database migrations"
echo ""
