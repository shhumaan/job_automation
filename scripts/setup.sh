#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "🚀 Starting Job Automation Setup Validation"
echo "============================================"

# Check if running with sudo/root
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Please don't run this script with sudo or as root${NC}"
  exit 1
fi

# Define the external volume path
EXTERNAL_VOLUME_PATH="/Volumes/External/job-automation"

# Check if .env file exists, if not create from example
if [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    echo -e "${YELLOW}Creating .env file from .env.example${NC}"
    cp .env.example .env
    echo -e "${GREEN}✅ Created .env file${NC}"
  else
    echo -e "${RED}❌ .env.example file not found${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✅ .env file exists${NC}"
fi

# Source .env file to get environment variables
source .env

# Check if external volume is mounted
if [ ! -d "$EXTERNAL_VOLUME" ]; then
  echo -e "${RED}❌ External volume not mounted at $EXTERNAL_VOLUME${NC}"
  echo -e "${YELLOW}Would you like to create this directory? (y/n)${NC}"
  read -r create_dir
  if [[ "$create_dir" =~ ^[Yy]$ ]]; then
    echo "Creating directory structure on external volume..."
    mkdir -p "$EXTERNAL_VOLUME"/{data/{n8n,postgresql,redis,ollama},logs/{nginx,n8n},backups}
    echo -e "${GREEN}✅ Created directory structure${NC}"
  else
    echo -e "${YELLOW}Please ensure external volume is mounted and update .env file if needed${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✅ External volume is mounted${NC}"
fi

# Create necessary directory structure
echo "Creating directory structure on external volume..."
mkdir -p "$EXTERNAL_VOLUME"/{data/{n8n,postgresql,redis,ollama},logs/{nginx,n8n},backups}
echo -e "${GREEN}✅ Created directory structure${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo -e "${RED}❌ Docker is not installed${NC}"
  echo -e "${YELLOW}Please install Docker Desktop or Docker Engine: https://docs.docker.com/get-docker/${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Docker is installed${NC}"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo -e "${RED}❌ Docker Compose is not installed${NC}"
  echo -e "${YELLOW}Please install Docker Compose: https://docs.docker.com/compose/install/${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Docker Compose is installed${NC}"
fi

# Check Docker is running
if ! docker info &> /dev/null; then
  echo -e "${RED}❌ Docker is not running${NC}"
  echo -e "${YELLOW}Please start Docker Desktop or Docker Engine${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Docker is running${NC}"
fi

# Check if required ports are available
check_port() {
  local port=$1
  local service=$2
  
  if lsof -i:$port -sTCP:LISTEN &> /dev/null; then
    echo -e "${RED}❌ Port $port is already in use (needed by $service)${NC}"
    echo -e "${YELLOW}Please free up port $port and try again${NC}"
    return 1
  else
    echo -e "${GREEN}✅ Port $port is available for $service${NC}"
    return 0
  fi
}

all_ports_available=true
check_port 5678 "n8n" || all_ports_available=false
check_port 80 "nginx" || all_ports_available=false
check_port 11434 "ollama" || all_ports_available=false

if [ "$all_ports_available" = false ]; then
  echo -e "${YELLOW}Please resolve port conflicts before continuing${NC}"
else
  echo -e "${GREEN}✅ All required ports are available${NC}"
fi

# Validate docker-compose.yml file
if [ -f "docker-compose.yml" ]; then
  echo "Validating docker-compose.yml..."
  if docker-compose config --quiet; then
    echo -e "${GREEN}✅ docker-compose.yml is valid${NC}"
  else
    echo -e "${RED}❌ docker-compose.yml has errors${NC}"
    exit 1
  fi
else
  echo -e "${RED}❌ docker-compose.yml not found${NC}"
  exit 1
fi

# Set permissions
echo "Setting correct permissions on external volume directories..."
chmod -R 755 "$EXTERNAL_VOLUME"/{data,logs,backups}
echo -e "${GREEN}✅ Permissions set${NC}"

# Summary
echo ""
echo "============================================"
echo -e "${GREEN}✅ Setup validation completed${NC}"
echo "Would you like to start the containers now? (y/n)"
read -r start_containers

if [[ "$start_containers" =~ ^[Yy]$ ]]; then
  echo "Starting containers..."
  docker-compose up -d
  
  echo "Checking container health..."
  sleep 10 # Give containers some time to start
  
  if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Containers started successfully${NC}"
    echo "You can access n8n at: http://localhost:5678"
  else
    echo -e "${RED}❌ Some containers failed to start${NC}"
    echo "Please check logs with: docker-compose logs"
  fi
else
  echo "You can start the containers later with: docker-compose up -d"
fi

echo ""
echo "Next steps:"
echo "1. Create a copy of .env.example to .env and customize values"
echo "2. Run docker-compose up -d to start all services"
echo "3. Access n8n at http://localhost:5678"
echo "4. Run scripts/health-check.sh to verify all services are healthy"
echo "5. Set up a cron job for automatic backups using scripts/backup.sh" 