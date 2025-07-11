#!/bin/bash

# SSL Certificate Setup Script for PWC App
# This script sets up SSL certificates using Certbot

set -e

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to get domain name
get_domain() {
    if [ -z "$1" ]; then
        read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
    else
        DOMAIN_NAME=$1
    fi
    
    if [ -z "$DOMAIN_NAME" ]; then
        print_error "Domain name cannot be empty"
        exit 1
    fi
    
    print_success "Domain set to: $DOMAIN_NAME"
}

# Function to check and install prerequisites
install_prerequisites() {
    print_status "Checking and installing prerequisites..."
    
    # Update package list
    if command_exists apt-get; then
        print_status "Updating package list..."
        apt-get update
        
        # Install required packages
        print_status "Installing required packages..."
        apt-get install -y curl wget software-properties-common
        
        # Add Certbot repository
        print_status "Adding Certbot repository..."
        add-apt-repository -y ppa:certbot/certbot
        apt-get update
        
        # Install Certbot
        print_status "Installing Certbot..."
        apt-get install -y certbot python3-certbot-nginx
        
    elif command_exists yum; then
        print_status "Installing required packages (yum)..."
        yum install -y curl wget epel-release
        
        # Install Certbot
        print_status "Installing Certbot..."
        yum install -y certbot python3-certbot-nginx
        
    elif command_exists dnf; then
        print_status "Installing required packages (dnf)..."
        dnf install -y curl wget
        
        # Install Certbot
        print_status "Installing Certbot..."
        dnf install -y certbot python3-certbot-nginx
        
    else
        print_error "Unsupported package manager. Please install certbot manually."
        exit 1
    fi
    
    print_success "Prerequisites installed successfully"
}

# Function to check if Nginx is installed
check_nginx() {
    if ! command_exists nginx; then
        print_warning "Nginx is not installed. Installing Nginx..."
        
        if command_exists apt-get; then
            apt-get install -y nginx
        elif command_exists yum; then
            yum install -y nginx
        elif command_exists dnf; then
            dnf install -y nginx
        else
            print_error "Cannot install Nginx automatically. Please install it manually."
            exit 1
        fi
        
        # Start and enable Nginx
        systemctl start nginx
        systemctl enable nginx
        print_success "Nginx installed and started"
    else
        print_success "Nginx is already installed"
    fi
}

# Function to create basic Nginx configuration
create_nginx_config() {
    print_status "Creating basic Nginx configuration for $DOMAIN_NAME..."
    
    # Create Nginx configuration file
    cat > /etc/nginx/sites-available/$DOMAIN_NAME << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /static/ {
        alias /app/staticfiles/;
    }
    
    location /media/ {
        alias /app/media/;
    }
}
EOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
    
    # Test Nginx configuration
    if nginx -t; then
        systemctl reload nginx
        print_success "Nginx configuration created and loaded"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
}

# Function to obtain SSL certificate
obtain_ssl_certificate() {
    print_status "Obtaining SSL certificate for $DOMAIN_NAME..."
    
    # Stop Nginx temporarily for certbot
    systemctl stop nginx
    
    # Obtain certificate
    if certbot certonly --standalone -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME; then
        print_success "SSL certificate obtained successfully"
    else
        print_error "Failed to obtain SSL certificate"
        systemctl start nginx
        exit 1
    fi
    
    # Start Nginx
    systemctl start nginx
}

# Function to create SSL Nginx configuration
create_ssl_nginx_config() {
    print_status "Creating SSL Nginx configuration..."
    
    # Create SSL Nginx configuration
    cat > /etc/nginx/sites-available/$DOMAIN_NAME << EOF
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    # Static files
    location /static/ {
        alias /app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias /app/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    # Test and reload Nginx
    if nginx -t; then
        systemctl reload nginx
        print_success "SSL Nginx configuration created and loaded"
    else
        print_error "SSL Nginx configuration test failed"
        exit 1
    fi
}

# Function to set up auto-renewal
setup_auto_renewal() {
    print_status "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > /etc/cron.d/certbot-renew << EOF
# Certbot renewal
0 12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
EOF
    
    # Test renewal
    if certbot renew --dry-run; then
        print_success "Auto-renewal setup completed"
    else
        print_warning "Auto-renewal test failed, but setup completed"
    fi
}

# Function to create Docker SSL directory
create_ssl_directory() {
    print_status "Creating SSL directory for Docker..."
    
    mkdir -p /opt/pwc-app/ssl
    
    # Copy certificates to Docker directory
    cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem /opt/pwc-app/ssl/cert.pem
    cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem /opt/pwc-app/ssl/key.pem
    
    # Set proper permissions
    chmod 644 /opt/pwc-app/ssl/cert.pem
    chmod 600 /opt/pwc-app/ssl/key.pem
    
    print_success "SSL certificates copied to /opt/pwc-app/ssl/"
}

# Function to create renewal hook
create_renewal_hook() {
    print_status "Creating renewal hook for Docker..."
    
    cat > /etc/letsencrypt/renewal-hooks/post/copy-to-docker.sh << EOF
#!/bin/bash
# Copy renewed certificates to Docker directory
cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem /opt/pwc-app/ssl/cert.pem
cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem /opt/pwc-app/ssl/key.pem
chmod 644 /opt/pwc-app/ssl/cert.pem
chmod 600 /opt/pwc-app/ssl/key.pem

# Reload Docker containers if running
if docker ps | grep -q pwc-app; then
    docker-compose -f /opt/pwc-app/docker-compose.prod.yml restart nginx
fi
EOF
    
    chmod +x /etc/letsencrypt/renewal-hooks/post/copy-to-docker.sh
    print_success "Renewal hook created"
}

# Main execution
main() {
    print_status "Starting SSL certificate setup..."
    
    # Check if running as root
    check_root
    
    # Get domain name
    get_domain "$1"
    
    # Install prerequisites
    install_prerequisites
    
    # Check Nginx
    check_nginx
    
    # Create basic Nginx configuration
    create_nginx_config
    
    # Obtain SSL certificate
    obtain_ssl_certificate
    
    # Create SSL Nginx configuration
    create_ssl_nginx_config
    
    # Set up auto-renewal
    setup_auto_renewal
    
    # Create Docker SSL directory
    create_ssl_directory
    
    # Create renewal hook
    create_renewal_hook
    
    print_success "SSL certificate setup completed successfully!"
    print_status "Your domain $DOMAIN_NAME is now accessible via HTTPS"
    print_status "Certificates will auto-renew every 60 days"
    print_status "SSL certificates are available in /opt/pwc-app/ssl/ for Docker"
}

# Run main function with command line argument
main "$@" 