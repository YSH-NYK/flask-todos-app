#!/bin/bash
set -e

APP_DIR="/var/www/todos-app"
SERVICE_NAME="todos-app"

echo "Starting deployment..."

# Stop nginx if it's running
if systemctl is-active --quiet nginx; then
    echo "Stopping nginx..."
    sudo systemctl stop nginx
    sudo systemctl disable nginx
fi

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

# Copy .env file if it exists
if [ -f /home/ec2-user/todos-deploy/.env ]; then
    echo "Copying .env file..."
    sudo cp /home/ec2-user/todos-deploy/.env $APP_DIR/.env
else
    echo "Warning: .env file not found in deployment directory"
    echo "Creating minimal .env file..."
    sudo tee $APP_DIR/.env > /dev/null <<ENVEOF
FLASK_ENV=production
SECRET_KEY=temporary-secret-key-change-in-production
SQLALCHEMY_DATABASE_URI=sqlite:///todos.db
ENVEOF
fi

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
python -c "from app import db; db.create_all()" || true

# Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Flask Todos Application
After=network.target

[Service]
Type=exec
User=ec2-user
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
EnvironmentFile=-$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/gunicorn -w 4 -b 0.0.0.0:8000 wsgi:app --timeout 120
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "Service file created. Contents:"
cat /etc/systemd/system/$SERVICE_NAME.service

# Reload systemd and start service
echo "Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

# Wait for service to start and check status
echo "Waiting for service to start..."
sleep 5

if systemctl is-active --quiet $SERVICE_NAME; then
    echo "✓ Service $SERVICE_NAME is running"
    sudo systemctl status $SERVICE_NAME --no-pager
else
    echo "✗ Service $SERVICE_NAME failed to start"
    echo "Checking logs:"
    sudo journalctl -u $SERVICE_NAME -n 50 --no-pager
    exit 1
fi

echo "Deployment completed successfully!"