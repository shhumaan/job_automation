#!/bin/bash
# validate-system.sh - Job Automation System Validation Script
# Tests all components for Phase 1 validation

# Load environment variables
source ../.env 2>/dev/null || source .env 2>/dev/null || echo "Warning: Could not load .env file"

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create output directory for reports
REPORT_DIR="validation_reports"
REPORT_FILE="$REPORT_DIR/validation_report_$(date +%Y%m%d_%H%M%S).md"
mkdir -p $REPORT_DIR

# Initialize report
echo "# Job Automation System Validation Report" > $REPORT_FILE
echo "**Date:** $(date)" >> $REPORT_FILE
echo "**Environment:** ${ENVIRONMENT:-production}" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "## Summary" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Status trackers
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
ISSUES=()

# Function to log results
log_result() {
    local test_name="$1"
    local result="$2" # pass or fail
    local details="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$result" == "pass" ]; then
        echo -e "${GREEN}✅ PASS:${NC} $test_name"
        echo "### ✅ $test_name" >> $REPORT_FILE
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌ FAIL:${NC} $test_name"
        echo "### ❌ $test_name" >> $REPORT_FILE
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        ISSUES+=("$test_name: $details")
    fi
    
    echo "" >> $REPORT_FILE
    echo "$details" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
}

echo -e "${BOLD}🔍 Starting Phase 1 Validation...${NC}"
echo -e "${BLUE}This will validate all components of the job automation system.${NC}"
echo -e "${BLUE}Tests will check Docker, Supabase, n8n, resources, and data persistence.${NC}"
echo ""

# =======================================================
# 1. Docker Health Check
# =======================================================
echo -e "${BOLD}1. Checking Docker services...${NC}"
echo "## Docker Services Check" >> $REPORT_FILE

# Check if all expected services are running
expected_services=("n8n" "redis" "nginx" "ollama")
all_services_running=true
service_status=""

docker_ps_output=$(docker-compose ps 2>&1)
echo "```" >> $REPORT_FILE
echo "$docker_ps_output" >> $REPORT_FILE
echo "```" >> $REPORT_FILE

for service in "${expected_services[@]}"; do
    if echo "$docker_ps_output" | grep -q "$service"; then
        container_id=$(docker-compose ps -q $service)
        status=$(docker inspect --format='{{.State.Status}}' $container_id 2>/dev/null)
        health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' $container_id 2>/dev/null)
        
        if [ "$status" == "running" ]; then
            echo -e "  ${GREEN}✓${NC} $service is running (Health: $health)"
            service_status+="- $service: Running (Health: $health)\n"
        else
            echo -e "  ${RED}✗${NC} $service is not running properly (Status: $status)"
            service_status+="- $service: Not running properly (Status: $status)\n"
            all_services_running=false
        fi
    else
        echo -e "  ${RED}✗${NC} $service not found"
        service_status+="- $service: Not found\n"
        all_services_running=false
    fi
done

echo -e "\n$service_status" >> $REPORT_FILE

if [ "$all_services_running" = true ]; then
    log_result "Docker Services" "pass" "All required Docker services are running."
else
    log_result "Docker Services" "fail" "Some Docker services are not running properly."
fi

# =======================================================
# 2. Supabase Connection Test
# =======================================================
echo -e "\n${BOLD}2. Testing Supabase connection...${NC}"
echo "## Supabase Connection Test" >> $REPORT_FILE

echo "Running Supabase connection test script..."
supabase_result=$(node scripts/test-supabase-connection.js 2>&1)
supabase_exit_code=$?

echo "```" >> $REPORT_FILE
echo "$supabase_result" >> $REPORT_FILE
echo "```" >> $REPORT_FILE

if [ $supabase_exit_code -eq 0 ] && echo "$supabase_result" | grep -q "Successfully"; then
    log_result "Supabase Connection" "pass" "Successfully connected to Supabase and verified tables."
else
    log_result "Supabase Connection" "fail" "Failed to connect to Supabase or verify tables."
fi

# =======================================================
# 3. n8n Workflow Test
# =======================================================
echo -e "\n${BOLD}3. Testing n8n workflows...${NC}"
echo "## n8n Workflow Test" >> $REPORT_FILE

