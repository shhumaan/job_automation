#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "🔍 Job Automation Health Check"
echo "============================="

# Check if Docker is running
if ! docker info &> /dev/null; then
  echo -e "${RED}❌ Docker is not running${NC}"
  exit 1
fi

# Check if all required containers are running
required_services=("n8n" "redis" "nginx" "ollama")
all_running=true

for service in "${required_services[@]}"; do
  container_id=$(docker-compose ps -q $service 2>/dev/null)
  
  if [ -z "$container_id" ]; then
    echo -e "${RED}❌ $service container is not running${NC}"
    all_running=false
    continue
  fi
  
  # Check container status
  status=$(docker inspect --format='{{.State.Status}}' $container_id 2>/dev/null)
  if [ "$status" != "running" ]; then
    echo -e "${RED}❌ $service container is $status${NC}"
    all_running=false
    continue
  fi
  
  # Check health status if available
  health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}' $container_id 2>/dev/null)
  
  if [ "$health" == "healthy" ]; then
    echo -e "${GREEN}✅ $service is running and healthy${NC}"
  elif [ "$health" == "starting" ]; then
    echo -e "${YELLOW}⏳ $service is starting up${NC}"
    all_running=false
  elif [ "$health" == "no-health-check" ]; then
    echo -e "${GREEN}✅ $service is running (no health check)${NC}"
  else
    echo -e "${RED}❌ $service health check failed: $health${NC}"
    all_running=false
  fi
done

echo ""
echo "=== Detailed Health Information ==="

# n8n health check
echo -e "\n${YELLOW}Checking n8n...${NC}"
n8n_url="http://localhost:5678/healthz"
if curl -s -f "$n8n_url" > /dev/null; then
  echo -e "${GREEN}✅ n8n API is responding${NC}"
else
  echo -e "${RED}❌ n8n API is not responding${NC}"
  all_running=false
fi

# Supabase connection check (basic URL check)
echo -e "\n${YELLOW}Checking Supabase connection...${NC}"
if [ -n "$SUPABASE_URL" ] && [ "$SUPABASE_URL" != "your_supabase_url" ]; then
  if curl -s -f "$SUPABASE_URL" > /dev/null; then
    echo -e "${GREEN}✅ Supabase URL is accessible${NC}"
  else
    echo -e "${YELLOW}⚠️ Unable to reach Supabase URL - may require authentication${NC}"
  fi
else
  echo -e "${YELLOW}⚠️ Supabase URL not configured correctly in .env${NC}"
fi

# Redis health check
echo -e "\n${YELLOW}Checking Redis...${NC}"
if docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
  echo -e "${GREEN}✅ Redis is responding${NC}"
else
  echo -e "${RED}❌ Redis is not responding${NC}"
  all_running=false
fi

# Nginx health check
echo -e "\n${YELLOW}Checking Nginx...${NC}"
nginx_url="http://localhost/health"
if curl -s -f "$nginx_url" > /dev/null; then
  echo -e "${GREEN}✅ Nginx is responding${NC}"
else
  echo -e "${RED}❌ Nginx is not responding${NC}"
  all_running=false
fi

# Ollama health check
echo -e "\n${YELLOW}Checking Ollama...${NC}"
ollama_url="http://localhost:11435/api/health"
if curl -s -f "$ollama_url" > /dev/null; then
  echo -e "${GREEN}✅ Ollama API is responding${NC}"
else
  echo -e "${RED}❌ Ollama API is not responding${NC}"
  all_running=false
fi

# External volume check
echo -e "\n${YELLOW}Checking external volume...${NC}"
if [ -f ".env" ]; then
  source .env
  if [ -d "$EXTERNAL_VOLUME" ]; then
    echo -e "${GREEN}✅ External volume is mounted at $EXTERNAL_VOLUME${NC}"
    
    # Check disk space
    df_output=$(df -h "$EXTERNAL_VOLUME" | tail -n 1)
    used_percent=$(echo "$df_output" | awk '{print $5}' | tr -d '%')
    
    if [ "$used_percent" -gt 90 ]; then
      echo -e "${RED}⚠️ External volume is almost full (${used_percent}%)${NC}"
    else
      echo -e "${GREEN}✅ External volume has sufficient space (${used_percent}% used)${NC}"
    fi
  else
    echo -e "${RED}❌ External volume not mounted at $EXTERNAL_VOLUME${NC}"
    all_running=false
  fi
else
  echo -e "${RED}❌ .env file not found${NC}"
  all_running=false
fi

# Summary
echo -e "\n=== Health Check Summary ==="
if [ "$all_running" = true ]; then
  echo -e "${GREEN}✅ All services are running and healthy${NC}"
else
  echo -e "${RED}❌ Some services have issues${NC}"
  echo -e "${YELLOW}Run 'docker-compose logs [service]' to check logs for problematic services${NC}"
fi

# Output current date/time of check
echo -e "\nCheck completed at: $(date)"

# Exit with proper status code
if [ "$all_running" = true ]; then
  exit 0
else
  exit 1
fi 