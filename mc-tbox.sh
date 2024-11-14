#!/bin/bash

# ASCII Art Header
clear
echo -e "\033[1;32m"
echo "###########################################################"
echo "#                    mc-tbox: Advanced Minecraft Server Setup  #"
echo "#                      With Playit & Tmate                 #"
echo "###########################################################"
echo -e "\033[0m"

# Log file setup
LOG_FILE="$HOME/mc-tbox-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Prompt user for input
echo "[INFO] Gathering user input..."
read -p "Enter your email for receiving SSH credentials and notifications: " email
read -p "Enter your preferred SMTP server (gmail/yahoo/custom): " smtp_server
read -p "Enter Playit token (leave blank if you need help getting it): " playit_token
read -p "Enter your preferred server RAM allocation (e.g., 2G): " ram_allocation
# Confirm information

 
function conf_info {
    clear
    echo "Information Confirmation"
    echo "SSH & Notification Info E-mail: $email"
    echo "SMTP Server: $smtp_server"
    echo "Playit Token: $playit_token"
    echo "Server RAM Allocation: $ram_allocation"
    echo
    read -p "Is this information correct ([Y]/n): " inf_check
    case $inf_check in
        [Yy]*) 
            true
            ;;
        [Nn]*) 
            echo "[INFO] Re-enter user input..."
            read -p "Enter your email for receiving SSH credentials and notifications: " email
            read -p "Enter your preferred SMTP server (gmail/yahoo/custom): " smtp_server
            read -p "Enter Playit token (leave blank if you need help getting it): " playit_token
            read -p "Enter your preferred server RAM allocation (e.g., 2G): " ram_allocation
            # Recursive call to conf_info to confirm the newly entered info
            conf_info
            ;;
        *) 
            true
            ;;
    esac
}

# Check and Install Dependencies
function install_dependencies {
    echo "[INFO] Checking system dependencies..."
    if ! dpkg -s "tur-repo" &>/dev/null; then
            echo "[INFO] Installing tur-repo..."
            apt install -y "tur-repo" || { echo "[ERROR] Failed to install tur-repo"; exit 1; }
    fi
    pkgs=(openjdk-17 tmux playit tmate msmtp curl wget termux-tools)
    for pkg in "${pkgs[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            echo "[INFO] Installing $pkg..."
            apt install -y "$pkg" || { echo "[ERROR] Failed to install $pkg"; exit 1; }
        fi
    done
}

# System Compatibility Check
function check_system_compatibility {
    echo "[INFO] Checking system resources..."
    RAM=$(free -m | awk '/^Mem:/{print $2}')
    CORES=$(nproc)
    echo "[INFO] Available RAM: $RAM MB"
    echo "[INFO] CPU Cores: $CORES"
    if [[ $RAM -lt 2048 ]]; then
        echo "[WARNING] Less than 2GB RAM may lead to performance issues."
    fi
}

# Setup Playit Tunnel
function configure_playit {
    echo "[INFO] Configuring Playit..."
    if [[ -z "$playit_token" ]]; then
        read -p "Please provide your Playit token/claim code: " playit_token
    fi
    playit-cli claim url "$playit_token" || { echo "[ERROR] Playit configuration failed"; exit 1; }
}

# Configure Email Notifications
function setup_email {
    echo "[INFO] Setting up email notifications..."
    case $smtp_server in
        "gmail")
            echo "[INFO] Configuring Gmail SMTP..."
            echo "mail.smtp.host=smtp.gmail.com" > ~/.msmtprc
            echo "mail.smtp.port=587" >> ~/.msmtprc
            echo "mail.smtp.auth=on" >> ~/.msmtprc
            echo "mail.smtp.starttls=on" >> ~/.msmtprc
            ;;
        "yahoo")
            echo "[INFO] Configuring Yahoo SMTP..."
            echo "mail.smtp.host=smtp.mail.yahoo.com" > ~/.msmtprc
            echo "mail.smtp.port=587" >> ~/.msmtprc
            echo "mail.smtp.auth=on" >> ~/.msmtprc
            echo "mail.smtp.starttls=on" >> ~/.msmtprc
            ;;
        "custom")
            read -p "Enter your custom SMTP server address: " custom_smtp
            echo "mail.smtp.host=$custom_smtp" > ~/.msmtprc
            echo "mail.smtp.port=587" >> ~/.msmtprc
            echo "mail.smtp.auth=on" >> ~/.msmtprc
            echo "mail.smtp.starttls=on" >> ~/.msmtprc
            ;;
        *)
            echo "[ERROR] Unsupported SMTP server"; exit 1;
            ;;
    esac
}

