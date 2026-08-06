# Build configuration for batocera.pocket
# Based on upstream darkplace/Batocera-Custom-Qualcomm-Builds

# Parallel build settings
MAKE_JLEVEL := 12
MAKE_LLEVEL := 12
PARALLEL_BUILD := y

# Docker configuration (use suckbluefrog's image)
DOCKER_REPO := batoceralinux
IMAGE_NAME := batocera.linux-build
