#!/bin/bash
echo "🧹 Starting Environment Cleanup..."

# ==========================================
# 1. KILL NGROK TUNNEL
# ==========================================
echo "🌐 Shutting down Ngrok..."
# pkill finds the ngrok process and kills it safely. 
# The '|| true' ensures the script doesn't crash if ngrok is already dead.
pkill ngrok || true

# ==========================================
# 2. DESTROY KUBERNETES CLUSTER
# ==========================================
echo "📦 Deleting Kind cluster (transcriber-cluster)..."
kind delete cluster --name transcriber-cluster

# ==========================================
# 3. REMOVE DOCKER CONTAINERS
# ==========================================
echo "🐳 Stopping and removing Jenkins and Vault..."
docker stop jenkins vault || true
docker rm jenkins vault || true

# ==========================================
# 4. REMOVE LEFTOVER FILES
# ==========================================
echo "🗑️ Removing temporary local files..."
rm -f jenkins-kubeconfig.yaml ngrok.log

# ==========================================
# 5. REMOVE DOCKER IMAGES (DEEP CLEAN)
# ==========================================
echo "💿 Removing custom Docker images to free up space..."
# Remove the custom Jenkins image
docker rmi custom-jenkins-devops || true

# Remove the transcriber app CI/CD images
docker rmi transcriber-worker:ci-build transcriber-api:ci-build transcriber-frontend:ci-build || true

# Clean up any dangling "none" images left behind by old builds
docker image prune -f

# ==========================================
# 6. Remove Leftover Files
# ==========================================
echo "🗑️ Removing temporary local files..."
rm -f jenkins-kubeconfig.yaml ngrok.log

echo "=========================================="
echo "✨ CLEANUP COMPLETE!"
echo "Your system is completely reset."
echo "=========================================="