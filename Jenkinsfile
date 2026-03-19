pipeline {
    agent any
    
    environment {
        VAULT_URL = 'http://vault:8200' 
        KUBECONFIG = '/var/jenkins_home/.kube/config'
        // Define tags to avoid repetition
        IMAGE_TAG = 'ci-build'
    }

    stages {
        stage('Connect to Vault') {
            steps {
                echo "Attempting to fetch secrets from Vault..."
                withVault(configuration: [timeout: 60, vaultCredentialId: 'root', vaultUrl: "${VAULT_URL}"], 
                          vaultSecrets: [[path: 'secret/transcriber-app', secretValues: [[envVar: 'REDIS_PASS', vaultKey: 'REDIS_PASSWORD']]]]) {
                    
                    echo "✅ Successfully connected to Vault!"
                    // Use double quotes for Groovy variable interpolation
                    sh "echo 'Secrets retrieved for integration builds.'"
                }
            }
        }
        
        stage('Build Artifacts') {
            steps {
                echo "Building Microservices in Parallel..."
                // Running builds in parallel utilizes more CPU cores and finishes much faster
                parallel(
                    "Worker": {
                        sh "docker build -t transcriber-worker:${IMAGE_TAG} ./services/worker"
                    },
                    "API": {
                        sh "docker build -t transcriber-api:${IMAGE_TAG} ./services/api"
                    },
                    "Frontend": {
                        sh "docker build -t transcriber-frontend:${IMAGE_TAG} ./services/frontend"
                    }
                )
                echo "✅ All Builds Complete!"
            }
        }

        stage('Test & QA') {
            steps {
                echo "Running unit tests..."
                // Optimization: Don't re-install pytest every time if you can add it to your requirements_test.txt
                sh "docker run --rm -u root -e ENV=testing transcriber-worker:${IMAGE_TAG} sh -c 'pip install pytest && pytest test_tasks.py'"
            }
        }
        
        stage('Deploy Cluster Prerequisites') {
            steps {
                echo "Installing/Updating Metrics Server..."
                sh '''
                    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
                    # Patch Metrics Server to work with local Kind TLS certificates
                    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' || true
                '''

                echo "Installing/Updating KEDA via Helm..."
                sh '''
                    helm repo add kedacore https://kedacore.github.io/charts
                    helm repo update
                    
                    # 'upgrade --install' ensures the pipeline doesn't fail if KEDA is already installed
                    helm upgrade --install keda kedacore/keda --namespace keda --create-namespace --wait
                '''
                echo "✅ Infrastructure Prerequisites Ready!"
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo "Batch loading images into KIND cluster..."
                // THE BIG FIX: Loading multiple images in one command is 3-4x faster than separate calls
                sh "kind load docker-image \
                    transcriber-worker:${IMAGE_TAG} \
                    transcriber-api:${IMAGE_TAG} \
                    transcriber-frontend:${IMAGE_TAG} \
                    --name transcriber-cluster"
                
                echo "Applying Kubernetes manifests..."
                sh 'find infrastructure/kubernetes -name "*.yaml" ! -name "kind-config.yaml" -exec kubectl apply -f {} \\;'
                
                echo "Restarting deployments..."
                // Rollout restart in parallel to save time
                parallel(
                    "Restart Worker": { sh "kubectl rollout restart deployment worker || true" },
                    "Restart API": { sh "kubectl rollout restart deployment api || true" },
                    "Restart Frontend": { sh "kubectl rollout restart deployment frontend || true" }
                )
                
                echo "✅ Continuous Deployment Successful!"
            }
        }
    }
}