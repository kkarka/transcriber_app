# Start from the official Jenkins LTS image
FROM jenkins/jenkins:lts

# Switch to root to install packages and modify permissions
USER root

# LAYER OPTIMIZATION: Combine installs to reduce image size
RUN apt-get update && \
    apt-get install -y docker.io curl && \
    rm -rf /var/lib/apt/lists/* && \
    \
    echo "Installing KIND..." && \
    curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64 && \
    chmod +x /usr/local/bin/kind && \
    \
    echo "Installing kubectl..." && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    \
    echo "Installing Helm..." && \
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && \
    rm get_helm.sh

# AUTOMATE PLUGINS: Pre-install Vault and Pipeline tools to avoid manual UI installation
# Switch back to the jenkins user so plugins get the correct file permissions!
USER jenkins
RUN jenkins-plugin-cli --plugins \
    hashicorp-vault-plugin \
    workflow-aggregator \
    git \
    docker-workflow \
    pipeline-stage-view
    
# Force ownership to the jenkins user so it can execute them on startup
COPY --chown=jenkins:jenkins infrastructure/jenkins/vault-cred.groovy /usr/share/jenkins/ref/init.groovy.d/
COPY --chown=jenkins:jenkins infrastructure/jenkins/create-job.groovy /usr/share/jenkins/ref/init.groovy.d/