pipeline {
    agent any
    
    environment {
        // Use host.docker.internal or 172.17.0.1 to reach Vault from inside the Jenkins container
        VAULT_URL = 'http://172.17.0.1:8200' 
    }

    stages {
        stage('Connect to Vault') {
            steps {
                echo "Attempting to fetch secrets from Vault..."
                
                withVault(configuration: [timeout: 60, vaultCredentialId: 'vault-dev-token', vaultUrl: "${VAULT_URL}"], 
                          vaultSecrets: [[envVar: 'REDIS_PASS', path: 'secret/transcriber-app', secretValues: [[envVar: 'REDIS_PASS', vaultKey: 'REDIS_PASSWORD']]]]) {
                    
                    echo "✅ Successfully connected to Vault!"
                    // Jenkins will automatically mask the actual password with asterisks (***) in the logs!
                    sh 'echo "The fetched Redis Password is: ${REDIS_PASS}"'
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo "Building the Transcriber Worker Image..."
                sh 'docker build -t transcriber-worker:ci-build ./services/worker'
                echo "✅ Build Complete!"
            }
        }
    }
}