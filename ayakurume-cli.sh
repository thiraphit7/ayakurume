#!/bin/bash

###########################################
#     ayakurume CLI-GUI Automation Tool   #
#     iOS 15/16 Jailbreak for checkm8     #
###########################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

# Set architecture and binary path
ARCH=$(detect_arch)
BIN_PATH="${BIN_PATH:-$SCRIPT_DIR/bin/$ARCH}"

# Add bin directory to PATH if it exists
if [[ -d "$BIN_PATH" ]]; then
    export PATH="$BIN_PATH:$PATH"
fi

# Configuration
SSHRD_PATH="${SSHRD_PATH:-../SSHRD_Script}"
SSH_PORT=2222
IPROXY_PORT=4444
DEVICE_TYPE=""
IOS_VERSION=""
DEVICE_BOARD=""
DEVICE_UUID=""

# Device configurations
declare -A DEVICE_CONFIGS
DEVICE_CONFIGS["iPhone 6s"]="n71:15.7.1:19H117:iPhone8,1"
DEVICE_CONFIGS["iPhone X"]="d22:16.7.12:20H364:iPhone10,6"

###########################################
#           Utility Functions             #
###########################################

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     █████╗ ██╗   ██╗ █████╗ ██╗  ██╗██╗   ██╗██████╗     ║"
    echo "║    ██╔══██╗╚██╗ ██╔╝██╔══██╗██║ ██╔╝██║   ██║██╔══██╗    ║"
    echo "║    ███████║ ╚████╔╝ ███████║█████╔╝ ██║   ██║██████╔╝    ║"
    echo "║    ██╔══██║  ╚██╔╝  ██╔══██║██╔═██╗ ██║   ██║██╔══██╗    ║"
    echo "║    ██║  ██║   ██║   ██║  ██║██║  ██╗╚██████╔╝██║  ██║    ║"
    echo "║    ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝    ║"
    echo "║                                                           ║"
    echo "║        iOS 15/16 Jailbreak CLI Automation Tool            ║"
    echo "║              For checkm8 devices (A8-A11)                 ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[→]${NC} $1"
}

press_enter() {
    echo ""
    echo -e "${WHITE}Press ENTER to continue...${NC}"
    read -r
}

confirm_action() {
    echo -e "${YELLOW}$1 [y/N]${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

###########################################
#        Dependency Check Functions       #
###########################################

check_command() {
    local cmd=$1
    local bin_path="$BIN_PATH/$cmd"

    # First check in local bin directory
    if [[ -x "$bin_path" ]]; then
        print_status "$cmd found in bin/$ARCH/"
        return 0
    # Then check in system PATH
    elif command -v "$cmd" &> /dev/null; then
        print_status "$cmd found (system)"
        return 0
    else
        print_error "$cmd not found"
        print_info "  Install to: bin/$ARCH/$cmd"
        return 1
    fi
}

# Get tool path (local bin or system)
get_tool() {
    local cmd=$1
    local bin_path="$BIN_PATH/$cmd"

    if [[ -x "$bin_path" ]]; then
        echo "$bin_path"
    else
        echo "$cmd"
    fi
}

check_dependencies() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}        Checking Dependencies          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    echo -e "${WHITE}System Info:${NC}"
    echo -e "  Architecture: ${GREEN}$ARCH${NC}"
    echo -e "  Binary Path:  ${GREEN}$BIN_PATH${NC}"
    echo ""

    local all_ok=true

    echo -e "${CYAN}Required Tools:${NC}"
    # Check required tools
    check_command "gaster" || all_ok=false
    check_command "irecovery" || all_ok=false
    check_command "iproxy" || all_ok=false
    check_command "ssh" || all_ok=false
    check_command "scp" || all_ok=false
    check_command "bspatch" || all_ok=false

    echo ""
    echo -e "${CYAN}img4 Tool:${NC}"
    # Check img4 tool - check local bin first, then macos/
    if [[ -x "$BIN_PATH/img4" ]]; then
        print_status "img4 found in bin/$ARCH/"
    elif [[ -f "$SCRIPT_DIR/macos/img4" ]]; then
        print_status "img4 found in macos/"
    else
        print_error "img4 not found"
        print_info "  Install to: bin/$ARCH/img4"
        all_ok=false
    fi

    # Check SSHRD_Script
    if [[ -d "$SSHRD_PATH" ]]; then
        print_status "SSHRD_Script found at $SSHRD_PATH"
    else
        print_warning "SSHRD_Script not found at $SSHRD_PATH"
        print_info "Set SSHRD_PATH environment variable to specify location"
    fi

    # Check ios files
    echo ""
    echo -e "${CYAN}Checking iOS files:${NC}"
    local ios_files=("ios/lightstrap.tar" "ios/jb.dylib" "ios/jbloader" "ios/launchd")
    for file in "${ios_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            print_status "$file"
        else
            print_error "$file not found"
            all_ok=false
        fi
    done

    echo ""
    if $all_ok; then
        print_status "All dependencies satisfied!"
    else
        print_error "Some dependencies are missing"
    fi

    press_enter
}

