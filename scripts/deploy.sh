#!/bin/bash

# Django Production Deployment Script
# This script builds and deploys the Django project using Docker Compose

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

# Export DOMAIN_NAME for Docker Compose
export DOMAIN_NAME

print_status "Starting deployment for domain: $DOMAIN_NAME"

# Check if we're in the project root
if [ ! -f "manage.py" ]; then
    print_error "This script must be run from the Django project root directory"
    exit 1
fi

# Check if required files exist
if [ ! -f "docker-compose.prod.yml" ]; then
    print_error "docker-compose.prod.yml not found"
    print_error "Please create the production Docker Compose file first"
    exit 1
fi

if [ ! -f "nginx/nginx.prod.conf" ]; then
    print_error "nginx/nginx.prod.conf not found"
    print_error "Please create the production nginx configuration first"
    exit 1
fi

# Check if SSL certificate exists
if [ ! -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
    print_error "SSL certificate not found for $DOMAIN_NAME"
    print_error "Please run the server setup script first: ./scripts/server_setup.sh $DOMAIN_NAME"
    exit 1
fi

print_success "SSL certificate found for $DOMAIN_NAME"

# Update nginx configuration with domain name
print_status "Updating nginx configuration with domain: $DOMAIN_NAME"
sed -i "s/yourdomain\.com/$DOMAIN_NAME/g" nginx/nginx.prod.conf
sed -i "s/www\.yourdomain\.com/www.$DOMAIN_NAME/g" nginx/nginx.prod.conf

print_success "Nginx configuration updated"

# Check if .env.prod exists, if not create from example
if [ ! -f ".env.prod" ]; then
    if [ -f "env.prod.example" ]; then
        print_status "Creating .env.prod from env.prod.example"
        cp env.prod.example .env.prod
        
        # Update domain in .env.prod (handle both variable and literal references)
        sed -i "s/yourdomain\.com/$DOMAIN_NAME/g" .env.prod
        sed -i "s/www\.yourdomain\.com/www.$DOMAIN_NAME/g" .env.prod
        sed -i "s/DOMAIN_NAME=yourdomain\.com/DOMAIN_NAME=$DOMAIN_NAME/g" .env.prod
        
        # Generate secure secret key
        SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
        sed -i "s/your-super-secret-production-key-change-this-immediately/$SECRET_KEY/g" .env.prod
        
        # Generate secure database password
        DB_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
        sed -i "s/your-strong-production-password/$DB_PASSWORD/g" .env.prod
        
        # Set secure file permissions
        chmod 600 .env.prod
        
        print_success ".env.prod created with secure defaults"
        print_warning "Please review and update .env.prod with your specific settings"
        print_warning "Especially update the email settings for your email provider"
    else
        print_error "No .env.prod or env.prod.example found"
        print_error "Please create a production environment file"
        exit 1
    fi
else
    print_status ".env.prod already exists, updating domain references..."
    # Update domain in existing .env.prod
    sed -i "s/yourdomain\.com/$DOMAIN_NAME/g" .env.prod
    sed -i "s/www\.yourdomain\.com/www.$DOMAIN_NAME/g" .env.prod
    sed -i "s/DOMAIN_NAME=yourdomain\.com/DOMAIN_NAME=$DOMAIN_NAME/g" .env.prod
    print_success "Domain references updated in existing .env.prod"
fi

# Create logs directory if it doesn't exist
print_status "Ensuring logs directory exists..."
mkdir -p logs

# Stop any existing containers
print_status "Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down 2>/dev/null || true

# Remove old images to ensure fresh build
print_status "Removing old images..."
docker-compose -f docker-compose.prod.yml down --rmi all 2>/dev/null || true

# Build and start containers
print_status "Building and starting containers..."
DOMAIN_NAME=$DOMAIN_NAME docker-compose -f docker-compose.prod.yml up -d --build

# Wait for containers to be ready
print_status "Waiting for containers to be ready..."
sleep 10

# Check if containers are running
if ! docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
    print_error "Containers failed to start"
    print_status "Checking container logs..."
    docker-compose -f docker-compose.prod.yml logs
    exit 1
fi

print_success "Containers started successfully"

# Note: Migrations and static collection are now handled in the container startup command
print_status "Migrations and static collection are handled during container startup..."

# Check if superuser exists, if not create one
print_status "Checking for superuser..."
if ! docker-compose -f docker-compose.prod.yml exec -T web python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); print('Superuser exists' if User.objects.filter(is_superuser=True).exists() else 'No superuser')" 2>/dev/null | grep -q "Superuser exists"; then
    print_warning "No superuser found. You can create one with:"
    print_warning "docker-compose -f docker-compose.prod.yml exec web python manage.py createsuperuser"
fi

# Test nginx configuration
print_status "Testing nginx configuration..."
if ! docker-compose -f docker-compose.prod.yml exec nginx nginx -t; then
    print_error "Nginx configuration test failed"
    exit 1
fi

print_success "Nginx configuration is valid"

# Check if the application is responding
print_status "Testing application response..."
sleep 5

# Test HTTP response
if curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN_NAME" | grep -q "301\|200"; then
    print_success "HTTP redirect working"
else
    print_warning "HTTP response test failed"
fi

# Test HTTPS response (if certificate is valid)
if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN_NAME" 2>/dev/null | grep -q "200"; then
    print_success "HTTPS response working"
else
    print_warning "HTTPS response test failed (this is normal if DNS is not configured yet)"
fi

# Show container status
print_status "Container status:"
docker-compose -f docker-compose.prod.yml ps

# Show useful commands
print_success "Deployment completed successfully!"
print_status "Your Django application is now running at: https://$DOMAIN_NAME"

echo ""
print_status "Useful commands:"
echo "  View logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "  Restart services: docker-compose -f docker-compose.prod.yml restart"
echo "  Stop services: docker-compose -f docker-compose.prod.yml down"
echo "  Create superuser: docker-compose -f docker-compose.prod.yml exec web python manage.py createsuperuser"
echo "  Shell access: docker-compose -f docker-compose.prod.yml exec web python manage.py shell"
echo ""

print_warning "Remember to:"
print_warning "- Configure your DNS to point $DOMAIN_NAME to this server"
print_warning "- Update email settings in .env.prod"
print_warning "- Set up regular backups"
print_warning "- Monitor your application logs" 