#!/bin/bash
# Author : Taeyoung Kim (https://github.com/Taeyoung96)

# Set the project directory (PROJECT_DIR) as the parent directory of the current working directory
PROJECT_DIR=$(dirname "$PWD")

# Move to the parent folder of the project directory
cd "$PROJECT_DIR"

# Print the current working directory to verify the change
echo "Current working directory: $PROJECT_DIR"

# Check if arguments are provided for the image name and tag
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <container_name> <image_name:tag>"
  exit 1
fi

# Assign the arguments to variables for clarity
CONTAINER_NAME="$1"
IMAGE_NAME="$2"
SRC_DIR="$PROJECT_DIR/src"
DATASET_DIR="$PROJECT_DIR/data"


        #    --volume="$SRC_DIR:/root/ros2_ws/src" \
        #    --volume="$DATASET_DIR:/root/data" \

xhost +local:docker
# Launch the nvidia-docker container with the provided image name and tag
docker run --privileged -it \
	   --volume="/media/riaarora/hardisk1/ria_bag_0:/root/"\
           --volume="$PROJECT_DIR:/root/ros2_ws" \
           --volume=/tmp/.X11-unix:/tmp/.X11-unix:rw \
           --device-cgroup-rule="a *:* rmw" \
           --device /dev/dri:/dev/dri \
           --net=host \
           --ipc=host \
           --shm-size=4gb \
           --name="$CONTAINER_NAME" \
           --env="DISPLAY=$DISPLAY" \
           --rm \
           "$IMAGE_NAME" /bin/bash


#   docker run -it --rm --network=host \
#             -v /dev:/dev \
#             --privileged \
#             --name ${container_name} \
#             --device-cgroup-rule="a *:* rmw" \
#             --device /dev/dri:/dev/dri \
#             --volume=/tmp/.X11-unix:/tmp/.X11-unix -v ${XAUTH}:${XAUTH} \
#             -e XAUTHORITY=${XAUTH} \
#             -v ${PWD}:/workspace \
#             -w=/workspace \
#             -e DISPLAY=${DISPLAY} \
#             ${image_tag}
    
