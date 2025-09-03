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
RUN pip3 install --no-cache-dir ansible==9.7.0

# Install AWS CLI v2
RUN curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
 && unzip /tmp/awscliv2.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Terraform
ARG TF_VERSION=1.7.5
RUN curl -sSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip \
 && unzip /tmp/terraform.zip -d /usr/local/bin \
 && rm -f /tmp/terraform.zip

# Back to Jenkins user
USER jenkins
