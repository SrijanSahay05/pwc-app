# Django Deployment Setup Guide

This guide explains how to deploy your Django application after running the server setup script.

## Prerequisites

- Server setup script has been run: `./scripts/server_setup.sh yourdomain.com`
- SSL certificates are available in `/etc/letsencrypt/`
- Docker and Docker Compose are installed

## Docker Setup

### 1. Create docker-compose.yml

```yaml
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: django_prod
      POSTGRES_USER: django_user
      POSTGRES_PASSWORD: your_secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U django_user -d django_prod"]
      interval: 30s
      timeout: 5s
      retries: 3

  web:
    build: .
    command: gunicorn core.wsgi:application --bind 0.0.0.0:8000 --workers 2
    volumes:
      - .:/app
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    environment:
      - DEBUG=False
      - ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
      - DB_HOST=db
      - DB_PORT=5432
      - DB_NAME=django_prod
      - DB_USER=django_user
      - DB_PASSWORD=your_secure_password
    depends_on:
      - db
    restart: unless-stopped
    expose:
      - "8000"

  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - static_volume:/app/staticfiles:ro
      - media_volume:/app/media:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - web
    restart: always

volumes:
  postgres_data:
  static_volume:
  media_volume:
```

### 2. Create Dockerfile

```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn

# Copy project
COPY . .

# Create directories
RUN mkdir -p staticfiles media

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "core.wsgi:application"]
```

### 3. Create nginx.conf

```nginx
worker_processes 1;
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    
    upstream web {
        server web:8000;
    }

    # HTTP server - redirect to HTTPS
    server {
        listen 80;
        server_name yourdomain.com www.yourdomain.com;
        
        # Certbot challenge (for SSL renewal)
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Redirect to HTTPS
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name yourdomain.com www.yourdomain.com;

        # SSL certificates (mounted from host)
        ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # Static files
        location /static/ {
            alias /app/staticfiles/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        location /media/ {
            alias /app/media/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Django app
        location / {
            proxy_pass http://web;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_redirect off;
        }
    }
}
```

## Deployment Steps

### 1. Clone your project
```bash
cd ~
git clone your-repository-url
cd your-project
```

### 2. Create the configuration files
Create the three files above (`docker-compose.yml`, `Dockerfile`, `nginx.conf`) in your project directory.

### 3. Update domain names
Replace `yourdomain.com` with your actual domain in:
- `docker-compose.yml` (ALLOWED_HOSTS)
- `nginx.conf` (server_name)

### 4. Set up environment variables
Create a `.env` file or update the environment variables in `docker-compose.yml`:
```bash
# Database
DB_PASSWORD=your_secure_password

# Django
SECRET_KEY=your-secret-key
DEBUG=False
```

### 5. Deploy
```bash
# Build and start containers
docker-compose up -d --build

# Run Django commands
docker-compose exec web python manage.py migrate
docker-compose exec web python manage.py collectstatic --noinput
docker-compose exec web python manage.py createsuperuser
```

## SSL Certificate Management

### Check certificate status
```bash
sudo certbot certificates
```

### Manual renewal
```bash
sudo certbot renew
```

### View renewal logs
```bash
sudo journalctl -u certbot.timer
```

## Management Commands

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f web
docker-compose logs -f nginx
docker-compose logs -f db
```

### Restart services
```bash
# All services
docker-compose restart

# Specific service
docker-compose restart web
```

### Update and redeploy
```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose down
docker-compose up -d --build
```

### Stop all services
```bash
docker-compose down
```

## Troubleshooting

### SSL Certificate Issues
```bash
# Check if certificates exist
sudo ls -la /etc/letsencrypt/live/yourdomain.com/

# Test nginx configuration
docker-compose exec nginx nginx -t

# Check nginx logs
docker-compose logs nginx
```

### Database Issues
```bash
# Check database connection
docker-compose exec db pg_isready -U django_user -d django_prod

# View database logs
docker-compose logs db
```

### Django Issues
```bash
# Check Django logs
docker-compose logs web

# Run Django shell
docker-compose exec web python manage.py shell

# Check static files
docker-compose exec web python manage.py collectstatic --dry-run
```

## Security Notes

- SSL certificates auto-renew every 60 days
- Firewall is configured to allow only SSH, HTTP, and HTTPS
- Fail2ban is active to prevent brute force attacks
- Keep your system updated: `sudo apt update && sudo apt upgrade`

## Performance Optimization

### Gunicorn Workers
Adjust the number of workers based on your CPU cores:
```bash
# In docker-compose.yml, update the web service command:
command: gunicorn core.wsgi:application --bind 0.0.0.0:8000 --workers 4
```

### Database Optimization
Consider adding these environment variables to the db service:
```yaml
environment:
  POSTGRES_DB: django_prod
  POSTGRES_USER: django_user
  POSTGRES_PASSWORD: your_secure_password
  POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
```

### Static Files
For better performance, consider using a CDN for static files in production.

Your Django application is now ready for production deployment with SSL! 