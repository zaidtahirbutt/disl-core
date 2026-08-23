#!/bin/bash

# Define variables
TARGETS_FILE='targets.json'

# Check if 'jq' is installed
if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' (JSON processor) is not installed. Please install it."
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "No key provided. Using the default key: $DEFAULT_KEY"
  TARGET="DEFAULT"
else
  TARGET="$1"
fi

result=$(jq -r ".$TARGET | {CONTAINER_NAME,IMAGE_NAME,SYSTEM,SYSTEM_DIR,BUILD_DIR,BOARD}" "$TARGETS_FILE")

# Check if the result is empty or not
if [ -z "$result" ]; then
  echo "Error: Key '$TARGET' not found in the JSON file."
  exit 1
fi

CONTAINER_NAME=$(echo "$result" | jq -r '.CONTAINER_NAME')
IMAGE_NAME=$(echo "$result" | jq -r '.IMAGE_NAME')
SYSTEM=$(echo "$result" | jq -r '.SYSTEM')
SYSTEM_DIR=$(echo "$result" | jq -r '.SYSTEM_DIR')
BUILD_DIR=$(echo "$result" | jq -r '.BUILD_DIR')
BOARD=$(echo "$result" | jq -r '.BOARD')

echo "Targets:"
echo "CONTAINER_NAME: $CONTAINER_NAME"
echo "IMAGE_NAME: $IMAGE_NAME"
echo "SYSTEM: $SYSTEM"
echo "SYSTEM_DIR: $SYSTEM_DIR"
echo "BUILD_DIR: $BUILD_DIR"
echo "BOARD: $BOARD"

#Something to do with cgroups and systemctl - don't know why this is needed, but we get permission error without it
export DBUS_SESSION_BUS_ADDRESS=

# Start the container
podman run -d -it --name $CONTAINER_NAME  localhost/$IMAGE_NAME

# Copy the host folder to the container
podman exec $CONTAINER_NAME mkdir /tmp/build_$SYSTEM
podman exec $CONTAINER_NAME mkdir /tmp/system
podman cp $SYSTEM_DIR/$SYSTEM $CONTAINER_NAME:/tmp/system/$SYSTEM

podman exec $CONTAINER_NAME python configure.py --board $BOARD --example_dir system --example $SYSTEM --build_dir /tmp/build_$SYSTEM

# Copy the /disl/build folder from the container to the host
mkdir -p $BUILD_DIR/build_$SYSTEM
podman cp $CONTAINER_NAME:/tmp/build_$SYSTEM $BUILD_DIR/build_$SYSTEM

# Stop and remove the container
podman stop $CONTAINER_NAME
podman rm $CONTAINER_NAME

echo "Script completed successfully."