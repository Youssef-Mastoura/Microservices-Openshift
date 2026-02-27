#!/bin/bash

# Configuration
PROJECT_NAME="ms-demo"
MANIFEST_DIR="base"

echo "---------------------------------------------------"
echo "🚀 Starting Microservices Demo Deployment..."
echo "---------------------------------------------------"

# 1. Create the project if it doesn't exist
if oc get project "$PROJECT_NAME" >/dev/null 2>&1; then
    echo "✅ Project '$PROJECT_NAME' already exists. Switching context..."
    oc project "$PROJECT_NAME"
else
    echo "📂 Creating new project: $PROJECT_NAME"
    oc new-project "$PROJECT_NAME"
fi

# 2. Apply all YAML files in the 'base' directory
echo "📄 Applying manifests from /$MANIFEST_DIR..."
if [ -d "$MANIFEST_DIR" ]; then
    oc apply -f "$MANIFEST_DIR/"
else
    echo "❌ Error: Directory '$MANIFEST_DIR' not found!"
    exit 1
fi

echo "---------------------------------------------------"
echo "⏳ Waiting for deployments to initialize..."
echo "---------------------------------------------------"

# 3. List the status of pods
oc get pods

echo ""
echo "💡 TIP: You can track the status using: 'oc get pods -w'"
echo "🌐 To get your frontend URL, run: 'oc get route frontend'"
echo "---------------------------------------------------"
echo "✅ Deployment script finished!"
