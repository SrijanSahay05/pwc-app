#!/bin/bash

# Complete Server Deployment Script for PWC App
# This script sets up a fresh server, configures SSL, and deploys the application

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root
cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_header() {
    echo -e "${PURPLE}[DEPLOY]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --domain DOMAIN     - Domain name for SSL certificate"
    echo "  --email EMAIL       - Email for Let's Encrypt notifications"
    echo "  --skip-ssl          - Skip SSL certificate setup"
    echo "  --skip-server-setup - Skip server setup (Docker, etc.)"
    echo "  --help              - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --domain example.com --email admin@example.com"
    echo "  $0 --domain example.com --email admin@example.com --skip-server-setup"
    echo "  $0 --skip-ssl  # For development/testing"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to parse command line arguments
parse_args() {
    DOMAIN=""
    EMAIL=""
    SKIP_SSL=false
    SKIP_SERVER_SETUP=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --email)
                EMAIL="$2"
                shift 2
                ;;
            --skip-ssl)
                SKIP_SSL=true
                shift
                ;;
            --skip-server-setup)
                SKIP_SERVER_SETUP=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ "$SKIP_SSL" == false ]] && [[ -z "$DOMAIN" ]]; then
        print_error "Domain name is required for SSL setup"
        show_usage
        exit 1
    fi
    
    if [[ "$SKIP_SSL" == false ]] && [[ -z "$EMAIL" ]]; then
        print_error "Email is required for SSL setup"
        show_usage
        exit 1
    fi
}

# Function to run server setup
run_server_setup() {
    print_header "Running server setup..."
    
    if [ ! -f "./scripts/server_setup.sh" ]; then
        print_error "Server setup script not found: ./scripts/server_setup.sh"
        exit 1
    fi
    
    print_status "Setting up server with Docker, Node.js, and other dependencies..."
    bash ./scripts/server_setup.sh
    
    if [[ $? -eq 0 ]]; then
        print_success "Server setup completed successfully!"
    else
        print_error "Server setup failed!"
        exit 1
    fi
}

# Function to run SSL setup
run_ssl_setup() {
    print_header "Running SSL certificate setup..."
    
    if [ ! -f "./scripts/setup_ssl.sh" ]; then
        print_error "SSL setup script not found: ./scripts/setup_ssl.sh"
        exit 1
    fi
    
    print_status "Setting up SSL certificates for domain: $DOMAIN"
    print_status "Email for notifications: $EMAIL"
    
    # Run the SSL setup script directly
    # The script will prompt for domain and email, but we can provide them
    print_status "Starting SSL setup process..."
    print_warning "You will be prompted for domain and email. Use:"
    print_warning "  Domain: $DOMAIN"
    print_warning "  Email: $EMAIL"
    
    bash ./scripts/setup_ssl.sh
    
    if [[ $? -eq 0 ]]; then
        print_success "SSL setup completed successfully!"
    else
        print_error "SSL setup failed!"
        exit 1
    fi
}

# Function to deploy application
deploy_application() {
    print_header "Deploying application..."
    
    if [ ! -f "./scripts/deploy_prod.sh" ]; then
        print_error "Production deployment script not found: ./scripts/deploy_prod.sh"
        exit 1
    fi
    
    print_status "Building and deploying application..."
    ./scripts/deploy_prod.sh build
    
    if [[ $? -eq 0 ]]; then
        print_success "Application deployed successfully!"
    else
        print_error "Application deployment failed!"
        exit 1
    fi
}

# Function to display deployment summary
display_summary() {
    print_header "Deployment Summary"
    echo "==================="
    
    if [[ "$SKIP_SERVER_SETUP" == false ]]; then
        echo "✓ Server setup completed"
    else
        echo "⚠ Server setup skipped"
    fi
    
    if [[ "$SKIP_SSL" == false ]]; then
        echo "✓ SSL certificates configured for: $DOMAIN"
    else
        echo "⚠ SSL setup skipped"
    fi
    
    echo "✓ Application deployed"
    
    echo
    print_success "🚀 Deployment completed successfully!"
    
    if [[ "$SKIP_SSL" == false ]]; then
        echo
        print_status "Your application is now available at:"
        echo "  🌐 https://$DOMAIN"
        echo "  📊 https://$DOMAIN/admin"
    else
        echo
        print_status "Your application is now available at:"
        echo "  🌐 http://$(curl -s ifconfig.me || echo "your-server-ip")"
        echo "  📊 http://$(curl -s ifconfig.me || echo "your-server-ip")/admin"
    fi
    
    echo
    print_status "Default admin credentials:"
    echo "  📧 Email: admin@email.com"
    echo "  🔑 Password: test@123"
    
    echo
    print_warning "Important notes:"
    echo "• Change the default admin password after first login"
    echo "• Monitor application logs: ./scripts/deploy_prod.sh logs"
    echo "• Check application health: ./scripts/deploy_prod.sh health"
    echo "• SSL certificates will auto-renew every 60 days"
}

# Main function
main() {
    echo "========================================================"
    echo "       Complete Server Deployment for PWC App         "
    echo "========================================================"
    echo
    
    # Check if running as root
    check_root
    
    # Parse command line arguments
    parse_args "$@"
    
    # Show deployment plan
    print_header "Deployment Plan"
    echo "=================="
    if [[ "$SKIP_SERVER_SETUP" == false ]]; then
        echo "1. Server setup (Docker, Node.js, etc.)"
    else
        echo "1. Server setup (SKIPPED)"
    fi
    
    if [[ "$SKIP_SSL" == false ]]; then
        echo "2. SSL certificate setup for: $DOMAIN"
    else
        echo "2. SSL setup (SKIPPED)"
    fi
    
    echo "3. Application deployment"
    echo
    
    echo -n "Continue with deployment? (y/N): "
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled"
        exit 0
    fi
    
    echo
    print_header "Starting deployment process..."
    
    # Step 1: Server setup
    if [[ "$SKIP_SERVER_SETUP" == false ]]; then
        run_server_setup
    else
        print_status "Skipping server setup as requested"
    fi
    
    # Step 2: SSL setup
    if [[ "$SKIP_SSL" == false ]]; then
        run_ssl_setup
    else
        print_status "Skipping SSL setup as requested"
    fi
    
    # Step 3: Application deployment
    deploy_application
    
    # Display summary
    display_summary
}

# Run main function with all arguments
main "$@" 