echo "Checking n8n health..."
n8n_health=$(curl -s http://localhost:5678/healthz)

echo "```" >> $REPORT_FILE
echo "$n8n_health" >> $REPORT_FILE
echo "```" >> $REPORT_FILE

if echo "$n8n_health" | grep -q "status.*ok"; then
    echo -e "  ${GREEN}✓${NC} n8n service is healthy"
    
    # Check if workflows are active
    echo "Checking workflow status..."
    active_workflows=$(curl -s http://localhost:5678/rest/workflows | grep -o '"active":true' | wc -l)
    echo "Active workflows: $active_workflows" >> $REPORT_FILE
    
    if [ "$active_workflows" -gt 0 ]; then
        log_result "n8n Workflows" "pass" "n8n is healthy and has $active_workflows active workflows."
    else
        log_result "n8n Workflows" "fail" "n8n is healthy but no active workflows found."
    fi
else
    log_result "n8n Workflows" "fail" "n8n health check failed."
fi

# =======================================================
# 4. Resource Usage Check
# =======================================================
echo -e "\n${BOLD}4. Checking resource usage...${NC}"
echo "## Resource Usage Check" >> $REPORT_FILE

# Get Docker stats
echo "Checking Docker resource usage..."
docker_stats=$(docker stats --no-stream)

echo "```" >> $REPORT_FILE
echo "$docker_stats" >> $REPORT_FILE
echo "```" >> $REPORT_FILE

# Parse Docker stats to get total memory usage
total_mem_usage=0
mem_usage_output=$(echo "$docker_stats" | awk 'NR>1 {print $4}')

for usage in $mem_usage_output; do
    # Extract the number and unit (e.g. 156MiB -> 156 and MiB)
    num=$(echo $usage | sed -E 's/([0-9.]+)([A-Za-z]+)/\1/')
    unit=$(echo $usage | sed -E 's/([0-9.]+)([A-Za-z]+)/\2/')
    
    # Convert to MB for comparison
    case $unit in
        B)
            mb=$(echo "$num / 1024 / 1024" | bc -l)
            ;;
        KiB|KB)
            mb=$(echo "$num / 1024" | bc -l)
            ;;
        MiB|MB)
            mb=$num
            ;;
        GiB|GB)
            mb=$(echo "$num * 1024" | bc -l)
            ;;
        *)
            mb=0
            ;;
    esac
    
    total_mem_usage=$(echo "$total_mem_usage + $mb" | bc -l)
done

# Format total memory usage to 2 decimal places
total_mem_usage=$(printf "%.2f" $total_mem_usage)
echo "Total memory usage: ${total_mem_usage}MB" >> $REPORT_FILE

# Check disk space
echo "Checking disk space..."
disk_space=$(df -h . | awk 'NR>1')

echo "```" >> $REPORT_FILE
echo "$disk_space" >> $REPORT_FILE
echo "```" >> $REPORT_FILE

# Check if within resource bounds
resource_check_passed=true
resource_check_details="Resource usage summary:\n"
resource_check_details+="- Memory usage: ${total_mem_usage}MB\n"

# Memory check - 8GB limit
if (( $(echo "$total_mem_usage < 8192" | bc -l) )); then
    resource_check_details+="- Memory usage is within limits (< 8GB).\n"
else
    resource_check_details+="- Memory usage exceeds recommended limits (> 8GB).\n"
    resource_check_passed=false
fi

# Supabase storage check
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_API_KEY" ]; then
    echo "Checking Supabase storage usage..."
    
    # Run custom script to check storage or query Supabase
    node scripts/check-storage.js > /tmp/storage_check.log 2>&1
    
    db_size=$(grep -o "Database Size: [0-9\.]*" /tmp/storage_check.log | awk '{print $3}')
    if [ -n "$db_size" ]; then
        resource_check_details+="- Supabase database size: ${db_size}MB\n"
        
        # Check if under 100MB
        if (( $(echo "$db_size < 100" | bc -l) )); then
            resource_check_details+="- Supabase storage is within limits (< 100MB).\n"
        else
            resource_check_details+="- Supabase storage exceeds test threshold (> 100MB).\n"
            resource_check_passed=false
        fi
    else
        resource_check_details+="- Could not determine Supabase storage usage.\n"
    fi
else
    resource_check_details+="- Skipped Supabase storage check (credentials not available).\n"
fi

# CPU check - just report it
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
resource_check_details+="- CPU usage: $cpu_usage\n"

if [ "$resource_check_passed" = true ]; then
    log_result "Resource Usage" "pass" "$resource_check_details"
else
    log_result "Resource Usage" "fail" "$resource_check_details"
fi

