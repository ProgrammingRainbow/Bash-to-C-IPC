#!/bin/env bash

SERVER="server"
CLIENT="client"
SHM_DATA="/dev/shm/my_shared_data"
SHM_LOCK="/dev/shm/my_shared_lock"

# Make sure the server is compiled.
if [ ! -e $SERVER ]; then
    echo "Error: $SERVER is missing. Try running 'make release'."
    exit 1
fi
# Make sure the client is compiled.
if [ ! -e $CLIENT ]; then
    echo "Error: $CLIENT is missing. Try running 'make release'."
    exit 1
fi

# Ensure shared memory file exists
[[ -e "$SHM_DATA" ]] || touch "$SHM_DATA"
[[ -e "$SHM_LOCK" ]] || touch "$SHM_LOCK"

# If server is already running kill it.
if pidof "$SERVER" >/dev/null; then
    echo "[CLIENT] Killing existing server..."
    killall "$SERVER"
    sleep 0.1
fi

# Start the C server in the background.
./$SERVER --shared &
SERVER_PID=$!

# Make sure the server started.
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[CLIENT] Server failed to start. Exiting."
    exit 1
fi

cleanup() {
    # Remove the EXIT trap to prevent recursive cleanup.
    trap - EXIT

    # If the server process is still running, send shutdown signal.
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[CLIENT] Send shutdown signal to server."
        ./$CLIENT "shutdown"
    fi

    # Remove shared memory from the filesystem.
    rm "$SHM_DATA" 2>/dev/null
    rm "$SHM_LOCK" 2>/dev/null

    exit $1
}

# Register cleanup function to run on script exit
trap 'cleanup 0' EXIT

# send_server() {
#     reply=$(./$CLIENT $1)
# }

send_server() {
    read -r reply < <("./$CLIENT" "$1")
}
