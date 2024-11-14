#!/bin/bash

# Color definitions for terminal output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# ASCII Art Header
clear
echo -e "${GREEN}"
echo "###########################################################"
echo "#                    mc-tbox: Advanced Minecraft Server Setup  #"
echo "#                      With Playit & Tmate                 #"
echo "###########################################################"
echo -e "${RESET}"

# Log file setup
LOG_FILE="$HOME/mc-tbox-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Prompt user for input
echo -e "${CYAN}[INFO]${RESET} Gathering user input..."
read -p "Enter your email for receiving SSH credentials and notifications: " email
read -p "Enter your preferred SMTP server (gmail/yahoo/custom): " smtp_server
read -p "Enter Playit token (leave blank if you need help getting it): " playit_token
read -p "Enter PaperMC version (e.g., 1.19): " MINECRAFT_VERSION
read -p "Enter your preferred server RAM allocation (e.g., 2G): " ram_allocation

# Confirm information
function conf_info {
    clear
    echo -e "${CYAN}[INFO]${RESET} Information Confirmation"
    echo "SSH & Notification Info E-mail: $email"
    echo "SMTP Server: $smtp_server"
    echo "Playit Token: $playit_token"
    echo "PaperMC Version: $MINECRAFT_VERSION"
    echo "Server RAM Allocation: $ram_allocation"
    echo
    read -p "Is this information correct ([Y]/n): " inf_check
    case $inf_check in
        [Yy]*) ;;
        [Nn]*) conf_info ;;
        *) ;;
    esac
}

# Check and Install Dependencies
function install_dependencies {
    echo -e "${CYAN}[INFO]${RESET} Checking system dependencies..."
    if ! dpkg -s "tur-repo" &>/dev/null; then
        echo -e "${CYAN}[INFO]${RESET} Installing tur-repo..."
        apt install -y "tur-repo" || { echo -e "${RED}[ERROR]${RESET} Failed to install tur-repo"; exit 1; }
    fi
    pkgs=(openjdk-17 tmux playit tmate msmtp curl wget termux-tools jq)
    for pkg in "${pkgs[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            echo -e "${CYAN}[INFO]${RESET} Installing $pkg..."
            apt install -y "$pkg" || { echo -e "${RED}[ERROR]${RESET} Failed to install $pkg"; exit 1; }
        fi
    done
}

# System Compatibility Check
function check_system_compatibility {
    echo -e "${CYAN}[INFO]${RESET} Checking system resources..."
    RAM=$(free -m | awk '/^Mem:/{print $2}')
    CORES=$(nproc)
    echo -e "${CYAN}[INFO]${RESET} Available RAM: $RAM MB"
    echo -e "${CYAN}[INFO]${RESET} CPU Cores: $CORES"
    if [[ $RAM -lt 2048 ]]; then
        echo -e "${YELLOW}[WARNING]${RESET} Less than 2GB RAM may lead to performance issues."
    fi
}

# Setup Playit Tunnel
function configure_playit {
    echo -e "${CYAN}[INFO]${RESET} Configuring Playit..."
    if [[ -z "$playit_token" ]]; then
        read -p "Please provide your Playit token/claim code: " playit_token
    fi
    playit-cli claim url "$playit_token" || { echo -e "${RED}[ERROR]${RESET} Playit configuration failed"; exit 1; }
}

# Configure Email Notifications
function setup_email {
    echo -e "${CYAN}[INFO]${RESET} Setting up email notifications..."
    # Clear any existing msmtp configuration to avoid duplicates
    rm -f ~/.msmtprc

    case $smtp_server in
        "gmail")
            echo -e "${CYAN}[INFO]${RESET} Configuring Gmail SMTP..."
            read -p "Enter your Gmail user/email: " guser
            read -p "Enter Your Gmail password/app password: " gpass
            echo "
account default
host smtp.gmail.com
port 587
auth on
user $guser
password $gpass
tls on
tls_trust_file /data/data/com.termux/files/usr/etc/tls/cert.pem

