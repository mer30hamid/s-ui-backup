#!/bin/bash

ENV_FILE=".env"
BACKUP_SCRIPT="/usr/local/bin/backup_and_send.sh"

if [[ "$1" == "-u" ]]; then
    echo "Uninstalling the backup script..."

    if [ -f $ENV_FILE ]; then
        rm $ENV_FILE
        echo "Removed $ENV_FILE"
    else
        echo "$ENV_FILE does not exist."
    fi

    if [ -f $BACKUP_SCRIPT ]; then
        rm $BACKUP_SCRIPT
        echo "Removed $BACKUP_SCRIPT"
    else
        echo "$BACKUP_SCRIPT does not exist."
    fi

    crontab -l | grep -v "$BACKUP_SCRIPT" | crontab -
    echo "Cron job removed."

    echo "Uninstallation complete."
    exit 0
fi

prompt_input() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3

    if [ -n "$default_value" ]; then
        read -p "$prompt_message [$default_value]: " input
        input=${input:-$default_value}
    else
        read -p "$prompt_message: " input
    fi
    echo "$var_name=\"$input\"" >> $ENV_FILE
}

if [ -f $ENV_FILE ]; then
    echo "Existing configuration found:"
    cat $ENV_FILE
    echo
    read -p "Do you want to reset the configuration? (y/n): " reset_config

    if [[ "$reset_config" != "y" ]]; then
        echo "Using existing configuration. Exiting setup."
        exit 0
    fi

    echo "Resetting configuration..."
    rm $ENV_FILE
fi

echo "Configuring the backup script..."

prompt_input "TELEGRAM_BOT_TOKEN" "Enter your Telegram bot token" ""

prompt_input "TELEGRAM_CHAT_ID" "Enter your Telegram chat ID" ""

read -p "Enter the backup interval in days (e.g., 1 for daily, 8 for every 8 days) [1]: " backup_interval
backup_interval=${backup_interval:-1}
if [[ "$backup_interval" =~ ^[0-9]+$ && "$backup_interval" -gt 0 ]]; then
    echo "BACKUP_INTERVAL=\"$backup_interval\"" >> $ENV_FILE
else
    echo "Invalid input. Defaulting to daily (1 day)."
    echo "BACKUP_INTERVAL=\"1\"" >> $ENV_FILE
    backup_interval=1
fi

BACKUP_FOLDER="/usr/local/s-ui/"
BACKUP_DIR="/tmp/backups/"
echo "BACKUP_FOLDER=\"$BACKUP_FOLDER\"" >> $ENV_FILE
echo "BACKUP_DIR=\"$BACKUP_DIR\"" >> $ENV_FILE

mkdir -p $BACKUP_DIR

cat > $BACKUP_SCRIPT << 'EOF'
#!/bin/bash

source /path/to/.env

backup_name="backup_$(date '+%Y%m%d_%H%M%S').zip"
backup_path="$BACKUP_DIR$backup_name"

zip -r "$backup_path" "$BACKUP_FOLDER"

curl -F chat_id="$TELEGRAM_CHAT_ID" \
     -F document=@"$backup_path" \
     "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument"
EOF

sed -i "s|/path/to/.env|$(pwd)/.env|g" $BACKUP_SCRIPT

chmod +x $BACKUP_SCRIPT

cron_interval=$((backup_interval * 24 * 60))
cron_schedule="*/$cron_interval * * * *"

crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab -
(crontab -l 2>/dev/null; echo "$cron_schedule $BACKUP_SCRIPT") | crontab -

echo "Configuration completed. The backup script has been set up and scheduled."
