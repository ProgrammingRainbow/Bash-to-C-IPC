#!/bin/env bash

SERVER="server"
PIPE_TO_SERVER="/tmp/my_pipe_to_server"
PIPE_FROM_SERVER="/tmp/my_pipe_from_server"

# Make sure the server is compiled.
if [ ! -e $SERVER ]; then
    echo "Error: $SERVER is missing. Try running 'make release'."
    exit 1
fi

# Create named pipes if needed
[[ -p "$PIPE_TO_SERVER" ]] || mkfifo "$PIPE_TO_SERVER"
[[ -p "$PIPE_FROM_SERVER" ]] || mkfifo "$PIPE_FROM_SERVER"

# Start the C server in the background.
./$SERVER --pipe &
SERVER_PID=$!

# Make sure the server started.
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[CLIENT] Server failed to start."
    exit 1
fi

# Open both pipes once and keep them open.
exec {TO_SERVER}> "$PIPE_TO_SERVER"
exec {FROM_SERVER}< "$PIPE_FROM_SERVER"

cleanup() {
    # Remove the EXIT trap to prevent recursive cleanup.
    trap - EXIT

    # If the server process is still running, send shutdown signal.
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[CLIENT] Send shutdown signal to server."
        echo "-2" >&$TO_SERVER
    fi

    # Close file descriptors used for the pipes.
    exec {TO_SERVER}>&- 2>/dev/null
    exec {FROM_SERVER}<&- 2>/dev/null

    # Remove named pipes from the filesystem.
    rm "$PIPE_TO_SERVER"
    rm "$PIPE_FROM_SERVER"

    exit "$1"
}

# Register cleanup function to run on script exit
trap 'cleanup 0' EXIT

send_server() {
    # Send argument 1 to named pipe in.
    echo "$1" >&$TO_SERVER || cleanup 1
    # Read named pipe out to global variable reply (Blocking).
    read -r reply <&$FROM_SERVER
}
