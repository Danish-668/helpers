#!/bin/bash
set -euo pipefail

SCRIPT_PATH="$HOME/espanso-restart-on-keyboard.sh"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="espanso-keyboard-monitor.service"

# Check dependencies
for cmd in espanso udevadm stdbuf; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd not found" >&2
        exit 1
    fi
done

# Create the monitor script
cat > "$SCRIPT_PATH" << 'MONITOR'
#!/bin/bash
# Monitor for keyboard plug-in events and restart espanso.
# Runs as a user service — no root needed.

last_restart=0

stdbuf -oL udevadm monitor --subsystem-match=input --property | while read -r line; do
    if [[ "$line" == *"ID_INPUT_KEYBOARD=1"* ]]; then
        now=$(date +%s)
        if (( now - last_restart >= 3 )); then
            last_restart=$now
            echo "Keyboard detected, restarting espanso..."
            espanso restart || true
        fi
    fi
done
MONITOR
chmod +x "$SCRIPT_PATH"

# Create the systemd user service
mkdir -p "$SERVICE_DIR"
cat > "$SERVICE_DIR/$SERVICE_NAME" << EOF
[Unit]
Description=Restart espanso on keyboard plug-in
After=espanso.service

[Service]
ExecStart=$SCRIPT_PATH
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME"

echo "Done. Check status with: systemctl --user status $SERVICE_NAME"
