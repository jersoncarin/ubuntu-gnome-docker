#!/bin/bash

# Default values
DEFAULT_VNC_PORT=5901
DEFAULT_SSH_PORT=2222
DETACH=false
RESTART_POLICY="unless-stopped"

usage() {
    echo "Usage: $0 <image_name> [--vnc-port <vnc_port>] [--SSH-port <ssh_port>] [--username <username>] [--password <password>] [--sp <sudo_cap>] [--cft <cloudflared_token>] [--detach|-d] [--restart <policy>]"
    echo "Restart policy options: no, always, unless-stopped, on-failure[:max-retries]"
    exit 1
}

# Check if docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if first argument exists (image)
if [[ $# -lt 1 ]]; then
    echo "Error: image name is required"
    usage
fi

# First argument is the image
IMAGE="$1"
shift

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vnc-port) VNC_PORT="$2"; shift 2 ;;
        --ssh-port) DEFAULT_SSH_PORT="$2"; shift 2 ;;
        --username) USERNAME="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --sp) SUDO_CAP="$2"; shift 2 ;;
        --cft) CLOUD_FLARED="$2"; shift 2 ;;
        --detach|-d) DETACH=true; shift ;;
        --restart) RESTART_POLICY="$2"; shift 2 ;;
        *) echo "Unknown option $1"; usage ;;
    esac
done

# Set VNC port to default if not provided
if [[ -z "$VNC_PORT" ]]; then
    VNC_PORT=$DEFAULT_VNC_PORT
    while lsof -Pi :$VNC_PORT -sTCP:LISTEN -t >/dev/null ; do
        VNC_PORT=$((VNC_PORT + 1))
    done
fi

echo "VNC available on vnc://localhost:$VNC_PORT"
echo "Restart policy: $RESTART_POLICY"

# Determine run mode
if [[ "$DETACH" == true ]]; then
    RUN_FLAGS="-d"
else
    RUN_FLAGS="-it"
fi

sudo docker run $RUN_FLAGS \
--privileged \
--security-opt seccomp=unconfined \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-v "$HOME/$IMAGE:/home" \
-v /dev/dri:/dev/dri \
-e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix \
--runtime=nvidia \
--gpus all \
-p "$VNC_PORT":"$VNC_PORT" \
-p "$DEFAULT_SSH_PORT":22 \
--restart $RESTART_POLICY \
"$IMAGE" \
"${USERNAME:-}" "${PASSWORD:-}" "${SUDO_CAP:-}" "${CLOUD_FLARED:-}" "${VNC_PORT:-}"
