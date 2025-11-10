#!/bin/bash
set -e

APP_DIR="/var/www/todos-app"
SERVICE_NAME="todos-app"

echo "Starting deployment..."

# Stop the service if running
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "Stopping $SERVICE_NAME service..."
    sudo systemctl stop $SERVICE_NAME
fi

# Create app directory if it doesn't exist
sudo mkdir -p $APP_DIR

# Remove old venv with sudo to avoid permission issues
if [ -d "$APP_DIR/venv" ]; then
    echo "Removing old virtual environment..."
    sudo rm -rf $APP_DIR/venv
fi

# Copy application files
echo "Copying application files..."
sudo rsync -av --exclude='venv' --exclude='*.pyc' --exclude='__pycache__' \
    /home/ec2-user/todos-deploy/ $APP_DIR/

# Set proper ownership
sudo chown -R ec2-user:ec2-user $APP_DIR

# Create new virtual environment
echo "Creating virtual environment..."
cd $APP_DIR
python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# Set up database
echo "Setting up database..."
python -c "from app import db; db.create_all()"

# Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Flask Todos Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/gunicorn -w 4 -b 0.0.0.0:80 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
echo "Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "Deployment completed successfully!"