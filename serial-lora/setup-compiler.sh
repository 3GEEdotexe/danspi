echo "deb [trusted=yes] https://dl.espressif.com/dl/eim/apt/ stable main" | sudo tee /etc/apt/sources.list.d/espressif.list

sudo apt update

echo "=================================================="
echo "ESP (Expressif) IDF (IoT Devepolment Framework) Installation"
echo "Debian-Based Linux Installation via APT"
echo "=================================================="

if ! command -v apt >/dev/null 2>&1; then
  echo "This script is for Debian/Ubuntu systems with apt."
  exit 1
fi

echo "Add the EIM repository to your APT sources list to make it available for installation."
echo "deb [trusted=yes] https://dl.espressif.com/dl/eim/apt/ stable main" | sudo tee /etc/apt/sources.list.d/espressif.list
sudo apt update

echo "Install the EIM Command Line Interface (CLI) via APT."
sudo apt install eim

echo "Add the EIM repository to your DNF sources list to make it available for installation."
sudo tee /etc/yum.repos.d/espressif-eim.repo << 'EOF'
[eim]
name=ESP-IDF Installation Manager
baseurl=https://dl.espressif.com/dl/eim/rpm/$basearch
enabled=1
gpgcheck=0
EOF

echo "Install the EIM Command Line Interface (CLI) via DNF."
sudo dnf install eim

# =================== installation instructions ===================
echo "Online Installation Using EIM CLI"
echo

echo "This helper now walks you through the commands instead of merely" \
     "printing them.  Choose an option below:"
echo

echo "  1) non-interactive install (eim install)"
echo "  2) interactive wizard (eim wizard)"
echo "  3) install specific version (eim install -i <id>)"
echo "  4) show help and quit"
echo

while :; do
    printf 'Select an option [1-4]: '
    read -r choice
    case "$choice" in
        1)
            echo "running non-interactive install..."
            eim install
            break
            ;;
        2)
            echo "starting interactive wizard..."
            eim wizard
            break
            ;;
        3)
            printf 'Enter version identifier (e.g. v5.4.2): '
            read -r ver
            if [ -n "$ver" ]; then
                echo "installing version $ver..."
                eim install -i "$ver"
            else
                echo "no version entered, aborting."
            fi
            break
            ;;
        4)
            echo "showing help..."
            eim --help
            exit 0
            ;;
        *)
            echo "invalid choice, please enter 1-4."
            ;;
    esac
done

echo "When you install ESP-IDF, the installer automatically saves your setup to a configuration file named eim_config.toml in the installation directory. This configuration file can be reused on other computers to reproduce the same installation setup."
echo "Complete"d! You can now use the EIM CLI to manage your ESP-IDF installations. For example, you can run 'eim list' to see all installed versions, or 'eim use <version>' to switch between them. Happy coding with ESP-IDF!"