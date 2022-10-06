#!/bin/bash

DURATION=$(</dev/stdin)
if (($DURATION <= 4000)); then
    echo "JAM Web UI may take a while to start, please be patient..."
    exit 60
else
    if curl --silent --fail jam.embassy &>/dev/null; then
        echo "JAM Web UI is unreachable" >&2
        exit 1
    fi
fi
