FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Manila

ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV NVIDIA_VISIBLE_DEVICES=all

# Create runtime dir and set environment variable
RUN mkdir -p /tmp/runtime-cuda && \
    chown 1000:1000 /tmp/runtime-cuda

ENV XDG_RUNTIME_DIR=/tmp/runtime-cuda
ENV __GLX_VENDOR_LIBRARY_NAME=nvidia
ENV __NV_PRIME_RENDER_OFFLOAD=1

COPY ./scripts/nvidia_icd.json /etc/vulkan/icd.d
ENV VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json

# Base system update & upgrade
RUN apt-get -y update && apt-get -y upgrade

# Install GNOME desktop (minimal set to avoid bloat)
RUN apt-get install -y \
    ubuntu-desktop \
    dbus-x11 \
    openssh-server \
    sudo \
    wget \
    curl \
    git \
    mesa-utils \
    tigervnc-standalone-server \ 
    tigervnc-xorg-extension \
    nano && \
    apt-get remove -y light-locker xscreensaver && \
    apt-get autoremove -y && \
    rm -rf /var/cache/apt /var/lib/apt/lists

RUN rm /run/reboot-required*

# transfer the vnc server
COPY ./scripts/vnc.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/vnc.sh

# Create the SSH directory and configure permissions
RUN mkdir /var/run/sshd

# Enable password authentication in the SSH configuration
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Optional: Disable root login via SSH
RUN echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# Python setup
RUN apt-get update && apt-get install -y python3-pip python-is-python3 python3.12-venv

# Gnome tweaks
RUN apt-get install -y nautilus nautilus-extension-gnome-terminal

# Install goodies
RUN apt install -y software-properties-common apt-transport-https

# Install Vulkan
RUN apt-get update \
    && apt-get install -y \
    libxext6 \
    libvulkan1 \
    libvulkan-dev \
    vulkan-tools

# Force GNOME to use X11
RUN grep -q '^WaylandEnable=false' /etc/gdm3/custom.conf || \
    (sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf || \
     echo "WaylandEnable=false" >> /etc/gdm3/custom.conf)

COPY ./scripts/systemd/systemctl3.py /usr/bin/systemctl
RUN test -e /bin/systemctl || ln -sf /usr/bin/systemctl /bin/systemctl


# Vscode
# Add Microsoft GPG key and repo for VSCode
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg \
    && install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg \
    && rm -f microsoft.gpg \
    && echo "Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: amd64,arm64,armhf\nSigned-By: /usr/share/keyrings/microsoft.gpg" \
        > /etc/apt/sources.list.d/vscode.sources \
    && apt-get update \
    && apt-get install -y code \
    && rm -rf /var/cache/apt /var/lib/apt/lists/*

# Webots
RUN wget https://github.com/cyberbotics/webots/releases/download/R2025a/webots_2025a_amd64.deb \
    && apt-get update \
    && apt-get install -y ./webots_2025a_amd64.deb \
    && rm -f webots_2025a_amd64.deb \
    && rm -rf /var/cache/apt /var/lib/apt/lists/*

# Cloudflared
RUN mkdir -p /usr/share/keyrings && \
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" > /etc/apt/sources.list.d/cloudflared.list && \
    apt-get update && apt-get install -y --no-install-recommends cloudflared && \
    rm -rf /var/lib/apt/lists/*

# Remove snap firefox (preinstalled on Ubuntu)
RUN apt-get purge -y firefox \
    && apt-get purge -y snapd \
    && rm -rf /var/cache/apt/* /var/lib/snapd /snap /var/snap /var/lib/snapd

# Install Firefox from Mozilla's APT repo
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
       | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
       > /etc/apt/sources.list.d/mozilla.list \
    && printf "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n" \
       > /etc/apt/preferences.d/mozilla \
    && apt-get update \
    && apt-get install -y --no-install-recommends firefox \
    && rm -rf /var/lib/apt/lists/*

# Download RustDesk
RUN wget https://github.com/rustdesk/rustdesk/releases/download/1.4.2/rustdesk-1.4.2-x86_64.deb -O /tmp/rustdesk_1.4.2.deb \
    && apt-get update \
    && apt-get install -y /tmp/rustdesk_1.4.2.deb \
    && rm -f /tmp/rustdesk_1.4.2.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# Copy your entrypoint script
COPY ./scripts/start.sh /usr/bin/
RUN mv /usr/bin/start.sh /usr/bin/run.sh && chmod +x /usr/bin/run.sh

# Docker config
EXPOSE 22
EXPOSE 1
EXPOSE 5901
EXPOSE 3389

ENTRYPOINT ["/usr/bin/run.sh"]
