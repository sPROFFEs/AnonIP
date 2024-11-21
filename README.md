# AnonIP 🌐

[![Bash Script](https://img.shields.io/badge/script-bash-green.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Debian/Ubuntu](https://img.shields.io/badge/platform-debian%2Fubuntu-orange.svg)](https://www.debian.org/)

A modular bash script for network anonymization that allows you to:
- 🔄 Automatically change your MAC address
- 🌍 Rotate your IP address
- 🧅 Route your traffic through TOR network
- ⏱️ Set custom intervals for changes
- 🔒 Enhanced privacy and security features

## Features

- **MAC Address Randomization**: Generate and apply random MAC addresses
- **IP Address Rotation**: Request new IP addresses via DHCP
- **TOR Integration**: Route traffic through TOR network
- **Modular Design**: Use any combination of features
- **Automatic Mode**: Set and forget with customizable intervals
- **Clean Shutdown**: Proper cleanup of all changes
- **Status Monitoring**: Track your current IP and changes

## Requirements

### System Requirements
- Debian/Ubuntu-based Linux distribution
- Root privileges (sudo)
- Active network interface (WiFi or Ethernet)
- Internet connection

### Dependencies
```bash
# Install all required packages
sudo apt update && sudo apt install -y \
    tor \
    curl \
    dhclient \
    iptables \
    net-tools \
    iproute2
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/AnonIP.git
cd AnonIP
```

2. Make the script executable:
```bash
chmod +x AnonIP.sh
```

3. Verify dependencies:
```bash
./AnonIP.sh --help
```

## Usage

### Basic Usage

```bash
# Start with all features (MAC, IP, and TOR)
sudo ./AnonIP.sh -m -p -T -i wlan0

# Only use TOR
sudo ./AnonIP.sh -T

# Change MAC and IP every hour
sudo ./AnonIP.sh -m -p -t 3600

# Change only MAC address
sudo ./AnonIP.sh -m -i wlan0
```

### Available Options

| Option | Long Option | Description |
|--------|------------|-------------|
| `-h` | `--help` | Show help message |
| `-i` | `--interface` | Specify network interface (e.g., wlan0) |
| `-t` | `--time` | Set interval in seconds between changes |
| `-m` | `--mac` | Enable MAC address randomization |
| `-p` | `--ip` | Enable IP address rotation |
| `-T` | `--tor` | Enable TOR routing |
| `-s` | `--switch-tor` | Switch TOR exit node |
| `-x` | `--stop` | Stop all services and restore configuration |

### Examples

1. **Maximum Privacy Setup**:
```bash
sudo ./AnonIP.sh -i wlan0 -m -p -T -t 600
```
This will:
- Use interface wlan0
- Change MAC address every 10 minutes
- Rotate IP address every 10 minutes
- Route traffic through TOR
- Switch TOR exit node every 10 minutes

2. **Quick TOR Switch**:
```bash
sudo ./AnonIP.sh -s
```
This will only switch the TOR exit node.

3. **Stop All Services**:
```bash
sudo ./AnonIP.sh -x
```
This will stop all anonymization services and restore original network configuration.

## Security Considerations

⚠️ **Important Security Notes**:

1. This script modifies system network configuration. Use with caution.
2. TOR routing may significantly reduce your internet speed.
3. Some services might not work properly when routing through TOR.
4. MAC address changes might not work on all network interfaces.
5. Script must run as root, verify the code before running.

## How It Works

1. **MAC Randomization**:
   - Generates random MAC addresses following IEEE standards
   - Applies changes using `ip link` commands

2. **IP Rotation**:
   - Releases current DHCP lease
   - Requests new IP address from DHCP server

3. **TOR Integration**:
   - Configures local TOR service
   - Sets up transparent proxy
   - Modifies DNS resolution
   - Configures iptables for routing

## Troubleshooting

### Common Issues

1. **"Must be run as root" error**:
   ```bash
   sudo ./AnonIP.sh [options]
   ```

2. **Interface not found**:
   - Check available interfaces:
   ```bash
   ip link show
   ```

3. **TOR service fails to start**:
   - Check TOR service status:
   ```bash
   systemctl status tor
   ```

4. **No internet after running script**:
   - Stop all services and restore configuration:
   ```bash
   sudo ./AnonIP.sh -x
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This tool is provided for educational and research purposes only. Users are responsible for complying with all applicable laws and regulations in their jurisdiction.

## Acknowledgments

- TOR Project for their amazing privacy tool
- Inspiration from various privacy-focused projects
- Community feedback and contributions

---

Made with ❤️ for the privacy-conscious community
