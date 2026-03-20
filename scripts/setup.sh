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
# CONDITION: Check if cluster already exists
if kind get clusters | grep -q "^transcriber-cluster$"; then
    echo "✅ Kind cluster 'transcriber-cluster' already exists. Skipping creation."
else
    echo "📦 Creating Kind cluster (transcriber-cluster) with custom networking..."
    # CRITICAL UPDATE: Passing the config file so extraPortMappings are applied!
    # Note: Adjust the path to kind-config.yaml if it is not in your root directory.
    kind create cluster --name transcriber-cluster --config infrastructure/kubernetes/kind-config.yaml --image kindest/node:v1.30.0 || { echo "❌ Failed to create cluster"; exit 1; }
fi

echo "🔑 Extracting internal Kubeconfig for Jenkins..."
kind get kubeconfig --name transcriber-cluster --internal > jenkins-kubeconfig.yaml
chmod 644 jenkins-kubeconfig.yaml


# ==========================================
# 2. HASHICORP VAULT
# ==========================================
echo "🔐 Setting up HashiCorp Vault..."

if [ "$(docker ps -aq -f name=^vault$)" ]; then
    if [ "$(docker inspect -f '{{.State.Running}}' vault)" == "true" ]; then
        echo "✅ Vault container is already running."
    else
        echo "🔄 Starting existing Vault container..."
        docker start vault
    fi
else
    echo "🚀 Creating new Vault container..."
    docker run -d \
      --name vault \
      --network kind \
      -p 8200:8200 \
      --cap-add=IPC_LOCK \
      -e 'VAULT_DEV_ROOT_TOKEN_ID=root' \
      -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' \
      hashicorp/vault
fi

echo "⏳ Waiting for Vault to fully initialize..."
for i in {1..30}; do
    if docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault vault status > /dev/null 2>&1; then
        echo "✅ Vault is online and ready!"
        break
    fi
    sleep 2
done

echo "💉 Injecting Redis secret into Vault..."
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault vault kv put secret/transcriber-app REDIS_PASSWORD="$REDIS_SECRET" GITHUB_TOKEN="$GITHUB_SECRET" > /dev/null 2>&1

unset REDIS_SECRET
unset GITHUB_SECRET


# ==========================================
# 3. JENKINS
# ==========================================
echo "🏗️ Building custom Jenkins Docker image..."
docker build --no-cache -t custom-jenkins-devops -f infrastructure/jenkins/Dockerfile .

FRESH_START=false
if [ -z "$(docker volume ls -q -f name=^jenkins_home$)" ]; then
    FRESH_START=true
    echo "🌟 First time Jenkins setup detected!"
else
    echo "♻️ Existing Jenkins data found. Skipping first-time setup."
fi

echo "⚙️ Setting up Jenkins..."

if [ "$(docker ps -aq -f name=^jenkins$)" ]; then
    if [ "$(docker inspect -f '{{.State.Running}}' jenkins)" == "true" ]; then
        echo "✅ Jenkins container is already running."
    else
        echo "🔄 Starting existing Jenkins container..."
        docker start jenkins
    fi
else
    echo "🚀 Creating new Jenkins container..."
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
fi

if [ "$FRESH_START" = true ]; then
    echo "⏳ Waiting for Jenkins to boot and generate the initial password (this takes about 20-40 seconds)..."
    for i in {1..30}; do
        if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
            JENKINS_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
            echo "=========================================="
            echo "🚨 FIRST TIME LOGIN REQUIRED 🚨"
            echo "Your Initial Admin Password is:"
            echo -e "\033[1;32m$JENKINS_PASS\033[0m" 
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
echo "🌐 Setting up Ngrok Tunnel..."
if pgrep -x "ngrok" > /dev/null; then
    echo "✅ Ngrok is already running."
else
    echo "🚀 Starting Ngrok..."
    nohup ngrok http --domain=nonfossiliferous-jovanni-geophilous.ngrok-free.dev 8080 > ngrok.log 2>&1 &
fi


echo "=========================================="
echo "✅ ENVIRONMENT FULLY PROVISIONED!"
echo "=========================================="
echo "🔗 Jenkins:       http://localhost:8080"
echo "🔗 Vault:         http://localhost:8200 (Login Token: root)"
echo "🔗 GitHub Webhook: https://nonfossiliferous-jovanni-geophilous.ngrok-free.dev"
echo "=========================================="

echo "🔍 Performing Final Health Check..."
containers=("jenkins" "vault")
for container in "${containers[@]}"; do
    if [ "$(docker inspect -f '{{.State.Running}}' $container)" == "true" ]; then
        echo "✅ $container is healthy."
    else
        echo "❌ $container failed to start! Check 'docker logs $container'"
    fi
done

echo ""
echo "✨ APP ACCESS READY ✨"
echo "Your NGINX Gateway is routing traffic directly from your localhost to the cluster."
echo "👉 View the application at: http://localhost"
echo "👉 View the API directly at: http://localhost/api/"