# Start from the official Jenkins LTS image
FROM jenkins/jenkins:lts

# Switch to root to install packages and modify permissions
USER root

# Install Docker CLI and curl
RUN apt-get update && \
   apt-get install -y docker.io curl && \
   rm -rf /var/lib/apt/lists/*

# Install KIND (v0.27.0)
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64 && \
   chmod +x ./kind && \
   mv ./kind /usr/local/bin/kind

# Install kubectl (Latest Stable)
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
   chmod +x ./kubectl && \
   mv ./kubectl /usr/local/bin/kubectl


# Install Helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
   chmod 700 get_helm.sh && \
   ./get_helm.sh && \
   rm get_helm.sh