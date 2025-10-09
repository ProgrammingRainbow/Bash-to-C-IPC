#!/bin/env bash

if [ $# == 1 ]; then
    case $1 in
        --client) source client.sh ;;
        --shared) source shared.sh ;;
        --socket) source socket.sh ;;
        --pipe) source pipe.sh ;;
        *)
            echo "Usage: $0 {--pipe|--socket|--shared|--client}"
            exit 1
            ;;
    esac
else
    echo "Usage: $0 {--pipe|--socket|--shared|--client}"
    exit 1
fi

total_send=100000
total_received=0

for ((i=1; i<=total_send; i++)); do
    send_server $i
    if (( reply == i )); then
        total_received=$((total_received + 1))
    else
        echo "[CLIENT] Error $reply did not equal $i"
        cleanup 1
    fi
done

echo "Total received: $total_received of $total_send"

cleanup 0
