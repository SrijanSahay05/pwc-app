# Scripts Directory

This directory contains deployment and setup scripts for the PWC App with comprehensive administrative controls.

## 📁 Scripts Overview

### 🚀 Deployment Scripts

#### `deploy_dev.sh`
Development environment management script with administrative controls.
- **Full deployment**: Sets up development environment with Docker
- **Administrative commands**: Start, stop, restart, logs, migrations, etc.
- **Database operations**: Migrations, superuser creation, shell access
- **Maintenance**: Static files, health checks, database flush

**Usage:**
```bash
./scripts/deploy_dev.sh [COMMAND]
```

**Available Commands:**
- `start` - Start development environment
- `stop` - Stop development environment
- `restart` - Restart development environment
- `build` - Build and start (full deployment)
- `logs` - Show logs (use `-f` for follow)
- `migrate` - Run database migrations
- `createsuperuser` - Create Django superuser
- `flush` - Flush database (clear all data)
- `shell` - Open Django shell
- `collectstatic` - Collect static files
- `health` - Check application health
- `help` - Show help message

#### `deploy_prod.sh`
Production environment management script with administrative controls.
- **Full deployment**: Sets up production environment with Docker and SSL
- **Administrative commands**: Start, stop, restart, logs, migrations, etc.
- **Database operations**: Migrations, superuser creation, shell access, backup/restore
- **Maintenance**: Static files, health checks, database flush

**Usage:**
```bash
./scripts/deploy_prod.sh [COMMAND]
```

**Available Commands:**
- `start` - Start production environment
- `stop` - Stop production environment
- `restart` - Restart production environment
- `build` - Build and start (full deployment)
- `logs` - Show logs (use `-f` for follow)
- `migrate` - Run database migrations
- `createsuperuser` - Create Django superuser
- `flush` - Flush database (clear all data)
- `shell` - Open Django shell
- `collectstatic` - Collect static files
- `health` - Check application health
- `backup` - Create database backup
- `restore` - Restore database from backup
- `help` - Show help message

### 🔒 SSL Setup Script

#### `setup_ssl.sh`
Automated SSL certificate setup script.
- Installs Certbot and prerequisites
- Obtains Let's Encrypt SSL certificates
- Configures Nginx with SSL
- Sets up auto-renewal
- Integrates with Docker containers

**Usage:**
```bash
# Interactive mode
sudo ./scripts/setup_ssl.sh

# With domain name
sudo ./scripts/setup_ssl.sh yourdomain.com
```

## 🔧 Administrative Commands

### Basic Operations
```bash
# Start environment
./scripts/deploy_dev.sh start
./scripts/deploy_prod.sh start

# Stop environment
./scripts/deploy_dev.sh stop
./scripts/deploy_prod.sh stop

# Restart environment
./scripts/deploy_dev.sh restart
./scripts/deploy_prod.sh restart

# View logs
./scripts/deploy_dev.sh logs
./scripts/deploy_prod.sh logs

# Follow logs in real-time
./scripts/deploy_dev.sh logs -f
./scripts/deploy_prod.sh logs -f
```

### Database Operations
```bash
# Run migrations (ensures core_users runs first)
./scripts/deploy_dev.sh migrate
./scripts/deploy_prod.sh migrate

# Create superuser (admin@email.com / test@123)
./scripts/deploy_dev.sh createsuperuser
./scripts/deploy_prod.sh createsuperuser

# Flush database (with confirmation)
./scripts/deploy_dev.sh flush
./scripts/deploy_prod.sh flush

# Open Django shell
./scripts/deploy_dev.sh shell
./scripts/deploy_prod.sh shell
```

### Production-Specific Operations
```bash
# Create database backup
./scripts/deploy_prod.sh backup

# Restore from backup
./scripts/deploy_prod.sh restore backup_20231201_143022.sql
```

### Maintenance Operations
```bash
# Collect static files
./scripts/deploy_dev.sh collectstatic
./scripts/deploy_prod.sh collectstatic

# Check application health
./scripts/deploy_dev.sh health
./scripts/deploy_prod.sh health
```

## 🔄 Migration Order

The scripts ensure proper migration order to prevent foreign key constraint issues:

1. **core_users migrations** run first (foundational user models)
2. **All other migrations** run second (dependent models)

This ensures data integrity and prevents dependency conflicts.

## 🔧 Script Features

### Automatic Directory Detection
All scripts automatically detect their location and navigate to the project root, so they can be run from any directory.

### Error Handling
- Comprehensive error checking
- Clear error messages with colored output
- Graceful failure handling

### Environment Validation
- Checks for required environment files
- Auto-generates .env files from examples if missing
- Validates SSL certificates (production)
- Ensures prerequisites are met

### Logging
- Colored output for better readability
- Progress indicators
- Success/failure status messages

### Safety Features
- Confirmation prompts for destructive operations
- Database flush requires explicit confirmation
- Backup operations create timestamped files

## 📋 Prerequisites

### For Development
- Docker and Docker Compose installed
- `.env.dev` file (auto-generated from env.dev.example if missing)

### For Production
- Docker and Docker Compose installed
- `.env.prod` file (auto-generated from env.prod.example if missing)
- Domain name pointing to server
- Root access for SSL setup
- Ports 80 and 443 available

## 🚀 Quick Start

### Development
```bash
# Environment file will be auto-generated from env.dev.example
# Edit .env.dev with your settings (if needed)
nano .env.dev

# Full deployment
./scripts/deploy_dev.sh build

# Or start only
./scripts/deploy_dev.sh start
```

### Production
```bash
# Environment file will be auto-generated from env.prod.example
# Edit .env.prod with your settings (if needed)
nano .env.prod

# Set up SSL certificates
./scripts/setup_ssl.sh

# Full deployment
./scripts/deploy_prod.sh build

# Or start only
./scripts/deploy_prod.sh start
```

## 🚨 Troubleshooting

### Common Issues

1. **Permission denied:**
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Environment file missing:**
   ```bash
   # Scripts will auto-generate from examples, but you can also do it manually:
   cp env.dev.example .env.dev
   cp env.prod.example .env.prod
   ```

3. **SSL setup fails:**
   - Ensure domain points to server
   - Check ports 80/443 are free
   - Verify root access

4. **Docker not running:**
   ```bash
   sudo systemctl start docker
   ```

5. **Migration issues:**
   ```bash
   # Run migrations manually
   ./scripts/deploy_dev.sh migrate
   ```

6. **Database connection issues:**
   ```bash
   # Check if containers are running
   docker-compose ps
   
   # View database logs
   ./scripts/deploy_dev.sh logs | grep db
   ```

### Logs and Debugging

```bash
# View all logs
./scripts/deploy_dev.sh logs

# Follow logs in real-time
./scripts/deploy_dev.sh logs -f

# Check health
./scripts/deploy_dev.sh health
```

## 📝 Notes

- Scripts are designed to be idempotent (safe to run multiple times)
- All scripts include proper error handling and validation
- SSL certificates auto-renew every 60 days
- Scripts automatically handle directory navigation
- Production scripts include health checks
- Database operations include safety confirmations
- Migration order is enforced to prevent dependency issues
- Backup files are timestamped for easy identification
- Default admin user: admin@email.com / test@123 