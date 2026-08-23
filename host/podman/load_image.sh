#!/bin/bash
IMAGE_NAME="disl_20231007154738"
IMAGE_DIR="./images"
SORCE_IMAGE="$IMAGE_DIR/${IMAGE_NAME}_${TIMESTAMP}"
podman load -i $DEST_IMAGE
echo "Image '$IMAGE_NAME' loaded successfully."