#!/bin/bash

# Generic SSL Setup Script for Ubuntu Server with Docker Compose
# This script sets up SSL certification using certbot for projects deployed with Docker Compose + nginx
# Compatible with Ubuntu/Debian systems

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

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to check if running on Ubuntu/Debian
check_os() {
    if [[ ! -f /etc/debian_version ]]; then
        print_error "This script is designed for Ubuntu/Debian systems only"
        exit 1
    fi
    print_success "Running on Ubuntu/Debian system"
}

# Function to check if domain is accessible
check_domain_accessibility() {
    local domain=$1
    print_status "Checking if domain $domain is accessible..."
    
    if curl -s --connect-timeout 10 -I "http://$domain" > /dev/null 2>&1; then
        print_success "Domain $domain is accessible"
        return 0
    else
        print_warning "Domain $domain may not be accessible. SSL setup may fail."
        echo -n "Continue anyway? (y/N): "
        read -r continue_choice
        if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
            print_error "Exiting..."
            exit 1
        fi
    fi
}

# Function to install certbot using apt
install_certbot() {
    print_status "Checking if certbot is installed..."
    
    if command -v certbot &> /dev/null; then
        print_success "Certbot is already installed"
        return 0
    fi
    
    print_status "Installing certbot using apt..."
    
    # Update package list
    apt update
    
    # Install certbot
    apt install -y certbot
    
    print_success "Certbot installed successfully"
}

# Function to stop services that might use port 80/443
stop_services_on_ports() {
    print_status "Checking for services using ports 80 and 443..."
    
    # Check if docker is installed and running
    if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
        # Stop all docker compose services in current directory
        if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
            print_status "Stopping Docker Compose services..."
            docker-compose down 2>/dev/null || true
        fi
        
        # Also check for common compose file names
        for compose_file in docker-compose.prod.yml docker-compose.dev.yml docker-compose.staging.yml; do
            if [[ -f "$compose_file" ]]; then
                print_status "Stopping Docker Compose services from $compose_file..."
                docker-compose -f "$compose_file" down 2>/dev/null || true
            fi
        done
        
        # Stop any containers using ports 80 or 443
        containers_on_port_80=$(docker ps --filter "publish=80" --format "{{.ID}}" 2>/dev/null || true)
        containers_on_port_443=$(docker ps --filter "publish=443" --format "{{.ID}}" 2>/dev/null || true)
        
        if [[ -n "$containers_on_port_80" ]]; then
            print_status "Stopping containers using port 80..."
            echo "$containers_on_port_80" | xargs docker stop 2>/dev/null || true
        fi
        
        if [[ -n "$containers_on_port_443" ]]; then
            print_status "Stopping containers using port 443..."
            echo "$containers_on_port_443" | xargs docker stop 2>/dev/null || true
        fi
    fi
    
    # Check if nginx is running on the host
    if systemctl is-active --quiet nginx 2>/dev/null; then
        print_status "Stopping nginx service on host..."
        systemctl stop nginx
    fi
    
    # Check if apache is running on the host
    if systemctl is-active --quiet apache2 2>/dev/null; then
        print_status "Stopping apache2 service on host..."
        systemctl stop apache2
    fi
    
    # Wait a moment for ports to be freed
    sleep 2
}

# Function to obtain SSL certificate
obtain_ssl_certificate() {
    local domain=$1
    local email=$2
    local additional_domains=$3
    
    print_status "Obtaining SSL certificate for $domain..."
    
    # Stop services that might use ports 80/443
    stop_services_on_ports
    
    # Build certbot command
    local certbot_cmd="certbot certonly --standalone --non-interactive --agree-tos --email \"$email\" -d \"$domain\""
    
    # Add additional domains if provided
    if [[ -n "$additional_domains" ]]; then
        IFS=',' read -ra ADDR <<< "$additional_domains"
        for domain_part in "${ADDR[@]}"; do
            domain_part=$(echo "$domain_part" | xargs)  # trim whitespace
            if [[ -n "$domain_part" ]]; then
                certbot_cmd="$certbot_cmd -d \"$domain_part\""
            fi
        done
    fi
    
    # Execute certbot command
    if eval "$certbot_cmd"; then
        print_success "SSL certificate obtained successfully"
    else
        print_error "Failed to obtain SSL certificate"
        print_error "Common issues:"
        print_error "1. Domain DNS doesn't point to this server"
        print_error "2. Port 80 is not accessible from the internet"
        print_error "3. Firewall is blocking port 80"
        print_error "4. Domain validation failed"
        exit 1
    fi
}

