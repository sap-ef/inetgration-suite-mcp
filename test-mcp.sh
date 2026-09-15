#!/usr/bin/env bash
# ============================================================
# test-mcp.sh — Manual MCP Server validation via curl
# Blog: From REST API to Claude Code: Building a Governed
#       MCP Server with SAP Integration Suite
# ============================================================
# Usage:
#   1. Copy .env.example to .env and fill in your values
#   2. Run:  bash test-mcp.sh
#
# NEVER commit .env — it contains credentials!
# ============================================================

set -euo pipefail

# ============================================================
# Load configuration from .env file (if it exists)
# ============================================================

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/.env" ]]; then
  # shellcheck disable=SC1090
  source "$(dirname "${BASH_SOURCE[0]}")/.env"
  echo "✓ Loaded .env configuration"
else
  echo "⚠ .env file not found — using default values (or export env vars)"
fi

# ============================================================
# Configuration Variables — Defaults (override in .env)
# ============================================================

IDENTITY_ZONE="${IDENTITY_ZONE:-ABC12345}"
VIRTUAL_HOST="${VIRTUAL_HOST:-mcp-server.example.com}"
MCP_PATH="${MCP_PATH:-mcp}"
AUTH_REGION="${AUTH_REGION:-eu10}"
DRY_RUN="${DRY_RUN:-false}"

# ============================================================
# Derived URLs (built from variables above)
# ============================================================

MCP_URL="${MCP_URL:-https://${VIRTUAL_HOST}/${MCP_PATH}}"
SAP_MCP_TOKEN_URL="${SAP_MCP_TOKEN_URL:-https://${IDENTITY_ZONE}.authentication.${AUTH_REGION}.hana.ondemand.com/oauth/token}"

echo "═══════════════════════════════════════════════════════════"
echo "  MCP Server Validation Script"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Configuration:"
echo "  MCP URL:           ${MCP_URL}"
echo "  Token URL:         ${SAP_MCP_TOKEN_URL}"
echo ""

# ============================================================
# Validate configuration
# ============================================================

CONFIG_VALID=true

if [[ "${VIRTUAL_HOST}" == "mcp-server.example.com" ]]; then
  echo "⚠️  VIRTUAL_HOST is still a placeholder — update .env with your actual MCP server host"
  CONFIG_VALID=false
fi

if [[ "${IDENTITY_ZONE}" == "ABC12345" ]]; then
  echo "⚠️  IDENTITY_ZONE is still a placeholder — update .env with your actual SAP BTP Identity Zone"
  CONFIG_VALID=false
fi

if [[ "${SAP_MCP_CLIENT_ID:-}" == "" ]] && [[ "${DRY_RUN}" != "true" ]]; then
  echo "⚠️  SAP_MCP_CLIENT_ID is not set — will be prompted at runtime"
fi

if [[ "${CONFIG_VALID}" == "false" ]]; then
  echo ""
  echo "ℹ️  To get your actual values:"
  echo "   1. IDENTITY_ZONE: From SAP BTP Cockpit → Subaccount → Overview (copy the subdomain)"
  echo "   2. VIRTUAL_HOST: Where your MCP Server is deployed (e.g., mcp-prod.cloud.sap)"
  echo "   3. Fill these in .env and try again"
  echo ""
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "ℹ️  DRY_RUN=true — continuing with placeholder values for testing structure..."
    echo ""
  else
    echo "ℹ️  To test script structure without real credentials:"
    echo "   DRY_RUN=true bash test-mcp.sh"
    echo ""
    exit 1
  fi
fi

# Prompt for credentials at runtime (keeps secrets out of the script)
if [[ "${DRY_RUN}" != "true" ]]; then
  if [[ -z "${SAP_MCP_CLIENT_ID:-}" ]]; then
    read -r -p "Client ID:     " SAP_MCP_CLIENT_ID
    export SAP_MCP_CLIENT_ID
  fi

  if [[ -z "${SAP_MCP_CLIENT_SECRET:-}" ]]; then
    read -r -s -p "Client Secret: " SAP_MCP_CLIENT_SECRET
    export SAP_MCP_CLIENT_SECRET
    echo
  fi
else
  echo "🧪 DRY_RUN mode — skipping credential prompts"
  SAP_MCP_CLIENT_ID="${SAP_MCP_CLIENT_ID:-test-client-id}"
  SAP_MCP_CLIENT_SECRET="${SAP_MCP_CLIENT_SECRET:-test-client-secret}"
fi

# ------- Step 1: Obtain access token -----------------------

echo ""
echo "→ Fetching OAuth token..."

TOKEN_RESPONSE=$(
  curl -sS \
    -u "${SAP_MCP_CLIENT_ID}:${SAP_MCP_CLIENT_SECRET}" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'grant_type=client_credentials' \
    "${SAP_MCP_TOKEN_URL}" 2>&1
) || {
  echo "✗ Error: Failed to contact token URL"
  echo "  URL: ${SAP_MCP_TOKEN_URL}"
  echo "  Response: ${TOKEN_RESPONSE}"
  exit 1
}

TOKEN=$(echo "${TOKEN_RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>&1) || {
  echo "✗ Error: Failed to parse token response"
  echo "  Response was:"
  echo "${TOKEN_RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${TOKEN_RESPONSE}"
  exit 1
}

if [[ -z "${TOKEN}" ]]; then
  echo "✗ Error: No access_token in response"
  echo "  Response was:"
  echo "${TOKEN_RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${TOKEN_RESPONSE}"
  exit 1
fi

export TOKEN

echo "✓ Token obtained."
echo "  Length:           ${#TOKEN}"
echo "  Parts (dots):     $(echo "$TOKEN" | tr -cd '.' | wc -c)"
echo ""

# ------- Step 2: MCP initialize ----------------------------

echo "→ Sending MCP 'initialize' request..."

MCP_RESPONSE=$(curl -sS \
  -X POST \
  "${MCP_URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-03-26",
      "capabilities": {},
      "clientInfo": {
        "name": "curl-test",
        "version": "1.0"
      }
    }
  }')

echo ""
echo "→ MCP initialize response:"
echo "${MCP_RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${MCP_RESPONSE}"

# ------- Step 3: List tools --------------------------------

echo ""
echo "→ Sending MCP 'tools/list' request..."

TOOLS_RESPONSE=$(curl -sS \
  -X POST \
  "${MCP_URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list",
    "params": {}
  }')

echo ""
echo "→ Available MCP tools:"
echo "${TOOLS_RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
tools = data.get('result', {}).get('tools', [])
if tools:
    for t in tools:
        print(f\"  - {t.get('name')}: {t.get('description', '')[:80]}\")
else:
    print(json.dumps(data, indent=2))
" 2>/dev/null || echo "${TOOLS_RESPONSE}"

echo ""
echo "✓ Test complete."
