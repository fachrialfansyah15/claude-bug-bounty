#!/bin/bash
# =============================================================================
# Subdomain Monitor
# Usage: ./tools/monitor_subdomains.sh <target>
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
    echo "Usage: ./tools/monitor_subdomains.sh <target-domain>"
    exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RECON_DIR="$BASE_DIR/recon/$TARGET"
SUBS_DIR="$RECON_DIR/subdomains"
NOTIFIER="$BASE_DIR/tools/notifier.py"

if [ ! -d "$SUBS_DIR" ] || [ ! -f "$SUBS_DIR/all.txt" ]; then
    echo -e "${RED}[-] No previous recon data found for $TARGET. Run ./recon_engine.sh first.${NC}"
    exit 1
fi

# Backup old subdomains
cp "$SUBS_DIR/all.txt" "$SUBS_DIR/all_old.txt"

echo -e "${CYAN}[*] Monitoring $TARGET for new subdomains...${NC}"

# Run subfinder (fast passive)
if command -v subfinder &>/dev/null; then
    subfinder -d "$TARGET" -silent -all -o "$SUBS_DIR/subfinder_new.txt" 2>/dev/null || true
else
    echo -e "${RED}[-] subfinder is required for monitoring.${NC}"
    exit 1
fi

# Merge new subs with old ones
cat "$SUBS_DIR/subfinder_new.txt" "$SUBS_DIR/all_old.txt" | sort -u > "$SUBS_DIR/all.txt"

# Find what's new (in all.txt but NOT in all_old.txt)
comm -13 "$SUBS_DIR/all_old.txt" "$SUBS_DIR/all.txt" > "$SUBS_DIR/new_subdomains.txt"

NEW_COUNT=$(wc -l < "$SUBS_DIR/new_subdomains.txt" | tr -d ' ')

if [ "$NEW_COUNT" -gt 0 ]; then
    echo -e "${GREEN}[+] Found $NEW_COUNT NEW subdomains!${NC}"
    
    # Send notification if configured
    if [ -x "$NOTIFIER" ]; then
        msg="🚨 [Subdomain Monitor] Found $NEW_COUNT new subdomains for $TARGET\n"
        if [ "$NEW_COUNT" -le 10 ]; then
            msg="$msg\n$(cat "$SUBS_DIR/new_subdomains.txt")"
        else
            msg="$msg\n(Check recon/$TARGET/subdomains/new_subdomains.txt for full list)"
        fi
        
        # Trigger httpx on new subs? Optional for future.
        python3 "$NOTIFIER" "$msg"
    fi
else
    echo -e "${YELLOW}[!] No new subdomains found.${NC}"
fi

# Cleanup temp file
rm -f "$SUBS_DIR/subfinder_new.txt"
