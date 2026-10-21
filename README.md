A beautiful, feature-rich MOTD installer for Debian and Fedora systems.

## Features
- 🖥️  Screen clearing on login
- 🎨 Fancy ASCII hostname display (using toilet)
- 💚 Green welcome banner
- 📊 Color-coded system monitoring
- 🌐 Network information
- 📦 Update tip shows `nala` when it is installed, `apt` otherwise (checked at every login)
- 📈 Monitoring tip shows `btop` when it is installed, `htop` otherwise (checked at every login)
- 🔤 Sets up a UTF-8 locale (en_US.UTF-8) when the machine has none, as on minimal Debian images; existing UTF-8 setups are left alone
- ⚡ Works on Debian and Fedora

## Installation

```bash
# Download and run
curl -sSL https://raw.githubusercontent.com/oaquique/motdinstaller/main/motd_installer.sh | sudo bash

# Or download, inspect, and run
wget https://raw.githubusercontent.com/oaquique/motdinstaller/main/motd_installer.sh
sudo bash motd_installer.sh
```

## Usage

```bash
# Install (default)
sudo bash motd_installer.sh

# Uninstall
sudo bash motd_installer.sh --uninstall

# Help
bash motd_installer.sh --help
```

Re-running the installer is safe: it replaces the previous MOTD and keeps the
original `/etc/pam.d/sshd` backup that `--uninstall` restores.

## Customization

The MOTD script is located at:

- Debian/Ubuntu: `/etc/update-motd.d/00-dynamic-motd`
- Fedora: `/etc/profile.d/00-dynamic-motd.sh`

Edit these files to customize colors, layout, or add additional information.
