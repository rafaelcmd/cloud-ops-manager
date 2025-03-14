#!/bin/bash

set -e

echo "Updating the system and installing dependencies"
sudo dnf update -y
sudo dnf install -y git

APP_DIR="/home/ec2-user/resource-provisioner-api"
GO_VERSION="1.24.1"
GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"

# Install Go
if ! command -v go &> /dev/null; then
  echo "Installing Go ${GO_VERSION}"
  curl -fsSL -o go.tar.gz $GO_URL
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf go.tar.gz
  echo "export PATH=$PATH:/usr/local/go/bin" | sudo tee -a /etc/profile
  source /etc/profile
fi

# Clone the repository
if [ ! -d "$APP_DIR" ]; then
  echo "Cloning the repository"
  sudo git clone https://github.com/rafaelcmd/cloud-ops-manager.git $APP_DIR
else
  echo "Pulling the latest changes"
  cd $APP_DIR
  sudo git pull origin main
fi

# Build the application
echo "Building the application"
cd $APP_DIR/resource-provisioner-api/cmd/server
/usr/local/go/bin/go build -o resource-provisioner-api

# Move the binary to the bin directory
sudo mv resource-provisioner-api /usr/local/bin/resource-provisioner-api-app

# Restart the application using systemd
sudo systemctl restart resource-provisioner-api-app || sudo systemctl start resource-provisioner-api-app
sudo systemctl enable resource-provisioner-api-app

echo "Deployment completed successfully"

