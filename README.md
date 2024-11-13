# mc-tbox: Advanced Minecraft Server Setup Script for Termux

**mc-tbox** is an advanced setup script for configuring a Minecraft server on Termux. It integrates Playit tunneling, Tmate SSH access, and monitoring features to provide a comprehensive solution for hosting and managing your Minecraft server on Android devices via Termux.

## Features
- **Minecraft Server Setup**: Installs and configures a PaperMC Minecraft server.
- **Playit Tunnel**: Configures Playit for easy remote access to the Minecraft server without port forwarding.
- **Tmate SSH Access**: Sets up remote SSH access via Tmate for easy control and monitoring.
- **Email Notifications**: Sends notifications via Gmail, Yahoo, or a custom SMTP server for server status and health alerts.
- **Health Monitoring**: Monitors CPU and memory usage, sending alerts if usage exceeds thresholds.
- **Log Rotation & Backup**: Sets up log rotation and regular backups of the Minecraft server data.
- **Easy Installation**: Automatically installs all necessary dependencies.

## Requirements
- **Termux**: Make sure Termux is installed and up to date.
- **Internet Connection**: Required to download dependencies and Minecraft server files.
- **Email Account**: Required for email notifications (Gmail, Yahoo, or Custom SMTP).

## Installation

1. **Install Termux**: 
   - You can download Termux from [GitHub](https://github.com/termux/termux-app) or [F-Droid](https://f-droid.org/packages/com.termux/).
   
2. **Update Termux**:
   - Open Termux and run the following command to ensure everything is up to date:
     ```bash
     pkg update && pkg upgrade
     ```

3. **Download the Script**:
   - You can clone this repository or download the script directly:
     ```bash
     git clone https://github.com/samir717le/mc-tbox.git
     cd mc-tbox
     chmod +x mc-tbox.sh
     ```

4. **Run the Script**:
   - Execute the script to begin the setup:
     ```bash
     ./mc-tbox.sh
     ```

5. **Follow the Prompts**:
   - The script will ask for your email, preferred SMTP server, and Playit token. Enter the necessary information to proceed.

## Script Breakdown

### 1. **Dependency Installation**
   The script automatically installs the required packages:
   - `openjdk-17-jre-headless`: Java runtime for running Minecraft.
   - `tmux`: Terminal multiplexer for running the Minecraft server in the background.
   - `playit-cli`: Playit tunneling tool for remote access.
   - `tmate`: For remote SSH access.
   - `msmtp`: Lightweight SMTP client for email notifications.
   - `curl`, `wget`: For downloading files.

### 2. **Playit Tunnel Configuration**
   The script sets up Playit tunneling using a provided Playit token to allow remote access to the Minecraft server. If no token is provided, the script will prompt you to enter one.

### 3. **Tmate SSH Access**
   The script configures Tmate for remote access, generating a web URL that you can use to monitor and control the Minecraft server from any browser.

### 4. **Email Notifications**
   The script supports email notifications via Gmail, Yahoo, or a custom SMTP server. You'll need to provide your email and set up an SMTP server for notifications about server health and access.

### 5. **Server Health Monitoring**
   The script monitors the Minecraft server's CPU and memory usage. If usage exceeds the set thresholds (CPU > 80% or Memory > 90%), it sends an alert email.

### 6. **Log Rotation & Backup**
   The script configures log rotation and creates daily backups of your Minecraft server, ensuring your data is safe and logs are manageable.

## Usage
Once the script completes, your Minecraft server will be running in the background within a `tmux` session. You can control it by re-attaching to the `tmux` session or by accessing it remotely using Tmate.

### Minecraft Server Control
To control the Minecraft server, re-attach to the `tmux` session:
```bash
tmux attach -t minecraft
