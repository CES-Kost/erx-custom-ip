#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

# 🔥 Version of this script
SCRIPT_VERSION="1.3"

# 📌 GitHub repo for updates
GITHUB_REPO="CES-Kost/erx-custom-ip"
SCRIPT_NAME="erx-set-custom-ip.sh"
SCRIPT_PATH="/config/scripts/update_custom_ip.sh"
CONFIG_FILE="/config/scripts/api_url.conf"
LOG_FILE="/var/log/update_custom_ip.log"

# 🛠 Function: Log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 🔄 Function: Check for script updates
update_script() {
    log_message "🔄 Checking for script updates..."

    # Get latest version from GitHub
    LATEST_VERSION=$(curl -s "https://raw.githubusercontent.com/$GITHUB_REPO/main/version.txt")

    if [[ "$LATEST_VERSION" != "$SCRIPT_VERSION" ]]; then
        log_message "🚀 New version ($LATEST_VERSION) available! Updating script..."
        curl -sL "https://raw.githubusercontent.com/$GITHUB_REPO/main/$SCRIPT_NAME" -o "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        log_message "✅ Script updated to version $LATEST_VERSION. Restarting..."
        exec "$SCRIPT_PATH" update
    else
        log_message "✔️ Script is up to date (v$SCRIPT_VERSION)."
    fi
}

# 📡 Function: Get or prompt for API URL
get_api_url() {
    if [[ -f "$CONFIG_FILE" ]]; then
        API_URL=$(cat "$CONFIG_FILE")
    else
        read -p "Enter the API update URL: " API_URL
        echo "$API_URL" > "$CONFIG_FILE"
        log_message "✅ API URL saved to $CONFIG_FILE"
    fi
    echo "$API_URL"
}

# 🌎 Get public IP
get_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me)
    if [[ -z "$PUBLIC_IP" ]]; then
        log_message "❌ Failed to retrieve public IP."
        exit 1
    fi
    echo "$PUBLIC_IP"
}

# 🚀 Function: Send update to API
send_update() {
    PUBLIC_IP=$(get_public_ip)
    API_URL=$(get_api_url)

    log_message "🌍 Sending Public IP: $PUBLIC_IP to API: $API_URL"

    DEVICE_ID=$(cat /sys/class/net/eth0/address | tr -d ':')  # Use MAC address as device identifier

    JSON_PAYLOAD=$(cat <<EOF
{
  "deviceId": "$DEVICE_ID",
  "publicIp": "$PUBLIC_IP"
}
EOF
)

    RESPONSE=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "$JSON_PAYLOAD")

    log_message "✅ API Response: $RESPONSE"
}

# 🛠 Function: Install cron job
install_cron() {
    log_message "🛠 Installing cron job to update public IP every 3 hours..."

    # Add cron job (if not exists)
    (crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH" ) || (
        echo "0 */3 * * * $SCRIPT_PATH update" | crontab -
    )

    log_message "✅ Cron job installed successfully."
}

# 🗑 Function: Remove script and settings
remove_script() {
    log_message "🚨 Removing script and settings..."

    # Remove cron job
    log_message "🛠 Removing cron job..."
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -

    # Remove saved API URL
    log_message "🗑 Removing API URL config..."
    rm -f "$CONFIG_FILE"

    # Remove script
    log_message "🗑 Deleting script file..."
    rm -f "$SCRIPT_PATH"

    log_message "✅ Removal completed!"
}

# 🔧 Handle script actions
case "$1" in
    update)
        update_script
        send_update
        ;;
    install)
        install_cron
        send_update
        ;;
    remove)
        remove_script
        ;;
    *)
        echo "Usage: $0 {install|update|remove}"
        exit 1
        ;;
esac