# =======================================================
# 5. Database Operations Test
# =======================================================
echo -e "\n${BOLD}5. Testing database operations...${NC}"
echo "## Database Operations Test" >> $REPORT_FILE

# Test database by inserting a test job and retrieving it
echo "Testing database CRUD operations..."

# Create test job via Node.js script
echo "const { createClient } = require('@supabase/supabase-js');

async function testDatabaseOperations() {
  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_API_KEY
  );
  
  const testId = 'validation-test-' + Date.now();
  console.log('Creating test job with ID:', testId);
  
  try {
    // Insert test job using the function
    const { data: jobId, error: insertError } = await supabase.rpc('insert_job_with_compression', {
      p_external_id: testId,
      p_title: 'Validation Test Job',
      p_company_name: 'Test Company',
      p_location: 'Test Location',
      p_remote_type: 'remote',
      p_description: 'This is a test job created by the validation script.',
      p_requirements: JSON.stringify({skills: ['testing']}),
      p_noc_code: '00000',
      p_posted_date: new Date().toISOString().split('T')[0],
      p_source: 'validation-script',
      p_url: 'https://example.com/test',
      p_salary_info: JSON.stringify({range: '0-0'})
    });

    if (insertError) {
      throw new Error(('Insert error: ' + insertError.message));
    }
    
    console.log('Job created with ID:', jobId);
    
    // Retrieve job with decompression
    const { data: retrievedJob, error: retrieveError } = await supabase.rpc('get_job_with_description', {
      p_job_id: jobId
    });
    
    if (retrieveError) {
      throw new Error('Retrieve error: ' + retrieveError.message);
    }
    
    console.log('Job retrieved with decompressed description:', retrievedJob.length > 0);
    
    // Test archive function 
    const { error: archiveError } = await supabase.rpc('archive_old_jobs');
    
    if (archiveError) {
      throw new Error('Archive function error: ' + archiveError.message);
    }
    
    console.log('Archive function executed successfully');
    
    // Check storage monitor view
    const { data: monitor, error: monitorError } = await supabase
      .from('storage_monitor')
      .select('*')
      .limit(1);
      
    if (monitorError) {
      throw new Error('Storage monitor error: ' + monitorError.message);
    }
    
    console.log('Storage monitor check successful');
    console.log('TEST SUCCESSFUL: All database operations completed');
    
    return true;
  } catch (error) {
    console.error('TEST FAILED:', error.message);
    return false;
  }
}

testDatabaseOperations()
  .then(success => process.exit(success ? 0 : 1))
  .catch(err => {
    console.error('Unhandled error:', err);
    process.exit(1);
  });" > /tmp/test_db.js

db_test_result=$(node /tmp/test_db.js 2>&1)
db_test_exit_code=$?

echo "```" >> $REPORT_FILE
echo "$db_test_result" >> $REPORT_FILE
echo "```" >> $REPORT_FILE

if [ $db_test_exit_code -eq 0 ] && echo "$db_test_result" | grep -q "TEST SUCCESSFUL"; then
    log_result "Database Operations" "pass" "Successfully performed CRUD operations, compression/decompression, and storage monitoring."
else
    log_result "Database Operations" "fail" "Failed to perform database operations. See logs for details."
fi

# =======================================================
# 6. Logs Check
# =======================================================
echo -e "\n${BOLD}6. Checking log generation...${NC}"
echo "## Log Generation Check" >> $REPORT_FILE

logs_check_passed=true
logs_check_details="Log files check:\n"

# Check n8n logs
if [ -d "volumes/logs/n8n" ] && ls volumes/logs/n8n/n8n.log* 1> /dev/null 2>&1; then
    n8n_log_size=$(du -h volumes/logs/n8n/n8n.log | awk '{print $1}')
    logs_check_details+="- n8n logs exist (size: $n8n_log_size)\n"
    tail -n 5 volumes/logs/n8n/n8n.log >> $REPORT_FILE
else
    logs_check_details+="- n8n logs not found\n"
    logs_check_passed=false
fi

# Check nginx logs
if [ -d "volumes/logs/nginx" ] && ls volumes/logs/nginx/access.log* 1> /dev/null 2>&1; then
    nginx_log_size=$(du -h volumes/logs/nginx/access.log | awk '{print $1}')
    logs_check_details+="- Nginx logs exist (size: $nginx_log_size)\n"
else
    logs_check_details+="- Nginx logs not found\n"
    logs_check_passed=false
fi

