#!/bin/bash

# Digital Ocean Server Setup Script
# This script sets up a fresh Digital Ocean droplet for Django deployment with SSL

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if domain name is provided
if [ $# -ne 1 ]; then
    print_error "Usage: $0 <domain_name>"
    print_error "Example: $0 example.com"
    exit 1
fi

DOMAIN_NAME=$1

print_status "Starting server setup for domain: $DOMAIN_NAME"

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
print_status "Installing required packages..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    ufw \
    fail2ban \
    htop \
    vim \
    unzip \
    certbot

# Install Docker
print_status "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
print_status "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Configure firewall
print_status "Configuring firewall..."
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 22

# Configure fail2ban
print_status "Configuring fail2ban..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Stop any services running on ports 80 and 443
print_status "Stopping services on ports 80 and 443..."
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl stop lighttpd 2>/dev/null || true

# Kill any processes using ports 80 and 443
sudo pkill -f "python.*http.server.*80" 2>/dev/null || true
sudo pkill -f "nginx" 2>/dev/null || true
sudo pkill -f "apache" 2>/dev/null || true

# Wait a moment to ensure ports are free
sleep 2

# Verify ports are free
if sudo netstat -tlnp | grep -E ":80 |:443 " > /dev/null; then
    print_error "Ports 80 and 443 are still in use. Please stop the services manually and try again."
    print_status "You can check what's using the ports with: sudo netstat -tlnp | grep -E ':80 |:443 '"
    exit 1
fi

print_success "Ports 80 and 443 are now free"

# Create a simple web server for SSL certificate validation
print_status "Setting up temporary web server for SSL certificate..."

# Create a simple HTML file for certificate validation
sudo mkdir -p /tmp/certbot-webroot/.well-known/acme-challenge
sudo tee /tmp/certbot-webroot/index.html > /dev/null << EOF
<!DOCTYPE html>
<html>
<head><title>Server Setup</title></head>
<body><h1>Server is ready for Django deployment!</h1></body>
</html>
EOF

# Start a temporary web server for certbot using Python's built-in server
print_status "Starting temporary web server on port 80..."
cd /tmp/certbot-webroot
sudo python3 -m http.server 80 &
HTTP_SERVER_PID=$!

# Wait a moment for the server to start and verify it's running
sleep 3
if ! sudo netstat -tlnp | grep ":80 " > /dev/null; then
    print_error "Failed to start temporary web server on port 80"
    exit 1
fi

print_success "Temporary web server started successfully"

# Obtain SSL certificate using webroot method
print_status "Obtaining SSL certificate for $DOMAIN_NAME..."
sudo certbot certonly --webroot --webroot-path=/tmp/certbot-webroot -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME

# Stop the temporary web server
print_status "Stopping temporary web server..."
sudo kill $HTTP_SERVER_PID 2>/dev/null || true

# Return to original directory
cd ~

# Set up automatic SSL renewal
print_status "Setting up automatic SSL renewal..."
sudo crontab -l 2>/dev/null | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | sudo crontab -

print_success "Server setup completed successfully!"
print_status "Server is now ready for Django deployment!"
print_status "Domain: $DOMAIN_NAME"
print_status "SSL Certificate: Active"

print_warning "Next steps:"
print_warning "1. Clone your Django project in ~/"
print_warning "2. Create your own docker-compose.yml and Dockerfile"
print_warning "3. Deploy your application"

print_success "You can now access your server at: https://$DOMAIN_NAME" 