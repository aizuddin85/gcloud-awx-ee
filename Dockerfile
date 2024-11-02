# Base AWX execution environment
FROM quay.io/ansible/awx-ee:latest

# Set environment variables
ENV CLOUD_SDK_VERSION=446.0.0 \
    PATH="/usr/local/gcloud/google-cloud-sdk/bin:${PATH}" \
    PYTHONPATH="/usr/local/lib/python3.9/site-packages" \
    ARGO_VERSION=v2.12.6  \
    ANSIBLE_CORE_VERSION=2.14.11

USER root

# Install system dependencies
RUN dnf install -y \
        python3-devel \
        python3-pip \
        gcc \
        gcc-c++ \
        git \
        wget \
        unzip \
        which \
        tar \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

# Install specific version of ansible-core
RUN pip uninstall -y ansible-core \
    && pip install ansible-core==${ANSIBLE_CORE_VERSION}

# Install gcloud SDK
RUN mkdir -p /usr/local/gcloud \
    && curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz \
    && tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz -C /usr/local/gcloud \
    && /usr/local/gcloud/google-cloud-sdk/install.sh \
        --quiet \
        --path-update=true \
        --usage-reporting=false \
        --additional-components \
        alpha \
        beta \
        kubectl \
        gke-gcloud-auth-plugin \
    && rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz

# Install Argo CD CLI
RUN curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/${ARGO_VERSION}/argocd-linux-amd64 \
    && chmod +x /usr/local/bin/argocd

# Install Python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --upgrade pip setuptools \
    && python3 -m pip install --no-cache-dir -r /tmp/requirements.txt

# Install Ansible collections
RUN ansible-galaxy collection install google.cloud kubernetes.core

# Set up ansible configuration
COPY ansible.cfg /etc/ansible/ansible.cfg

# Create directory for credentials
RUN mkdir -p /var/lib/awx/credentials \
    && chmod 755 /var/lib/awx/credentials

# Switch back to non-root user
USER 1000
