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
    nginx \
    certbot \
    python3-certbot-nginx

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

# Install nginx if not already installed
print_status "Installing nginx..."
sudo apt install -y nginx

# Create basic nginx configuration for SSL setup
print_status "Creating nginx configuration..."
sudo tee /etc/nginx/sites-available/$DOMAIN_NAME > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    
    location / {
        return 200 "Server is ready for Django deployment!";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx

# Obtain SSL certificate
print_status "Obtaining SSL certificate for $DOMAIN_NAME..."
sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME

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