# Setup Minecraft Server with Tmux
function setup_minecraft_server {
    echo "[INFO] Setting up Minecraft server..."
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
            curl -o paper.jar $PAPERMC_URL
            echo "Download completed"
         else
          echo "[ERROR] No stable paper build for version $MINECRAFT_VERSION found :(" 
          exit 1
        fi 
    fi
    tmux new -d -s minecraft "java -Xmx$ram_allocation -Xms$ram_allocation -jar $SERVER_DIR/paper.jar nogui" || { echo "[ERROR] Failed to start Minecraft server"; exit 1; }
}

# Start Tmate and Send Credentials
function setup_tmate {
    echo "[INFO] Setting up remote SSH access with Tmate..."
    tmux new -d -s tmate_session "tmate -F" || { echo "[ERROR] Failed to start Tmate"; exit 1; }
    sleep 5
    tmate show-messages | grep "web session" | mail -s "Minecraft Server Access" "$email" || { echo "[ERROR] Failed to send Tmate access email"; exit 1; }
}

# Monitor Server Health
function monitor_health {
    echo "[INFO] Starting server health monitoring..."
    while true; do
        CPU=$(top -bn1 | grep load | awk '{printf "%.2f", $(NF-2)}')
        MEM=$(free -m | awk '/Mem:/ {printf "%3.1f", $3/$2*100}')
        if [[ "$CPU" > 80.0 || "$MEM" > 90.0 ]]; then
            echo "[ALERT] High CPU or Memory usage!" | mail -s "Minecraft Server Health Alert" "$email" || { echo "[ERROR] Failed to send health alert"; exit 1; }
        fi
        sleep 60
    done
}

# Log Rotation and Backup
function setup_logging_backup {
    LOG_DIR="$HOME/mc-logs"
    BACKUP_DIR="$HOME/mc-backups"
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir "$LOG_DIR"
    fi
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir "$BACKUP_DIR"
    fi
    echo "[INFO] Log rotation and backup configured."
}

# Backup the Minecraft Server Data
function backup_minecraft_server {
    echo "[INFO] Starting server backup..."
    BACKUP_FILE="$BACKUP_DIR/mc-backup-$(date +'%Y%m%d%H%M').tar.gz"
    tar -czf "$BACKUP_FILE" -C "$SERVER_DIR" . || { echo "[ERROR] Backup failed"; exit 1; }
    echo "[INFO] Backup created: $BACKUP_FILE"
}

# Create Termux Boot Script
function create_termux_boot_script {
    echo "[INFO] Creating Termux:Boot startup script..."
    BOOT_SCRIPT="$HOME/.termux/boot/mc-tbox-startup.sh"
    echo "#!/bin/bash" > "$BOOT_SCRIPT"
    echo "cd $HOME/mc-server" >> "$BOOT_SCRIPT"
    echo "tmux new -d -s minecraft 'java -Xmx$ram_allocation -Xms$ram_allocation -jar $HOME/mc-server/paper.jar nogui'" >> "$BOOT_SCRIPT"
    chmod +x "$BOOT_SCRIPT"
    echo "[INFO] Termux:Boot startup script created at $BOOT_SCRIPT"
}

# Run all functions
inf_check
install_dependencies
check_system_compatibility
#configure_playit
setup_email
setup_minecraft_server
setup_tmate
monitor_health &
setup_logging_backup
create_termux_boot_script

# Backup every 24 hours
while true; do
    backup_minecraft_server
    sleep 86400  # 24 hours
done

echo "[INFO] Setup complete! Your Minecraft server is now running."
