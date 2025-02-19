#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

# 🔥 Version of this script
SCRIPT_VERSION="1.6"

# 📌 Config file location
CONFIG_FILE="/config/scripts/update_custom_ip.conf"
LOG_FILE="/var/log/update_custom_ip.log"

# 🛠 Function: Log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
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
        log_message "⚠️ No config file found. Run '$0 install' to set it up."
        exit 1
    fi
}

write_config() {
    echo "API_URL=\"$API_URL\"" > "$CONFIG_FILE"
    echo "APP_API_KEY=\"$APP_API_KEY\"" >> "$CONFIG_FILE"
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
    log_message "🛠 Installing script..."

    # Prompt for API details
    read -p "Enter API Update URL (e.g., https://api.yourdomain.com): " API_URL
    read -p "Enter APP_API_KEY: " APP_API_KEY

    write_config  # Save API details

    # Install cron job
    log_message "🛠 Installing cron job to update public IP every 3 hours..."
    (crontab -l 2>/dev/null | grep -q "$0" ) || (
        echo "0 */3 * * * $0 update" | crontab -
    )

    log_message "✅ Installation complete!"
}

# 🗑 Function: Remove Script & Cron
remove_script() {
    log_message "🚨 Removing script and settings..."

    # Remove cron job
    log_message "🛠 Removing cron job..."
    crontab -l 2>/dev/null | grep -v "$0" | crontab -

    # Remove config file
    log_message "🗑 Deleting config file..."
    rm -f "$CONFIG_FILE"

    log_message "✅ Removal completed!"
}

# 🔧 Handle script actions
case "$1" in
    update)
        update_api
        ;;
    install)
        install_script
        ;;
    remove)
        remove_script
        ;;
    *)
        echo "Usage: $0 {install|update|remove}"
        exit 1
        ;;
esac