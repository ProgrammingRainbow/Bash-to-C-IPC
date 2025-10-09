#!/bin/env bash

SERVER="server"
SHM_DATA="/dev/shm/my_shared_data"
SHM_LOCK="/dev/shm/my_shared_lock"

# Make sure the server is compiled.
if [ ! -e $SERVER ]; then
    echo "Error: $SERVER is missing. Try running 'make release'."
    exit 1
fi

# Ensure shared memory file exists
[[ -e "$SHM_DATA" ]] || touch "$SHM_DATA"
[[ -e "$SHM_LOCK" ]] || touch "$SHM_LOCK"

# Make client wait for server to clear the lock.
exec {FD_LOCK}<>"$SHM_LOCK"
printf "\x01" >&$FD_LOCK
exec {FD_LOCK}>&-

# If server is already running kill it.
if pidof "$SERVER_NAME" >/dev/null; then
    echo "[CLIENT] Killing existing server..."
    killall "$SERVER_NAME"
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
        exec {FD_LOCK}<>"$SHM_LOCK"
        printf "\x03" >&$FD_LOCK
        exec {FD_LOCK}>&-
    fi

    # Remove shared memory from the filesystem.
    rm "$SHM_DATA" 2>/dev/null
    rm "$SHM_LOCK" 2>/dev/null

    exit $1
}

# Register cleanup function to run on script exit
trap 'cleanup 0' EXIT

send_server() {
    while true; do
        # Check lock status.
        exec {FD_LOCK}<>"$SHM_LOCK"
        read -r -n1 -u $FD_LOCK status
        exec {FD_LOCK}<&-

        # If status is not free loop.
        [[ "$status" != $'\x00' ]] && continue

        # Send argument to the shared data.
        exec {FD_DATA}<>"$SHM_DATA"
        printf "%s\n" "$1" >&$FD_DATA
        exec {FD_DATA}>&-

        # Set shared lock.
        exec {FD_LOCK}<>"$SHM_LOCK"
        printf "\x01" >&$FD_LOCK
        exec {FD_LOCK}>&-

        while true; do
            # Check lock status again.
            exec {FD_LOCK}<>"$SHM_LOCK"
            read -r -n1 -u $FD_LOCK status
            exec {FD_LOCK}<&-

            if [[ "$status" == $'\x02' ]]; then
                # Read from shared data to global reply.
                exec {FD_DATA}<>"$SHM_DATA"
                read -r -u $FD_DATA reply
                exec {FD_DATA}<&-

                # Unset shared lock.
                exec {FD_LOCK}<>"$SHM_LOCK"
                printf "\x00" >&$FD_LOCK
                exec {FD_LOCK}>&-

                break
            fi
        done
        break
    done
}
