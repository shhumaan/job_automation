#!/bin/bash
# simple-validate.sh - Simplified Job Automation System Validation Script

# Create necessary directories
mkdir -p validation_reports
mkdir -p volumes/logs

# Set report file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="validation_reports/validation_report_${TIMESTAMP}.md"

# Initialize report
cat > "$REPORT_FILE" << EOL
# Phase 1 Validation Report
Generated on: $(date)

EOL

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status trackers
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

echo -e "${BOLD}🔍 Starting Phase 1 Validation...${NC}"
echo "This will validate all components of the job automation system."

# Function to log results
log_result() {
    local test_name="$1"
    local result="$2" # pass or fail
    local details="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$result" == "pass" ]; then
        echo -e "${GREEN}✅ PASS:${NC} $test_name"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        
        cat >> "$REPORT_FILE" << EOL
## ✅ $test_name
$details

EOL
    else
        echo -e "${RED}❌ FAIL:${NC} $test_name"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        
        cat >> "$REPORT_FILE" << EOL
## ❌ $test_name
$details

EOL
    fi
}

# 1. Docker Health Check
echo -e "\n${BOLD}1. Checking Docker services...${NC}"

# Check if all expected services are running
expected_services=("n8n" "redis" "nginx" "ollama")
all_services_running=true
docker_ps_output=$(docker-compose ps 2>&1)

cat >> "$REPORT_FILE" << EOL
## Docker Services Check
\`\`\`
$docker_ps_output
\`\`\`

EOL

for service in "${expected_services[@]}"; do
    if docker-compose ps | grep -q "${service}.*Up"; then
        echo -e "  ${GREEN}✓${NC} $service is running"
    else
        echo -e "  ${RED}✗${NC} $service is not running"
        all_services_running=false
    fi
done

if [ "$all_services_running" = true ]; then
    log_result "Docker Services" "pass" "All required Docker services are running."
else
    log_result "Docker Services" "fail" "Some Docker services are not running properly."
fi

# 2. Supabase Connection Test
echo -e "\n${BOLD}2. Testing Supabase connection...${NC}"
supabase_result=$(node scripts/test-supabase-connection.js 2>&1)
supabase_exit_code=$?

cat >> "$REPORT_FILE" << EOL
## Supabase Connection Test
\`\`\`
$supabase_result
\`\`\`

EOL

if [ $supabase_exit_code -eq 0 ]; then
    log_result "Supabase Connection" "pass" "Successfully connected to Supabase."
else
    log_result "Supabase Connection" "fail" "Failed to connect to Supabase. See logs for details."
fi

# 3. n8n Workflow Test
echo -e "\n${BOLD}3. Testing n8n workflows...${NC}"
n8n_health=$(curl -s http://localhost:5678/healthz 2>&1)

cat >> "$REPORT_FILE" << EOL
## n8n Workflow Test
\`\`\`
$n8n_health
\`\`\`

EOL

if echo "$n8n_health" | grep -q "status.*ok"; then
    echo -e "  ${GREEN}✓${NC} n8n service is healthy"
    active_workflows=$(curl -s http://localhost:5678/rest/workflows 2>/dev/null | grep -o '"active":true' | wc -l)
    
    if [ "$active_workflows" -gt 0 ]; then
        log_result "n8n Workflows" "pass" "n8n is healthy and has $active_workflows active workflows."
    else
        log_result "n8n Workflows" "fail" "n8n is healthy but no active workflows found."
    fi
else
    log_result "n8n Workflows" "fail" "n8n health check failed."
fi

# 4. Log Generation Check
echo -e "\n${BOLD}4. Checking log generation...${NC}"
mkdir -p volumes/logs/nginx
touch volumes/logs/nginx/test.log 2>/dev/null
log_check_result=$?

cat >> "$REPORT_FILE" << EOL
## Log Generation Check

EOL

if [ $log_check_result -eq 0 ]; then
    log_result "Log Generation" "pass" "Log directories are accessible and writable."
    rm volumes/logs/nginx/test.log 2>/dev/null
else
    log_result "Log Generation" "fail" "Log directories are not accessible or writable."
fi

# Generate summary
PASS_RATE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))

cat >> "$REPORT_FILE" << EOL
## Validation Results
Passed: $PASSED_CHECKS / Failed: $FAILED_CHECKS / Total: $TOTAL_CHECKS
Pass rate: ${PASS_RATE}%

## Recommendation for Phase 2:
EOL

echo -e "\n${BOLD}Phase 1 Validation Complete${NC}"
echo "Passed: $PASSED_CHECKS / Failed: $FAILED_CHECKS / Total: $TOTAL_CHECKS"
echo "Pass rate: ${PASS_RATE}%"
echo "Report saved to: $REPORT_FILE"

if [ $PASS_RATE -ge 80 ]; then
    echo -e "${GREEN}GO:${NC} Validation passed with sufficient confidence to proceed to Phase 2."
    echo "GO: Validation passed with sufficient confidence to proceed to Phase 2." >> "$REPORT_FILE"
else
    echo -e "${RED}NO-GO:${NC} Too many validation checks failed. Fix issues before proceeding to Phase 2."
    echo "NO-GO: Too many validation checks failed. Fix issues before proceeding to Phase 2." >> "$REPORT_FILE"
fi

exit $FAILED_CHECKS 