###########################################
#         Device Selection Menu           #
###########################################

select_device() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}         Select Target Device          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} iPhone 6s (iPhone8,1) - iOS 15.7.1"
    echo -e "  ${WHITE}2)${NC} iPhone X  (iPhone10,6) - iOS 16.7.12 ${YELLOW}[WIP]${NC}"
    echo ""
    echo -e "  ${WHITE}0)${NC} Back to Main Menu"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -n "Select device [0-2]: "
    read -r choice

    case $choice in
        1)
            DEVICE_TYPE="iPhone 6s"
            DEVICE_BOARD="n71"
            IOS_VERSION="15.7.1"
            DEVICE_MODEL="iPhone8,1"
            FIRMWARE_DIR="n71_19H117"
            print_status "Selected: iPhone 6s (iOS 15.7.1)"
            return 0
            ;;
        2)
            DEVICE_TYPE="iPhone X"
            DEVICE_BOARD="d22"
            IOS_VERSION="16.7.12"
            DEVICE_MODEL="iPhone10,6"
            FIRMWARE_DIR="d22_20H364"
            print_warning "iPhone X support is Work In Progress"
            print_status "Selected: iPhone X (iOS 16.7.12)"
            return 0
            ;;
        0)
            return 1
            ;;
        *)
            print_error "Invalid selection"
            return 1
            ;;
    esac
}

get_uuid_from_device() {
    print_info "Getting UUID from device..."
    print_warning "Please enter the UUID from /mnt6/ on device"
    print_info "You can find it by running 'ls /mnt6/' on the device"
    echo -n "UUID: "
    read -r DEVICE_UUID

    if [[ -z "$DEVICE_UUID" ]]; then
        print_error "UUID cannot be empty"
        return 1
    fi
    print_status "UUID set to: $DEVICE_UUID"
    return 0
}

###########################################
#       SSHRD Setup Functions             #
###########################################

