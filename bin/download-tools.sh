#!/bin/bash

###########################################
#   Download Required Tools for ayakurume #
###########################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }
print_step() { echo -e "${CYAN}[→]${NC} $1"; }

# Detect architecture
detect_arch() {
    local arch=$(uname -m)
    local os=$(uname -s)

    case "$arch" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        aarch64)
            if [[ "$os" == "Darwin" ]]; then
                echo "arm64"
            else
                echo "aarch64"
            fi
            ;;
        arm64)
            echo "arm64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Download gaster
download_gaster() {
    local arch=$1
    local dest_dir="$SCRIPT_DIR/$arch"

    print_step "Downloading gaster for $arch..."

    case "$arch" in
        x86_64)
            # Linux x86_64
            curl -L -o "$dest_dir/gaster" "https://nightly.link/verygenericname/gaster/workflows/build/main/gaster-Linux.zip" 2>/dev/null && \
            cd "$dest_dir" && unzip -o gaster-Linux.zip 2>/dev/null && rm -f gaster-Linux.zip && cd - >/dev/null || \
            print_warning "Could not download gaster for x86_64, please build manually"
            ;;
        arm64)
            # macOS arm64
            curl -L -o "$dest_dir/gaster" "https://nightly.link/verygenericname/gaster/workflows/build/main/gaster-macOS.zip" 2>/dev/null && \
            cd "$dest_dir" && unzip -o gaster-macOS.zip 2>/dev/null && rm -f gaster-macOS.zip && cd - >/dev/null || \
            print_warning "Could not download gaster for arm64, please build manually"
            ;;
        aarch64)
            print_warning "gaster for Linux aarch64 needs to be built from source"
            print_info "Clone https://github.com/0x7ff/gaster and build"
            ;;
    esac

    [[ -f "$dest_dir/gaster" ]] && chmod +x "$dest_dir/gaster" && print_status "gaster downloaded"
}

# Download irecovery (from libimobiledevice)
download_irecovery() {
    local arch=$1
    local dest_dir="$SCRIPT_DIR/$arch"

    print_step "Downloading irecovery for $arch..."

    case "$arch" in
        x86_64)
            # Try getting from libimobiledevice releases
            local url="https://github.com/libimobiledevice/libirecovery/releases/latest/download/libirecovery-linux-x86_64.tar.gz"
            if curl -fL -o "$dest_dir/libirecovery.tar.gz" "$url" 2>/dev/null; then
                cd "$dest_dir" && tar -xzf libirecovery.tar.gz 2>/dev/null
                [[ -f "irecovery" ]] || [[ -d "usr" ]] && mv usr/local/bin/irecovery . 2>/dev/null
                rm -rf libirecovery.tar.gz usr 2>/dev/null
                cd - >/dev/null
            else
                print_warning "irecovery for x86_64 - install via: apt install libirecovery-utils"
            fi
            ;;
        arm64)
            print_warning "irecovery for macOS - install via: brew install libirecovery"
            ;;
        aarch64)
            print_warning "irecovery for aarch64 - install via: apt install libirecovery-utils"
            ;;
    esac

    [[ -f "$dest_dir/irecovery" ]] && chmod +x "$dest_dir/irecovery" && print_status "irecovery downloaded"
}

# Download/setup iproxy (from libusbmuxd)
download_iproxy() {
    local arch=$1
    local dest_dir="$SCRIPT_DIR/$arch"

    print_step "Setting up iproxy for $arch..."

    case "$arch" in
        x86_64)
            print_warning "iproxy for x86_64 - install via: apt install libusbmuxd-tools"
            ;;
        arm64)
            print_warning "iproxy for macOS - install via: brew install libusbmuxd"
            ;;
        aarch64)
            print_warning "iproxy for aarch64 - install via: apt install libusbmuxd-tools"
            ;;
    esac
}

# Download img4
download_img4() {
    local arch=$1
    local dest_dir="$SCRIPT_DIR/$arch"

    print_step "Setting up img4 for $arch..."

    # Check if already exists in macos/
    if [[ -f "$SCRIPT_DIR/../macos/img4" ]]; then
        print_info "img4 found in macos/ directory"
        if [[ "$arch" == "arm64" ]]; then
            cp "$SCRIPT_DIR/../macos/img4" "$dest_dir/img4"
            chmod +x "$dest_dir/img4"
            print_status "img4 copied to $arch"
        fi
    fi

    case "$arch" in
        x86_64|aarch64)
            print_warning "img4 for $arch needs to be built from xerub/img4lib"
            print_info "Clone https://github.com/xerub/img4lib and build"
            ;;
    esac
}

# Download bspatch
setup_bspatch() {
    local arch=$1
    local dest_dir="$SCRIPT_DIR/$arch"

    print_step "Setting up bspatch for $arch..."

    # bspatch is usually part of bsdiff package
    case "$arch" in
        x86_64|aarch64)
            print_info "bspatch - install via: apt install bsdiff"
            ;;
        arm64)
            print_info "bspatch - usually pre-installed on macOS, or: brew install bsdiff"
            ;;
    esac
}

# Create wrapper scripts that check for binaries
create_wrapper() {
    local tool=$1
    local dest_dir="$SCRIPT_DIR/$2"

    if [[ ! -f "$dest_dir/$tool" ]]; then
        cat > "$dest_dir/$tool" << 'WRAPPER'
#!/bin/bash
echo "Error: This tool binary is not installed yet."
echo "Please install it using your package manager or build from source."
exit 1
WRAPPER
        chmod +x "$dest_dir/$tool"
    fi
}

# Main download function
download_all() {
    local arch=$1

    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Downloading tools for: $arch${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""

    mkdir -p "$SCRIPT_DIR/$arch"

    download_gaster "$arch"
    download_irecovery "$arch"
    download_iproxy "$arch"
    download_img4 "$arch"
    setup_bspatch "$arch"

    echo ""
}

# Show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --all          Download for all architectures"
    echo "  --x86_64       Download for x86_64 (Linux Intel/AMD)"
    echo "  --aarch64      Download for aarch64 (Linux ARM64)"
    echo "  --arm64        Download for arm64 (macOS Apple Silicon)"
    echo "  --auto         Auto-detect architecture and download"
    echo "  --help         Show this help"
    echo ""
}

# Main
main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   ayakurume Tools Downloader              ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    case "${1:-}" in
        --all)
            download_all "x86_64"
            download_all "aarch64"
            download_all "arm64"
            ;;
        --x86_64)
            download_all "x86_64"
            ;;
        --aarch64)
            download_all "aarch64"
            ;;
        --arm64)
            download_all "arm64"
            ;;
        --auto|"")
            local arch=$(detect_arch)
            if [[ "$arch" == "unknown" ]]; then
                print_error "Unknown architecture: $(uname -m)"
                exit 1
            fi
            print_info "Detected architecture: $arch"
            download_all "$arch"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac

    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Download Summary${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""

    for arch_dir in x86_64 aarch64 arm64; do
        if [[ -d "$SCRIPT_DIR/$arch_dir" ]]; then
            echo -e "${YELLOW}$arch_dir/:${NC}"
            ls -la "$SCRIPT_DIR/$arch_dir/" 2>/dev/null | grep -v "^total" | grep -v "^d" | awk '{print "  " $NF}' || echo "  (empty)"
            echo ""
        fi
    done

    print_info "Some tools may need to be installed via package manager"
    print_info "or built from source. See messages above."
    echo ""
}

main "$@"