account default : default
            " > ~/.msmtprc
            ;;
        "yahoo")
            echo -e "${CYAN}[INFO]${RESET} Configuring Yahoo SMTP..."
            read -p "Enter your Yahoo user/email: " yuser
            read -p "Enter Your Yahoo password/app password: " ypass
            echo "
account default
host smtp.mail.yahoo.com
port 587
auth on
user $yuser
password $ypass
tls on
tls_trust_file /data/data/com.termux/files/usr/etc/tls/cert.pem
            " > ~/.msmtprc
            ;;
        "custom")
            read -p "Enter your custom SMTP server address: " custom_smtp
            read -p "Enter your custom SMTP port: " custom_port
            read -p "Enter your custom SMTP username: " cuser
            read -p "Enter your custom SMTP password: " cpass
            echo "
account default
host $custom_smtp
port $custom_port
auth on
user $cuser
password $cpass
tls on
tls_trust_file /data/data/com.termux/files/usr/etc/tls/cert.pem

account default : default
            " > ~/.msmtprc
            ;;
        *)
            echo -e "${RED}[ERROR]${RESET} Unsupported SMTP server"; exit 1;
            ;;
    esac
    chmod 600 ~/.msmtprc
}

# Setup Minecraft Server with Tmux
function setup_minecraft_server {
    echo -e "${CYAN}[INFO]${RESET} Setting up Minecraft server..."
    SERVER_DIR="$HOME/mc-server"
    if [[ ! -d "$SERVER_DIR" ]]; then
        mkdir -p "$SERVER_DIR"
        PROJECT="paper"

        LATEST_BUILD=$(curl -s https://api.papermc.io/v2/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds | \
        jq -r '.builds | map(select(.channel == "default") | .build) | .[-1]')

        if [ "$LATEST_BUILD" != "null" ]; then
            JAR_NAME=${PROJECT}-${MINECRAFT_VERSION}-${LATEST_BUILD}.jar
            PAPERMC_URL="https://api.papermc.io/v2/projects/${PROJECT}/versions/${MINECRAFT_VERSION}/builds/${LATEST_BUILD}/downloads/${JAR_NAME}"

            # Download the latest Paper version
            curl -o "$SERVER_DIR/paper.jar" "$PAPERMC_URL" || { echo -e "${RED}[ERROR]${RESET} Failed to download PaperMC"; exit 1; }
        else
            echo -e "${RED}[ERROR]${RESET} No stable paper build for version $MINECRAFT_VERSION found"; exit 1
        fi
    fi
    tmux new -d -s minecraft "java -Xmx$ram_allocation -Xms$ram_allocation -jar $SERVER_DIR/paper.jar nogui" || { echo -e "${RED}[ERROR]${RESET} Failed to start Minecraft server"; exit 1; }
}

# Start Tmate and Send Credentials
function setup_tmate {
    echo -e "${CYAN}[INFO]${RESET} Setting up remote SSH access with Tmate..."
    # Specify a unique socket file for tmate session
    TMATE_SOCKET="/tmp/tmate_session.sock"
    tmux new -d -s tmate_session "tmate -S $TMATE_SOCKET new-session -d" || { echo -e "${RED}[ERROR]${RESET} Failed to start Tmate"; exit 1; }
    sleep 5
    # Retrieve Tmate session link and send it via email
    tmate -S $TMATE_SOCKET wait tmate-ready || { echo -e "${RED}[ERROR]${RESET} Failed to wait for tmate-ready"; exit 1; }
    Tmate_URL=$(tmate -S $TMATE_SOCKET display -p '#{web_url}')
    echo -e "${CYAN}[INFO]${RESET} Sending Tmate access link to $email..."
    echo "Minecraft server is ready. Access it remotely via: $Tmate_URL" | msmtp -a default "$email" || { echo -e "${RED}[ERROR]${RESET} Failed to send Tmate access email"; exit 1; }
}

# Run all functions
conf_info
install_dependencies
check_system_compatibility
configure_playit
setup_email
setup_minecraft_server
setup_tmate

echo -e "${CYAN}[INFO]${RESET} Setup complete! Your Minecraft server is now running."
