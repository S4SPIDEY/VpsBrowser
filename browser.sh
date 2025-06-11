#!/bin/bash

show() {
  echo -e "\033[1;35m$1\033[0m"
}

# Check if curl is installed
if ! [ -x "$(command -v curl)" ]; then
  show "curl is not installed. Please install it to continue."
  exit 1
else
  show "curl is already installed."
fi

# Check and save public IP
IP=$(curl -s ifconfig.me)
read -p "Enter your username(a-z,0-9 only): " USERNAME
read -p "Enter your password: " PASSWORD
#USERNAME="abc"
#PASSWORD="123"

# Generate unique instance ID based on timestamp
INSTANCE_ID=$(date +%s)

# Generate unique ports
BASE_HTTP_PORT=7000
BASE_HTTPS_PORT=7001
HTTP_PORT=$((BASE_HTTP_PORT + INSTANCE_ID % 1000)) # Ensures no overlap for a while
HTTPS_PORT=$((BASE_HTTPS_PORT + INSTANCE_ID % 1000))

# Generate random MAC address
RANDOM_MAC=$(printf '02:00:%02x:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

# Define unique credentials file for this instance
mkdir $HOME/creds
CREDENTIALS_FILE="$HOME/creds/vps-browser-credentials-${INSTANCE_ID}.json"

# Check if Docker is installed
if ! [ -x "$(command -v docker)" ]; then
  show "Docker is not installed. Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  if [ -x "$(command -v docker)" ]; then
    show "Docker installation was successful."
  else
    show "Docker installation failed."
    exit 1
  fi
else
  show "Docker is already installed."
fi

# Pull Chromium Docker image
show "Pulling the latest Chromium Docker image..."
if ! sudo docker pull linuxserver/chromium:latest; then
  show "Failed to pull the Chromium Docker image."
  exit 1
else
  show "Successfully pulled the Chromium Docker image."
fi

# Create a unique configuration directory for this instance
CONFIG_DIR="$HOME/chromium/config_${INSTANCE_ID}"
mkdir -p "$CONFIG_DIR"

# Run a new Docker container for this instance with random MAC address
CONTAINER_NAME="browser_${INSTANCE_ID}"
show "Running Chromium Docker container: $CONTAINER_NAME..."
sudo docker run -d --name $CONTAINER_NAME \
  -e TITLE=PX${INSTANCE_ID} \
  -e DISPLAY=:1 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e CUSTOM_USER="$USERNAME" \
  -e PASSWORD="$PASSWORD" \
  -e LANGUAGE=en_US.UTF-8 \
  -v "$CONFIG_DIR:/config" \
  -p $HTTP_PORT:3000 \
  -p $HTTPS_PORT:3001 \
  --mac-address="$RANDOM_MAC" \
  --shm-size="2gb" \
  --restart unless-stopped \
  lscr.io/linuxserver/chromium:latest

# Save credentials to a file
cat <<EOL > "$CREDENTIALS_FILE"
{
  "AccessPoint": "https://$IP:$HTTPS_PORT/",
  "username": "$USERNAME"
  "password": "$PASSWORD",
  "mac_address": "$RANDOM_MAC"
}
EOL

# Check if the container started successfully
if [ $? -eq 0 ]; then
  show "Chromium Docker container $CONTAINER_NAME started successfully."
  show "Copy the link https://$IP:$HTTPS_PORT/ and open it from your local PC browser."
  show "Use the username: $USERNAME and password: $PASSWORD to log in."
  show "Credentials are also saved in $CREDENTIALS_FILE."
else
  show "Failed to start the Chromium Docker container $CONTAINER_NAME."
  exit 1
fi