setup_sshrd() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}     Step 1: SSHRD Setup & Boot        ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    if [[ -z "$DEVICE_TYPE" ]]; then
        print_error "No device selected. Please select a device first."
        press_enter
        return 1
    fi

    print_info "Device: $DEVICE_TYPE ($DEVICE_MODEL)"
    print_info "iOS Version: $IOS_VERSION"
    echo ""

    # Check SSHRD_Script
    if [[ ! -d "$SSHRD_PATH" ]]; then
        print_error "SSHRD_Script not found at $SSHRD_PATH"
        print_info "Please clone SSHRD_Script and set SSHRD_PATH"
        press_enter
        return 1
    fi

    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Create ramdisk for iOS $IOS_VERSION"
    echo "  2. Boot device into SSH ramdisk"
    echo "  3. Open SSH connection"
    echo ""

    if ! confirm_action "Continue with SSHRD setup?"; then
        return 1
    fi

    # Step 1: Create ramdisk
    print_step "Creating ramdisk for iOS $IOS_VERSION..."
    cd "$SSHRD_PATH" || exit 1

    print_info "Running: ./sshrd.sh $IOS_VERSION"
    if ./sshrd.sh "$IOS_VERSION"; then
        print_status "Ramdisk created successfully"
    else
        print_error "Failed to create ramdisk"
        cd "$SCRIPT_DIR" || exit 1
        press_enter
        return 1
    fi

    # Step 2: Boot device
    print_step "Booting device into SSH ramdisk..."
    print_warning "Please put your device into DFU mode"
    press_enter

    print_info "Running: ./sshrd.sh boot"
    if ./sshrd.sh boot; then
        print_status "Device booted successfully"
    else
        print_error "Failed to boot device"
        cd "$SCRIPT_DIR" || exit 1
        press_enter
        return 1
    fi

    # Step 3: Wait for device
    print_step "Waiting for device to boot (30 seconds)..."
    sleep 30

    # Step 4: Start SSH
    print_step "Starting SSH connection..."
    print_info "Running: ./sshrd.sh ssh"

    echo ""
    print_warning "SSH session will open in a new terminal"
    print_info "Run the following commands on the iOS device:"
    echo ""
    echo -e "${WHITE}───────────────────────────────────────${NC}"
    echo -e "${GREEN}# Create fakefs and mount${NC}"
    echo "newfs_apfs -A -D -o role=r -v System /dev/disk0s1"
    echo "mount_apfs /dev/disk0s1s1 /mnt1"
    echo "mount_apfs /dev/disk0s1s8 /mnt2"
    echo "mount_apfs /dev/disk0s1s6 /mnt6"
    echo ""
    echo -e "${GREEN}# Copy rootfs to fakefs${NC}"
    echo "cp -a /mnt1/. /mnt2/"
    echo "umount /mnt1"
    echo ""
    echo -e "${GREEN}# Create directories${NC}"
    echo "mkdir /mnt6/{UUID}/binpack"
    echo "mkdir /mnt2/jbin"
    echo -e "${WHITE}───────────────────────────────────────${NC}"
    echo ""
    print_warning "Replace {UUID} with your device's UUID from /mnt6/"

    ./sshrd.sh ssh &

    cd "$SCRIPT_DIR" || exit 1
    press_enter
    return 0
}

###########################################
#       Copy Files to Device              #
###########################################

copy_files_to_device() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}    Step 2: Copy Files to Device       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    if [[ -z "$DEVICE_TYPE" ]]; then
        print_error "No device selected. Please select a device first."
        press_enter
        return 1
    fi

    if [[ -z "$DEVICE_UUID" ]]; then
        if ! get_uuid_from_device; then
            press_enter
            return 1
        fi
    fi

    print_info "Device: $DEVICE_TYPE"
    print_info "UUID: $DEVICE_UUID"
    echo ""

    echo -e "${YELLOW}This will copy:${NC}"
    echo "  - ios/lightstrap.tar -> /mnt6/"
    echo "  - ios/jb.dylib, jbloader, launchd -> /mnt2/jbin/"
    echo ""

    if ! confirm_action "Continue copying files?"; then
        return 1
    fi

    # Copy lightstrap.tar
    print_step "Copying lightstrap.tar to device..."
    if scp -o StrictHostKeyChecking=no -P $SSH_PORT ios/lightstrap.tar root@localhost:/mnt6/; then
        print_status "lightstrap.tar copied"
    else
        print_error "Failed to copy lightstrap.tar"
        press_enter
        return 1
    fi

    # Copy jailbreak files
    print_step "Copying jailbreak files to device..."
    if scp -o StrictHostKeyChecking=no -P $SSH_PORT ios/jb.dylib ios/jbloader ios/launchd root@localhost:/mnt2/jbin/; then
        print_status "Jailbreak files copied"
    else
        print_error "Failed to copy jailbreak files"
        press_enter
        return 1
    fi

    echo ""
    print_status "Files copied successfully!"
    echo ""
    print_info "Now run these commands on the iOS device:"
    echo ""
    echo -e "${WHITE}───────────────────────────────────────${NC}"
    echo "tar -xvf /mnt6/lightstrap.tar -C /mnt6/$DEVICE_UUID/binpack/"
    echo "rm /mnt6/lightstrap.tar"
    echo -e "${WHITE}───────────────────────────────────────${NC}"

    press_enter
    return 0
}

