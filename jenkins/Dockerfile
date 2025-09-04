FROM jenkins/jenkins:lts

# Become root to install packages
USER root

# Basic tools
RUN apt-get update && apt-get install -y \
    curl unzip gnupg lsb-release software-properties-common \
    python3 python3-pip \
    sshpass git jq iputils-ping netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible
RUN pip3 install --no-cache-dir ansible==9.7.0 --break-system-packages

# Install AWS CLI v2 (ARM64 build for Apple Silicon)
RUN curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip \
 && unzip /tmp/awscliv2.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Terraform
ARG TF_VERSION=1.7.5
RUN curl -sSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip \
 && unzip /tmp/terraform.zip -d /usr/local/bin \
 && mv /usr/local/bin/terraform /usr/bin/terraform \
 && rm -f /tmp/terraform.zip

# Verify installations (optional but useful for debugging build)
RUN terraform -version \
 && ansible --version \
 && aws --version

# Back to Jenkins user
USER jenkins
