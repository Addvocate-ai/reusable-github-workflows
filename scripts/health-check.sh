#!/bin/bash
set -e

# Health Check Script for Post-Deployment Verification
# Environment variables:
#   APP_URL           - The URL to check (required)
#   MAX_RETRIES       - Maximum number of retry attempts (default: 5)
#   RETRY_DELAY       - Delay between retries in seconds (default: 10)
#   TIMEOUT           - Request timeout in seconds (default: 30)
#   EXPECTED_STATUS   - Expected HTTP status code range (default: 2xx-3xx)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check for required environment variables
if [ -z "$APP_URL" ]; then
  echo -e "${RED}Error: APP_URL environment variable must be set.${NC}"
  exit 1
fi

# 2. Set defaults for optional variables
MAX_RETRIES="${MAX_RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-10}"
TIMEOUT="${TIMEOUT:-30}"

echo "=========================================="
echo "  Post-Deployment Health Check"
echo "=========================================="
echo "URL:         $APP_URL"
echo "Max Retries: $MAX_RETRIES"
echo "Retry Delay: ${RETRY_DELAY}s"
echo "Timeout:     ${TIMEOUT}s"
echo "=========================================="

# 3. Initial stabilization wait
INITIAL_WAIT="${INITIAL_WAIT:-10}"
echo -e "${YELLOW}Waiting ${INITIAL_WAIT}s for deployment to stabilize...${NC}"
sleep "$INITIAL_WAIT"

# 4. Perform health check with retries
for i in $(seq 1 "$MAX_RETRIES"); do
  echo ""
  echo "--- Attempt $i of $MAX_RETRIES ---"
  
  # Make the request and capture both status and response time
  START_TIME=$(date +%s%N)
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$APP_URL" 2>/dev/null || echo "000")
  END_TIME=$(date +%s%N)
  
  # Calculate response time in milliseconds
  RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
  
  echo "HTTP Status:   $HTTP_STATUS"
  echo "Response Time: ${RESPONSE_TIME}ms"
  
  # Check if status is in acceptable range (2xx or 3xx)
  if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 400 ]; then
    echo ""
    echo -e "${GREEN}=========================================="
    echo "  ✅ Health Check PASSED!"
    echo "==========================================${NC}"
    echo "Final Status:  $HTTP_STATUS"
    echo "Response Time: ${RESPONSE_TIME}ms"
    echo "Attempts:      $i of $MAX_RETRIES"
    exit 0
  else
    echo -e "${YELLOW}⚠️  Health check failed with status: $HTTP_STATUS${NC}"
    
    if [ "$HTTP_STATUS" = "000" ]; then
      echo "   (Connection failed or timed out)"
    fi
    
    if [ "$i" -lt "$MAX_RETRIES" ]; then
      echo "Retrying in ${RETRY_DELAY}s..."
      sleep "$RETRY_DELAY"
    fi
  fi
done

# 5. All retries exhausted
echo ""
echo -e "${RED}=========================================="
echo "  ❌ Health Check FAILED!"
echo "==========================================${NC}"
echo "URL:           $APP_URL"
echo "Final Status:  $HTTP_STATUS"
echo "Total Attempts: $MAX_RETRIES"
echo ""
echo "Possible causes:"
echo "  - Application failed to start"
echo "  - Network/DNS issues"
echo "  - Firewall blocking requests"
echo "  - Application crashed after deployment"
echo ""

exit 1
