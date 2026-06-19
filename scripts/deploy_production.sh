#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# GoldTaxi Production Deployment Script
# =============================================================================
# This script handles:
# 1. Validating all required environment variables
# 2. Building Flutter web for production
# 3. Deploying to Firebase Hosting
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FIREBASE_PROJECT_ID="goldtaxi-202ff"
FIREBASE_HOSTING_SITE="gold-taxi-clean"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Validation Functions
# =============================================================================

validate_env_file() {
    local env_file="$1"
    local env_name="$2"
    
    echo -e "${BLUE}Checking ${env_name} environment file...${NC}"
    
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}❌ Error: Environment file not found: ${env_file}${NC}"
        echo "   Run: cp .env.production .env.production.deployment && edit .env.production.deployment"
        return 1
    fi
    
    # Check for required keys
    local missing_keys=()
    
    if ! grep -q "^BACKEND_MODE=firebase" "$env_file"; then
        missing_keys+=("BACKEND_MODE (must be 'firebase')")
    fi
    
    if ! grep -q "^GOOGLE_MAPS_API_KEY=" "$env_file" || grep -q "^GOOGLE_MAPS_API_KEY=YOUR_" "$env_file"; then
        missing_keys+=("GOOGLE_MAPS_API_KEY")
    fi
    
    if ! grep -q "^GOOGLE_PLACES_API_KEY=" "$env_file" || grep -q "^GOOGLE_PLACES_API_KEY=YOUR_" "$env_file"; then
        missing_keys+=("GOOGLE_PLACES_API_KEY")
    fi
    
    if ! grep -q "^FIREBASE_WEB_VAPID_KEY=" "$env_file" || grep -q "^FIREBASE_WEB_VAPID_KEY=YOUR_" "$env_file"; then
        missing_keys+=("FIREBASE_WEB_VAPID_KEY")
    fi
    
    if [ ${#missing_keys[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing or placeholder values in ${env_file}:${NC}"
        for key in "${missing_keys[@]}"; do
            echo "   - $key"
        done
        return 1
    fi
    
    echo -e "${GREEN}✓ ${env_name} environment file validated${NC}"
    return 0
}

check_firebase_login() {
    echo -e "${BLUE}Checking Firebase login...${NC}"
    # Simple check: try to get logged in user
    local login_output
    login_output=$(firebase login:list 2>&1 || true)
    
    # Check if there's a user logged in
    if echo "$login_output" | grep -qE "(Logged in|email)"; then
        local logged_user
        logged_user=$(echo "$login_output" | grep -oE '(Logged in as [^ ]+|email[^ ]*[[:space:]]+[^ ]+)' | sed 's/.*as //' | sed 's/.* //')
        echo -e "${GREEN}✓ Firebase login verified (${logged_user:-user})${NC}"
        
        # Set and verify the Firebase project
        local current_project
        current_project=$(firebase use 2>&1 | grep -o "$FIREBASE_PROJECT_ID" || echo "")
        
        if [ -z "$current_project" ]; then
            # Try to set it
            if firebase use "$FIREBASE_PROJECT_ID" 2>&1; then
                echo -e "${GREEN}✓ Project set to ${FIREBASE_PROJECT_ID}${NC}"
            else
                echo -e "${YELLOW}⚠ Warning: Could not verify project ${FIREBASE_PROJECT_ID}${NC}"
            fi
        else
            echo -e "${GREEN}✓ Project: ${FIREBASE_PROJECT_ID}${NC}"
        fi
        return 0
    fi
    
    echo -e "${RED}❌ Error: Not logged in to Firebase${NC}"
    echo "   Run: firebase login"
    return 1
}

check_flutter() {
    echo -e "${BLUE}Checking Flutter installation...${NC}"
    if ! command -v flutter &>/dev/null; then
        echo -e "${RED}❌ Error: Flutter not found${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Flutter: $(flutter --version | head -1)${NC}"
    return 0
}

# =============================================================================
# Pre-deployment Checks
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         GoldTaxi Production Deployment                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/4] Running pre-deployment checks...${NC}"
echo ""

check_flutter
check_firebase_login

ENV_FILE=""

# Check for production env file (either .env.production or .env.production.deployment)
if [ -f "$PROJECT_DIR/.env.production.deployment" ]; then
    ENV_FILE=".env.production.deployment"
    validate_env_file "$PROJECT_DIR/$ENV_FILE" "Production deployment"
elif [ -f "$PROJECT_DIR/.env.production" ]; then
    ENV_FILE=".env.production"
    echo -e "${YELLOW}⚠ Warning: Using template .env.production file${NC}"
    echo "  Consider copying to .env.production.deployment with real values"
    validate_env_file "$PROJECT_DIR/$ENV_FILE" "Production"
else
    echo -e "${RED}❌ Error: No production environment file found${NC}"
    echo "  Expected: .env.production or .env.production.deployment"
    exit 1
fi

echo ""

# =============================================================================
# Build Step
# =============================================================================

echo -e "${YELLOW}[2/4] Building Flutter web for production...${NC}"
echo ""

cd "$PROJECT_DIR"

# Clean previous build
echo -e "${BLUE}Cleaning previous build...${NC}"
flutter clean 2>/dev/null || echo "Clean skipped"

# Get dependencies
echo -e "${BLUE}Getting dependencies...${NC}"
flutter pub get

# Run analysis
echo -e "${BLUE}Running code analysis...${NC}"
flutter analyze

# Run tests
echo -e "${BLUE}Running tests...${NC}"
flutter test

# Build for production
echo -e "${BLUE}Building web release...${NC}"
flutter build web --release \
    --dart-define-from-file="$ENV_FILE"

echo -e "${GREEN}✓ Build completed: build/web${NC}"
echo ""

# =============================================================================
# Deploy Step
# =============================================================================

echo -e "${YELLOW}[3/4] Deploying to Firebase Hosting...${NC}"
echo ""

# Show what will be deployed
echo -e "${BLUE}Target project: ${FIREBASE_PROJECT_ID}${NC}"
echo -e "${BLUE}Target site: ${FIREBASE_HOSTING_SITE}${NC}"
echo -e "${BLUE}Source: build/web${NC}"
echo -e "${BLUE}Environment: ${ENV_FILE}${NC}"

# Deploy with confirmation
read -p "Deploy to production? (y/N): " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}Starting deployment...${NC}"
    firebase deploy --only hosting --project "$FIREBASE_PROJECT_ID"
    echo -e "${GREEN}✓ Deployment completed${NC}"
else
    echo ""
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

echo ""

# =============================================================================
# Post-deployment Verification
# =============================================================================

echo -e "${YELLOW}[4/4] Post-deployment verification...${NC}"
echo ""

# Smoke test
echo -e "${BLUE}Running smoke tests...${NC}"
if [ -f "$SCRIPT_DIR/smoke_hosting.sh" ]; then
    "$SCRIPT_DIR/smoke_hosting.sh" || echo -e "${YELLOW}⚠ Smoke tests warning${NC}"
else
    echo "No smoke test script found"
fi

# Show deployment info
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Production Deployment Successful!                               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "🚀 Your app is live at: https://${FIREBASE_HOSTING_SITE}.web.app"
echo ""
