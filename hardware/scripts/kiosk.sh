#!/bin/bash

URL="http://192.168.168.3:8123"
# Extract IP and Port for the network check
HA_IP="192.168.168.3"
HA_PORT="8123"
PROFILE="$HOME/.config/chromium"

export DISPLAY=:0
mkdir -p /tmp/chrome-cache /tmp/chrome-media

# Keep screen always on
xset s off
xset s noblank
xset -dpms

# Clean only cache parts (keeps login)
DEFAULT="$PROFILE/Default"
rm -rf \
  "$DEFAULT/Cache" \
  "$DEFAULT/Code Cache" \
  "$DEFAULT/Service Worker" \
  "$DEFAULT/Storage/ext" \
  "$DEFAULT/GPUCache" 2>/dev/null || true

# Start Chromium
while true; do
  /usr/lib/chromium/chromium \
    --kiosk \
    --no-first-run \
    --noerrdialogs \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --disable-overlay-scrollbar \
    --user-data-dir="$PROFILE" \
    --disk-cache-dir=/tmp/chrome-cache \
    --media-cache-dir=/tmp/chrome-media \
    --hide-scrollbars \
    --force-dark-mode \
    --enable-features=WebContentsForceDark \
    --js-flags="--max-old-space-size=256" \
    --single-process \
    --disable-dev-shm-usage \
    --disable-gpu \
    "$URL"

  sleep 2
done
