pipeline {
    agent any
    
    environment {
        VAULT_URL = 'http://vault:8200' 
        KUBECONFIG = '/var/jenkins_home/.kube/config'
        IMAGE_TAG = 'local'
    }

    stages {
        stage('Connect to Vault') {
            steps {
                echo "Attempting to fetch secrets from Vault..."
                withVault(configuration: [timeout: 60, vaultCredentialId: 'root', vaultUrl: "${VAULT_URL}"], 
                  vaultSecrets: [
                      [path: 'secret/transcriber-app', secretValues: [
                          [envVar: 'REDIS_PASS', vaultKey: 'REDIS_PASSWORD'],
                          [envVar: 'GITHUB_TOKEN', vaultKey: 'GITHUB_TOKEN']
                      ]]
                  ]) {
                    echo "✅ Successfully connected to Vault!"
                    sh "echo 'Secrets retrieved for integration builds.'"
                }
            }
        }
        
        stage('Build Artifacts') {
            // Using Declarative parallel stages for better visualization and stability
            parallel {
                stage('Build Worker') {
                    steps {
                        retry(2) { sh "docker build -t worker:${IMAGE_TAG} ./services/worker" }
                    }
                }
                stage('Build API') {
                    steps {
                        retry(2) { sh "docker build -t api:${IMAGE_TAG} ./services/api" }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        retry(2) { sh "docker build -t frontend:${IMAGE_TAG} ./services/frontend" }
                    }
                }
            }
        }

        stage('Test & QA') {
            steps {
                echo "Running unit tests..."
                sh "docker run --rm -u root -e ENV=testing worker:${IMAGE_TAG} sh -c 'pip install pytest && pytest test_tasks.py'"
            }
        }
        
        stage('Deploy Cluster Prerequisites') {
            steps {
                echo "Installing/Updating Metrics Server..."
                sh '''
                    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
                    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' || true
                '''

                echo "Installing/Updating KEDA via Helm..."
                sh '''
                    helm repo add kedacore https://kedacore.github.io/charts
                    helm repo update
                    helm upgrade --install keda kedacore/keda --namespace keda --create-namespace --wait
                '''
                echo "✅ Infrastructure Prerequisites Ready!"
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo "Batch loading images into KIND cluster..."
                sh "kind load docker-image worker:${IMAGE_TAG} api:${IMAGE_TAG} frontend:${IMAGE_TAG} --name transcriber-cluster"
                
                echo "Applying Kubernetes manifests..."
                sh 'find infrastructure/kubernetes -name "*.yaml" ! -name "kind-config.yaml" -exec kubectl apply -f {} \\;'
                
                echo "Restarting deployments..."
                // Simple one-liner rollout for all services
                sh "kubectl rollout restart deployment worker api frontend || true"
                
                echo "✅ Continuous Deployment Successful!"
            }
        }
    } // End of Stages

    post {
        always {
            echo "🧹 Cleaning up workspace..."
            cleanWs()
        }
        failure {
            echo "🚨 Pipeline failed! Sending notification..."
        }
    }
} // End of Pipeline