#!/bin/bash

# Development Deployment Script for PWC App

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       - Start development environment"
    echo "  stop        - Stop development environment"
    echo "  restart     - Restart development environment"
    echo "  build       - Build and start development environment"
    echo "  logs        - Show logs (use -f for follow)"
    echo "  migrate     - Run database migrations"
    echo "  createsuperuser - Create Django superuser"
    echo "  flush       - Flush database (clear all data)"
    echo "  shell       - Open Django shell"
    echo "  collectstatic - Collect static files"
    echo "  health      - Check application health"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs -f"
    echo "  $0 migrate"
    echo "  $0 createsuperuser"
}

# Function to check if .env.dev exists and create from example if needed
check_env() {
    if [ ! -f .env.dev ]; then
        if [ -f env.dev.example ]; then
            print_status "Creating .env.dev from env.dev.example..."
            cp env.dev.example .env.dev
            print_success ".env.dev created from example. Please review and configure as needed."
        else
            print_error ".env.dev file not found and env.dev.example not available."
            exit 1
        fi
    fi
    export $(cat .env.dev | grep -v '^#' | xargs)
}

# Function to create necessary directories
create_directories() {
    mkdir -p logs ssl
}

# Function to run migrations in proper order
run_migrations() {
    print_status "Running database migrations in proper order..."
    
    # First, run core_users migrations
    print_status "Running core_users migrations..."
    docker-compose --env-file .env.dev -f docker-compose.dev.yml exec -T web python manage.py migrate core_users
    
    # Then run all other migrations
    print_status "Running all other migrations..."
    docker-compose --env-file .env.dev -f docker-compose.dev.yml exec -T web python manage.py migrate
    
    print_success "All migrations completed successfully!"
}

# Function to start development environment
start_dev() {
    print_status "Starting development environment..."
    check_env
    create_directories
    
    docker-compose --env-file .env.dev -f docker-compose.dev.yml up -d
    print_success "Development environment started!"
}

# Function to stop development environment
stop_dev() {
    print_status "Stopping development environment..."
    docker-compose --env-file .env.dev -f docker-compose.dev.yml down
    print_success "Development environment stopped!"
}

# Function to restart development environment
restart_dev() {
    print_status "Restarting development environment..."
    stop_dev
    sleep 2
    start_dev
    print_success "Development environment restarted!"
}

# Function to build and start
build_dev() {
    print_status "Building and starting development environment..."
    check_env
    create_directories
    
    docker-compose --env-file .env.dev -f docker-compose.dev.yml down
    docker-compose --env-file .env.dev -f docker-compose.dev.yml build
    docker-compose --env-file .env.dev -f docker-compose.dev.yml up -d
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    sleep 10
    
    # Run migrations
    run_migrations
    
    # Create superuser if needed
    print_status "Creating superuser..."
    docker-compose --env-file .env.dev -f docker-compose.dev.yml exec -T web python manage.py shell <<EOF
from core_users.models import CustomUser

email = "admin@email.com"
phone = "0000000000"
password = "test@123"

if not CustomUser.objects.filter(email=email).exists():
    admin = CustomUser.objects.create(
        email=email,
        phone=phone,
        first_name='admin',
        last_name='user',
        is_staff=True,
        is_superuser=True
    )
    admin.set_password(password)
    admin.save()
    print("Admin user created successfully!")
else:
    print("Admin user already exists.")
EOF
    
    # Collect static files
    print_status "Collecting static files..."
    docker-compose --env-file .env.dev -f docker-compose.dev.yml exec -T web python manage.py collectstatic --noinput
    
    print_success "Development deployment completed!"
    echo "🌐 Access your application at: http://localhost"
    echo "📊 Django admin at: http://localhost/admin"
}

# Function to show logs
show_logs() {
    if [ "$1" = "-f" ]; then
        docker-compose --env-file .env.dev -f docker-compose.dev.yml logs -f
    else
        docker-compose --env-file .env.dev -f docker-compose.dev.yml logs
    fi
}

# Function to run migrations
migrate_dev() {
    print_status "Running migrations..."
    run_migrations
}

# Function to create superuser
create_superuser() {
    print_status "Creating Django superuser..."
    check_env  # Ensure environment variables are loaded
    docker-compose --env-file .env.dev -f docker-compose.dev.yml exec -T web python manage.py shell <<EOF
from core_users.models import CustomUser

email = "admin@email.com"
phone = "0000000000"
password = "test@123"

if not CustomUser.objects.filter(email=email).exists():
    admin = CustomUser.objects.create(
        email=email,
        phone=phone,
        first_name='admin',
        last_name='user',
        is_staff=True,
        is_superuser=True
    )
    admin.set_password(password)
    admin.save()
    print("Admin user created successfully!")
else:
    print("Admin user already exists.")
EOF
    
    print_success "Superuser setup completed!"
    echo "📧 Email: admin@email.com"
    echo "📱 Phone: 0000000000"
    echo "🔑 Password: test@123"
}

# Function to flush database
flush_database() {
    print_warning "This will clear ALL data from the database!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Flushing database..."
        docker-compose --env-file .env.dev -f docker-compose.dev.yml exec -T web python manage.py flush --noinput
        print_success "Database flushed successfully!"
    else
        print_status "Database flush cancelled."
    fi
}

# Function to open Django shell
open_shell() {
    print_status "Opening Django shell..."
    docker-compose --env-file .env.dev -f docker-compose.dev.yml exec -T web python manage.py shell
}

# Function to collect static files
collect_static() {
    print_status "Collecting static files..."
    docker-compose --env-file .env.dev -f docker-compose.dev.yml exec -T web python manage.py collectstatic --noinput
    print_success "Static files collected!"
}

# Function to check health
check_health() {
    print_status "Checking application health..."
    if curl -f http://localhost/health/ > /dev/null 2>&1; then
        print_success "Application is healthy!"
    else
        print_error "Application health check failed!"
        exit 1
    fi
}

# Main execution
case "${1:-help}" in
    start)
        start_dev
        ;;
    stop)
        stop_dev
        ;;
    restart)
        restart_dev
        ;;
    build)
        build_dev
        ;;
    logs)
        show_logs "$2"
        ;;
    migrate)
        migrate_dev
        ;;
    createsuperuser)
        create_superuser
        ;;
    flush)
        flush_database
        ;;
    shell)
        open_shell
        ;;
    collectstatic)
        collect_static
        ;;
    health)
        check_health
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac 