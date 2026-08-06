# Build configuration for batocera.pocket
# Based on upstream darkplace/Batocera-Custom-Qualcomm-Builds

# Parallelism without forcing BR2_PER_PACKAGE_DIRECTORIES (PARALLEL_BUILD=y
# appends that and breaks fresh/partial trees missing per-package host tools).
MAKE_JLEVEL := 12
MAKE_LLEVEL := 12
MAKE_OPTS += -j$(MAKE_JLEVEL) -l$(MAKE_LLEVEL)

# Docker configuration (use suckbluefrog's image)
DOCKER_REPO := batoceralinux
IMAGE_NAME := batocera.linux-build
