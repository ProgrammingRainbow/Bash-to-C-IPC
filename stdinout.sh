#!/usr/bin/env bash

IPC_SHELL=0
if [ -n "$BASH_VERSION" ]; then
    echo "Running in Bash"
elif [ -n "$ZSH_VERSION" ]; then
    echo "Running in Zsh"
    echo "Setting zero array indexing."
    setopt KSH_ARRAYS
    setopt SH_WORD_SPLIT
    IPC_SHELL=1
else
    echo "Please run in Bash or Zsh."
    exit 1
fi

SERVER="ipc-server"
SHUTDOWN_SERVER=1

# Make sure the server is compiled.
if [ ! -e "$SERVER" ]; then
    echo "Error: $SERVER is missing. Try running 'make release'."
    exit 1
fi

# Start the server in a coprocess using --stdin mode.
if [ "$IPC_SHELL" -eq 1 ]; then
    # Zsh assigns the coprocess file descriptor to $SERVER_PROC
    coproc { ./"$SERVER" --stdinout $$; }
    # Write to server's stdin
    exec 3>&p
    # Read from server's stdout
    exec 4<&p
else
    # Bash version.
    eval 'coproc SERVER_PROC { ./"$SERVER" --stdinout $$; }'
    # Write to server's stdin
    exec 3>&"${SERVER_PROC[1]}"
    # Read from server's stdout
    exec 4<&"${SERVER_PROC[0]}"
fi

ipc_quit() {
    # Remove the EXIT trap to prevent recursive cleanup.
    trap - EXIT

    if [ "$SHUTDOWN_SERVER" -ne 0 ]; then
        ipc_cmd "quit"
    fi

    # Close file descriptors.
    exec 3>&- 2>/dev/null
    exec 4<&- 2>/dev/null

    exit "$1"
}

# If the server initiated shutdown don't shut down recursively.
trap 'SHUTDOWN_SERVER=0; ipc_quit 0' SIGUSR1
trap 'ipc_quit 0' SIGINT SIGTERM SIGQUIT EXIT

ipc_cmd() {
    # Send argument 1 to stdin.
    echo "$1" >&3 || ipc_quit 1

    # If cmd starts with get read stdin to global variable reply (Blocking).
    [[ $1 == get* ]] && read -r -u 4 reply
}
