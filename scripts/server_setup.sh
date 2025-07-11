#!/bin/bash

# Server Setup Script for Ignite Website Deployment
# This script sets up a fresh Ubuntu server with all required dependencies
# and automatically configures SSL certificates

set -e  # Exit on any error

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
    echo -e "${PURPLE}[SETUP]${NC} $1"
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
    
    # Get OS info
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION
        print_success "Detected: $OS_NAME $OS_VERSION"
    fi
}

# Function to update system packages
update_system() {
    print_header "Updating system packages..."
    
    apt update
    apt upgrade -y
    
    # Install essential packages
    apt install -y \
        curl \
        wget \
        gnupg \
        lsb-release \
        ca-certificates \
        software-properties-common \
        apt-transport-https \
        unzip \
        git \
        nano \
        htop \
        ufw
    
    print_success "System packages updated successfully"
}

# Function to configure firewall
configure_firewall() {
    print_header "Configuring firewall..."
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (be careful not to lock yourself out)
    ufw allow ssh
    ufw allow 22/tcp
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall
    ufw --force enable
    
    print_success "Firewall configured successfully"
    print_status "Allowed ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
}

# Function to install Docker
install_docker() {
    print_header "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed"
        docker --version
        return 0
    fi
    
    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    apt update
    
    # Install Docker Engine
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group (if not root)
    if [[ $SUDO_USER ]]; then
        usermod -aG docker $SUDO_USER
        print_status "Added $SUDO_USER to docker group (logout/login required)"
    fi
    
    print_success "Docker installed successfully"
    docker --version
}

# Function to install Docker Compose (standalone)
install_docker_compose() {
    print_header "Installing Docker Compose..."
    
    # Check if docker-compose is already installed
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose is already installed"
        docker-compose --version
        return 0
    fi
    
    # Get latest version of Docker Compose
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    # Download and install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Make it executable
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for easier access
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose installed successfully"
    docker-compose --version
}

# Function to install Node.js and npm
install_nodejs() {
    print_header "Installing Node.js and npm..."
    
    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js is already installed: $NODE_VERSION"
        return 0
    fi
    
    # Install NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    
    # Install Node.js
    apt install -y nodejs
    
    # Verify installation
    print_success "Node.js and npm installed successfully"
    print_status "Node.js version: $(node --version)"
    print_status "npm version: $(npm --version)"
}

# Function to install certbot
install_certbot() {
    print_header "Installing certbot..."
    
    # Check if certbot is already installed
    if command -v certbot &> /dev/null; then
        print_success "Certbot is already installed"
        certbot --version
        return 0
    fi
    
    # Install certbot
    apt install -y certbot
    
    print_success "Certbot installed successfully"
    certbot --version
}

# Function to optimize system for Docker
optimize_system() {
    print_header "Optimizing system for Docker deployment..."
    
    # Increase file descriptor limits
    cat >> /etc/security/limits.conf << 'EOF'

# Docker optimization
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    
    # Configure Docker daemon
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
    
    # Restart Docker to apply changes
    systemctl restart docker
    
    print_success "System optimized for Docker deployment"
}

# Function to create swap file (if not exists)
create_swap() {
    print_header "Checking swap configuration..."
    
    # Check if swap is already configured
    if swapon --show | grep -q "/swapfile"; then
        print_success "Swap file already configured"
        return 0
    fi
    
    # Check available memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    
    if [[ $MEMORY_GB -lt 2 ]]; then
        print_status "Creating 2GB swap file for low memory system..."
        
        # Create 2GB swap file
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        
        # Make swap permanent
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        
        print_success "2GB swap file created and activated"
    else
        print_success "Sufficient memory available, no swap needed"
    fi
}

# Function to setup directory structure
setup_directories() {
    print_header "Setting up directory structure..."
    
    # Get the actual user who ran sudo
    if [[ $SUDO_USER ]]; then
        ACTUAL_USER=$SUDO_USER
        USER_HOME="/home/$SUDO_USER"
    else
        ACTUAL_USER="root"
        USER_HOME="/root"
    fi
    
    # Create directories for SSL certificates and logs
    mkdir -p /var/log/ssl-setup
    chown $ACTUAL_USER:$ACTUAL_USER /var/log/ssl-setup
    
    # Set proper permissions for letsencrypt directory (will be created by certbot)
    mkdir -p /etc/letsencrypt
    chmod 755 /etc/letsencrypt
    
    print_success "Directory structure created"
}

