#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "Updating system and installing dev + LoRa tooling"
echo "=================================================="

sudo apt update
sudo apt full-upgrade -y

sudo apt install -y \
  build-essential \
  gcc \
  g++ \
  gdb \
  clang \
  make \
  cmake \
  ninja-build \
  pkg-config \
  git \
  git-lfs \
  curl \
  wget \
  unzip \
  zip \
  tar \
  xz-utils \
  file \
  nano \
  vim \
  htop \
  tree \
  jq \
  screen \
  tmux \
  minicom \
  picocom \
  usbutils \
  pciutils \
  lsof \
  strace \
  net-tools \
  iproute2 \
  iputils-ping \
  dnsutils \
  rfkill \
  wireless-tools \
  network-manager \
  openssh-server \
  python3 \
  python3-dev \
  python3-pip \
  python3-venv \
  python3-setuptools \
  python3-wheel \
  python3-serial \
  python3-spidev \
  python3-gpiozero \
  python3-libgpiod \
  libgpiod-dev \
  i2c-tools \
  libi2c-dev \
  spi-tools \
  libssl-dev \
  libffi-dev \
  libudev-dev \
  python3-smbus

echo "=================================================="
echo "Upgrading pip tooling"
echo "=================================================="

python3 -m pip install --upgrade pip setuptools wheel --break-system-packages || true

echo "=================================================="
echo "Enabling SSH"
echo "=================================================="

sudo systemctl enable --now ssh

echo "=================================================="
echo "Adding user to common hardware access groups"
echo "=================================================="

sudo usermod -aG dialout,gpio,i2c,spi "$USER" || true

echo "=================================================="
echo "Installed versions"
echo "=================================================="

gcc --version | head -n 1 || true
g++ --version | head -n 1 || true
cmake --version | head -n 1 || true
python3 --version || true
pip3 --version || true
git --version || true

echo "=================================================="
echo "Done"
echo
echo "You may need to log out and back in for new group memberships"
echo "to take effect."
echo "=================================================="
