#!/bin/env bash

SERVER="server"
SOCKET_PATH="/tmp/my_socket"

# Make sure the server is compiled.
if [ ! -e $SERVER ]; then
    echo "Error: $SERVER is missing. Try running 'make release'."
    exit 1
fi

cleanup() {
    # Remove the EXIT trap to prevent recursive cleanup.
    trap - EXIT

    # If the server process is still running, send shutdown signal.
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[CLIENT] Send shutdown signal to server."
        echo "-2" >&"$SOCKET_OUT"
    fi

    # Close the socket file descriptors.
    exec {SOCKET_OUT}>&- 2>/dev/null
    exec {SOCKET_IN}<&- 2>/dev/null

    exit "$1"
}

# Register cleanup function to run on script exit
trap 'cleanup 0' EXIT

# Start the C server in the background.
./$SERVER --socket &
SERVER_PID=$!

# Make sure the server started and wait for the socket.
while [[ ! -e "$SOCKET_PATH" ]]; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "Daemon exited unexpectedly. Exiting."
        exit 1
    fi
    sleep 0.1
done

# Open bidirectional socket connection to server using socat coprocess.
coproc SOCKET { socat - UNIX-CONNECT:"$SOCKET_PATH"; }
SOCKET_IN=${SOCKET[0]}
SOCKET_OUT=${SOCKET[1]}

send_server() {
    # Send argument 1 to socket.
    echo "$1" >&"$SOCKET_OUT" || cleanup 1
    # Read socket to global variable reply (Blocking).
    read -r reply <&"$SOCKET_IN"
}
