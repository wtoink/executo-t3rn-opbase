#!/bin/bash

curl -s https://raw.githubusercontent.com/bangpateng/symphony/main/logo.sh | bash
sleep 5

echo "T3rn Executor!"

sudo apt update && sudo apt upgrade -y
if [ $? -ne 0 ]; then
  echo "Error updating and upgrading packages. Exiting..."
  exit 1
fi

sudo apt install curl wget tar build-essential jq unzip -y
if [ $? -ne 0 ]; then
  echo "Error installing packages. Exiting..."
  exit 1
fi

sudo systemctl stop executor || true
sudo systemctl disable executor || true
sudo rm -f /etc/systemd/system/executor.service || true
sudo systemctl daemon-reload

if [ -d "executor" ]; then
  rm -rf executor
fi

download_and_extract_binary() {
    LATEST_VERSION=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep 'tag_name' | cut -d\" -f4)
    EXECUTOR_URL="https://github.com/t3rn/executor-release/releases/download/${LATEST_VERSION}/executor-linux-${LATEST_VERSION}.tar.gz"
    EXECUTOR_FILE="executor-linux-${LATEST_VERSION}.tar.gz"

    echo "Latest version detected: $LATEST_VERSION"
    echo "Downloading Executor binary from $EXECUTOR_URL..."
    curl -L -o $EXECUTOR_FILE $EXECUTOR_URL

    if [ $? -ne 0 ]; then
        echo "Failed to download Executor binary. Please check your internet connection and try again."
        exit 1
    fi

    echo "Extracting binary..."
    tar -xzvf $EXECUTOR_FILE
    if [ $? -ne 0 ]; then
        echo "Extraction failed. Exiting."
        exit 1
    fi

    rm -rf $EXECUTOR_FILE
    cd executor/executor/bin || exit
    echo "Binary successfully downloaded and extracted."
}

set_environment_variables() {
    export NODE_ENV=testnet
    export LOG_LEVEL=info
    export LOG_PRETTY=false
    echo "Environment variables set: NODE_ENV=$NODE_ENV, LOG_LEVEL=$LOG_LEVEL, LOG_PRETTY=$LOG_PRETTY"
}

set_private_key() {
    while true; do
        read -p "Enter your Private Key (without 0x prefix): " PRIVATE_KEY_LOCAL
        PRIVATE_KEY_LOCAL=${PRIVATE_KEY_LOCAL#0x}

        if [ ${#PRIVATE_KEY_LOCAL} -eq 64 ]; then
            export PRIVATE_KEY_LOCAL
            echo "Private key has been set."
            break
        else
            echo "Invalid private key. It must be 64 characters long (without 0x prefix)."
        fi
    done
}

set_enabled_networks() {
    export ENABLED_NETWORKS='blast-sepolia,optimism-sepolia,l1rn'
    echo "Enabled networks: $ENABLED_NETWORKS"
}

create_systemd_service() {
    SERVICE_FILE="/etc/systemd/system/executor.service"
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Executor Service
After=network.target

[Service]
User=root
WorkingDirectory=/root/executor/executor
Environment="NODE_ENV=testnet"
Environment="LOG_LEVEL=info"
Environment="LOG_PRETTY=false"
Environment="PRIVATE_KEY_LOCAL=0x$PRIVATE_KEY_LOCAL"
Environment="ENABLED_NETWORKS=$ENABLED_NETWORKS"
ExecStart=/root/executor/executor/bin/executor
Restart=always
RestartSec=3600

[Install]
WantedBy=multi-user.target
EOL
}

start_service() {
    sudo systemctl daemon-reload
    sudo systemctl enable executor.service
    sudo systemctl start executor.service
    echo "Setup complete! Executor service has been created and started."
    echo "You can check the service status using: sudo systemctl status executor.service"
}

display_log() {
    echo "Displaying logs from the executor service:"
    sudo journalctl -u executor.service -f
}

download_and_extract_binary
set_environment_variables
set_private_key
set_enabled_networks
create_systemd_service
start_service
display_log
