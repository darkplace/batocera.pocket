#!/bin/bash
# RETIRED — batocera.pocket builds are Docker-only.
# See docs/BUILD.md. Former Arch tree: output/sm8750-arch-backup (removed).
echo "ERROR: build-arch-persistent.sh is retired. Use Docker:" >&2
echo "  make sm8750-build DIRECT_BUILD= PARALLEL_BUILD= BATCH_MODE=1" >&2
exit 1
