#!/bin/bash

# Voila Search App Deployment Script
# Run this script on your Digital Ocean droplet to deploy the Flask app

set -e  # Exit on any error

APP_NAME="voila-search"
APP_DIR="/var/www/$APP_NAME"
REPO_URL="https://github.com/your-username/your-repo-name.git"  # Update this!
SERVICE_NAME="voila-search"

echo "=== Voila Search App Deployment ==="
echo "App Directory: $APP_DIR"
echo "Service Name: $SERVICE_NAME"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

# Update system packages
echo "Updating system packages..."
apt update && apt upgrade -y

# Install required system packages
echo "Installing required packages..."
apt install -y python3 python3-pip python3-venv git nginx

# Create app directory
echo "Setting up application directory..."
mkdir -p $APP_DIR
cd $APP_DIR

# Clone or update repository
if [ -d ".git" ]; then
    echo "Updating existing repository..."
    git pull origin main
else
    echo "Cloning repository..."
    git clone $REPO_URL .
fi

# Set up Python virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Set proper permissions
echo "Setting file permissions..."
chown -R www-data:www-data $APP_DIR
chmod +x startup.sh

# Initialize database
echo "Initializing database..."
sudo -u www-data $APP_DIR/venv/bin/python -c "from main import init_database; init_database()"

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Voila Search Flask Application
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
Environment=FLASK_ENV=production
Environment=PYTHONUNBUFFERED=1
Environment=PORT=5000
ExecStart=$APP_DIR/venv/bin/python main.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
echo "Starting service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# Check service status
echo "Service status:"
systemctl status $SERVICE_NAME --no-pager

echo
echo "=== Deployment Complete! ==="
echo "The Flask app is now running on port 5000"
echo "Service name: $SERVICE_NAME"
echo "App directory: $APP_DIR"
echo
echo "To check logs: journalctl -u $SERVICE_NAME -f"
echo "To restart: systemctl restart $SERVICE_NAME"
echo "To stop: systemctl stop $SERVICE_NAME"
echo
echo "Next step: Configure Nginx reverse proxy to serve the app"
echo "Run the diagnostic script to help with Nginx configuration!"
echo
