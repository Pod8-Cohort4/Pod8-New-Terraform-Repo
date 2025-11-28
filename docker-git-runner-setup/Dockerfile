FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core tools (NO docker.io)
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    unzip \
    software-properties-common \
    sudo \
    gnupg \
    lsb-release \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform

# Install Node.js (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Create runner user
RUN useradd -m -s /bin/bash runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /home/runner

# Install GitHub Runner
RUN curl -s https://api.github.com/repos/actions/runner/releases/latest \
  | jq -r '.assets[] | select(.name | test("linux-x64")) | .browser_download_url' \
  | xargs curl -LO && \
  tar xzf actions-runner-linux-x64-*.tar.gz && \
  rm actions-runner-linux-x64-*.tar.gz

RUN mkdir -p /home/runner/_work && chown -R runner:runner /home/runner

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER runner

ENTRYPOINT ["/entrypoint.sh"]
