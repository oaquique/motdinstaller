#!/bin/bash

# Dynamic MOTD Installer for Debian and Fedora
# Features: Clear screen, fancy hostname, green banner, color-coded system info
# Usage: sudo bash motd-installer.sh
# Version: 3.0

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
    echo -e "${WHITE}  Dynamic MOTD Installer v3.0             ${NC}"
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
        fedora|centos|rhel)
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
    rm -f /etc/profile.d/*motd*.sh 2>/dev/null || true
    rm -f /etc/update-motd.d/10-dynamic-motd 2>/dev/null || true
    rm -f /etc/update-motd.d/00-dynamic-motd 2>/dev/null || true
    rm -f /etc/update-motd.d/*motd* 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Install dependencies
install_dependencies() {
    print_info "Installing dependencies (bc, toilet)..."
    
    case $PACKAGE_MANAGER in
        apt)
            apt update -qq 2>/dev/null || true
            apt install -y bc toilet > /dev/null 2>&1
            ;;
        dnf)
            dnf install -y bc toilet > /dev/null 2>&1
            ;;
        yum)
            yum install -y bc toilet > /dev/null 2>&1
            ;;
    esac
    
    # Verify toilet installation
    if ! command -v toilet &> /dev/null; then
        print_error "Failed to install toilet. Falling back to basic banner."
        USE_TOILET=false
    else
        USE_TOILET=true
        print_success "Dependencies installed (toilet available)"
    fi
}

# Create the enhanced MOTD script
create_motd_content() {
    if [ "$USE_TOILET" = true ]; then
        cat << 'MOTD_SCRIPT_EOF'
#!/bin/bash

# Enhanced Dynamic MOTD Script
# Clear screen completely and position cursor at top
printf '\033[2J\033[H'

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

create_banner() {
    local text="$1"
    local length=${#text}
    local border=$(printf '%*s' $((length + 4)) '' | tr ' ' '=')
    echo -e "${GREEN}${border}${NC}"
    echo -e "${GREEN}  $text  ${NC}"
    echo -e "${GREEN}${border}${NC}"
}

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

get_memory_usage() {
    local mem_info=$(free -m | awk 'NR==2{printf "%d %d %.0f", $3,$2,$3*100/$2}')
    local used=$(echo $mem_info | awk '{print $1}')
    local total=$(echo $mem_info | awk '{print $2}')
    local percent=$(echo $mem_info | awk '{print $3}')
    
    local color=$GREEN
    if [ "$percent" -gt 80 ]; then
        color=$RED
    elif [ "$percent" -gt 60 ]; then
        color=$YELLOW
    fi
    
    echo -e "  ${color}${used}MB/${total}MB (${percent}%)${NC}"
}

get_disk_usage() {
    local disk_info=$(df -h / | awk 'NR==2{print $3,$2,$5}')
    local used=$(echo $disk_info | awk '{print $1}')
    local total=$(echo $disk_info | awk '{print $2}')
    local percent=$(echo $disk_info | awk '{print $3}' | tr -d '%')
    
    local color=$GREEN
    if [ "$percent" -gt 90 ]; then
        color=$RED
    elif [ "$percent" -gt 75 ]; then
        color=$YELLOW
    fi
    
    echo -e "  ${color}${used}/${total} (${percent}%)${NC}"
}

get_load_color() {
    local load=$(cat /proc/loadavg | awk '{print $1}')
    local cpu_count=$(nproc)
    local load_percent=$(echo "scale=0; $load * 100 / $cpu_count" | bc -l 2>/dev/null || echo "0")
    
    if [ "$load_percent" -gt 80 ]; then
        echo -e "${RED}"
    elif [ "$load_percent" -gt 60 ]; then
        echo -e "${YELLOW}"
    else
        echo -e "${GREEN}"
    fi
}

get_network_info() {
    local ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    if [ -n "$ip" ]; then
        echo -e "  ${CYAN}$ip${NC}"
    else
        echo -e "  ${RED}No connection${NC}"
    fi
}

# Main MOTD display
echo
toilet -f smblock -F metal "$(hostname)"
echo
create_banner "Welcome to $(hostname)"
echo

echo -e "${WHITE}System Information:${NC}"
echo -e "  OS: ${CYAN}$(get_os_info)${NC}"
echo -e "  Kernel: ${CYAN}$(uname -r)${NC}"
echo -e "  Uptime: ${CYAN}$(uptime -p)${NC}"
echo -e "  Load: $(get_load_color)$(cat /proc/loadavg | awk '{print $1, $2, $3}')${NC}"
echo

echo -e "${WHITE}Resources:${NC}"
echo -e "  Memory:$(get_memory_usage)"
echo -e "  Disk (Root):$(get_disk_usage)"
echo

echo -e "${WHITE}Network:${NC}"
echo -e "  IP Address:$(get_network_info)"
echo

echo -e "${PURPLE}System Time: ${CYAN}$(date)${NC}"
echo
MOTD_SCRIPT_EOF
    else
        # Fallback version without toilet
        cat << 'MOTD_FALLBACK_EOF'
#!/bin/bash

# Dynamic MOTD Script (without toilet)
printf '\033[2J\033[H'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Welcome to $(hostname)${NC}"
echo -e "${GREEN}================================${NC}"
echo

echo -e "${WHITE}System Information:${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "  OS: ${CYAN}$PRETTY_NAME${NC}"
else
    echo -e "  OS: ${CYAN}$(uname -s)${NC}"
fi
echo -e "  Kernel: ${CYAN}$(uname -r)${NC}"
echo -e "  Uptime: ${CYAN}$(uptime -p)${NC}"
echo -e "  Load: ${GREEN}$(cat /proc/loadavg | awk '{print $1, $2, $3}')${NC}"
echo

echo -e "${WHITE}Resources:${NC}"
echo -e "  Memory: ${GREEN}$(free -h | awk 'NR==2{printf "%s/%s", $3,$2}')${NC}"
echo -e "  Disk: ${GREEN}$(df -h / | awk 'NR==2{printf "%s/%s", $3,$2}')${NC}"
echo

echo -e "${WHITE}Network:${NC}"
local_ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
if [ -n "$local_ip" ]; then
    echo -e "  IP: ${CYAN}$local_ip${NC}"
else
    echo -e "  IP: ${RED}No connection${NC}"
fi
echo

echo -e "${PURPLE}Time: ${CYAN}$(date)${NC}"
echo
MOTD_FALLBACK_EOF
    fi
}

# Install using update-motd.d method
install_update_motd_method() {
    print_info "Installing using update-motd.d method..."
    
    # Create the script as 00-dynamic-motd to run first
    create_motd_content > /etc/update-motd.d/00-dynamic-motd
    chmod +x /etc/update-motd.d/00-dynamic-motd
    
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
        cp /etc/pam.d/sshd /etc/pam.d/sshd.backup 2>/dev/null || true
        sed -i '/pam_motd/d' /etc/pam.d/sshd 2>/dev/null || true
        echo "session optional pam_exec.so /usr/bin/update-motd" >> /etc/pam.d/sshd
        echo "session optional pam_motd.so motd=/run/motd.dynamic noupdate" >> /etc/pam.d/sshd
    fi
    
    # Test the script
    if /etc/update-motd.d/00-dynamic-motd > /dev/null 2>&1; then
        print_success "update-motd.d method installed successfully"
        return 0
    else
        print_error "update-motd.d method failed"
        return 1
    fi
}

# Fallback to profile.d method
install_profile_method() {
    print_info "Using profile.d method..."
    
    # Create profile.d script with SSH detection
    cat > /etc/profile.d/00-dynamic-motd.sh << 'PROFILE_SCRIPT_EOF'
#!/bin/bash

# Only show for SSH interactive sessions
if [[ $- == *i* ]] && [[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
    
printf '\033[2J\033[H'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo
if command -v toilet &> /dev/null; then
    toilet -f smblock -F metal "$(hostname)"
    echo
fi

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Welcome to $(hostname)${NC}"
echo -e "${GREEN}================================${NC}"
echo

echo -e "${WHITE}System Information:${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "  OS: ${CYAN}$PRETTY_NAME${NC}"
else
    echo -e "  OS: ${CYAN}$(uname -s)${NC}"
fi
echo -e "  Kernel: ${CYAN}$(uname -r)${NC}"
echo -e "  Uptime: ${CYAN}$(uptime -p)${NC}"
echo -e "  Load: ${GREEN}$(cat /proc/loadavg | awk '{print $1, $2, $3}')${NC}"
echo

echo -e "${WHITE}Resources:${NC}"
echo -e "  Memory: ${GREEN}$(free -h | awk 'NR==2{printf "%s/%s", $3,$2}')${NC}"
echo -e "  Disk: ${GREEN}$(df -h / | awk 'NR==2{printf "%s/%s", $3,$2}')${NC}"
echo

echo -e "${WHITE}Network:${NC}"
local_ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
if [ -n "$local_ip" ]; then
    echo -e "  IP: ${CYAN}$local_ip${NC}"
else
    echo -e "  IP: ${RED}No connection${NC}"
fi
echo

echo -e "${PURPLE}Time: ${CYAN}$(date)${NC}"
echo

fi
PROFILE_SCRIPT_EOF

    chmod +x /etc/profile.d/00-dynamic-motd.sh
    
    # Disable default MOTD
    if [ -f /etc/motd ]; then
        mv /etc/motd /etc/motd.backup 2>/dev/null || true
        print_info "Disabled default MOTD (backed up to /etc/motd.backup)"
    fi
    
    # Test the script
    if SSH_CONNECTION="test" bash /etc/profile.d/00-dynamic-motd.sh > /dev/null 2>&1; then
        print_success "profile.d method installed successfully"
        return 0
    else
        print_error "profile.d method failed"
        return 1
    fi
}

# Test the installation
test_installation() {
    print_info "Testing installation..."
    
    if [ -f /etc/update-motd.d/00-dynamic-motd ]; then
        echo -e "\n${CYAN}--- MOTD Preview ---${NC}"
        /etc/update-motd.d/00-dynamic-motd 2>/dev/null || true
        echo -e "${CYAN}--- End Preview ---${NC}\n"
        MOTD_FILE="/etc/update-motd.d/00-dynamic-motd"
    elif [ -f /etc/profile.d/00-dynamic-motd.sh ]; then
        echo -e "\n${CYAN}--- MOTD Preview ---${NC}"
        SSH_CONNECTION="test" bash /etc/profile.d/00-dynamic-motd.sh 2>/dev/null || true
        echo -e "${CYAN}--- End Preview ---${NC}\n"
        MOTD_FILE="/etc/profile.d/00-dynamic-motd.sh"
    fi
    
    print_success "Installation completed successfully!"
    echo -e "${CYAN}ℹ  MOTD file location: $MOTD_FILE${NC}"
}

# Uninstall function
uninstall() {
    print_header
    print_info "Uninstalling Dynamic MOTD..."
    
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
    
    print_success "Dynamic MOTD uninstalled successfully"
}

# Main installation function
install() {
    print_header
    
    check_root
    detect_os
    cleanup
    install_dependencies
    
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
    
    # Restart SSH service if possible
    if command -v systemctl &> /dev/null; then
        systemctl restart sshd 2>/dev/null || true
    fi
    
    test_installation
    
    echo -e "${GREEN}🎉 Installation complete!${NC}"
    if [ "$USE_TOILET" = true ]; then
        echo -e "${CYAN}ℹ  Features: Screen clear, fancy hostname (toilet), green banner, color-coded stats${NC}"
    else
        echo -e "${CYAN}ℹ  Features: Screen clear, green banner, color-coded stats${NC}"
    fi
    echo -e "${CYAN}ℹ  Log out and SSH back in to see your new MOTD${NC}"
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
        echo "Dynamic MOTD with enhanced features:"
        echo "  • Screen clearing on login"
        echo "  • Fancy ASCII hostname (using toilet)"
        echo "  • Green welcome banner"
        echo "  • Color-coded system monitoring"
        echo "  • Works on Debian and Fedora"
        echo
        echo "Options:"
        echo "  --install, -i    Install dynamic MOTD (default)"
        echo "  --uninstall, -u  Uninstall dynamic MOTD"
        echo "  --help, -h       Show this help message"
        echo
        ;;
    *)
        install
        ;;
esac
