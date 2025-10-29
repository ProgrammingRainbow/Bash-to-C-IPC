#!/usr/bin/env bash

# Option for choosing communication to server.
if [[ $# -eq 1 ]]; then
    case $1 in
        --client|--shared|--socket|--stdinout|--pipe)
            source "${1#--}.sh" || {
                echo "Error: Failed to source file for '$1'"
                exit 1
            }
            ;;
        *)
            echo "Usage: $0 {--pipe|--stdinout|--socket|--shared|--client}"
            exit 1
            ;;
    esac
else
    echo "Usage: $0 {--pipe|--stdinout|--socket|--shared|--client}"
    exit 1
fi

total_send=1000000
total_received=0

for ((i=1; i <= total_send; i++)); do
    ipc_cmd "set $(( i + 10 ))" # Send to the server without reply.
    ipc_cmd "get $i" # Send to the server with reply.
    if (( reply == i )); then
        total_received=$((total_received + 1))
    else
        echo "Error $reply did not equal $i"
        ipc_quit 1
    fi
done

echo "Total received: $total_received of $total_send"

ipc_quit 0
