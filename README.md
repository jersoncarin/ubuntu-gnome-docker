# Ubuntu Latest GNOME on Docker RDP

This guide explains how to build and run a Docker container with a full desktop environment, RDP access, and Cloudflared.

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

> This creates a Docker image named `mydockerimg` ready to be run with desktop and RDP support.

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

**Examples:**

**Interactive mode (default):**

```bash
./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken
```

**Detached mode (background) with default restart policy:**

```bash
./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken --detach
# or short version
./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken -d
```

**Detached mode with custom restart policy:**

```bash
./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken --detach --restart always
```

> The script automatically chooses port `3390` for RDP and increments if the port is busy.  
> After the container starts, it prints the RDP URL:
>
> ```
> Running on rdp://localhost:3390
> ```

---

## Accessing the RDP Server via Cloudflared

To access the container's RDP remotely, you can use **Cloudflared** on your client machine:

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
cloudflared access rdp --hostname rdp.jersnetdev.com/<user> --url rdp://localhost:3390
```

> Take note: if the container auto-increments the port (because 3390 is in use), replace `3390` with the correct port printed by the `run.sh` script.

3. **Open your RDP client** (Microsoft RDP or other) and connect using the forwarded port from Cloudflared.

---

## Features

- Creates a user inside the container.
- Optionally grants sudo access.
- Installs and registers Cloudflared service if not present.
- Starts xRDP services for remote desktop access.
- Auto-detects free RDP port starting from 3390.
- Allows secure remote access via Cloudflared tunnel.
- Supports running in detached mode (`--detach` / `-d`).
- Supports automatic restart policies (`--restart`).

---

## Troubleshooting

1. **Port conflicts**

   - The script auto-increments the RDP port if `3390` is busy.
   - Check which ports are in use:
     ```bash
     sudo lsof -iTCP -sTCP:LISTEN -P
     ```

2. **xRDP fails to start**

   - Ensure previous PID files are removed:
     ```bash
     sudo rm -rf /var/run/xrdp*
     ```
   - Restart the container.

3. **Docker permission denied**

   - Use `sudo ./run.sh ...` or add your user to the Docker group.

4. **Cloudflared or Firefox installation issues**
   - Check internet connectivity inside the container.
   - Make sure the `wget` and `curl` packages are installed.

---

## Notes

- Always run `run.sh` with execute permissions:

  ```bash
  chmod +x run.sh
  ```

- If Docker is not in your user group, prepend `sudo`:

  ```bash
  sudo ./run.sh mydockerimg --username testuser --password testpass --sp yes --cft mytoken
  ```

- The container directory `/home/<image_name>` is mounted to persist files between runs.

- Remember to match the Cloudflared RDP port with the port printed by `run.sh`.

---

## Credits

Thanks to [danchitnis](https://github.com/danchitnis/container-xrdp/) for the Dockerfile and config.