###########################################
#       Copy apticket.der                 #
###########################################

copy_apticket() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}     Step 3: Copy apticket.der         ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    if [[ -z "$DEVICE_UUID" ]]; then
        if ! get_uuid_from_device; then
            press_enter
            return 1
        fi
    fi

    print_info "UUID: $DEVICE_UUID"
    echo ""

    if ! confirm_action "Copy apticket.der from device?"; then
        return 1
    fi

    print_step "Copying apticket.der from device..."
    local apticket_path="/mnt6/$DEVICE_UUID/System/Library/Caches/apticket.der"

    if scp -o StrictHostKeyChecking=no -P $SSH_PORT "root@localhost:$apticket_path" ./apticket.der; then
        print_status "apticket.der copied successfully"
    else
        print_error "Failed to copy apticket.der"
        press_enter
        return 1
    fi

    echo ""
    print_info "Now reboot the device by running 'reboot' on iOS"

    press_enter
    return 0
}

###########################################
#      First-run Preparations             #
###########################################

prepare_first_run() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}   Step 4: First-run Preparations      ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    if [[ -z "$DEVICE_TYPE" ]]; then
        print_error "No device selected. Please select a device first."
        press_enter
        return 1
    fi

    local ibss_file="iBSS.${DEVICE_BOARD}.RELEASE.im4p"
    local ibss_dec="iBSS.${DEVICE_BOARD}.RELEASE.dec"
    local ibss_patched="pwniBSS.dec"
    local ibss_img4="iBSS.img4"
    local patch_file="$FIRMWARE_DIR/jboot/iBSS.patch"

    print_info "Device: $DEVICE_TYPE"
    print_info "Firmware dir: $FIRMWARE_DIR"
    echo ""

    # Check required files
    if [[ ! -f "apticket.der" ]]; then
        print_error "apticket.der not found"
        print_info "Please complete Step 3 first"
        press_enter
        return 1
    fi

    # Check for im4p file in firmware dir
    local im4p_found=""
    if [[ -f "$FIRMWARE_DIR/$ibss_file" ]]; then
        im4p_found="$FIRMWARE_DIR/$ibss_file"
    elif [[ -f "$ibss_file" ]]; then
        im4p_found="$ibss_file"
    fi

    if [[ -z "$im4p_found" ]]; then
        print_error "$ibss_file not found"
        print_info "Please ensure the iBSS file is in $FIRMWARE_DIR/"
        press_enter
        return 1
    fi

    # Check patch file
    if [[ ! -f "$patch_file" ]]; then
        print_error "iBSS patch file not found at $patch_file"
        press_enter
        return 1
    fi

    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Exploit device with gaster pwn"
    echo "  2. Decrypt iBSS"
    echo "  3. Patch iBSS with jailbreak"
    echo "  4. Create signed iBSS.img4"
    echo ""

    if ! confirm_action "Continue with first-run preparations?"; then
        return 1
    fi

    # Step 1: gaster pwn
    print_step "Exploiting device with gaster..."
    print_warning "Please put device into DFU mode"
    press_enter

    if gaster pwn; then
        print_status "Device exploited successfully"
    else
        print_error "Failed to exploit device"
        press_enter
        return 1
    fi

    # Step 2: Decrypt iBSS
    print_step "Decrypting iBSS..."
    if gaster decrypt "$im4p_found" "$ibss_dec"; then
        print_status "iBSS decrypted"
    else
        print_error "Failed to decrypt iBSS"
        press_enter
        return 1
    fi

    # Step 3: Patch iBSS
    print_step "Patching iBSS..."
    if bspatch "$ibss_dec" "$ibss_patched" "$patch_file"; then
        print_status "iBSS patched"
    else
        print_error "Failed to patch iBSS"
        press_enter
        return 1
    fi

    # Step 4: Create img4
    print_step "Creating signed iBSS.img4..."

    # Find img4 tool
    local img4_tool=""
    if [[ -x "$BIN_PATH/img4" ]]; then
        img4_tool="$BIN_PATH/img4"
    elif [[ -x "$SCRIPT_DIR/macos/img4" ]]; then
        img4_tool="$SCRIPT_DIR/macos/img4"
    else
        print_error "img4 tool not found"
        press_enter
        return 1
    fi

    if "$img4_tool" -i "$ibss_patched" -o "$ibss_img4" -M apticket.der -A -T ibss; then
        print_status "iBSS.img4 created"
    else
        print_error "Failed to create iBSS.img4"
        press_enter
        return 1
    fi

    # Cleanup
    print_step "Cleaning up temporary files..."
    rm -f "$ibss_dec" "$ibss_patched"
    print_status "Cleanup complete"

    echo ""
    print_status "First-run preparations complete!"
    print_info "iBSS.img4 is ready for booting"

    press_enter
    return 0
}

