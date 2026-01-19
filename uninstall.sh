#!/usr/bin/env bash
#
# Meldoc CLI Uninstaller (macOS/Linux)
# Usage: curl -fsSL https://meldoc.io/uninstall.sh | bash
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
BINARY_NAME="meldoc"

# Search directories in order of priority (user-space first)
COMMON_INSTALL_DIRS=(
    "$HOME/.local/bin"
    "$HOME/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "/usr/bin"
)

# ============================================================================
# Colors
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# Logging functions
# ============================================================================
log_info() {
    echo -e "${BLUE}==>${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# ============================================================================
# Find installation
# ============================================================================
find_installation() {
    # Try which command first
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        INSTALL_PATH=$(command -v "$BINARY_NAME")
        INSTALLED_VERSION=$("$BINARY_NAME" version 2>&1 || echo "unknown")
        return 0
    fi
    
    # Search in common directories
    for dir in "${COMMON_INSTALL_DIRS[@]}"; do
        if [[ -f "$dir/$BINARY_NAME" ]]; then
            INSTALL_PATH="$dir/$BINARY_NAME"
            INSTALLED_VERSION=$("$INSTALL_PATH" version 2>&1 || echo "unknown")
            return 0
        fi
    done
    
    return 1
}

# ============================================================================
# Check if path requires sudo
# ============================================================================
needs_sudo() {
    local path="$1"
    local dir
    dir=$(dirname "$path")
    
    # Try to create a test file
    local test_file="${dir}/.${BINARY_NAME}-uninstall-test.$$"
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file" 2>/dev/null
        return 1  # No sudo needed
    fi
    return 0  # Sudo needed
}

# ============================================================================
# Remove binary
# ============================================================================
remove_binary() {
    local use_sudo="$1"
    
    log_info "Removing ${INSTALL_PATH}..."
    
    if [[ "$use_sudo" -eq 1 ]]; then
        if sudo rm "$INSTALL_PATH"; then
            log_success "Binary removed successfully"
            return 0
        else
            log_error "Failed to remove binary"
            return 1
        fi
    else
        if rm "$INSTALL_PATH"; then
            log_success "Binary removed successfully"
            return 0
        else
            log_error "Failed to remove binary"
            return 1
        fi
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║     Meldoc CLI Uninstaller            ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    # Find installation
    if ! find_installation; then
        log_error "meldoc is not installed or not found in PATH"
        echo ""
        echo "Searched in:"
        for dir in "${COMMON_INSTALL_DIRS[@]}"; do
            echo "  - $dir"
        done
        echo ""
        exit 1
    fi
    
    log_success "Found meldoc installation"
    echo ""
    echo -e "  Location: ${CYAN}${INSTALL_PATH}${NC}"
    echo -e "  Version:  ${CYAN}${INSTALLED_VERSION}${NC}"
    echo ""
    
    # Check if sudo is needed
    use_sudo=0
    if needs_sudo "$INSTALL_PATH"; then
        use_sudo=1
        log_warning "Removal requires elevated permissions (sudo)"
        echo ""
    fi
    
    # Remove binary
    if ! remove_binary "$use_sudo"; then
        exit 1
    fi
    
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║     ✓ Uninstallation Complete         ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    # Verify removal
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        log_warning "meldoc is still in PATH (may be cached)"
        echo ""
        echo "Try running: hash -r"
        echo "Or restart your terminal"
    else
        log_success "meldoc has been completely removed"
    fi
    
    echo ""
    echo "Thank you for using meldoc! 👋"
    echo ""
}

main "$@"
