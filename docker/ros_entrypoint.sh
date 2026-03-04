#!/bin/bash

set -e

# Ros build
source "/opt/ros/humble/setup.bash"

source install/setup.bash

# Ensure /usr/local/lib is in LD_LIBRARY_PATH (Livox SDK, GTSAM, etc.) - must run before any build that may fail
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}

echo "==============FAST-LIO ROS2 Docker Env Ready================"

cd /root/ros2_ws

cd src/livox_ros_driver2 && ./build.sh humble || true

cd /root/ros2_ws && colcon build --symlink-install

exec "$@"