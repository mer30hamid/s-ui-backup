# S-UI Backup Management Script

A simple script for managing backups of the [S-UI panel](https://github.com/alireza0/s-ui). The backups are sent via a Telegram bot, and the backup cycle can be customized during the setup process.

---

## 🚀 Installation

To install the script, run the following command:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/NimaTarlani/s-ui-backup/master/install.sh)
```

## 📖 Usage

Once installed, you can run the script, and you will see the following menu:

```code
  S-UI Backup Management Script
————————————————————————————————
  0. Exit
————————————————————————————————
  1. Let's Config
————————————————————————————————
  2. Start Cronjob (@daily)
  3. Stop Cronjob
————————————————————————————————
  4. Uninstall
————————————————————————————————

.env state: Existing configuration found
Cronjob state: Active

Please enter your selection [0-4]:
```


**Menu Options:**

1. Let's Config: Configure the required settings (Telegram bot token, user ID, and backup cycle).
2. Start Cronjob (@daily): Activate the cronjob for daily backups.
3. Stop Cronjob: Deactivate the cronjob.
4. Uninstall: Completely remove the script.


## 🛠️ Requirements
 - Telegram Bot: You need the bot token and user ID for sending backups.
 - Linux Server: This script is designed to run on Linux systems.

## ✨ Features
 - Sends backups via Telegram.
 - Allows scheduling automated backups.
 - Easy installation and removal.

## 🗑️ Uninstallation

To remove the script, use this command:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/NimaTarlani/s-ui-backup/master/install.sh) -u
```

## Stargazers over Time
[![Stargazers over time](https://starchart.cc/NimaTarlani/s-ui-backup.svg)](https://starchart.cc/NimaTarlani/s-ui-backup)
