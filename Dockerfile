FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Manila

# Base system update & upgrade
RUN apt-get -y update && apt-get -y upgrade

# Install GNOME desktop (minimal set to avoid bloat)
RUN apt-get install -y \
    ubuntu-desktop \
    dbus-x11 \
    sudo \
    wget \
    curl \
    xrdp && \
    apt-get remove -y light-locker xscreensaver && \
    apt-get autoremove -y && \
    rm -rf /var/cache/apt /var/lib/apt/lists

RUN rm /run/reboot-required*

RUN sed -i '3 a echo "\
export GNOME_SHELL_SESSION_MODE=ubuntu\\n\
export XDG_SESSION_TYPE=x11\\n\
export XDG_CURRENT_DESKTOP=ubuntu:GNOME\\n\
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg\\n\
" > ~/.xsessionrc' /etc/xrdp/startwm.sh

# Python setup
RUN apt-get update && apt-get install -y python3-pip python-is-python3 python3.12-venv

# Gnome tweaks
RUN apt-get install -y nautilus nautilus-extension-gnome-terminal

# VSCode
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

# Install goodies
RUN apt install -y wget software-properties-common apt-transport-https

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


# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# Copy your entrypoint script
COPY ./build.sh /usr/bin/
RUN mv /usr/bin/build.sh /usr/bin/run.sh && chmod +x /usr/bin/run.sh

# Docker config
EXPOSE 3389
ENTRYPOINT ["/usr/bin/run.sh"]
