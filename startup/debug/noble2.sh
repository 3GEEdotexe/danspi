#!/usr/bin/env bash

set -u

LOG="$HOME/repair_ssh_install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "=================================================="
echo "Repair OpenSSH install / dpkg state"
echo "=================================================="
echo "Timestamp: $(date -Is)"
echo "Log: $LOG"
echo

step() {
    echo
    echo "--------------------------------------------------"
    echo "$1"
    echo "--------------------------------------------------"
}

run() {
    echo "+ $*"
    "$@"
}

step "1) Show current package/process state"
run ps -ef
echo
echo "+ filtered package processes"
ps -ef | grep -E 'apt|dpkg|debconf|unattended|packagekit|ubiquity' | grep -v grep || true

echo
echo "+ sudo lsof /var/cache/debconf/config.dat"
sudo lsof /var/cache/debconf/config.dat || true

echo
echo "+ sudo lsof /var/lib/dpkg/lock"
sudo lsof /var/lib/dpkg/lock || true

echo
echo "+ sudo lsof /var/lib/dpkg/lock-frontend"
sudo lsof /var/lib/dpkg/lock-frontend || true

step "2) Show current OpenSSH state"
run apt-cache policy openssh-server openssh-client openssh-sftp-server
echo
echo "+ dpkg -l | grep openssh"
dpkg -l | grep openssh || true
echo
echo "+ dpkg -s openssh-server"
dpkg -s openssh-server || true

step "3) If no package manager is running, clear stale locks"
PKG_PROCS="$(ps -ef | grep -E 'apt|dpkg|debconf|unattended|packagekit|ubiquity' | grep -v grep || true)"
if [ -z "$PKG_PROCS" ]; then
    echo "No active package-management processes detected."
    run sudo rm -f /var/lib/dpkg/lock
    run sudo rm -f /var/lib/dpkg/lock-frontend
    run sudo rm -f /var/cache/debconf/config.dat-lock
else
    echo "Active package-related process detected."
    echo "Not removing locks."
fi

step "4) Reconfigure pending packages"
echo "+ sudo dpkg --configure -a"
sudo dpkg --configure -a || true

step "5) Fix broken packages"
echo "+ sudo apt --fix-broken install -y"
sudo apt --fix-broken install -y || true

step "6) Force consistent OpenSSH package set"
echo "+ sudo apt install -y openssh-client openssh-sftp-server openssh-server"
sudo apt install -y openssh-client openssh-sftp-server openssh-server || true

step "7) Retry configure"
echo "+ sudo dpkg --configure -a"
sudo dpkg --configure -a || true

step "8) Try enabling SSH if install succeeded"
echo "+ sudo systemctl enable --now ssh"
sudo systemctl enable --now ssh || true

echo
echo "+ sudo systemctl status ssh --no-pager"
sudo systemctl status ssh --no-pager || true

echo
echo "+ sudo ss -tulpn | grep ':22'"
sudo ss -tulpn | grep ':22' || true

step "9) Recent dpkg / apt logs"
echo "+ tail -n 120 /var/log/dpkg.log"
tail -n 120 /var/log/dpkg.log 2>/dev/null || true

echo
echo "+ tail -n 120 /var/log/apt/term.log"
tail -n 120 /var/log/apt/term.log 2>/dev/null || true

echo
echo "=================================================="
echo "Done"
echo "Paste this log if SSH still fails:"
echo "$LOG"
echo "=================================================="