###########################################
#           First Run (Bootstrap)         #
###########################################

run_first_boot() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}      Step 5: First Run (Bootstrap)    ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    if [[ ! -f "iBSS.img4" ]]; then
        print_error "iBSS.img4 not found"
        print_info "Please complete Step 4 first"
        press_enter
        return 1
    fi

    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Exploit device and boot with iBSS.img4"
    echo "  2. Setup iproxy for SSH connection"
    echo "  3. Guide you through bootstrap installation"
    echo ""

    print_warning "Required files (download if not present):"
    echo "  - bootstrap-ssh.tar"
    echo "  - org.swift.libswift_5.0-electra2_iphoneos-arm.deb"
    echo "  - com.ex.substitute_2.3.1_iphoneos-arm.deb"
    echo "  - com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb"
    echo ""

    if ! confirm_action "Continue with first boot?"; then
        return 1
    fi

    # Step 1: gaster pwn and boot
    print_step "Exploiting device..."
    print_warning "Please put device into DFU mode"
    press_enter

    if ! gaster pwn; then
        print_error "Failed to exploit device"
        press_enter
        return 1
    fi
    print_status "Device exploited"

    print_step "Sending iBSS.img4..."
    if ! irecovery -f iBSS.img4; then
        print_error "Failed to send iBSS.img4"
        press_enter
        return 1
    fi
    print_status "iBSS.img4 sent"

    # Step 2: Wait for dropbear
    echo ""
    print_warning "Wait for dropbear to start on device..."
    print_info "You should see the device boot with verbose output"
    press_enter

    # Step 3: Start iproxy
    print_step "Starting iproxy on port $IPROXY_PORT..."
    iproxy $IPROXY_PORT 44 &
    IPROXY_PID=$!
    sleep 2
    print_status "iproxy started (PID: $IPROXY_PID)"

    # Step 4: Instructions for bootstrap
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}    Bootstrap Installation Commands     ${NC}"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}# First, copy required files:${NC}"
    echo "scp -P $IPROXY_PORT bootstrap-ssh.tar root@localhost:/var/root"
    echo "scp -P $IPROXY_PORT org.swift.libswift_5.0-electra2_iphoneos-arm.deb root@localhost:/var/root"
    echo "scp -P $IPROXY_PORT com.ex.substitute_2.3.1_iphoneos-arm.deb root@localhost:/var/root"
    echo "scp -P $IPROXY_PORT com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb root@localhost:/var/root"
    echo ""
    echo -e "${GREEN}# SSH into device:${NC}"
    echo "ssh root@localhost -p $IPROXY_PORT"
    echo ""
    echo -e "${GREEN}# On iOS device, run:${NC}"
    echo "mount -uw /"
    echo "cd /var/root"
    echo "tar --preserve-permissions --no-overwrite-dir -xvf bootstrap-ssh.tar -C /"
    echo "/prep_bootstrap.sh"
    echo "apt update"
    echo "apt upgrade -y"
    echo "apt install org.coolstar.sileo"
    echo "dpkg -i *.deb"
    echo "rm *.deb"
    echo "rm bootstrap-ssh.tar"
    echo "touch /.installed_ayakurume"
    echo "reboot"
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    echo ""

    print_info "Press ENTER when done to kill iproxy"
    read -r

    kill $IPROXY_PID 2>/dev/null
    print_status "iproxy stopped"

    press_enter
    return 0
}