# Function to setup auto-renewal
setup_auto_renewal() {
    print_status "Setting up automatic certificate renewal..."
    
    # Create renewal script that handles Docker containers
    cat > /usr/local/bin/certbot-docker-renew.sh << 'EOF'
#!/bin/bash

# SSL Certificate Renewal Script for Docker Compose Projects
# This script stops Docker containers before renewal and restarts them after

set -e

LOGFILE="/var/log/certbot-renewal.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting certificate renewal process..."

# Find and stop containers using ports 80 and 443
STOPPED_CONTAINERS_80=""
STOPPED_CONTAINERS_443=""

if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    # Stop containers using port 80
    containers_on_port_80=$(docker ps --filter "publish=80" --format "{{.ID}}" 2>/dev/null || true)
    if [[ -n "$containers_on_port_80" ]]; then
        log "Stopping containers using port 80: $containers_on_port_80"
        echo "$containers_on_port_80" | xargs docker stop 2>/dev/null || true
        STOPPED_CONTAINERS_80="$containers_on_port_80"
    fi
    
    # Stop containers using port 443
    containers_on_port_443=$(docker ps --filter "publish=443" --format "{{.ID}}" 2>/dev/null || true)
    if [[ -n "$containers_on_port_443" ]]; then
        log "Stopping containers using port 443: $containers_on_port_443"
        echo "$containers_on_port_443" | xargs docker stop 2>/dev/null || true
        STOPPED_CONTAINERS_443="$containers_on_port_443"
    fi
fi

# Wait for ports to be freed
sleep 5

# Renew certificates
log "Renewing certificates..."
if certbot renew --quiet; then
    log "Certificate renewal successful"
else
    log "Certificate renewal failed"
fi

# Restart stopped containers
if [[ -n "$STOPPED_CONTAINERS_80" ]]; then
    log "Restarting containers that were using port 80..."
    echo "$STOPPED_CONTAINERS_80" | xargs docker start 2>/dev/null || true
fi

if [[ -n "$STOPPED_CONTAINERS_443" ]]; then
    log "Restarting containers that were using port 443..."
    echo "$STOPPED_CONTAINERS_443" | xargs docker start 2>/dev/null || true
fi

log "Certificate renewal process completed"
EOF
    
    chmod +x /usr/local/bin/certbot-docker-renew.sh
    
    # Create cron job for automatic renewal
    cat > /etc/cron.d/certbot-docker << 'EOF'
# Renew SSL certificates twice daily for Docker Compose projects
# Runs at random times to avoid overloading Let's Encrypt servers
0 12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && /usr/local/bin/certbot-docker-renew.sh
0 0 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && /usr/local/bin/certbot-docker-renew.sh
EOF
    
    print_success "Auto-renewal configured"
    print_status "Renewal logs will be stored in: /var/log/certbot-renewal.log"
}

# Function to display certificate information
display_certificate_info() {
    local domain=$1
    
    print_status "Certificate information:"
    echo "========================"
    echo "Certificate location: /etc/letsencrypt/live/$domain/"
    echo "Full chain: /etc/letsencrypt/live/$domain/fullchain.pem"
    echo "Private key: /etc/letsencrypt/live/$domain/privkey.pem"
    echo "Certificate: /etc/letsencrypt/live/$domain/cert.pem"
    echo "Chain: /etc/letsencrypt/live/$domain/chain.pem"
    echo
    
    # Show certificate expiry
    if [[ -f "/etc/letsencrypt/live/$domain/cert.pem" ]]; then
        expiry_date=$(openssl x509 -noout -dates -in "/etc/letsencrypt/live/$domain/cert.pem" | grep "notAfter" | cut -d= -f2)
        print_status "Certificate expires: $expiry_date"
    fi
}

