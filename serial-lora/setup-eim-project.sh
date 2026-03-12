#!/bin/sh

# This script walks you through activating ESP-IDF, creating a project,
# building, flashing and monitoring a "hello_world" example using the EIM-
# installed toolchain.

set -e

# 1. Activate environment ---------------------------------------------------

echo "\n=== 1. Activate ESP-IDF environment ==="
echo "The EIM installer prints a line such as:"
echo "    source \"/path/to/.espressif/tools/activate_idf_vX.Y.Z.sh\""
echo "If you haven't already sourced it, please provide the path below."

printf 'Activation script (leave empty to skip): '
read -r ACT_PATH
if [ -n "$ACT_PATH" ]; then
    if [ -f "$ACT_PATH" ]; then
        echo "sourcing $ACT_PATH"
        # shellcheck source=/dev/null
        . "$ACT_PATH"
    else
        echo "warning: file not found: $ACT_PATH"
    fi
fi

# ensure IDF_PATH is set
: "${IDF_PATH:=}">
if [ -z "$IDF_PATH" ]; then
    echo "IDF_PATH is empty. Please set IDF_PATH to your ESP-IDF install location."
    printf 'IDF_PATH (e.g. $HOME/esp-idf): '
    read -r IDF_PATH
    export IDF_PATH
fi

echo "IDF_PATH is $IDF_PATH"

# 2. Start a project --------------------------------------------------------

echo "\n=== 2. Create hello_world project ==="
echo "Projects must not live in paths containing spaces."

DEFAULT_BASE="$HOME/esp"
printf 'Base directory for projects [%s]: ' "$DEFAULT_BASE"
read -r BASE_DIR
BASE_DIR=${BASE_DIR:-$DEFAULT_BASE}
mkdir -p "$BASE_DIR"

echo "copying example"
if [ -d "$IDF_PATH/examples/get-started/hello_world" ]; then
    cp -r "$IDF_PATH/examples/get-started/hello_world" "$BASE_DIR"/
    PROJECT_DIR="$BASE_DIR/hello_world"
    echo "project copied to $PROJECT_DIR"
else
    echo "error: example directory not found under $IDF_PATH"
    exit 1
fi

# 3. Connect device ---------------------------------------------------------

echo "\n=== 3. Connect your ESP32 board ==="
echo "Plug the board in now, then press ENTER."
read -r

echo "Available serial ports (Linux/macOS):"
ls /dev/tty* /dev/cu* 2>/dev/null || true
printf 'Enter port name to use (e.g. /dev/ttyUSB0): '
read -r PORT

# 4. Configure project ------------------------------------------------------

echo "\n=== 4. Configure project ==="
cd "$PROJECT_DIR"

# set target (clears existing build/config)
idf.py set-target esp32

echo "Launching menuconfig (make any changes, then exit)"
idf.py menuconfig

echo "menuconfig done"

# 5. Build ------------------------------------------------------------------

echo "\n=== 5. Build project ==="
idf.py build

echo "build finished. You can flash with 'idf.py -p PORT flash' or simply" \
     "run the next step from this script."

# 6. Flash ------------------------------------------------------------------

echo "\n=== 6. Flash to device ==="
printf 'Flash now? [y/N] '
read -r ANS
ANS=${ANS,,}
if [ "$ANS" = y ] || [ "$ANS" = yes ]; then
    if [ -n "$PORT" ]; then
        idf.py -p "$PORT" flash
    else
        idf.py flash
    fi
else
    echo "skipping flash."
fi

# 7. Monitor ----------------------------------------------------------------

echo "\n=== 7. Monitor output ==="
printf 'Run idf.py monitor now? [y/N] '
read -r ANS
ANS=${ANS,,}
if [ "$ANS" = y ] || [ "$ANS" = yes ]; then
    if [ -n "$PORT" ]; then
        idf.py -p "$PORT" monitor
    else
        idf.py monitor
    fi
else
    echo "done. you can manually start the monitor later."
fi

# Additional notes

echo "\nNotes:"
echo " * If monitor output is garbled, try re-running menuconfig and set" \
     "CONFIG_XTAL_FREQ appropriately (26 or 40MHz)."
echo " * If you get permission denied on the serial port, add yourself to" \
     "   the dialout/uucp group or run 'sudo chmod a+rw $PORT'."
echo " * To erase flash: idf.py -p $PORT erase-flash"

echo "\nAll steps complete. You're now ready to explore other examples or" \
     "start your own application."