###########################################
#           Normal Boot                   #
###########################################

run_normal_boot() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}        Step 6: Boot Jailbreak         ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    if [[ ! -f "iBSS.img4" ]]; then
        print_error "iBSS.img4 not found"
        print_info "Please complete Step 4 first"
        press_enter
        return 1
    fi

    echo -e "${YELLOW}This will boot the device with jailbreak.${NC}"
    echo ""

    if ! confirm_action "Continue with boot?"; then
        return 1
    fi

    print_step "Exploiting device..."
    print_warning "Please put device into DFU mode"
    press_enter

    if ! gaster pwn; then
        print_error "Failed to exploit device"
        press_enter
        return 1
    fi
    print_status "Device exploited"

    print_step "Sending iBSS.img4..."
    if ! irecovery -f iBSS.img4; then
        print_error "Failed to send iBSS.img4"
        press_enter
        return 1
    fi
    print_status "iBSS.img4 sent"

    echo ""
    print_status "Device should be booting with jailbreak!"

    press_enter
    return 0
}

###########################################
#           Full Auto Setup               #
###########################################

run_full_auto() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}     Full Automatic Setup (Steps 1-5)  ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    if [[ -z "$DEVICE_TYPE" ]]; then
        if ! select_device; then
            return 1
        fi
    fi

    print_info "Device: $DEVICE_TYPE ($DEVICE_MODEL)"
    print_info "iOS: $IOS_VERSION"
    echo ""

    print_warning "This will run all setup steps automatically:"
    echo "  1. SSHRD Setup & Boot"
    echo "  2. Copy files to device"
    echo "  3. Copy apticket.der"
    echo "  4. First-run preparations"
    echo "  5. First run bootstrap"
    echo ""

    if ! confirm_action "Start full automatic setup?"; then
        return 1
    fi

    # Run each step
    setup_sshrd || { print_error "SSHRD setup failed"; return 1; }
    copy_files_to_device || { print_error "File copy failed"; return 1; }
    copy_apticket || { print_error "apticket copy failed"; return 1; }
    prepare_first_run || { print_error "First-run prep failed"; return 1; }
    run_first_boot || { print_error "First boot failed"; return 1; }

    echo ""
    print_status "Full setup completed!"
    press_enter
    return 0
}

###########################################
#           Download Dependencies         #
###########################################

download_dependencies() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}       Download Required Files         ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}Required bootstrap files:${NC}"
    echo ""

    local files=(
        "bootstrap-ssh.tar|https://cdn.discordapp.com/attachments/1017153024768081921/1026161261077090365/bootstrap-ssh.tar"
        "org.swift.libswift_5.0-electra2_iphoneos-arm.deb|https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb"
        "com.ex.substitute_2.3.1_iphoneos-arm.deb|https://apt.bingner.com/debs/1443.00/com.ex.substitute_2.3.1_iphoneos-arm.deb"
        "com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb|https://apt.bingner.com/debs/1443.00/com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb"
    )

    for item in "${files[@]}"; do
        IFS='|' read -r filename url <<< "$item"
        if [[ -f "$filename" ]]; then
            print_status "$filename (already exists)"
        else
            print_warning "$filename (not found)"
            echo "  URL: $url"
        fi
        echo ""
    done

    if ! confirm_action "Download missing files?"; then
        return 1
    fi

    for item in "${files[@]}"; do
        IFS='|' read -r filename url <<< "$item"
        if [[ ! -f "$filename" ]]; then
            print_step "Downloading $filename..."
            if curl -L -o "$filename" "$url"; then
                print_status "$filename downloaded"
            else
                print_error "Failed to download $filename"
            fi
        fi
    done

    press_enter
    return 0
}

