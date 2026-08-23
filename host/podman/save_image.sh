#!/bin/bash
IMAGE_NAME="disl"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
IMAGE_DIR="./images"
SOURCE_IMAGE="localhost/$IMAGE_NAME"
DEST_IMAGE="$IMAGE_DIR/${IMAGE_NAME}_${TIMESTAMP}"
mkdir -p $IMAGE_DIR
podman save $SOURCE_IMAGE -o $DEST_IMAGE
echo "Image '$IMAGE_NAME' saved successfully."