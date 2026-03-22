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
        

        stage('Static Analysis & Quality Gate') {
            steps {
                script {
                    // 🔍 Step 1: Run SonarQube Scanner
                    // This uses the sonar-project.properties we created
                    withSonarQubeEnv('SonarQube-Server') {
                        sh 'sonar-scanner'
                    }
                    
                    // 🚦 Step 2: Pause until SonarQube results are in
                    // Pipeline will fail here if Quality Gate fails
                    timeout(time: 5, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
        }

        stage('Build Artifacts & Security Scan') {
            parallel {
                stage('Worker') {
                    steps {
                        retry(2) { sh "docker build -t worker:${IMAGE_TAG} -f services/worker/Dockerfile ." }
                        echo "🛡️ Scanning Worker Image..."
                        sh "trivy image --severity CRITICAL --exit-code 1 worker:${IMAGE_TAG}"
                    }
                }
                stage('API') {
                    steps {
                        retry(2) { sh "docker build -t api:${IMAGE_TAG} -f services/api/Dockerfile ." }
                        echo "🛡️ Scanning API Image..."
                        sh "trivy image --severity CRITICAL --exit-code 1 api:${IMAGE_TAG}"
                    }
                }
                stage('Build Frontend') {
                    steps {
                        retry(2) { sh "docker build -t frontend:${IMAGE_TAG} -f services/frontend/Dockerfile ." }
                        echo "🛡️ Scanning Frontend Image..."
                        sh "trivy image --severity CRITICAL --exit-code 1 frontend:${IMAGE_TAG}"
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
                sh '''
                    find infrastructure/kubernetes -name "*.yaml" \
                    ! -name "kind-config.yaml" \
                    ! -name "grafana-values.yaml" \
                    -exec kubectl apply -f {} \\;
                '''

                echo "Waiting for deployments to exist before restarting..."
                sh "sleep 10"

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