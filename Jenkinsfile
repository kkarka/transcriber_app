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
                // Keeping these inside the environment so they are available to all stages
                withVault(configuration: [timeout: 60, vaultCredentialId: 'root', vaultUrl: "${VAULT_URL}"], 
                  vaultSecrets: [
                      [path: 'secret/transcriber-app', secretValues: [
                          [envVar: 'REDIS_PASS', vaultKey: 'REDIS_PASSWORD'],
                          [envVar: 'GITHUB_TOKEN', vaultKey: 'GITHUB_TOKEN']
                      ]]
                  ]) {
                    echo "✅ Successfully connected to Vault!"
                    // We don't echo the actual secrets here for security
                    sh "echo 'Secrets retrieved and masked for security.'"
                }
            }
        }
        
        stage('Build Artifacts') {
            parallel {
                stage('Build Worker') {
                    steps {
                        retry(2) { sh "docker build -t worker:${IMAGE_TAG} -f services/worker/Dockerfile ." }
                    }
                }
                stage('Build API') {
                    steps {
                        retry(2) { sh "docker build -t api:${IMAGE_TAG} -f services/api/Dockerfile ." }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        retry(2) { sh "docker build -t frontend:${IMAGE_TAG} -f services/frontend/Dockerfile ." }
                    }
                }
            }
        }

        stage('Test & QA') {
            steps {
                echo "Running unit tests..."
                // PYTHONPATH=. ensures the app code is discoverable by the test runner
                sh """
                    docker run --rm -u root \
                    -e ENV=testing \
                    -e PYTHONPATH=/app \
                    -w /app \
                    worker:${IMAGE_TAG} \
                    sh -c 'pip install pytest && pytest test_tasks.py'
                """
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
                // Breaking this into multiple lines ensures the shell interprets it correctly
                sh """
                    kind load docker-image worker:${IMAGE_TAG} --name transcriber-cluster
                    kind load docker-image api:${IMAGE_TAG} --name transcriber-cluster
                    kind load docker-image frontend:${IMAGE_TAG} --name transcriber-cluster
                """
                
                echo "Applying Kubernetes manifests..."
                sh 'find infrastructure/kubernetes -name "*.yaml" ! -name "kind-config.yaml" -exec kubectl apply -f {} \\;'
                
                echo "Restarting deployments to pick up new images..."
                sh "kubectl rollout restart deployment worker api frontend || true"
                
                echo "✅ Continuous Deployment Successful!"
            }
        }
    }

    post {
        always {
            echo "🧹 Cleaning up workspace..."
            cleanWs()
        }
        failure {
            echo "🚨 Pipeline failed! Check the console output above."
        }
    }
}