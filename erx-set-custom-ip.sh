#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

# 🔥 Version of this script
SCRIPT_VERSION="2.0"

# 📌 Config file location
CONFIG_FILE="/config/scripts/update_custom_ip.conf"
LOG_FILE="/var/log/update_custom_ip.log"
SCRIPT_PATH="/config/scripts/update_custom_ip.sh"
GITHUB_REPO="CES-Kost/erx-custom-ip"
VERSION_FILE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/version.txt"
SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/update_custom_ip.sh"

# Default update interval (in minutes)
DEFAULT_INTERVAL=180  # 3 hours

# 🛠 Function: Log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 🔄 Function: Check for script updates
update_script() {
    log_message "🔄 Checking for script updates..."

    LATEST_VERSION=$(curl -s "$VERSION_FILE_URL")
    
    if [[ "$LATEST_VERSION" != "$SCRIPT_VERSION" ]]; then
        log_message "🚀 New version ($LATEST_VERSION) available! Updating script..."
        curl -sL "$SCRIPT_URL" -o "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        log_message "✅ Script updated to version $LATEST_VERSION. Restarting..."
        exec "$SCRIPT_PATH" update
    else
        log_message "✔️ Script is up to date (v$SCRIPT_VERSION)."
    fi
}

# 🌎 Function: Get public IP
get_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me)
    if [[ -z "$PUBLIC_IP" ]]; then
        log_message "❌ Failed to retrieve public IP."
        exit 1
    fi
    echo "$PUBLIC_IP"
}

# 🔍 Function: Get MAC Address
get_mac_address() {
    cat /sys/class/net/eth0/address
}

# 📡 Function: Read/Write Config File
read_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        log_message "⚠️ No config file found. Run '$0 install <API_URL> [INTERVAL]' to set it up."
        exit 1
    fi
}

write_config() {
    echo "API_URL=\"$API_URL\"" > "$CONFIG_FILE"
    echo "APP_API_KEY=\"$APP_API_KEY\"" >> "$CONFIG_FILE"
    echo "UPDATE_INTERVAL=\"$UPDATE_INTERVAL\"" >> "$CONFIG_FILE"
}

# 🚀 Function: Send Public IP & MAC to API
update_api() {
    read_config
    PUBLIC_IP=$(get_public_ip)
    MAC_ADDRESS=$(get_mac_address)

    log_message "🌍 Sending Public IP: $PUBLIC_IP for MAC: $MAC_ADDRESS"

    RESPONSE=$(curl -s -X POST "$API_URL/update-ip" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $APP_API_KEY" \
        -d "{\"macAddress\": \"$MAC_ADDRESS\", \"publicIp\": \"$PUBLIC_IP\"}")

    log_message "✅ API Response: $RESPONSE"
}

# 🛠 Function: Install
install_script() {
    if [[ -z "$1" ]]; then
        echo "Usage: $0 install <API_URL> [INTERVAL]"
        exit 1
    fi

    API_URL="$1"
    UPDATE_INTERVAL="${2:-$DEFAULT_INTERVAL}"  # Use default interval if not provided

    log_message "🛠 Installing script using API: $API_URL"
    log_message "⏳ Update interval set to $UPDATE_INTERVAL minutes."

    # Fetch MAC address
    MAC_ADDRESS=$(get_mac_address)

    # Call API /init to get APP_API_KEY
    RESPONSE=$(curl -s -X POST "$API_URL/init" -H "Content-Type: application/json" -d "{\"macAddress\": \"$MAC_ADDRESS\"}")

    if echo "$RESPONSE" | grep -q "appApiKey"; then
        APP_API_KEY=$(echo "$RESPONSE" | jq -r '.appApiKey')
        log_message "✅ API key received and stored securely."
    else
        log_message "❌ Failed to retrieve API key. Response: $RESPONSE"
        exit 1
    fi

    write_config  # Save API details

    # Install cron job
    CRON_JOB="*/$UPDATE_INTERVAL * * * * $SCRIPT_PATH update"
    log_message "🛠 Installing cron job to update public IP every $UPDATE_INTERVAL minutes..."

    # Remove any existing cron job for this script
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH") | crontab -
    
    # Add new cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    log_message "✅ Cron job installed: $CRON_JOB"
    log_message "📌 Use 'crontab -l' to verify."

    # 🔥 Run an update immediately after install
    log_message "🚀 Running first update now..."
    update_api
}

# 🗑 Function: Remove Script & Cron
remove_script() {
    log_message "🚨 Removing script and settings..."

    # Remove cron job
    log_message "🛠 Removing cron job..."
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH") | crontab -

    # Remove config file
    log_message "🗑 Deleting config file..."
    rm -f "$CONFIG_FILE"

    log_message "✅ Removal completed!"
}

# 🔧 Handle script actions
case "$1" in
    update)
        update_script
        update_api
        ;;
    install)
        install_script "$2" "$3"
        ;;
    remove)
        remove_script
        ;;
    *)
        echo "Usage: $0 {install <API_URL> [INTERVAL]|update|remove}"
        exit 1
        ;;
esac