#!/bin/bash
# Launcher for sm8750 Arch OTA rebuild (survives parent shell exit).
set -euo pipefail
cd /home/lukemotion/batocera.pocket
export LOG_FILE=/home/lukemotion/batocera.pocket/rebuild-sm8750-ota.log
rm -f rebuild-sm8750-ota-OK rebuild-sm8750-ota-FAILED
./rebuild-sm8750-product-lock.sh
ec=$?
if [ "$ec" -eq 0 ]; then
  echo "OK $(date)" > rebuild-sm8750-ota-OK
else
  echo "FAIL ec=$ec $(date)" > rebuild-sm8750-ota-FAILED
fi
exit "$ec"
