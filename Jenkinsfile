pipeline {
    agent any
    
    environment {
        // IP to reach Vault from inside the Jenkins container
        VAULT_URL = 'http://172.17.0.1:8200' 
        // Force kubectl to use our correctly mapped config
        KUBECONFIG = '/var/jenkins_home/.kube/config'
    }

    stages {
        stage('Connect to Vault') {
            steps {
                echo "Attempting to fetch secrets from Vault..."
                withVault(configuration: [timeout: 60, vaultCredentialId: 'vault-dev-token', vaultUrl: "${VAULT_URL}"], 
                          vaultSecrets: [[path: 'secret/transcriber-app', secretValues: [[envVar: 'REDIS_PASS', vaultKey: 'REDIS_PASSWORD']]]]) {
                    
                    echo "✅ Successfully connected to Vault!"
                    sh 'echo "The fetched Redis Password is: ${REDIS_PASS}"'
                }
            }
        }
        
        stage('Build Artifacts') {
            steps {
                echo "Building ALL Microservices..."
                // Build all images FIRST so we can use them for testing
                sh 'docker build -t transcriber-worker:ci-build ./services/worker'
                sh 'docker build -t transcriber-api:ci-build ./services/api'
                sh 'docker build -t transcriber-frontend:ci-build ./services/frontend'
                echo "✅ All Builds Complete!"
            }
        }

        stage('Test & QA') {
            steps {
                echo "Running isolated unit tests INSIDE the built Worker image..."
                // We spin up the worker image we just built, inject 'pytest', and run the test!
                // '-u root' ensures we have permission to pip install pytest on the fly
                sh 'docker run --rm -u root -e ENV=testing transcriber-worker:ci-build sh -c "pip install pytest && pytest test_tasks.py"'
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo "Loading all images into KIND cluster..."
                sh 'kind load docker-image transcriber-worker:ci-build --name transcriber-cluster'
                sh 'kind load docker-image transcriber-api:ci-build --name transcriber-cluster'
                sh 'kind load docker-image transcriber-frontend:ci-build --name transcriber-cluster'
                
                echo "Applying Kubernetes manifests..."
                sh 'kubectl apply -f infrastructure/kubernetes/'
                
                echo "Triggering rolling updates to pull fresh images..."
                sh 'kubectl rollout restart deployment transcriber-worker || true'
                sh 'kubectl rollout restart deployment transcriber-api || true'
                sh 'kubectl rollout restart deployment transcriber-frontend || true'
                
                echo "✅ Continuous Deployment Successful!"
            }
        }
    }
}