# Function to create sample docker-compose configuration
create_sample_config() {
    local domain=$1
    
    echo
    echo -n "Create sample docker-compose SSL configuration? (y/N): "
    read -r create_sample
    
    if [[ $create_sample =~ ^[Yy]$ ]]; then
        print_status "Creating sample docker-compose.ssl.yml..."
        
        cat > docker-compose.ssl.yml << EOF
version: '3.8'

services:
  # Your application service
  app:
    # Add your app configuration here
    # build: .
    # image: your-app:latest
    restart: unless-stopped
    networks:
      - app-network

  # Nginx with SSL support
  nginx:
    image: nginx:alpine
    container_name: nginx-ssl
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      # SSL certificates from Let's Encrypt
      - /etc/letsencrypt:/etc/letsencrypt:ro
      # Your nginx configuration
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      # Your static files (if any)
      # - ./public:/usr/share/nginx/html:ro
    depends_on:
      - app
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
EOF
        
        print_success "Created docker-compose.ssl.yml"
        
        # Create sample nginx configuration
        print_status "Creating sample nginx.conf with SSL..."
        
        cat > nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $domain;
        return 301 https://\$server_name\$request_uri;
    }
    
    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $domain;
        
        # SSL certificate files
        ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
        
        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
        
        # SSL session settings
        ssl_session_timeout 1d;
        ssl_session_cache shared:MozTLS:10m;
        ssl_session_tickets off;
        
        # OCSP stapling
        ssl_stapling on;
        ssl_stapling_verify on;
        
        # Security headers
        add_header Strict-Transport-Security "max-age=63072000" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        
        # Proxy to your application (adjust as needed)
        location / {
            # For static files, use:
            # root /usr/share/nginx/html;
            # try_files \$uri \$uri/ /index.html;
            
            # For proxying to an app container, use:
            proxy_pass http://app:3000;  # Adjust port as needed
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        # Optional: Serve static assets with caching
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF
        
        print_success "Created sample nginx.conf"
        print_warning "Remember to:"
        print_warning "1. Adjust the proxy_pass URL in nginx.conf to match your app"
        print_warning "2. Update the docker-compose.ssl.yml with your app configuration"
        print_warning "3. Test the configuration before deploying"
    fi
}

# Main function
main() {
    echo "================================================"
    echo "  Generic SSL Setup Script for Docker Compose  "
    echo "================================================"
    echo
    
    # Check prerequisites
    check_root
    check_os
    
    # Get domain name from user
    echo -n "Enter your primary domain name (e.g., example.com): "
    read -r domain
    
    if [[ -z "$domain" ]]; then
        print_error "Domain name cannot be empty"
        exit 1
    fi
    
    # Basic domain validation - must contain a dot
    if [[ ! "$domain" == *.* ]]; then
        print_error "Invalid domain name format (must contain a dot, like: example.com)"
        exit 1
    fi
    
    # Get additional domains (optional)
    echo -n "Enter additional domains (comma-separated, optional): "
    read -r additional_domains
    
    # Get email for Let's Encrypt
    echo -n "Enter your email address for Let's Encrypt notifications: "
    read -r email
    
    if [[ -z "$email" ]]; then
        print_error "Email address cannot be empty"
        exit 1
    fi
    
    # Validate email format
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        print_error "Invalid email address format"
        exit 1
    fi
    
    # Show summary
    echo
    print_status "Configuration Summary:"
    echo "Primary domain: $domain"
    if [[ -n "$additional_domains" ]]; then
        echo "Additional domains: $additional_domains"
    fi
    echo "Email: $email"
    echo
    echo -n "Proceed with SSL setup? (y/N): "
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "Setup cancelled"
        exit 0
    fi
    
    echo
    print_status "Starting SSL setup process..."
    
    # Check domain accessibility
    check_domain_accessibility "$domain"
    
    # Install certbot
    install_certbot
    
    # Obtain SSL certificate
    obtain_ssl_certificate "$domain" "$email" "$additional_domains"
    
    # Setup auto-renewal
    setup_auto_renewal
    
    # Display certificate information
    display_certificate_info "$domain"
    
    # Create sample configuration
    create_sample_config "$domain"
    
    echo
    print_success "SSL setup completed successfully!"
    print_success "SSL certificates are ready for use with Docker Compose"
    
    echo
    print_status "Important notes:"
    echo "1. Certificates are stored in /etc/letsencrypt/live/$domain/"
    echo "2. Mount /etc/letsencrypt volume in your nginx container"
    echo "3. Auto-renewal is configured and will handle Docker containers"
    echo "4. Test your setup: docker-compose up -d"
    echo "5. Verify SSL: https://www.ssllabs.com/ssltest/"
    echo
    print_status "Next steps:"
    echo "1. Update your docker-compose.yml to include SSL configuration"
    echo "2. Configure nginx to use the SSL certificates"
    echo "3. Test your deployment"
    echo "4. Monitor renewal logs: tail -f /var/log/certbot-renewal.log"
}

# Run main function
main "$@" 