###########################################
#        Download Binary Tools            #
###########################################

download_binary_tools() {
    print_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}       Download Binary Tools           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    echo -e "${WHITE}Current Architecture: ${GREEN}$ARCH${NC}"
    echo ""

    local download_script="$SCRIPT_DIR/bin/download-tools.sh"

    if [[ ! -f "$download_script" ]]; then
        print_error "Download script not found: $download_script"
        press_enter
        return 1
    fi

    echo -e "${YELLOW}Options:${NC}"
    echo "  1) Download for current architecture ($ARCH)"
    echo "  2) Download for x86_64 (Linux Intel/AMD)"
    echo "  3) Download for aarch64 (Linux ARM64)"
    echo "  4) Download for arm64 (macOS Apple Silicon)"
    echo "  5) Download for all architectures"
    echo "  0) Back"
    echo ""
    echo -n "Select option: "
    read -r choice

    case $choice in
        1)
            bash "$download_script" --auto
            ;;
        2)
            bash "$download_script" --x86_64
            ;;
        3)
            bash "$download_script" --aarch64
            ;;
        4)
            bash "$download_script" --arm64
            ;;
        5)
            bash "$download_script" --all
            ;;
        0)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac

    press_enter
    return 0
}

###########################################
#              Main Menu                  #
###########################################

show_main_menu() {
    print_banner

    echo -e "${WHITE}  Current Settings:${NC}"
    echo -e "  Arch:   ${CYAN}$ARCH${NC}"
    if [[ -n "$DEVICE_TYPE" ]]; then
        echo -e "  Device: ${GREEN}$DEVICE_TYPE${NC} (${DEVICE_MODEL})"
        echo -e "  iOS:    ${GREEN}$IOS_VERSION${NC}"
    else
        echo -e "  Device: ${RED}Not Selected${NC}"
    fi
    if [[ -n "$DEVICE_UUID" ]]; then
        echo -e "  UUID:   ${GREEN}$DEVICE_UUID${NC}"
    fi
    echo ""

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}             Main Menu                 ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}0)${NC} Select Device"
    echo ""
    echo -e "  ${PURPLE}── Setup Steps ──${NC}"
    echo -e "  ${WHITE}1)${NC} SSHRD Setup & Boot"
    echo -e "  ${WHITE}2)${NC} Copy Files to Device"
    echo -e "  ${WHITE}3)${NC} Copy apticket.der"
    echo -e "  ${WHITE}4)${NC} First-run Preparations"
    echo -e "  ${WHITE}5)${NC} First Run (Bootstrap)"
    echo ""
    echo -e "  ${PURPLE}── Quick Actions ──${NC}"
    echo -e "  ${WHITE}6)${NC} Boot Jailbreak (after setup)"
    echo -e "  ${WHITE}7)${NC} Full Auto Setup (Steps 1-5)"
    echo ""
    echo -e "  ${PURPLE}── Tools ──${NC}"
    echo -e "  ${WHITE}8)${NC} Check Dependencies"
    echo -e "  ${WHITE}9)${NC} Download Required Files"
    echo -e "  ${WHITE}t)${NC} Download Binary Tools"
    echo -e "  ${WHITE}u)${NC} Set Device UUID"
    echo ""
    echo -e "  ${WHITE}q)${NC} Quit"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -n "Select option: "
}

main() {
    while true; do
        show_main_menu
        read -r choice

        case $choice in
            0)
                select_device
                ;;
            1)
                setup_sshrd
                ;;
            2)
                copy_files_to_device
                ;;
            3)
                copy_apticket
                ;;
            4)
                prepare_first_run
                ;;
            5)
                run_first_boot
                ;;
            6)
                run_normal_boot
                ;;
            7)
                run_full_auto
                ;;
            8)
                check_dependencies
                ;;
            9)
                download_dependencies
                ;;
            t|T)
                download_binary_tools
                ;;
            u|U)
                get_uuid_from_device
                press_enter
                ;;
            q|Q)
                echo ""
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"
