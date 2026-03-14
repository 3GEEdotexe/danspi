#!/usr/bin/env bash
set -u

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$HOME/apt_ssh_debug_${TS}.log"

exec > >(tee "$LOG") 2>&1

echo "============================================================"
echo "APT / DPKG / OPENSSH DEBUG LOG"
echo "============================================================"
echo "Timestamp: $(date -Is)"
echo "User: $(whoami)"
echo "Host: $(hostname)"
echo "Kernel: $(uname -a)"
echo "Arch: $(dpkg --print-architecture 2>/dev/null)"
echo

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

run() {
  echo
  echo "+ $*"
  "$@"
}

section "OS RELEASE"
run cat /etc/os-release

section "APT VERSION / DPKG VERSION"
run apt --version
run dpkg --version

section "NETWORK / NAME RESOLUTION"
run hostname -I
run ip addr
run ip route
run getent hosts ports.ubuntu.com
run getent hosts archive.ubuntu.com
run getent hosts security.ubuntu.com

section "APT SOURCES"
if [ -f /etc/apt/sources.list ]; then
  echo
  echo "+ cat /etc/apt/sources.list"
  cat /etc/apt/sources.list
fi

echo
echo "+ find /etc/apt/sources.list.d -maxdepth 1 -type f"
find /etc/apt/sources.list.d -maxdepth 1 -type f 2>/dev/null | sort

for f in /etc/apt/sources.list.d/*; do
  [ -f "$f" ] || continue
  echo
  echo "+ cat $f"
  cat "$f"
done

section "APT SOURCES (NON-COMMENT LINES)"
echo "+ grep -Rhv '^[[:space:]]*#' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources"
grep -Rhv '^[[:space:]]*#' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true

section "PACKAGE HOLDS"
run apt-mark showhold

section "APT POLICY - OPENSSH / SCREEN / CORE"
run apt policy openssh-server openssh-client openssh-sftp-server screen ubuntu-keyring apt dpkg

section "INSTALLED PACKAGE STATES"
echo
echo "+ dpkg -l | grep -E 'screen|openssh|apt|dpkg'"
dpkg -l | grep -E 'screen|openssh|apt|dpkg' || true

section "BROKEN / HALF-INSTALLED PACKAGE AUDIT"
run dpkg --audit

echo
echo "+ dpkg -C"
dpkg -C || true

section "PACKAGE STATUS DETAILS"
echo
echo "+ dpkg -s screen"
dpkg -s screen || true

echo
echo "+ dpkg -s openssh-server"
dpkg -s openssh-server || true

echo
echo "+ dpkg -s openssh-client"
dpkg -s openssh-client || true

echo
echo "+ dpkg -s openssh-sftp-server"
dpkg -s openssh-sftp-server || true

section "SCREEN PACKAGE FILES / MAINTAINER SCRIPTS"
echo
echo "+ dpkg-query -L screen"
dpkg-query -L screen 2>/dev/null || true

for f in \
  /var/lib/dpkg/info/screen.postinst \
  /var/lib/dpkg/info/screen.prerm \
  /var/lib/dpkg/info/screen.postrm \
  /var/lib/dpkg/info/screen.list \
  /var/lib/dpkg/info/screen.md5sums
do
  echo
  echo "+ ls -l $f"
  ls -l "$f" 2>/dev/null || true
  if [ -f "$f" ]; then
    echo "+ sed -n '1,220p' $f"
    sed -n '1,220p' "$f"
  fi
done

section "APT CACHE / CANDIDATE VERSIONS"
echo
echo "+ apt-cache policy openssh-server openssh-client openssh-sftp-server screen"
apt-cache policy openssh-server openssh-client openssh-sftp-server screen || true

echo
echo "+ apt-cache madison openssh-server openssh-client openssh-sftp-server screen"
apt-cache madison openssh-server openssh-client openssh-sftp-server screen || true

section "SIMULATED INSTALL / REPAIR ACTIONS"
echo
echo "+ sudo apt -s --fix-broken install"
sudo apt -s --fix-broken install || true

echo
echo "+ sudo apt -s install openssh-server"
sudo apt -s install openssh-server || true

echo
echo "+ sudo apt -s install openssh-client openssh-sftp-server openssh-server"
sudo apt -s install openssh-client openssh-sftp-server openssh-server || true

section "UPDATE OUTPUT"
echo
echo "+ sudo apt update"
sudo apt update || true

section "POST-UPDATE POLICY"
run apt policy openssh-server openssh-client openssh-sftp-server screen

section "DPKG CONFIGURE OUTPUT"
echo
echo "+ sudo dpkg --configure -a"
sudo dpkg --configure -a || true

section "RECENT APT / DPKG LOGS"
for f in /var/log/dpkg.log /var/log/apt/history.log /var/log/apt/term.log; do
  echo
  echo "+ tail -n 200 $f"
  tail -n 200 "$f" 2>/dev/null || true
done

section "JOURNAL ENTRIES RELATED TO APT / DPKG / SCREEN / SSH"
echo
echo "+ sudo journalctl -b --no-pager | grep -Ei 'apt|dpkg|screen|openssh|ssh' | tail -n 300"
sudo journalctl -b --no-pager | grep -Ei 'apt|dpkg|screen|openssh|ssh' | tail -n 300 || true

section "DISK / FILESYSTEM / INODES"
run df -h
run df -i

section "PERMISSIONS / OWNERSHIP OF KEY APT PATHS"
for p in \
  /var/lib/dpkg \
  /var/lib/dpkg/status \
  /var/lib/apt \
  /var/cache/apt \
  /etc/apt \
  /etc/apt/sources.list.d
do
  echo
  echo "+ ls -ld $p"
  ls -ld "$p" 2>/dev/null || true
done

section "DONE"
echo "Log saved to: $LOG"
echo
echo "Recommended next step:"
echo "1) copy the full contents of this log into ChatGPT"
echo "2) if too large, paste these sections first:"
echo "   - APT SOURCES"
echo "   - PACKAGE HOLDS"
echo "   - APT POLICY - OPENSSH / SCREEN / CORE"
echo "   - BROKEN / HALF-INSTALLED PACKAGE AUDIT"
echo "   - SCREEN PACKAGE FILES / MAINTAINER SCRIPTS"
echo "   - DPKG CONFIGURE OUTPUT"
echo "   - RECENT APT / DPKG LOGS"
