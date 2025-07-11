# Docker Setup for PWC App

This guide covers setting up and deploying the PWC App using Docker for both development and production environments.

## 📋 Prerequisites

- Docker and Docker Compose installed
- Domain name (for production)
- Server with root access (for production SSL)

## 🚀 Quick Start

### Development Environment

1. **Copy environment file:**
   ```bash
   cp env.dev.example .env.dev
   ```

2. **Edit `.env.dev` with your settings**

3. **Deploy:**
   ```bash
   ./scripts/deploy_dev.sh
   ```

4. **Access the application:**
   - App: http://localhost
   - Admin: http://localhost/admin

### Production Environment

1. **Set up SSL certificates:**
   ```bash
   sudo ./scripts/setup_ssl.sh yourdomain.com
   ```

2. **Copy environment file:**
   ```bash
   cp env.prod.example .env.prod
   ```

3. **Edit `.env.prod` with your production settings**

4. **Deploy:**
   ```bash
   ./scripts/deploy_prod.sh
   ```

5. **Access the application:**
   - App: https://yourdomain.com
   - Admin: https://yourdomain.com/admin

## 📁 File Structure

```
pwc-app/
├── Dockerfile.dev              # Development Dockerfile
├── Dockerfile.prod             # Production Dockerfile
├── docker-compose.dev.yml      # Development compose
├── docker-compose.prod.yml     # Production compose
├── nginx/
│   ├── nginx.dev.conf         # Development Nginx config
│   └── nginx.prod.conf        # Production Nginx config
├── scripts/
│   ├── setup_ssl.sh           # SSL certificate setup script
│   ├── deploy_dev.sh          # Development deployment script
│   └── deploy_prod.sh         # Production deployment script
├── env.dev.example            # Development environment template
├── env.prod.example           # Production environment template
└── ssl/                       # SSL certificates directory
```

## 🔧 Configuration

### Environment Variables

#### Development (.env.dev)
```bash
DEBUG=True
SECRET_KEY=your-secret-key
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0
DB_NAME=pwc_dev
DB_USER=pwc_user
DB_PASSWORD=pwc_password
```

#### Production (.env.prod)
```bash
DEBUG=False
SECRET_KEY=your-super-secret-production-key
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
CSRF_TRUSTED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
DB_NAME=pwc_prod
DB_USER=pwc_prod_user
DB_PASSWORD=your-strong-production-password
DOMAIN_NAME=yourdomain.com
```

## 🛠️ Manual Commands

### Development

```bash
# Build and start
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Run migrations
docker-compose -f docker-compose.dev.yml exec web python manage.py migrate

# Create superuser
docker-compose -f docker-compose.dev.yml exec web python manage.py createsuperuser

# Stop services
docker-compose -f docker-compose.dev.yml down
```

### Production

```bash
# Build and start
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Run migrations
docker-compose -f docker-compose.prod.yml exec web python manage.py migrate

# Create superuser
docker-compose -f docker-compose.prod.yml exec web python manage.py createsuperuser

# Stop services
docker-compose -f docker-compose.prod.yml down
```

## 🔒 SSL Certificate Setup

The `setup_ssl.sh` script automates SSL certificate setup:

1. **Installs prerequisites:**
   - Certbot
   - Nginx
   - Required packages

2. **Obtains SSL certificates:**
   - Uses Let's Encrypt
   - Supports multiple domains
   - Auto-renewal setup

3. **Configures Nginx:**
   - HTTP to HTTPS redirect
   - SSL security headers
   - Proxy to Django app

4. **Sets up Docker integration:**
   - Copies certificates to Docker directory
   - Creates renewal hooks
   - Auto-restarts containers on renewal

### Usage

```bash
# Interactive mode
sudo ./scripts/setup_ssl.sh

# With domain name
sudo ./scripts/setup_ssl.sh yourdomain.com
```

## 📊 Monitoring

### Health Checks

- **Application:** `GET /health/`
- **Docker:** Built-in health checks
- **Nginx:** Configuration validation

### Logs

```bash
# Application logs
docker-compose -f docker-compose.prod.yml logs web

# Database logs
docker-compose -f docker-compose.prod.yml logs db

# Nginx logs
docker-compose -f docker-compose.prod.yml logs nginx
```

## 🔄 Maintenance

### Certificate Renewal

Certificates auto-renew every 60 days. Manual renewal:

```bash
sudo certbot renew
```

### Database Backups

```bash
# Create backup
docker-compose -f docker-compose.prod.yml exec db pg_dump -U $DB_USER $DB_NAME > backup.sql

# Restore backup
docker-compose -f docker-compose.prod.yml exec -T db psql -U $DB_USER $DB_NAME < backup.sql
```

### Updates

```bash
# Pull latest code
git pull

# Rebuild and restart
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d
```

## 🚨 Troubleshooting

### Common Issues

1. **Port conflicts:**
   ```bash
   # Check what's using port 80/443
   sudo netstat -tlnp | grep :80
   sudo netstat -tlnp | grep :443
   ```

2. **SSL certificate issues:**
   ```bash
   # Check certificate status
   sudo certbot certificates
   
   # Test renewal
   sudo certbot renew --dry-run
   
   # Re-run SSL setup if needed
   sudo ./scripts/setup_ssl.sh yourdomain.com
   ```

3. **Database connection issues:**
   ```bash
   # Check database logs
   docker-compose -f docker-compose.prod.yml logs db
   
   # Test connection
   docker-compose -f docker-compose.prod.yml exec web python manage.py dbshell
   ```

4. **Static files not loading:**
   ```bash
   # Recollect static files
   docker-compose -f docker-compose.prod.yml exec web python manage.py collectstatic --noinput
   ```

### Debug Mode

For debugging, temporarily enable debug mode in production:

```bash
# Edit .env.prod
DEBUG=True

# Restart containers
docker-compose -f docker-compose.prod.yml restart web
```

## 📈 Performance Optimization

### Production Optimizations

1. **Database:**
   - Connection pooling
   - Query optimization
   - Regular maintenance

2. **Application:**
   - Gunicorn workers (3-4 per CPU core)
   - Static file caching
   - CDN for static assets

3. **Nginx:**
   - Gzip compression
   - Browser caching
   - SSL session caching

### Scaling

```bash
# Scale web workers
docker-compose -f docker-compose.prod.yml up -d --scale web=3

# Add load balancer
# (Use external load balancer like AWS ALB or Nginx Plus)
```

## 🔐 Security

### Production Security Checklist

- [ ] Strong SECRET_KEY
- [ ] DEBUG=False
- [ ] HTTPS enabled
- [ ] Security headers configured
- [ ] Database password complexity
- [ ] Regular security updates
- [ ] Firewall configured
- [ ] SSL certificate auto-renewal
- [ ] Log monitoring
- [ ] Backup strategy

### Security Headers

The production Nginx configuration includes:
- HSTS (HTTP Strict Transport Security)
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Referrer-Policy

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs for error messages
3. Verify configuration files
4. Test individual components

## 📝 Notes

- Development uses SQLite by default
- Production uses PostgreSQL
- SSL certificates are managed by Let's Encrypt
- Auto-renewal is configured via cron
- Health checks are built into containers
- Logs are stored in `./logs/` directory 