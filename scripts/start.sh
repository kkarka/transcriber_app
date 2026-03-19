#!/bin/bash

# SAFETY CHECK: Force the script to run from the project root directory
cd "$(dirname "$0")/.." || exit
echo "📂 Working directory set to: $(pwd)"

echo "🚀 Starting Enterprise Clean Environment Setup..."

# ==========================================
# 0. SECURE CREDENTIAL CAPTURE
# ==========================================
read -s -p "Enter Redis Password for Vault: " REDIS_SECRET
echo "" 

read -s -p "Enter GitHub Token for Vault: " GITHUB_SECRET
echo ""

if [ -z "$REDIS_SECRET" ] || [ -z "$GITHUB_SECRET" ]; then
    echo "❌ Error: Secrets cannot be empty. Exiting."
    exit 1
fi


# ==========================================
# 1. KUBERNETES CLUSTER (KIND)
# ==========================================
echo "📦 Creating Kind cluster (transcriber-cluster)..."
kind create cluster --name transcriber-cluster

echo "🔑 Extracting internal Kubeconfig for Jenkins..."
kind get kubeconfig --name transcriber-cluster --internal > jenkins-kubeconfig.yaml
chmod 644 jenkins-kubeconfig.yaml


# ==========================================
# 2. HASHICORP VAULT
# ==========================================
echo "🔐 Starting HashiCorp Vault..."
docker run -d \
  --name vault \
  --network kind \
  -p 8200:8200 \
  --cap-add=IPC_LOCK \
  -e 'VAULT_DEV_ROOT_TOKEN_ID=root' \
  -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' \
  hashicorp/vault

echo "⏳ Waiting for Vault to fully initialize..."
# SMART WAIT: Poll Vault until it responds with a healthy status
for i in {1..30}; do
    # 'vault status' checks if the server is awake and unsealed
    if docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault vault status > /dev/null 2>&1; then
        echo "✅ Vault is online and ready!"
        break
    fi
    sleep 2
done

echo "Injecting Redis secret into Vault..."

# Using HTTP to avoid the 'connection refused' error in local dev
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault vault kv put secret/transcriber-app REDIS_PASSWORD="$REDIS_SECRET" GITHUB_TOKEN="$GITHUB_SECRET"

# Clear variables from memory for security
unset REDIS_SECRET
unset GITHUB_SECRET


# ==========================================
# 3. JENKINS
# ==========================================
echo "🏗️ Building custom Jenkins Docker image..."
# Safely builds from the root directory because of our cd command at the top
docker build -t custom-jenkins-devops -f infrastructure/jenkins/Dockerfile .

# Check if this is a fresh start by looking for the Docker volume
FRESH_START=false
if [ -z "$(docker volume ls -q -f name=^jenkins_home$)" ]; then
    FRESH_START=true
    echo "🌟 First time Jenkins setup detected!"
else
    echo "♻️ Existing Jenkins data found. Skipping first-time setup."
fi

echo "⚙️ Starting Jenkins..."
docker run -d \
  --name jenkins \
  --network kind \
  --user root \
  --privileged \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/jenkins-kubeconfig.yaml:/var/jenkins_home/.kube/config \
  custom-jenkins-devops

# If it's a fresh start, poll the container until the password file is generated
if [ "$FRESH_START" = true ]; then
    echo "⏳ Waiting for Jenkins to boot and generate the initial password (this takes about 20-40 seconds)..."
    for i in {1..30}; do
        # Check if the password file exists yet
        if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
            JENKINS_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
            echo "=========================================="
            echo "🚨 FIRST TIME LOGIN REQUIRED 🚨"
            echo "Your Initial Admin Password is:"
            echo -e "\033[1;32m$JENKINS_PASS\033[0m"  # Prints in bold green!
            echo "Copy this password and go to http://localhost:8080"
            echo "=========================================="
            break
        fi
        sleep 2
    done
else
    echo "=========================================="
    echo "🔐 JENKINS LOGIN"
    echo "Go to http://localhost:8080 and use your previously created username and password."
    echo "=========================================="
fi



# ==========================================
# 4. NGROK TUNNEL
# ==========================================
echo "🌐 Starting Ngrok Tunnel..."
# Using your exact permanent dev domain!
nohup ngrok http --domain=nonfossiliferous-jovanni-geophilous.ngrok-free.dev 8080 > ngrok.log 2>&1 &




echo "=========================================="
echo "✅ ENVIRONMENT FULLY PROVISIONED!"
echo "=========================================="
echo "🔗 Jenkins: http://localhost:8080"
echo "🔗 Vault:   http://localhost:8200 (Login Token: root)"
echo "🔗 Ngrok:   https://nonfossiliferous-jovanni-geophilous.ngrok-free.dev (for GitHub Webhooks, Login with Jenkins Creds.)"
echo "=========================================="