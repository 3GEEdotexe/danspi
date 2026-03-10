#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=================================================="
echo "Ubuntu / Pi dev bootstrap"
echo "C/C++ + Python + serial/SPI/I2C/LoRa-friendly"
echo "=================================================="

if ! command -v apt >/dev/null 2>&1; then
  echo "This script is for Debian/Ubuntu systems with apt."
  exit 1
fi

echo
echo "[1/8] Refreshing package metadata and repairing package state..."
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo dpkg --configure -a || true
sudo apt update
sudo apt --fix-broken install -y || true
sudo apt full-upgrade -y
sudo apt autoremove -y

echo
echo "[2/8] Installing core development packages..."
sudo apt install -y --no-install-recommends \
  build-essential \
  gcc \
  g++ \
  gdb \
  make \
  cmake \
  ninja-build \
  pkg-config \
  git \
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
  tmux \
  screen

echo
echo "[3/8] Installing Python tooling..."
sudo apt install -y --no-install-recommends \
  python3 \
  python3-dev \
  python3-pip \
  python3-venv \
  python3-setuptools \
  python3-wheel

echo
echo "[4/8] Installing hardware / interface tools..."
sudo apt install -y --no-install-recommends \
  openssh-server \
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
  network-manager \
  i2c-tools \
  libi2c-dev \
  spi-tools \
  python3-serial \
  python3-spidev \
  python3-gpiozero \
  python3-libgpiod \
  libgpiod-dev \
  python3-smbus \
  libssl-dev \
  libffi-dev

echo
echo "[5/8] Enabling SSH..."
sudo systemctl enable --now ssh || true

echo
echo "[6/8] Adding current user to common hardware groups..."
for grp in dialout gpio i2c spi; do
  if getent group "$grp" >/dev/null 2>&1; then
    sudo usermod -aG "$grp" "$USER" || true
  fi
done

echo
echo "[7/8] Creating a Python virtual environment helper directory..."
mkdir -p "$HOME/venvs"

echo
echo "[8/8] Final cleanup..."
sudo apt --fix-broken install -y || true
sudo dpkg --configure -a || true
sudo apt autoremove -y

echo
echo "=================================================="
echo "Installed tool versions"
echo "=================================================="
gcc --version | head -n 1 || true
g++ --version | head -n 1 || true
cmake --version | head -n 1 || true
python3 --version || true
pip3 --version || true
git --version || true

echo
echo "=================================================="
echo "Done."
echo
echo "Notes:"
echo "- Log out and back in for new group memberships to apply."
echo "- Use Python virtual environments for extra libraries:"
echo "    python3 -m venv ~/venvs/lora"
echo "    source ~/venvs/lora/bin/activate"
echo "    pip install pyserial setuptools wheel"
echo "=================================================="
