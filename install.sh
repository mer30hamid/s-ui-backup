#!/bin/bash

ENV_FILE=".env"
BACKUP_SCRIPT="/usr/local/bin/backup_and_send.sh"

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"
BOLD="\033[1m"

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${RESET}"
}

if [[ "$1" == "-u" ]]; then
    print_message $RED "Uninstalling the backup script..."

    if [ -f $ENV_FILE ]; then
        rm $ENV_FILE
        print_message $RED "Removed $ENV_FILE"
    else
        print_message $YELLOW "$ENV_FILE does not exist."
    fi

    if [ -f $BACKUP_SCRIPT ]; then
        rm $BACKUP_SCRIPT
        print_message $RED "Removed $BACKUP_SCRIPT"
    else
        print_message $YELLOW "$BACKUP_SCRIPT does not exist."
    fi

    # Remove the cron job
    crontab -l | grep -v "$BACKUP_SCRIPT" | crontab -
    print_message $RED "Cron job removed."

    print_message $GREEN "Uninstallation complete."
    exit 0
fi

prompt_input() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3

    if [ -n "$default_value" ]; then
        echo -e "${CYAN}${prompt_message} [${default_value}]:${RESET} "
        read input
        input=${input:-$default_value}
    else
        echo -e "${CYAN}${prompt_message}:${RESET} "
        read input
    fi
    echo "$var_name=\"$input\"" >> $ENV_FILE
}

if [ -f $ENV_FILE ]; then
    print_message $YELLOW "Existing configuration found:"
    cat $ENV_FILE
    echo
    echo -e "${CYAN}Do you want to reset the configuration? (y/n):${RESET} "
    read reset_config

    if [[ "$reset_config" != "y" ]]; then
        print_message $GREEN "Using existing configuration. Exiting setup."
        exit 0
    fi

    print_message $YELLOW "Resetting configuration..."
    rm $ENV_FILE
fi

print_message $CYAN "Configuring the backup script..."

prompt_input "TELEGRAM_BOT_TOKEN" "Enter your Telegram bot token" ""

prompt_input "TELEGRAM_CHAT_ID" "Enter your Telegram chat ID" ""

echo -e "${CYAN}Enter the backup interval in days (e.g., 1 for daily, 8 for every 8 days) [1]:${RESET} "
read backup_interval
backup_interval=${backup_interval:-1}
if [[ "$backup_interval" =~ ^[0-9]+$ && "$backup_interval" -gt 0 ]]; then
    echo "BACKUP_INTERVAL=\"$backup_interval\"" >> $ENV_FILE
else
    print_message $RED "Invalid input. Defaulting to daily (1 day)."
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

zip -9 -r "$backup_path" "$BACKUP_FOLDER"

file_size=$(stat -c%s "$backup_path")

max_size=$((50 * 1024 * 1024))

if [ "$file_size" -le "$max_size" ]; then
    echo "Sending backup directly..."
    curl -F chat_id="$TELEGRAM_CHAT_ID" \
         -F document=@"$backup_path" \
         "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument"
    
    if [ $? -eq 0 ]; then
        echo "Backup sent successfully!"
    else
        echo "Failed to send the backup. Please check your Telegram settings."
    fi
else
    echo "Backup file is too large. Splitting into smaller parts..."

    split -b 48M "$backup_path" "${backup_path%.*}_part_"

    part_number=1
    for part in "${backup_path%.*}"_part_*; do
        part_renamed="${backup_path%.*}_part_${part_number}.zip"
        mv "$part" "$part_renamed"

        echo "Sending part: $part_renamed..."
        curl -F chat_id="$TELEGRAM_CHAT_ID" \
             -F document=@"$part_renamed" \
             "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument"
        
        if [ $? -eq 0 ]; then
            echo "Part $part_renamed sent successfully!"
        else
            echo "Failed to send part $part_renamed. Please check your Telegram settings."
        fi

        part_number=$((part_number + 1))
    done
fi

rm -f "${backup_path%.*}_part_"*

EOF

sed -i "s|/path/to/.env|$(pwd)/.env|g" $BACKUP_SCRIPT

chmod +x $BACKUP_SCRIPT

cron_interval=$((backup_interval * 24 * 60))
cron_schedule="*/$cron_interval * * * *"

crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab -
(crontab -l 2>/dev/null; echo "$cron_schedule $BACKUP_SCRIPT") | crontab -

print_message $CYAN "Sending the first backup..."
bash $BACKUP_SCRIPT
if [ $? -eq 0 ]; then
    print_message $GREEN "First backup sent successfully!"
else
    print_message $RED "Failed to send the first backup. Please check the configuration."
fi

print_message $GREEN "Configuration completed. The backup script has been set up and scheduled."