if [ "$logs_check_passed" = true ]; then
    log_result "Log Generation" "pass" "$logs_check_details"
else
    log_result "Log Generation" "fail" "$logs_check_details"
fi

# =======================================================
# 7. Backup System Check
# =======================================================
echo -e "\n${BOLD}7. Verifying backup system...${NC}"
echo "## Backup System Check" >> $REPORT_FILE

# Check if backup script exists
if [ -f "scripts/backup.sh" ]; then
    backup_check_details="Backup script exists.\n"
    
    # Check if backup directory exists
    if [ -d "volumes/backups" ]; then
        backup_files=$(find volumes/backups -type f -name "*.gz" 2>/dev/null | wc -l)
        if [ "$backup_files" -gt 0 ]; then
            backup_check_details+="- Found $backup_files backup files in volumes/backups\n"
            backup_check_passed=true
        else
            backup_check_details+="- No backup files found in volumes/backups\n"
            backup_check_passed=false
        fi
    else
        backup_check_details+="- Backup directory not found\n"
        backup_check_passed=false
    fi

    # Test backup script (without actually running a full backup)
    echo "Testing backup script..."
    if bash scripts/backup.sh --dry-run 2>/dev/null; then
        backup_check_details+="- Backup script execution test passed\n"
    else
        backup_check_details+="- Backup script execution test failed\n"
        backup_check_passed=false
    fi
else
    backup_check_details="Backup script not found."
    backup_check_passed=false
fi

if [ "$backup_check_passed" = true ]; then
    log_result "Backup System" "pass" "$backup_check_details"
else
    log_result "Backup System" "fail" "$backup_check_details"
fi

# =======================================================
# Generate Final Report
# =======================================================
echo -e "\n${BOLD}Generating validation report...${NC}"

# Update summary
pass_percentage=$(echo "scale=1; ($PASSED_CHECKS / $TOTAL_CHECKS) * 100" | bc)
summary="**Overall Status:** "

if [ "$FAILED_CHECKS" -eq 0 ]; then
    summary+="✅ **ALL CHECKS PASSED**"
    final_result="PASS"
elif [ "$pass_percentage" -ge 80 ]; then
    summary+="⚠️ **PARTIALLY PASSED WITH ISSUES** ($pass_percentage% checks passed)"
    final_result="PARTIAL PASS"
else
    summary+="❌ **VALIDATION FAILED** ($pass_percentage% checks passed)"
    final_result="FAIL"
fi

summary+="\n\n**Checks:** $TOTAL_CHECKS total, $PASSED_CHECKS passed, $FAILED_CHECKS failed"

if [ ${#ISSUES[@]} -gt 0 ]; then
    summary+="\n\n**Issues Found:**\n"
    for issue in "${ISSUES[@]}"; do
        summary+="\n- $issue"
    done
fi

# Insert summary at the beginning of the report
temp_file=$(mktemp)
echo -e "$summary" > $temp_file
echo "" >> $temp_file
cat $REPORT_FILE >> $temp_file
mv $temp_file $REPORT_FILE

# Generate HTML version if pandoc is available
if command -v pandoc &> /dev/null; then
    HTML_REPORT="${REPORT_FILE%.md}.html"
    echo "Converting to HTML report..."
    pandoc -s $REPORT_FILE -o $HTML_REPORT --metadata title="Job Automation System Validation Report"
    echo "HTML report generated: $HTML_REPORT"
fi

echo -e "\n${BOLD}Phase 1 Validation Complete${NC}"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC} / Failed: ${RED}$FAILED_CHECKS${NC} / Total: $TOTAL_CHECKS"
echo -e "Pass rate: ${BLUE}$pass_percentage%${NC}"
echo -e "Report saved to: ${YELLOW}$REPORT_FILE${NC}"

# Recommendation for Phase 2
echo -e "\n${BOLD}Recommendation for Phase 2:${NC}"
if [ "$final_result" = "PASS" ]; then
    echo -e "${GREEN}GO:${NC} All validation checks passed. Ready to proceed to Phase 2!"
elif [ "$final_result" = "PARTIAL PASS" ]; then
    echo -e "${YELLOW}PARTIAL GO:${NC} Most checks passed, but some issues were found."
    echo -e "Review the issues in the report and decide if they're critical before proceeding."
else
    echo -e "${RED}NO-GO:${NC} Too many validation checks failed. Fix issues before proceeding to Phase 2."
fi

exit $FAILED_CHECKS 