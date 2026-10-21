#!/bin/bash

# Universal Compact MOTD Installer for Debian and Fedora
# Features: Raspberry Pi style compact layout, clear screen, fancy hostname
# Usage: sudo bash motd_installer.sh
# Version: 4.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_header() {
    echo
    echo -e "${BLUE}============================================${NC}"
    echo -e "${WHITE}  Compact Dynamic MOTD Installer v4.0     ${NC}"
    echo -e "${WHITE}  Debian & Fedora Edition                 ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/fedora-release ]; then
        OS="fedora"
    else
        print_error "Unsupported operating system"
        exit 1
    fi
    
    case $OS in
        debian|ubuntu)
            PACKAGE_MANAGER="apt"
            ;;
        fedora|centos|rhel|rocky|alma)
            if command -v dnf &> /dev/null; then
                PACKAGE_MANAGER="dnf"
            else
                PACKAGE_MANAGER="yum"
            fi
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    print_success "Detected: $OS (using $PACKAGE_MANAGER)"
}

# Clean up any existing installations
cleanup() {
    print_info "Cleaning up previous installations..."
    
    # Remove any existing MOTD scripts
    rm -f /etc/profile.d/motd.sh 2>/dev/null || true
    rm -f /etc/profile.d/00-motd.sh 2>/dev/null || true
    rm -f /etc/profile.d/00-dynamic-motd.sh 2>/dev/null || true
    rm -f /etc/profile.d/*motd*.sh 2>/dev/null || true
    rm -f /etc/update-motd.d/00-dynamic-motd 2>/dev/null || true
    rm -f /etc/update-motd.d/10-dynamic-motd 2>/dev/null || true
    rm -f /etc/update-motd.d/*motd* 2>/dev/null || true
    
    # Remove conflicting default scripts
    rm -f /etc/update-motd.d/10-uname 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Install dependencies
install_dependencies() {
    print_info "Installing dependencies (bc, toilet, procps)..."

    # procps provides free and uptime, which minimal images may lack
    case $PACKAGE_MANAGER in
        apt)
            apt update -qq 2>/dev/null || true
            apt install -y bc toilet figlet procps > /dev/null 2>&1
            ;;
        dnf)
            dnf install -y bc toilet figlet procps-ng > /dev/null 2>&1
            ;;
        yum)
            yum install -y bc toilet figlet procps-ng > /dev/null 2>&1
            ;;
    esac
    
    # Verify installations
    if ! command -v toilet &> /dev/null; then
        print_error "Failed to install toilet. Will use ASCII fallback."
        USE_TOILET=false
    else
        USE_TOILET=true
    fi
    
    if ! command -v bc &> /dev/null; then
        print_error "Failed to install bc. Load calculation may be less accurate."
        USE_BC=false
    else
        USE_BC=true
    fi
    
    print_success "Dependencies installed (toilet: $USE_TOILET, bc: $USE_BC)"
}

# Make sure a UTF-8 locale exists. Minimal images (e.g. Debian LXC templates)
# ship only LANG=C, so the client's en_US.UTF-8 is dropped on SSH login and
# UTF-8 tools such as btop refuse to start. Existing UTF-8 setups are left alone.
ensure_utf8_locale() {
    print_info "Checking for a UTF-8 locale..."

    case $PACKAGE_MANAGER in
        apt)
            if locale -a 2>/dev/null | grep -viE '^(C|POSIX)(\.|$)' | grep -qiE 'utf-?8'; then
                print_success "UTF-8 locale already present"
            else
                apt install -y locales > /dev/null 2>&1
                sed -i -E 's/^#\s*(en_US\.UTF-8 UTF-8)/\1/' /etc/locale.gen 2>/dev/null || true
                grep -qE '^en_US\.UTF-8 UTF-8' /etc/locale.gen 2>/dev/null || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
                locale-gen > /dev/null 2>&1
                print_success "Generated en_US.UTF-8"
            fi
            # Set a UTF-8 default only when there is none (unset, C or POSIX)
            local current=$(grep -hE '^LANG=' /etc/default/locale 2>/dev/null | cut -d= -f2 | tr -d '"')
            case "$current" in
                ""|C|POSIX)
                    update-locale LANG=en_US.UTF-8 > /dev/null 2>&1 && print_success "Default locale set to en_US.UTF-8"
                    ;;
                *)
                    print_success "Default locale kept ($current)"
                    ;;
            esac
            ;;
        dnf|yum)
            if ! locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then
                $PACKAGE_MANAGER install -y glibc-langpack-en > /dev/null 2>&1 || true
            fi
            print_success "UTF-8 locale available"
            ;;
    esac
}

# Create the compact MOTD script
create_compact_motd() {
    local script_path="$1"
    
    cat > "$script_path" << 'COMPACT_MOTD_EOF'
#!/bin/bash

# Compact Dynamic MOTD Script - Complete Version
# Works for both update-motd.d and profile.d usage

# Only check for interactive shell if this is a profile.d script
if [[ "${BASH_SOURCE[0]}" == *"profile.d"* ]]; then
    # Profile.d method - check for interactive shell
    if [[ $- != *i* ]]; then
        return 0 2>/dev/null || exit 0
    fi
fi
    
printf '\033[2J\033[H'

# Color definitions - using default terminal color
RED='\033[0;31m'
DEFAULT='\033[0;39m'    # Default terminal foreground color
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'            # Reset to default

# Function to get OS information
get_os_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    elif [ -f /etc/debian_version ]; then
        echo "Debian $(cat /etc/debian_version)"
    elif [ -f /etc/fedora-release ]; then
        cat /etc/fedora-release
    elif [ -f /etc/redhat-release ]; then
        cat /etc/redhat-release
    else
        echo "$(uname -s) $(uname -r)"
    fi
}

# Function to calculate system load percentage
get_load_percent() {
    local load=$(cat /proc/loadavg | awk '{print $1}')
    local cpu_count=$(nproc)
    
    if [ "$cpu_count" -gt 0 ]; then
        if command -v bc &> /dev/null; then
            # Use bc for precise calculation
            echo "scale=0; $load * 100 / $cpu_count" | bc 2>/dev/null || echo "0"
        else
            # Fallback using awk
            echo "$load $cpu_count" | awk '{printf "%.0f", ($1 * 100) / $2}'
        fi
    else
        echo "0"
    fi
}

# Function to get memory usage percentage
get_memory_percent() {
    free | awk 'NR==2{printf "%.0f", $3*100/$2}'
}

# Function to get total memory
get_memory_total() {
    free -h | awk 'NR==2{print $2}'
}

# Function to get disk usage percentage
get_disk_percent() {
    df -h / | awk 'NR==2{print $5}' | tr -d '%'
}

# Function to get total disk space
get_disk_total() {
    df -h / | awk 'NR==2{print $2}'
}

# Function to get compact uptime format
get_uptime_compact() {
    uptime -p | sed 's/up //' | sed 's/ days\?/d/g' | sed 's/ hours\?/h/g' | sed 's/ minutes\?/m/g'
}

# Function to get primary IP address
get_ip() {
    ip route get 1 2>/dev/null | awk '{print $7}' | head -1
}

# Function to get last login information (for Fedora systems)
get_last_login() {
    # Get the most recent previous login (not current session)
    local previous_login=$(last -3 $USER 2>/dev/null | grep -v "still logged in" | head -1)
    
    if [ -n "$previous_login" ]; then
        echo "$previous_login" | awk '{
            if (NF >= 6 && $3 != "") {
                printf "%s %s %s %s from %s", $4, $5, $6, $7, $3
            }
        }'
    fi
}

# Function to check additional mount points
check_additional_mounts() {
    for mount_point in "/home" "/var" "/storage" "/opt" "/tmp" "/boot"; do
        if mount | grep -q " $mount_point " 2>/dev/null; then
            local disk_info=$(df -h "$mount_point" 2>/dev/null | awk 'NR==2{printf "%d %s", $5, $2}' | tr -d '%')
            if [ -n "$disk_info" ]; then
                local percent=$(echo $disk_info | awk '{print $1}')
                local total=$(echo $disk_info | awk '{print $2}')
                local mount_name=$(echo "$mount_point" | sed 's|/||')
                printf "${DEFAULT}%-10s     %2d%% of %s${NC}\n" \
                    "${mount_name}:" "$percent" "$total"
            fi
        fi
    done
}

# Get all system information
OS_INFO=$(get_os_info)
KERNEL=$(uname -r)
HOSTNAME=$(hostname)
LOAD_PERCENT=$(get_load_percent)
UPTIME=$(get_uptime_compact)
MEMORY_PERCENT=$(get_memory_percent)
MEMORY_TOTAL=$(get_memory_total)
DISK_PERCENT=$(get_disk_percent)
DISK_TOTAL=$(get_disk_total)
IP_ADDRESS=$(get_ip)

# Get last login only for Fedora systems (Debian handles it natively)
if command -v dnf &> /dev/null || (command -v yum &> /dev/null && ! command -v apt &> /dev/null); then
    LAST_LOGIN=$(get_last_login)
fi

# Display the compact MOTD
echo

# Hostname display using toilet (with fallback)
if command -v toilet &> /dev/null; then
    toilet -f smblock -F metal "$(hostname)"
else
    # ASCII art fallback
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                            ${HOSTNAME}                            ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
fi

# Welcome line with mixed colors (default text, red OS info)
echo -e "${DEFAULT}Welcome to ${RED}${OS_INFO}${DEFAULT} with Linux ${RED}${KERNEL}${NC}"

# Check for unsupported message (like Raspberry Pi)
if echo "$OS_INFO" | grep -qi "bookworm\|unstable\|testing"; then
    echo -e "${RED}No end-user support: unsupported ($(echo $OS_INFO | grep -oiE 'bookworm|unstable|testing')) userspace!${NC}"
fi

# Empty line as shown in screenshot
echo

# Full system info line (uname -srnvm)
echo -e "${DEFAULT}$(uname -srnvm)${NC}"

# Compact system information in horizontal layout
printf "${DEFAULT}System load:   %2d%%%-12s Up time:       %s${NC}\n" \
    "$LOAD_PERCENT" "" "$UPTIME"

printf "${DEFAULT}Memory usage:  %2d%% of %-8s IP:            %s${NC}\n" \
    "$MEMORY_PERCENT" "$MEMORY_TOTAL" "${IP_ADDRESS:-No connection}"

printf "${DEFAULT}Usage of /:    %2d%% of %s${NC}\n" \
    "$DISK_PERCENT" "$DISK_TOTAL"

# Check for additional mount points and display them
check_additional_mounts

# Empty line before menu
echo

# Prefer btop when installed; checked at every login, so it follows the machine
if command -v btop &> /dev/null; then
    MONITOR_CMD="btop"
else
    MONITOR_CMD="htop"
fi

# Menu/configuration line (red brackets, white commands)
if command -v apt &> /dev/null; then
    # Prefer nala when installed; checked at every login, so it follows the machine
    if command -v nala &> /dev/null; then
        UPDATE_CMD="sudo nala upgrade"
    else
        UPDATE_CMD="sudo apt update && sudo apt upgrade"
    fi
    echo -e "${RED}[ System management: ${WHITE}${MONITOR_CMD}${RED} | Updates: ${WHITE}${UPDATE_CMD}${RED} | Logs: ${WHITE}journalctl -f${RED} ]${NC}"
    # Raspberry Pi: add a raspi-config line, or how to install it when missing
    if [[ -f /proc/device-tree/model ]] && grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; then
        if command -v raspi-config &> /dev/null; then
            echo -e "${RED}[ Config: ${WHITE}sudo raspi-config${RED} ]${NC}"
        else
            echo -e "${RED}[ Menu-driven system configuration (beta): ${WHITE}${UPDATE_CMD/upgrade/install raspi-config}${RED} ]${NC}"
        fi
    fi
elif command -v dnf &> /dev/null; then
    # Fedora
    echo -e "${RED}[ System management: ${WHITE}sudo dnf install cockpit && sudo systemctl enable --now cockpit.socket${RED} ]${NC}"
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    echo -e "${RED}[ System management: ${WHITE}sudo yum install cockpit && sudo systemctl enable --now cockpit.socket${RED} ]${NC}"
else
    # Generic
    echo -e "${RED}[ System monitoring: ${WHITE}${MONITOR_CMD}${RED} | Logs: ${WHITE}journalctl -f${RED} | Config: ${WHITE}sudo nano /etc/profile.d/00-dynamic-motd.sh${RED} ]${NC}"
fi

echo

COMPACT_MOTD_EOF
    
    chmod +x "$script_path"
}

# Install using update-motd.d method (Debian/Ubuntu)
install_update_motd_method() {
    print_info "Installing using update-motd.d method..."
    
    # Create the script as 00-dynamic-motd to run first
    create_compact_motd "/etc/update-motd.d/00-dynamic-motd"
    
    # Disable default MOTD
    if [ -f /etc/motd ]; then
        mv /etc/motd /etc/motd.backup 2>/dev/null || true
        print_info "Disabled default MOTD (backed up to /etc/motd.backup)"
    fi
    
    # Create update-motd command if it doesn't exist
    if ! command -v update-motd &> /dev/null; then
        cat > /usr/bin/update-motd << 'UPDATE_MOTD_EOF'
#!/bin/bash
if [ -d /etc/update-motd.d ]; then
    run-parts /etc/update-motd.d > /run/motd.dynamic 2>/dev/null
    chmod 644 /run/motd.dynamic 2>/dev/null || true
fi
UPDATE_MOTD_EOF
        chmod +x /usr/bin/update-motd
    fi
    
    # Configure PAM for SSH
    if [ -f /etc/pam.d/sshd ]; then
        # Keep the first backup only, so a re-run never overwrites the original
        [ -f /etc/pam.d/sshd.backup ] || cp /etc/pam.d/sshd /etc/pam.d/sshd.backup 2>/dev/null || true
        # Drop pam_motd lines and any update-motd hook from a previous run
        sed -i '/pam_motd/d; /pam_exec\.so \/usr\/bin\/update-motd/d' /etc/pam.d/sshd 2>/dev/null || true
        echo "session optional pam_exec.so /usr/bin/update-motd" >> /etc/pam.d/sshd
        echo "session optional pam_motd.so motd=/run/motd.dynamic noupdate" >> /etc/pam.d/sshd
    fi
    
    # Test the script
    if /etc/update-motd.d/00-dynamic-motd > /dev/null 2>&1; then
        print_success "update-motd.d method installed successfully"
        MOTD_FILE="/etc/update-motd.d/00-dynamic-motd"
        return 0
    else
        print_error "update-motd.d method failed"
        return 1
    fi
}

# Install using profile.d method (Fedora/RHEL)
install_profile_method() {
    print_info "Installing using profile.d method..."
    
    # Create the compact MOTD script for profile.d
    create_compact_motd "/etc/profile.d/00-dynamic-motd.sh"
    
    # Disable default MOTD
    if [ -f /etc/motd ]; then
        mv /etc/motd /etc/motd.backup 2>/dev/null || true
        print_info "Disabled default MOTD (backed up to /etc/motd.backup)"
    fi
    
    # Test the script
    if SSH_CONNECTION="test" bash /etc/profile.d/00-dynamic-motd.sh > /dev/null 2>&1; then
        print_success "profile.d method installed successfully"
        MOTD_FILE="/etc/profile.d/00-dynamic-motd.sh"
        return 0
    else
        print_error "profile.d method failed"
        return 1
    fi
}

# Test the installation
test_installation() {
    print_info "Testing installation..."
    
    if [ -n "$MOTD_FILE" ] && [ -f "$MOTD_FILE" ]; then
        echo -e "\n${CYAN}--- Compact MOTD Preview ---${NC}"
        if [[ "$MOTD_FILE" == *"profile.d"* ]]; then
            SSH_CONNECTION="test" bash "$MOTD_FILE" 2>/dev/null || true
        else
            "$MOTD_FILE" 2>/dev/null || true
        fi
        echo -e "${CYAN}--- End Preview ---${NC}\n"
    fi
    
    print_success "Installation completed successfully!"
    echo -e "${CYAN}ℹ  MOTD file location: $MOTD_FILE${NC}"
}

# Uninstall function
uninstall() {
    print_header
    print_info "Uninstalling Compact Dynamic MOTD..."
    
    # Remove all MOTD files
    rm -f /etc/update-motd.d/00-dynamic-motd 2>/dev/null || true
    rm -f /etc/update-motd.d/10-dynamic-motd 2>/dev/null || true
    rm -f /etc/profile.d/00-dynamic-motd.sh 2>/dev/null || true
    rm -f /etc/profile.d/motd.sh 2>/dev/null || true
    rm -f /usr/bin/update-motd 2>/dev/null || true
    rm -f /run/motd.dynamic 2>/dev/null || true
    
    # Restore default MOTD
    if [ -f /etc/motd.backup ]; then
        mv /etc/motd.backup /etc/motd
        print_success "Restored original MOTD"
    fi
    
    # Restore PAM configuration
    if [ -f /etc/pam.d/sshd.backup ]; then
        mv /etc/pam.d/sshd.backup /etc/pam.d/sshd
        print_success "Restored original PAM configuration"
    fi
    
    print_success "Compact Dynamic MOTD uninstalled successfully"
}

# Main installation function
install() {
    print_header
    
    check_root
    detect_os
    cleanup
    install_dependencies
    ensure_utf8_locale

    # Choose installation method based on OS
    case $OS in
        debian|ubuntu)
            # Try update-motd.d method first, fallback to profile.d
            if [ -d /etc/update-motd.d ]; then
                if install_update_motd_method; then
                    print_success "Installed using update-motd.d method"
                else
                    print_info "update-motd.d failed, trying profile.d method..."
                    install_profile_method
                fi
            else
                install_profile_method
            fi
            ;;
        fedora|centos|rhel|rocky|alma)
            # Use profile.d method for Fedora/RHEL family
            install_profile_method
            ;;
        *)
            print_error "Unsupported OS for installation"
            exit 1
            ;;
    esac
    
    # Restart SSH service if possible
    if command -v systemctl &> /dev/null; then
        systemctl restart sshd 2>/dev/null || true
    fi
    
    test_installation
    
    echo -e "${GREEN}🎉 Compact MOTD Installation Complete!${NC}"
    echo -e "${CYAN}ℹ  Features:${NC}"
    echo -e "   • ${GREEN}Screen clearing on login${NC}"
    echo -e "   • ${GREEN}Fancy ASCII hostname (toilet)${NC}"
    echo -e "   • ${GREEN}Raspberry Pi style compact layout${NC}"
    echo -e "   • ${GREEN}Horizontal system information${NC}"
    echo -e "   • ${GREEN}Default terminal color scheme${NC}"
    echo -e "   • ${GREEN}Additional mount point detection${NC}"
    echo -e "   • ${GREEN}Smart OS detection (Raspberry Pi vs regular systems)${NC}"
    echo -e "   • ${GREEN}Last login info for Fedora (native for Debian)${NC}"
    echo
    echo -e "${CYAN}ℹ  Log out and SSH/login back in to see your new compact MOTD${NC}"
    echo -e "${CYAN}ℹ  To customize: sudo nano $MOTD_FILE${NC}"
    echo -e "${CYAN}ℹ  To uninstall: sudo bash $0 --uninstall${NC}"
    echo
}

# Handle command line arguments
case "${1:-}" in
    --uninstall|-u)
        uninstall
        ;;
    --help|-h)
        print_header
        echo "Usage: $0 [OPTION]"
        echo
        echo "Compact Dynamic MOTD with Raspberry Pi style layout:"
        echo "  • Screen clearing on login"
        echo "  • Fancy ASCII hostname (using toilet)"
        echo "  • Horizontal compact information display"
        echo "  • Mixed green/red color scheme"
        echo "  • Additional mount point detection"
        echo "  • Works on Debian and Fedora"
        echo
        echo "Options:"
        echo "  --install, -i    Install compact dynamic MOTD (default)"
        echo "  --uninstall, -u  Uninstall compact dynamic MOTD"
        echo "  --help, -h       Show this help message"
        echo
        echo "Examples:"
        echo "  sudo $0                    # Install compact MOTD"
        echo "  sudo $0 --uninstall       # Remove compact MOTD"
        echo
        ;;
    *)
        install
        ;;
esac