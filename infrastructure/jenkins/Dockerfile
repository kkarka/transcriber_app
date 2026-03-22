# Start from the official Jenkins LTS image
FROM jenkins/jenkins:lts

# Switch to root to install packages and modify permissions
USER root

# LAYER OPTIMIZATION: Now including Security Scanning (Trivy) and Quality Analysis (Sonar)
RUN apt-get update && \
    apt-get install -y docker.io curl wget gnupg lsb-release unzip && \
    \
    # --- 🛡️ Install Trivy (Vulnerability Scanner) ---
    wget -qO - https://aquasecurity.github.io/trivy-repo/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list && \
    apt-get update && apt-get install -y trivy && \
    \
    # --- 🏗️ Install Sonar Scanner ---
    curl -sSLo /tmp/sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip && \
    unzip /tmp/sonar-scanner.zip -d /opt && \
    ln -s /opt/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner && \
    \
    # --- 📦 Install KIND ---
    curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64 && \
    chmod +x /usr/local/bin/kind && \
    \
    # --- 🔑 Install kubectl ---
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    \
    # --- 🚢 Install Helm ---
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && \
    \
    # Cleanup to keep image small
    rm get_helm.sh /tmp/sonar-scanner.zip && \
    rm -rf /var/lib/apt/lists/*

# AUTOMATE PLUGINS: Adding 'sonar' plugin to the list
USER jenkins
RUN jenkins-plugin-cli --plugins \
    hashicorp-vault-plugin \
    workflow-aggregator \
    git \
    docker-workflow \
    pipeline-stage-view \
    sonar

# Force ownership to the jenkins user
COPY --chown=jenkins:jenkins infrastructure/jenkins/vault-cred.groovy /usr/share/jenkins/ref/init.groovy.d/
COPY --chown=jenkins:jenkins infrastructure/jenkins/create-job.groovy /usr/share/jenkins/ref/init.groovy.d/