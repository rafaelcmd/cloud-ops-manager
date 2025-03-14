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
  git reset --hard origin/main  # Resets local changes
  git clean -fd                 # Removes untracked files
  git pull origin main          # Pull latest changes
fi

# Fix permissions to ensure Go can write compiled binary
echo "Fixing directory ownership and permissions..."
sudo chown -R ec2-user:ec2-user $APP_DIR
sudo chmod -R 755 $APP_DIR

# Navigate to the application directory
echo "Navigating to the Go application directory..."
cd $APP_DIR/resource-provisioner-api/cmd/server

# Install dependencies
echo "Installing dependencies..."
go mod tidy

# Build the application
echo "Building the application"
go build -buildvcs=false -o resource-provisioner-api .

# Move binary to /usr/local/bin for easy execution
sudo mv myapp /usr/local/bin/"$SERVICE_NAME"

# Create systemd service file if it does not exist
if [ ! -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
  echo "Creating systemd service file..."
  sudo bash -c "cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=Resource Provisioner API
After=network.target

[Service]
ExecStart=/usr/local/bin/$SERVICE_NAME
WorkingDirectory=$APP_DIR/api/cmd/server
Restart=always
User=ec2-user

[Install]
WantedBy=multi-user.target
EOF"
fi

# Reload systemd, enable and restart service
echo "Reloading systemd and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo "Deployment completed successfully"

