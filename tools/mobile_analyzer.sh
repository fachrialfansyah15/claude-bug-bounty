#!/bin/bash
# =============================================================================
# Mobile Pentest Analyzer
# Usage: ./tools/mobile_analyzer.sh <path_to_apk> <output_dir>
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok()    { echo -e "${GREEN}[+]${NC} $1"; }
log_err()   { echo -e "${RED}[-]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
log_info()  { echo -e "${CYAN}[*]${NC} $1"; }

APK_FILE="${1:-}"
OUT_DIR="${2:-}"

if [ -z "$APK_FILE" ] || [ -z "$OUT_DIR" ]; then
    echo "Usage: ./tools/mobile_analyzer.sh <path_to_apk> <output_dir>"
    exit 1
fi

if [ ! -f "$APK_FILE" ]; then
    log_err "APK file not found: $APK_FILE"
    exit 1
fi

mkdir -p "$OUT_DIR"
log_info "Starting Mobile Analysis for $(basename "$APK_FILE")"

# 1. APKTool (Extract Resources & AndroidManifest.xml)
if command -v apktool &>/dev/null; then
    log_info "Running apktool..."
    apktool d -f "$APK_FILE" -o "$OUT_DIR/apktool_out" 1>/dev/null
    
    # Extract exported activities/providers (Potential Attack Surface)
    if [ -f "$OUT_DIR/apktool_out/AndroidManifest.xml" ]; then
        log_ok "Extracting exported components..."
        grep -iE '<(activity|provider|service|receiver).*android:exported="true"' "$OUT_DIR/apktool_out/AndroidManifest.xml" > "$OUT_DIR/exported_components.txt" || true
        log_ok "Found $(wc -l < "$OUT_DIR/exported_components.txt" 2>/dev/null || echo 0) exported components."
    fi
else
    log_warn "apktool not installed (brew install apktool) - skipping resource extraction"
fi

# 2. JADX (Decompile to Java)
if command -v jadx &>/dev/null; then
    log_info "Running jadx (Decompiling to Java)..."
    jadx -d "$OUT_DIR/jadx_out" -j 4 "$APK_FILE" 1>/dev/null 2>/dev/null
    
    # 3. Secret Hunting (grep)
    if [ -d "$OUT_DIR/jadx_out" ]; then
        log_info "Hunting for hardcoded secrets & endpoints..."
        grep -rIiohE '(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|client[_-]?secret|password|secret[_-]?key)["\s]*[:=]["\s]*[a-zA-Z0-9_\-]{8,}' "$OUT_DIR/jadx_out" | sort -u > "$OUT_DIR/hardcoded_secrets.txt" || true
        grep -rIiohE 'https?://[a-zA-Z0-9./_-]+' "$OUT_DIR/jadx_out" | sort -u > "$OUT_DIR/endpoints.txt" || true
        
        log_ok "Secrets found: $(wc -l < "$OUT_DIR/hardcoded_secrets.txt" 2>/dev/null || echo 0)"
        log_ok "Endpoints extracted: $(wc -l < "$OUT_DIR/endpoints.txt" 2>/dev/null || echo 0)"
    fi
else
    log_warn "jadx not installed (brew install jadx) - skipping Java decompilation"
fi

log_info "Mobile Analysis Complete. Results saved in: $OUT_DIR/"
