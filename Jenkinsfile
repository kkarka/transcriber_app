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

                    echo "Injecting secrets into Kubernetes..."
                    sh """
                        kubectl create secret generic transcriber-secrets \
                          --from-literal=REDIS_PASS=\$REDIS_PASS \
                          --from-literal=GITHUB_TOKEN=\$GITHUB_TOKEN \
                          --dry-run=client -o yaml | kubectl apply -f -
                    """
                    sh "echo '✅ Secrets safely injected into Kubernetes!'"
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
                sh """
                    docker run --rm -u root \
                    -e ENV=testing \
                    -e PYTHONPATH=/app:/shared \
                    -w /app \
                    worker:${IMAGE_TAG} \
                    sh -c 'pip install pytest && pytest test_tasks.py'
                """
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo "Batch loading images into KIND cluster..."
                sh """
                    kind load docker-image worker:${IMAGE_TAG} --name transcriber-cluster
                    kind load docker-image api:${IMAGE_TAG} --name transcriber-cluster
                    kind load docker-image frontend:${IMAGE_TAG} --name transcriber-cluster
                """
                
                echo "Applying Kubernetes manifests..."
                sh 'find infrastructure/kubernetes -name "*.yaml" ! -name "kind-config.yaml" -exec kubectl apply -f {} \\;'
                
                echo "Restarting deployments to pick up new images..."
                sh "kubectl rollout restart deployment worker api frontend gateway || true"
                
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