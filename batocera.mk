# Build configuration for batocera.pocket
#
# Canonical / maintainer flow (Docker + Ubuntu image) — all three boards:
#   make sm8750-build
#   make sm8550-build
#   make sm8250-build
# (see docs/BUILD.md for DIRECT_BUILD= PARALLEL_BUILD= BATCH_MODE=1 flags)
#
# Arch DIRECT_BUILD is emergency-only for sm8750; tree lives at
# output/sm8750-arch-backup (see docs/BUILD.md and ./build-arch-persistent.sh).
#
# Do NOT set DIRECT_BUILD here.
# Do NOT force PARALLEL_BUILD here — it breaks virtual provides
# (e.g. host-openssl vs host-libopenssl) and is not the stock Docker path.

# Match host CPU threads (this machine: 12). Override on CLI if needed.
MAKE_JLEVEL := 12
MAKE_LLEVEL := 12

DOCKER_REPO := batoceralinux
IMAGE_NAME := batocera.linux-build
