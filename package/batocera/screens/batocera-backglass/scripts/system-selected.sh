#!/bin/sh

GSYSTEM=$1

txt2http() {
    jq -sRr @uri
}

GSYSTEM=$(echo -n "${GSYSTEM}" | txt2http)
curl --http0.9 --silent --show-error --max-time 2 "http://localhost:2033/system?system=${GSYSTEM}" >/dev/null || true
