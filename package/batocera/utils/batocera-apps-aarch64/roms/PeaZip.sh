#!/bin/bash
set -euo pipefail
batocera-mouse show
trap 'batocera-mouse hide' EXIT
exec batocera-app-peazip
