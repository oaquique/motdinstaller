A beautiful, feature-rich MOTD installer for Debian and Fedora systems.

## Features
- 🖥️  Screen clearing on login
- 🎨 Fancy ASCII hostname display (using toilet)
- 💚 Green welcome banner
- 📊 Color-coded system monitoring
- 🌐 Network information
- ⚡ Works on Debian and Fedora

## Installation

```bash
# Download and run
curl -sSL https://raw.githubusercontent.com/YOUR-USERNAME/dynamic-motd-installer/main/motd-installer.sh | sudo bash

# Or download, inspect, and run
wget https://raw.githubusercontent.com/YOUR-USERNAME/dynamic-motd-installer/main/motd-installer.sh
sudo bash motd-installer.sh

## USAGE

# Install (default)
sudo bash motd_installer.sh

# Uninstall
sudo bash motd_installer.sh --uninstall

# Help
bash motd_installer.sh --help

## CUSTOMIZATION
The MOTD script is located at:

Debian/Ubuntu: /etc/update-motd.d/00-dynamic-motd
Fedora: /etc/profile.d/00-dynamic-motd.sh

Edit these files to customize colors, layout, or add additional information.
