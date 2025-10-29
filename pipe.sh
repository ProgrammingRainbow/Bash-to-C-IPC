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
PIPE_TO_SERVER="/tmp/ipc_pipe_to_server"
PIPE_FROM_SERVER="/tmp/ipc_pipe_from_server"
SHUTDOWN_SERVER=1

# Make sure the server is compiled.
if [ ! -e "$SERVER" ]; then
    echo "Error: $SERVER is missing. Try running 'make release'."
    exit 1
fi

# Create named pipes if needed
[ -p "$PIPE_TO_SERVER" ] || mkfifo "$PIPE_TO_SERVER"
[ -p "$PIPE_FROM_SERVER" ] || mkfifo "$PIPE_FROM_SERVER"

# Start the server in pipe mode with the script PID.
./"$SERVER" --pipe $$ &
SERVER_PID=$!

# Make sure the server started.
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[CLIENT] Server failed to start. Exiting."
    exit 1
fi

# Open both pipes once and keep them open.
exec 3> "$PIPE_TO_SERVER"
exec 4< "$PIPE_FROM_SERVER"

ipc_quit() {
    # Remove the EXIT trap to prevent recursive cleanup.
    trap - EXIT

    if [ "$SHUTDOWN_SERVER" -ne 0 ]; then
        ipc_cmd "quit"
    fi

    # Close file descriptors used for the pipes.
    exec 3>&- 2>/dev/null
    exec 4<&- 2>/dev/null

    # Remove named pipes from the filesystem.
    rm "$PIPE_TO_SERVER" 2>/dev/null
    rm "$PIPE_FROM_SERVER" 2>/dev/null

    exit "$1"
}

# If the server initiated shutdown don't shut down recursively.
trap 'SHUTDOWN_SERVER=0; ipc_quit 0' SIGUSR1
trap 'ipc_quit 0' SIGINT SIGTERM SIGQUIT EXIT

ipc_cmd() {
    # Send argument 1 to named pipe in.
    echo "$1" >&3 || sg_quit 1

    # If cmd starts with get read named pipe to global variable reply (Blocking).
    [[ $1 == get* ]] && read -r -u 4 reply
}
