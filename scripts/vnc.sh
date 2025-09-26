#!/bin/bash

export XDG_RUNTIME_DIR="/tmp/runtime-cuda"
export __GLX_VENDOR_LIBRARY_NAME="nvidia"
export __NV_PRIME_RENDER_OFFLOAD="1"
# export GNOME_SHELL_SESSION_MODE="ubuntu"
# export XDG_SESSION_TYPE="x11"
# export XDG_CURRENT_DESKTOP="ubuntu:GNOME"
# export XDG_CONFIG_DIRS="/etc/xdg/xdg-ubuntu:/etc/xdg"
# export XDG_SESSION_DESKTOP="ubuntu"
# export DESKTOP_SESSION="ubuntu"
export VK_ICD_FILENAMES="/etc/vulkan/icd.d/nvidia_icd.json"

exec dbus-launch --exit-with-session startxfce4