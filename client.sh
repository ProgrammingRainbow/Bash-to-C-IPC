#!/usr/bin/env bash

if [ -n "$BASH_VERSION" ]; then
    echo "Running in Bash"
elif [ -n "$ZSH_VERSION" ]; then
    echo "Running in Zsh"
    echo "Setting zero array indexing."
    setopt KSH_ARRAYS
    setopt SH_WORD_SPLIT
else
    echo "Please run in Bash or Zsh."
    exit 1
fi

SERVER="ipc-server"
CLIENT="ipc-client"
SHM_DATA="/dev/shm/ipc_shared_data"
SHM_LOCK="/dev/shm/ipc_shared_lock"
SHUTDOWN_SERVER=1

# Make sure the server is compiled.
if [ ! -e "$SERVER" ]; then
    echo "Error: $SERVER is missing. Try running 'make release'."
    exit 1
fi
# Make sure the client is compiled.
if [ ! -e "$CLIENT" ]; then
    echo "Error: $CLIENT is missing. Try running 'make release'."
    exit 1
fi

# Ensure shared memory file exists
[ -e "$SHM_DATA" ] || touch "$SHM_DATA"
[ -e "$SHM_LOCK" ] || touch "$SHM_LOCK"

# Make client wait for server to clear the lock.
exec 4<>"$SHM_LOCK"
printf "\x01" >&4
exec 4>&-

# If server is already running kill it.
if pidof "$SERVER" >/dev/null; then
    echo "[CLIENT] Killing existing server..."
    killall "$SERVER"
    sleep 0.1
fi

# Start the server in shared memory mode with the script PID.
./"$SERVER" --shared $$ &
SERVER_PID=$!

# Make sure the server started.
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[CLIENT] Server failed to start. Exiting."
    exit 1
fi

ipc_quit() {
    # Remove the EXIT trap to prevent recursive cleanup.
    trap - EXIT

    if [ "$SHUTDOWN_SERVER" -ne 0 ]; then
        ipc_cmd "quit"
    fi

    # Remove shared memory from the filesystem.
    rm "$SHM_DATA" 2>/dev/null
    rm "$SHM_LOCK" 2>/dev/null

    exit "$1"
}

# If the server initiated shutdown don't shut down recursively.
trap 'SHUTDOWN_SERVER=0; ipc_quit 0' SIGUSR1
trap 'ipc_quit 0' SIGINT SIGTERM SIGQUIT EXIT

ipc_cmd() {
    case "$1" in
        get*)
            read -r reply < <(./"$CLIENT" "$1")
            ;;
        *)
            ./"$CLIENT" "$1"
            ;;
    esac
}