# Function to display system information
display_system_info() {
    print_header "System Information Summary"
    echo "================================"
    
    # System info
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    
    # Memory info
    echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "Swap: $(free -h | grep '^Swap:' | awk '{print $2}')"
    
    # Disk info
    echo "Disk Usage:"
    df -h / | tail -1 | awk '{print "  Root: " $3 " used / " $2 " total (" $5 " used)"}'
    
    # Installed versions
    echo
    echo "Installed Software:"
    echo "  Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    echo "  Docker Compose: $(docker-compose --version | cut -d' ' -f3 | tr -d ',')"
    echo "  Node.js: $(node --version)"
    echo "  npm: $(npm --version)"
    echo "  certbot: $(certbot --version | cut -d' ' -f2)"
    
    echo
    echo "Network Configuration:"
    echo "  Public IP: $(curl -s ifconfig.me || echo "Unable to detect")"
    echo "  Firewall Status: $(ufw status | head -1 | cut -d' ' -f2)"
    
    echo "================================"
}

# Function to run SSL setup
run_ssl_setup() {
    print_header "Running SSL certificate setup..."
    
    # Check if SSL setup script exists
    if [[ ! -f "./scripts/setup_ssl.sh" ]]; then
        print_error "SSL setup script not found. Please ensure scripts/setup_ssl.sh exists."
        return 1
    fi
    
    print_status "Starting SSL certificate setup..."
    print_warning "You will be prompted for domain name and email address"
    
    # Run SSL setup script
    bash ./scripts/setup_ssl.sh
    
    if [[ $? -eq 0 ]]; then
        print_success "SSL certificate setup completed successfully"
    else
        print_error "SSL certificate setup failed"
        return 1
    fi
}

# Main function
main() {
    echo "========================================================"
    echo "       Server Setup Script for Ignite Website         "
    echo "========================================================"
    echo
    echo "This script will install and configure:"
    echo "  ✓ Docker & Docker Compose"
    echo "  ✓ Node.js & npm"
    echo "  ✓ Certbot for SSL certificates"
    echo "  ✓ Firewall configuration"
    echo "  ✓ System optimizations"
    echo "  ✓ SSL certificate setup"
    echo
    
    # Check prerequisites
    check_root
    check_os
    
    echo -n "Continue with server setup? (y/N): "
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "Setup cancelled"
        exit 0
    fi
    
    echo
    print_header "Starting server setup process..."
    
    # Execute setup steps
    update_system
    configure_firewall
    install_docker
    install_docker_compose
    install_nodejs
    install_certbot
    create_swap
    optimize_system
    setup_directories
    
    # Display system information
    echo
    display_system_info
    
    echo
    print_success "Server setup completed successfully!"
    
    # Ask if user wants to run SSL setup now
    echo
    echo -n "Do you want to run SSL certificate setup now? (y/N): "
    read -r ssl_confirm
    
    if [[ $ssl_confirm =~ ^[Yy]$ ]]; then
        echo
        run_ssl_setup
    else
        print_status "SSL setup skipped. You can run it later with: sudo ./setup-ssl.sh"
    fi
    
    echo
    print_success "🚀 Server is ready for Ignite website deployment!"
    
    echo
    print_header "Next Steps:"
    echo "1. If you skipped SSL setup, run: sudo ./scripts/setup_ssl.sh"
    echo "2. Deploy your application: ./scripts/deploy_prod.sh build"
    echo "3. Your website will be available at: https://yourdomain.com"
    
    echo
    print_warning "Important Notes:"
    echo "• If you're not logged in as root, logout and login again for Docker permissions"
    echo "• Make sure your domain's DNS points to this server's IP: $(curl -s ifconfig.me)"
    echo "• Firewall is configured to allow ports 22, 80, and 443"
    
    echo
    print_status "Server setup completed at: $(date)"
}

# Run main function
main "$@" 