# Build configuration for batocera.pocket (Arch host, Odin 3 / sm8750 tree)
#
# Canonical command (same method that produced the working Odin image):
#   ./build-arch-persistent.sh
#   # or:
#   make sm8750-build DIRECT_BUILD=y PARALLEL_BUILD=y MAKE_JLEVEL=20
#
# Do NOT continue this output/sm8750 tree inside Docker: host tools were
# linked against Arch glibc and break under the Ubuntu build image.

MAKE_JLEVEL := 20
MAKE_LLEVEL := 20
PARALLEL_BUILD := y

DOCKER_REPO := batoceralinux
IMAGE_NAME := batocera.linux-build
