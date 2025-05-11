# Job Automation System

A complete Docker Compose environment for job automation using n8n, PostgreSQL, Redis, Nginx, and Ollama.

## Features

- **n8n** for workflow automation (port 5678)
- **PostgreSQL** database for storing workflow data
- **Redis** for caching and rate limiting
- **Nginx** as a reverse proxy
- **Ollama** for AI processing
- Health monitoring for all services
- Automatic container restart on failure
- Backup and restore capabilities
- External volume data storage

## Requirements

- Docker and Docker Compose
- External drive mounted at `/Volumes/External/job-automation` (configurable)
- Available ports: 80, 5678, 11434

## Directory Structure

```
job-automation/
├── docker-compose.yml
├── .env.example (copy to .env and customize)
├── config/
│   ├── nginx/nginx.conf
│   └── n8n/
├── scripts/
│   ├── setup.sh (setup validation)
│   ├── health-check.sh (service monitoring)
│   └── backup.sh (data backup)
├── data/ (on external drive)
└── logs/ (on external drive)
```

## Quick Start

1. Clone this repository
2. Copy `.env.example` to `.env` and customize variables
3. Run setup validation:

```bash
./scripts/setup.sh
```

4. Start all services:

```bash
docker-compose up -d
```

5. Access n8n at `http://localhost:5678`

## Health Monitoring

Run the health check script to verify all services are functioning properly:

```bash
./scripts/health-check.sh
```

## Backup and Restore

Create a backup of all data:

```bash
./scripts/backup.sh
```

Backups are stored in the configured backup path and include:
- PostgreSQL database
- n8n workflows and credentials
- Configuration files

For scheduled backups, add to crontab:

```bash
0 2 * * * /path/to/scripts/backup.sh > /path/to/logs/backup_$(date +\%Y\%m\%d).log 2>&1
```

## Validation Checklist

- [ ] All services start successfully
- [ ] Data persists after container restart
- [ ] Logs are being written and rotated
- [ ] Health checks pass for all services
- [ ] External drive is properly mounted
- [ ] Environment variables are loaded

## Troubleshooting

If you encounter issues:

1. Check service health: `./scripts/health-check.sh`
2. View container logs: `docker-compose logs [service]`
3. Verify external volume is mounted
4. Ensure all ports are available

## Configuration

Edit `.env` file to customize:
- Database credentials
- External volume path
- n8n encryption key
- Backup retention days 