# Ubuntu Latest GNOME on Docker VNC

This guide explains how to build and run a Docker container with a full desktop environment, VNC access, and Cloudflared.

---

## Prerequisites

Before you begin, ensure the following are installed:

1. **Docker**

   Install Docker on Linux:

   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io
   sudo systemctl enable docker
   sudo systemctl start docker
   ```

   > Optional: Add your user to the Docker group to run Docker without `sudo`:

   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **curl / wget**  
   Required for downloading Firefox and Cloudflared.

---

## Build Docker Image

Build your Docker image using the `Dockerfile`:

```bash
sudo docker build -t <my_image_name> .
```

**Example:**

```bash
sudo docker build -t mydockerimg .
```

> This creates a Docker image named `mydockerimg` ready to be run with desktop and VNC support.

---

## Run Docker Container

Use the provided `run.sh` script to start the container:

```bash
./run.sh <image_name> [--port <port>] [--username <username>] [--password <password>] [--sp <yes/no>] [--cft <cloudflared_token>] [--detach|-d] [--restart <policy>]
```

**Parameters:**

| Parameter         | Description                                                                                                                        |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `<image_name>`    | Name of your Docker image (positional argument)                                                                                    |
| `--username`      | Username to create inside the container                                                                                            |
| `--password`      | Password for the user                                                                                                              |
| `--sp`            | Grant sudo privileges (`yes` or `no`)                                                                                              |
| `--cft`           | Cloudflared token for service registration (cloudflare tunnel)                                                                     |
| `--detach` / `-d` | Run container in background (detached mode)                                                                                        |
| `--restart`       | Restart policy for the container. Default: `unless-stopped`. Options: `no`, `always`, `unless-stopped`, `on-failure[:max-retries]` |
| `--vnc-port`      | The VNC Port access. Default: `5901`                                                                                               |
| `--ssh-port`      | The SSH port access. Default: `2222`                                                                                               |

**Examples:**

**Interactive mode (default):**

```bash
./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken --ssh-port 2222 --vnc-port 5912
```

**Detached mode (background) with default restart policy:**

```bash
./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken --detach --ssh-port 2222 --vnc-port 5912
# or short version
./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken -d --ssh-port 2222 --vnc-port 5912
```

**Detached mode with custom restart policy:**

```bash
./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken --detach --restart always --ssh-port 2222 --vnc-port 5912
```

> After the container starts, it prints the VNC URL:
>
> ```
> Running on vnc://localhost:5912
> ```

---

## Accessing the VNC Server via Cloudflared

To access the container's VNC remotely, you can use **Cloudflared** on your client machine:

1. **Install Cloudflared** on your client:

- **Windows:** Download from [Cloudflare Downloads](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/) and follow instructions.
- **Linux:**

  ```bash
  sudo apt-get install cloudflared
  ```

- **Mac:**

  ```bash
  brew install cloudflared
  ```

2. **Connect to the RDP server:**

```bash
cloudflared access rdp --hostname <host>.jersnetdev.com --url tcp://localhost:5902
```

> Take note: if the container auto-increments the vnc port (because 5901 is in use), replace `5901` with the correct port printed by the `run.sh` script.

3. **Open your TigerVNC client** and use the localhost:5902 depends on what port you put

## Troubleshooting

1. **Port conflicts**

   - The script auto-increments the VNC port if `5902` is busy.
   - Check which ports are in use:
     ```bash
     sudo lsof -iTCP -sTCP:LISTEN -P
     ```

2. **Docker permission denied**
   - Use `sudo ./run.sh ...` or add your user to the Docker group.

---

## Notes

- Always run `run.sh` with execute permissions:

  ```bash
  chmod +x run.sh
  ```

- If Docker is not in your user group, prepend `sudo`:

  ```bash
  sudo ./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken --ssh-port 2222 --vnc-port 5912
  ```

- The container directory `/home/<image_name>` is mounted to persist files between runs.

- Remember to match the Cloudflared VNC port with the port printed by `run.sh`.

---

## Author

Jerson Carin
