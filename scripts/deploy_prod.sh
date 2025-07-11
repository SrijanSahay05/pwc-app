#!/bin/bash

# Production Deployment Script for PWC App

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
    echo "  start       - Start production environment"
    echo "  stop        - Stop production environment"
    echo "  restart     - Restart production environment"
    echo "  build       - Build and start production environment"
    echo "  logs        - Show logs (use -f for follow)"
    echo "  migrate     - Run database migrations"
    echo "  createsuperuser - Create Django superuser"
    echo "  flush       - Flush database (clear all data)"
    echo "  shell       - Open Django shell"
    echo "  collectstatic - Collect static files"
    echo "  health      - Check application health"
    echo "  backup      - Create database backup"
    echo "  restore     - Restore database from backup"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs -f"
    echo "  $0 migrate"
    echo "  $0 backup"
}

# Function to check if .env.prod exists and create from example if needed
check_env() {
    if [ ! -f .env.prod ]; then
        if [ -f env.prod.example ]; then
            print_status "Creating .env.prod from env.prod.example..."
            cp env.prod.example .env.prod
            print_success ".env.prod created from example. Please review and configure as needed."
        else
            print_error ".env.prod file not found and env.prod.example not available."
            exit 1
        fi
    fi
    export $(cat .env.prod | grep -v '^#' | xargs)
}

# Function to check SSL certificates
check_ssl() {
    if [ ! -f ssl/cert.pem ] || [ ! -f ssl/key.pem ]; then
        print_error "SSL certificates not found. Please run scripts/setup_ssl.sh first."
        exit 1
    fi
}

# Function to create necessary directories
create_directories() {
    mkdir -p logs
}

# Function to run migrations in proper order
run_migrations() {
    print_status "Running database migrations in proper order..."
    
    # First, run core_users migrations
    print_status "Running core_users migrations..."
    docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T web python manage.py migrate core_users
    
    # Then run all other migrations
    print_status "Running all other migrations..."
    docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T web python manage.py migrate
    
    print_success "All migrations completed successfully!"
}

# Function to start production environment
start_prod() {
    print_status "Starting production environment..."
    check_env
    check_ssl
    create_directories
    
    docker-compose --env-file .env.prod -f docker-compose.prod.yml up -d
    print_success "Production environment started!"
}

# Function to stop production environment
stop_prod() {
    print_status "Stopping production environment..."
    docker-compose --env-file .env.prod -f docker-compose.prod.yml down
    print_success "Production environment stopped!"
}

# Function to restart production environment
restart_prod() {
    print_status "Restarting production environment..."
    stop_prod
    sleep 2
    start_prod
    print_success "Production environment restarted!"
}

# Function to build and start
build_prod() {
    print_status "Building and starting production environment..."
    check_env
    check_ssl
    create_directories
    
    docker-compose --env-file .env.prod -f docker-compose.prod.yml down
    docker-compose --env-file .env.prod -f docker-compose.prod.yml build
    docker-compose --env-file .env.prod -f docker-compose.prod.yml up -d
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    sleep 15
    
    # Run migrations
    run_migrations
    
    # Create superuser if needed
    print_status "Creating superuser..."
    docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T web python manage.py shell <<EOF
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
    docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T web python manage.py collectstatic --noinput
    
    # Check application health
    print_status "Checking application health..."
    sleep 5
    if curl -f http://localhost/health/ > /dev/null 2>&1; then
        print_success "Application is healthy!"
    else
        print_warning "Application health check failed, but deployment completed."
    fi
    
    print_success "Production deployment completed!"
    echo "🌐 Access your application at: https://$DOMAIN_NAME"
    echo "📊 Django admin at: https://$DOMAIN_NAME/admin"
}

# Function to show logs
show_logs() {
    if [ "$1" = "-f" ]; then
        docker-compose --env-file .env.prod -f docker-compose.prod.yml logs -f
    else
        docker-compose --env-file .env.prod -f docker-compose.prod.yml logs
    fi
}

# Function to run migrations
migrate_prod() {
    print_status "Running migrations..."
    run_migrations
}

# Function to create superuser
create_superuser() {
    print_status "Creating Django superuser..."
    check_env  # Ensure environment variables are loaded
    docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T web python manage.py shell <<EOF
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
    print_warning "This will clear ALL data from the production database!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Flushing database..."
        docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T web python manage.py flush --noinput
        print_success "Database flushed successfully!"
    else
        print_status "Database flush cancelled."
    fi
}

# Function to open Django shell
open_shell() {
    print_status "Opening Django shell..."
    docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T web python manage.py shell
}

# Function to collect static files
collect_static() {
    print_status "Collecting static files..."
    docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T web python manage.py collectstatic --noinput
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

# Function to create database backup
create_backup() {
    print_status "Creating database backup..."
    check_env
    
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T db pg_dump -U $DB_USER $DB_NAME > "$BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        print_success "Database backup created: $BACKUP_FILE"
    else
        print_error "Database backup failed!"
        exit 1
    fi
}

# Function to restore database from backup
restore_backup() {
    if [ -z "$1" ]; then
        print_error "Please specify backup file: $0 restore <backup_file>"
        exit 1
    fi
    
    BACKUP_FILE="$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    print_warning "This will overwrite the current database with backup: $BACKUP_FILE"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restoring database from backup..."
        docker-compose --env-file .env.prod -f docker-compose.prod.yml exec -T -U $DB_USER $DB_NAME < "$BACKUP_FILE"
        
        if [ $? -eq 0 ]; then
            print_success "Database restored successfully!"
        else
            print_error "Database restore failed!"
            exit 1
        fi
    else
        print_status "Database restore cancelled."
    fi
}

# Main execution
case "${1:-help}" in
    start)
        start_prod
        ;;
    stop)
        stop_prod
        ;;
    restart)
        restart_prod
        ;;
    build)
        build_prod
        ;;
    logs)
        show_logs "$2"
        ;;
    migrate)
        migrate_prod
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
    backup)
        create_backup
        ;;
    restore)
        restore_backup "$2"
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