#!/bin/bash

set -e

echo "Updating the system and installing dependencies"
sudo dnf update -y
sudo dnf install -y git

APP_DIR="/home/ec2-user/resource-provisioner-api"

# Check if Go is installed
if ! command -v go &> /dev/null; then
  echo "Go is not installed. Installing Go from Amazon Linux 2023 repositories..."
  sudo dnf install -y golang
fi

echo "Go version: $(go version)"

# Ensure GOPATH and PATH are set correctly
echo "export PATH=$PATH:$(go env GOPATH)/bin" | sudo tee -a /etc/profile
source /etc/profile

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
go build -buildvcs=false -o resource-provisioner-api

# Move the binary to the bin directory
sudo mv resource-provisioner-api /usr/local/bin/resource-provisioner-api-app

# Restart the application using systemd
sudo systemctl restart resource-provisioner-api-app || sudo systemctl start resource-provisioner-api-app
sudo systemctl enable resource-provisioner-api-app

echo "Deployment completed successfully"

