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
echo "Moving binary to /usr/local/bin/$SERVICE_NAME"
sudo mv resource-provisioner-api /usr/local/bin/"$SERVICE_NAME"

# Create systemd service file if it does not exist
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

if [ ! -f "$SERVICE_FILE" ]; then
  echo "Creating systemd service file..."
  sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=Resource Provisioner API
After=network.target

[Service]
ExecStart=/usr/local/bin/$SERVICE_NAME
WorkingDirectory=$APP_DIR/resource-provisioner-api/cmd/server
Restart=always
User=ec2-user
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF"
else
  echo "Systemd service file already exists."
fi

# Reload systemd
echo "Reloading systemd..."
sudo systemctl daemon-reload

# Verify service file exists before enabling
if [ -f "$SERVICE_FILE" ]; then
  echo "Systemd service file found: $SERVICE_FILE"
  echo "Enabling and starting the service..."
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl restart "$SERVICE_NAME"
else
  echo "❌ ERROR: Systemd service file is missing!"
  exit 1
fi

echo "Deployment completed successfully"

