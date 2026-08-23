#!/bin/bash

# Define variables
CONTAINER_NAME="disl-container"
IMAGE_NAME="disl"

#Something to do with cgroups and systemctl - don't know why this is needed, but we get permission error without it
export DBUS_SESSION_BUS_ADDRESS=


# Create a new container
container=$(buildah from --name $CONTAINER_NAME python:3.10-slim)
buildah run $container  pip install toml 
#mountpoint=$(buildah mount $container)

# Set the working directory
buildah config --workingdir /tmp $container

# Copy the configure.py script and fpga directory into the container
buildah copy $container ../../configure.py /tmp/configure.py
buildah copy $container ../../fpga /tmp/fpga

# Commit the container as an image
buildah commit $container $IMAGE_NAME

# Clean up by removing the temporary container
buildah rm $container
buildah rmi $(buildah images -f "dangling=true" -q)

echo "Image '$IMAGE_NAME' created successfully."