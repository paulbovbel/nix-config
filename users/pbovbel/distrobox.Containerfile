ARG baseImage
ARG hostSpawnVersion=v1.6.0
FROM $baseImage
ARG hostSpawnVersion

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
    age \
    apt-transport-https \
    bat \
    bind9-dnsutils \
    ca-certificates \
    curl \
    dnsutils \
    duf \
    ethtool \
    fd-find \
    file \
    git \
    git-lfs \
    gnupg \
    htop \
    iotop \
    iperf3 \
    jc \
    jq \
    kitty-terminfo \
    lsof \
    mtr-tiny \
    nano \
    ncdu \
    nethogs \
    net-tools \
    nmap \
    pciutils \
    psmisc \
    pv \
    ripgrep \
    socat \
    strace \
    tcpdump \
    tmux \
    tree \
    unzip \
    usbutils \
    wget \
    whois \
    zip \
  && rm -rf /var/lib/apt/lists/*

RUN curl -sLfo /usr/bin/host-spawn "https://github.com/1player/host-spawn/releases/download/$hostSpawnVersion/host-spawn-$(uname -m)" \
  && chmod +x /usr/bin/host-spawn
