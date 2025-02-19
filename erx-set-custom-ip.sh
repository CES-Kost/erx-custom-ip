#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

# 🔥 Version of this script
SCRIPT_VERSION="1.2"

# 📌 GitHub repo for updates
GITHUB_REPO="CES-Kost/erx-custom-ip"
SCRIPT_NAME="erx-set-custom-ip.sh"
SCRIPT_PATH="/config/scripts/update_custom_ip.sh"
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

# 🌎 Get public IP
get_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me)
    if [[ -z "$PUBLIC_IP" ]]; then
        log_message "❌ Failed to retrieve public IP."
        exit 1
    fi
    echo "$PUBLIC_IP"
}

# 🚀 Function: Set override-hostname-ip
update_override_ip() {
    PUBLIC_IP=$(get_public_ip)
    log_message "🌍 Setting Public IP: $PUBLIC_IP"

    configure
    # Delete the existing override-hostname-ip (if it exists)
    delete system ip override-hostname-ip || log_message "ℹ️ No previous override-hostname-ip to delete."
    set system ip override-hostname-ip "$PUBLIC_IP"
    commit
    save
    exit

    log_message "✅ Public IP updated successfully!"
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

    # Delete override-hostname-ip
    log_message "🗑 Removing override-hostname-ip..."
    configure
    delete system ip override-hostname-ip
    commit
    save
    exit

    # Remove script
    log_message "🗑 Deleting script file..."
    rm -f "$SCRIPT_PATH"

    log_message "✅ Removal completed!"
}

# 🔧 Handle script actions
case "$1" in
    update)
        update_script
        update_override_ip
        ;;
    install)
        install_cron
        update_override_ip
        ;;
    remove)
        remove_script
        ;;
    *)
        echo "Usage: $0 {install|update|remove}"
        exit 1
        ;;
esac
