#!/bin/bash

ENV_FILE=".env"
BACKUP_SCRIPT="/usr/local/bin/backup_and_send.sh"
BACKUP_FOLDER="/usr/local/s-ui/"
BACKUP_DIR="/tmp/backups/"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"
BOLD="\033[1m"
clear

before_show_menu() {
    echo && echo -n -e "${yellow}Press enter to return to the main menu: ${plain}" && read temp
    show_menu
}

function LOGE() {
    clear
    echo -e "${red}[ERR] $* ${plain}"
}

check_status() {
    if [[ -f $1 ]]; then
        return 0
    else
        return 1

    fi
}

show_status() {
    check_status $1
    case $? in
    0)
        echo -e "${1} state: ${green}Existing configuration found${plain}"
        ;;
    1)
        echo -e "${1} state: ${yellow}Not found${plain}"
        ;;
    esac
}
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${RESET}"
}

Uninstall() {
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

    crontab -l | grep -v "$BACKUP_SCRIPT" | crontab -
    print_message $RED "Cron job removed."
    print_message $GREEN "Uninstallation complete."
    before_show_menu

}

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
    echo "$var_name=\"$input\"" >>$ENV_FILE
}

configurat() {
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

    prompt_input "TELEGRAM_BOT_TOKEN" "Enter your Telegram bot token" ""
    prompt_input "TELEGRAM_CHAT_ID" "Enter your Telegram chat ID" ""
    echo "BACKUP_FOLDER=\"$BACKUP_FOLDER\"" >>$ENV_FILE
    echo "BACKUP_DIR=\"$BACKUP_DIR\"" >>$ENV_FILE

    echo -e "${CYAN}Enter the backup interval in days (e.g., 1 for daily, 8 for every 8 days) [1]:${RESET} "
    read backup_interval
    backup_interval=${backup_interval:-1}
    if [[ "$backup_interval" =~ ^[0-9]+$ && "$backup_interval" -gt 0 ]]; then
        echo "BACKUP_INTERVAL=\"$backup_interval\"" >>$ENV_FILE
    else
        print_message $RED "Invalid input. Defaulting to daily (1 day)."
        echo "BACKUP_INTERVAL=\"1\"" >>$ENV_FILE
        backup_interval=1
    fi
    BACKUP_FOLDER="/usr/local/s-ui/"
    BACKUP_DIR="/tmp/backups/"

    mkdir -p $BACKUP_DIR

    cat >$BACKUP_SCRIPT <<'EOF'
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

    cron_schedule="0 0 */$backup_interval * *"

    (crontab -l | grep -q "$BACKUP_SCRIPT") && (crontab -r | grep -q "$BACKUP_SCRIPT") && exit 0

    (
        crontab -l 2>/dev/null
        echo "$cron_schedule $BACKUP_SCRIPT"
    ) | crontab -
}

cronStart() {
    if [ -f $BACKUP_SCRIPT ]; then
        if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
            echo -e "${green}Cronjob already actived${plain}"
            # exit 0
            before_show_menu
        else
            echo -e "${green}Cronjob successfuly actived${plain}"
            (
                crontab -l 2>/dev/null
                echo "0 0 */1 * * $BACKUP_SCRIPT"
            ) | crontab -
        fi
    else
        LOGE "backup Bash not created. config first"
    fi
}
cronStop() {
    if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
        (crontab -r | grep -q "$BACKUP_SCRIPT")
        echo "removed"
        before_show_menu
    else
        echo "cronjob not actived"
    fi
}

show_menu() {
    clear
    echo -e "
  ${green}S-UI backup Management Script ${plain}
————————————————————————————————
  ${green}0.${plain} Exit
————————————————————————————————
  ${green}1.${plain} Let's Config 
————————————————————————————————
  ${green}2.${plain} Start Cronjob (@daily)
  ${green}3.${plain} Stop Cronjob
————————————————————————————————
  ${green}4.${plain} Uninstall
————————————————————————————————
 "
    show_status $ENV_FILE

    if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
        echo -e "Cronjob state: ${green}Active${plain}"
    else
        echo -e "Cronjob state: ${yellow}Not active${plain}"
    fi

    echo && read -p "Please enter your selection [0-4]: " num

    case "${num}" in
    0)
        clear
        exit 0
        ;;
    1)
        clear
        configurat
        ;;
    2)
        clear
        cronStart
        ;;
    3)
        clear
        cronStop
        ;;
    4)
        clear
        Uninstall
        ;;
    *)
        LOGE "Please enter the correct number [0-4]"
        ;;
    esac
}

installPrev() {
    echo "Checking for required packages..."

    REQUIRED_PACKAGES=("zip" "curl" "split")
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            echo "$pkg not found. Installing..."
            sudo apt update && sudo apt install -y "$pkg"
            if [ $? -eq 0 ]; then
                echo "$pkg installed successfully!"
            else
                echo "Failed to install $pkg. Please check your system."
                exit 1
            fi
        else
            echo "$pkg is already installed."
        fi
    done
    before_show_menu

}

while true; do
    show_menu
    read -p "Please select an option: " choice
    echo ""
done

printf "\033[?1049l"
