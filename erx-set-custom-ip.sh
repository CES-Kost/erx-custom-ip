#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

SCRIPT_PATH="/config/scripts/update_custom_ip.sh"
LOG_FILE="/var/log/custom_ip_update.log"
CRON_JOB="0 */3 * * * $SCRIPT_PATH update >> $LOG_FILE 2>&1"

# Function to fetch the public IP
get_public_ip() {
    curl -s ifconfig.me
}

# Function to update the system UNMS custom IP
update_custom_ip() {
    PUBLIC_IP=$(get_public_ip)

    if [[ -z "$PUBLIC_IP" ]]; then
        echo "❌ Failed to retrieve public IP."
        exit 1
    fi

    echo "🌍 Setting Public IP: $PUBLIC_IP"

    configure
    set system unms custom-ip "$PUBLIC_IP"
    commit
    save
    exit

    echo "✅ Public IP updated successfully!"
}

# Function to install the cron job
install_cron() {
    echo "🛠 Installing cron job to update public IP every 3 hours..."

    # Ensure script is executable
    chmod +x "$SCRIPT_PATH"

    # Add cron job (Check if already exists)
    if crontab -l | grep -q "update_custom_ip.sh"; then
        echo "⚡ Cron job already exists. Skipping installation."
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "✅ Cron job installed successfully."
    fi
}

# Function to remove the cron job
remove_cron() {
    echo "🛑 Removing scheduled cron job..."
    crontab -l | grep -v "update_custom_ip.sh" | crontab -
    echo "✅ Cron job removed."
}

# Script execution
case "$1" in
    update)
        update_custom_ip
        ;;
    install)
        install_cron
        ;;
    remove)
        remove_cron
        ;;
    *)
        echo "Usage: $0 {install|update|remove}"
        exit 1
        ;;
esac
