#!/bin/bash

prompt_input() {
    local var_name=$1
    local prompt_message=$2
    read -p "$prompt_message: " input
    echo "$var_name=\"$input\"" >> .env
}

echo "Configuring the backup script..."

ENV_FILE=".env"

[ -f $ENV_FILE ] && rm $ENV_FILE

prompt_input "TELEGRAM_BOT_TOKEN" "Enter your Telegram bot token"

prompt_input "TELEGRAM_CHAT_ID" "Enter your Telegram chat ID"

read -p "Enter the backup interval in days (e.g., 1 for daily, 8 for every 8 days): " backup_interval
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

BACKUP_SCRIPT="/usr/local/bin/backup_and_send.sh"

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

cron_interval=$((backup_interval * 24 * 60)) # Convert days to minutes
cron_schedule="*/$cron_interval * * * *"

(crontab -l 2>/dev/null; echo "$cron_schedule $BACKUP_SCRIPT") | crontab -

echo "Configuration completed. The backup script has been set up and scheduled."
