#!/usr/bin/env bash

if [ -n "$BASH_VERSION" ]; then
    echo "Running in Bash"
elif [ -n "$ZSH_VERSION" ]; then
    echo "Running in Zsh"
    echo "Setting zero array indexing."
    setopt KSH_ARRAYS
else
    echo "Please run in Bash or Zsh."
    exit 1
fi

SERVER="ipc-server"
SHM_DATA="/dev/shm/ipc_shared_data"
SHM_LOCK="/dev/shm/ipc_shared_lock"
SHUTDOWN_SERVER=1

# Make sure the server is compiled.
if [ ! -e $SERVER ]; then
    echo "Error: $SERVER is missing. Try running 'make release'."
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
if pidof "$SERVER_NAME" >/dev/null; then
    echo "[CLIENT] Killing existing server..."
    killall "$SERVER_NAME"
    sleep 0.1
fi

# Start the server in shared memory mode with the script PID.
./$SERVER --shared $$ &
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
trap 'SHUTDOWN_SERVER=0; ipc_quit 1' SIGUSR2
trap 'SHUTDOWN_SERVER=0; ipc_quit 0' SIGUSR1
trap 'ipc_quit 0' SIGINT SIGTERM SIGQUIT EXIT

ipc_cmd() {
    while true; do
        # Check lock status.
        exec 4<>"$SHM_LOCK"
        read -r -n1 -u 4 status
        exec 4<&-

        # If status is not free loop.
        [[ "$status" != $'\x00' ]] && continue

        # Send argument to the shared data.
        exec 3<>"$SHM_DATA"
        printf "%s\x00" "$1" >&3
        exec 3>&-

        # Set shared lock.
        exec 4<>"$SHM_LOCK"
        printf "\x01" >&4
        exec 4>&-
        
        # Read named pipe to global variable reply or array (Blocking).
        case "$1" in
            get*|new*)
                while true; do
                    # Check lock status again.
                    exec 4<>"$SHM_LOCK"
                    read -r -n1 -u 4 status
                    exec 4<&-

                    if [[ "$status" == $'\x02' ]]; then
                        # Read from shared data to global reply.
                        exec 3<>"$SHM_DATA"
                        read -r -u 3 reply
                        exec 3<&-

                        # Unset shared lock.
                        exec 4<>"$SHM_LOCK"
                        printf "\x00" >&4
                        exec 4>&-

                        break
                    fi
                done
                ;;
            arr*|free*)
                while true; do
                    # Check lock status again.
                    exec 4<>"$SHM_LOCK"
                    read -r -n1 -u 4 status
                    exec 4<&-

                    if [[ "$status" == $'\x02' ]]; then
                        # Read from shared data to global reply.
                        exec 3<>"$SHM_DATA"
                        read -r -u 3 line
                        array=($line)
                        exec 3<&-

                        # Unset shared lock.
                        exec 4<>"$SHM_LOCK"
                        printf "\x00" >&4
                        exec 4>&-

                        break
                    fi
                done
                ;;
        esac
        break
    done
}
