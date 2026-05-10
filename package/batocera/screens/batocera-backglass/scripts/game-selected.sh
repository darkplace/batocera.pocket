#!/bin/sh

GSYSTEM=$1
GPATH=$2

txt2http() {
    jq -sRr @uri
}

GSYSTEM=$(echo -n "${GSYSTEM}" | txt2http)
GPATH=$(echo -n "${GPATH}" | txt2http)
curl --http0.9 --silent --show-error --max-time 2 "http://localhost:2033/game?system=${GSYSTEM}&path=${GPATH}" >/dev/null || true
