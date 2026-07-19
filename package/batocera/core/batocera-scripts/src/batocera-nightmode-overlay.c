#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-layer-shell-unstable-v1-client-protocol.h"

struct state;

struct output_surface {
    struct state *state;
    struct wl_output *output;
    struct wl_surface *surface;
    struct zwlr_layer_surface_v1 *layer_surface;
    struct wl_buffer *buffer;
    void *buffer_data;
    size_t buffer_size;
    int buffer_busy;
    uint32_t width;
    uint32_t height;
    struct output_surface *next;
};

struct state {
    struct wl_display *display;
    struct wl_registry *registry;
    struct wl_compositor *compositor;
    struct wl_shm *shm;
    struct zwlr_layer_shell_v1 *layer_shell;
    struct output_surface *outputs;
    int intensity;
    int mapped_outputs;
};

static volatile sig_atomic_t stop_requested;
static volatile sig_atomic_t unmap_requested;

static void handle_signal(int signal_number)
{
    (void)signal_number;
    unmap_requested = 1;
    stop_requested = 1;
}

static int parse_intensity(const char *value)
{
    char *end = NULL;
    long parsed;

    if (value == NULL || *value == '\0')
        return 55;

    errno = 0;
    parsed = strtol(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0')
        return 55;

    if (parsed < 0)
        return 0;
    if (parsed > 100)
        return 100;

    return (int)parsed;
}

static int create_temp_file(size_t size)
{
    char template[] = "/tmp/batocera-nightmode-overlay.XXXXXX";
    int fd;

    fd = mkstemp(template);
    if (fd < 0)
        return -1;

    unlink(template);
    if (ftruncate(fd, (off_t)size) < 0) {
        close(fd);
        return -1;
    }

    return fd;
}

static uint8_t premultiply(uint8_t value, uint8_t alpha)
{
    return (uint8_t)(((unsigned int)value * (unsigned int)alpha + 127U) / 255U);
}

static uint32_t overlay_pixel(int intensity)
{
    double amount = (double)intensity / 100.0;
    uint8_t alpha = (uint8_t)((255.0 * 0.22 * amount) + 0.5);
    uint8_t red = premultiply(255, alpha);
    uint8_t green = premultiply(140, alpha);
    uint8_t blue = premultiply(0, alpha);

    return ((uint32_t)alpha << 24) |
           ((uint32_t)red << 16) |
           ((uint32_t)green << 8) |
           (uint32_t)blue;
}

static void destroy_buffer(struct output_surface *output)
{
    if (output->buffer != NULL)
        wl_buffer_destroy(output->buffer);
    if (output->buffer_data != MAP_FAILED && output->buffer_data != NULL)
        munmap(output->buffer_data, output->buffer_size);

    output->buffer = NULL;
    output->buffer_data = NULL;
    output->buffer_size = 0;
    output->buffer_busy = 0;
}

static void buffer_release(void *data, struct wl_buffer *buffer)
{
    struct output_surface *output = data;

    (void)buffer;
    output->buffer_busy = 0;
}

static const struct wl_buffer_listener buffer_listener = {
    .release = buffer_release,
};

static int draw_overlay(struct output_surface *output, uint32_t width, uint32_t height)
{
    struct wl_shm_pool *pool;
    uint32_t *pixels;
    uint32_t pixel;
    size_t stride;
    size_t size;
    size_t i;
    int fd;

    if (width == 0 || height == 0)
        return 0;
    if (output->buffer_busy)
        return 0;

    destroy_buffer(output);

    stride = (size_t)width * 4U;
    size = stride * (size_t)height;
    fd = create_temp_file(size);
    if (fd < 0)
        return -1;

    output->buffer_data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (output->buffer_data == MAP_FAILED) {
        close(fd);
        return -1;
    }
    output->buffer_size = size;

    pixels = output->buffer_data;
    pixel = overlay_pixel(output->state->intensity);
    for (i = 0; i < size / sizeof(uint32_t); i++)
        pixels[i] = pixel;

    pool = wl_shm_create_pool(output->state->shm, fd, (int32_t)size);
    output->buffer = wl_shm_pool_create_buffer(pool, 0, (int32_t)width,
                                               (int32_t)height, (int32_t)stride,
                                               WL_SHM_FORMAT_ARGB8888);
    wl_buffer_add_listener(output->buffer, &buffer_listener, output);
    wl_shm_pool_destroy(pool);
    close(fd);

    wl_surface_attach(output->surface, output->buffer, 0, 0);
    wl_surface_damage_buffer(output->surface, 0, 0, (int32_t)width, (int32_t)height);
    wl_surface_commit(output->surface);
    output->buffer_busy = 1;

    return 0;
}

static void layer_configure(void *data, struct zwlr_layer_surface_v1 *surface,
                            uint32_t serial, uint32_t width, uint32_t height)
{
    struct output_surface *output = data;

    zwlr_layer_surface_v1_ack_configure(surface, serial);
    output->width = width;
    output->height = height;

    if (draw_overlay(output, width, height) == 0 && width > 0 && height > 0)
        output->state->mapped_outputs++;
}

static void layer_closed(void *data, struct zwlr_layer_surface_v1 *surface)
{
    (void)data;
    (void)surface;
    stop_requested = 1;
}

static const struct zwlr_layer_surface_v1_listener layer_listener = {
    .configure = layer_configure,
    .closed = layer_closed,
};

static void refresh_outputs(struct state *state)
{
    struct output_surface *output;
    int refreshed = 0;

    for (output = state->outputs; output != NULL; output = output->next) {
        if (output->surface == NULL || output->buffer == NULL ||
            output->width == 0 || output->height == 0)
            continue;

        wl_surface_damage_buffer(output->surface, 0, 0,
                                 (int32_t)output->width, (int32_t)output->height);
        wl_surface_commit(output->surface);
        refreshed++;
    }

    if (refreshed > 0)
        wl_display_flush(state->display);
}

static int dispatch_until_stopped(struct state *state)
{
    struct pollfd poll_fd = {
        .fd = wl_display_get_fd(state->display),
        .events = POLLIN,
    };
    unsigned int refresh_ticks = 0;

    while (!stop_requested) {
        int result;

        if (wl_display_dispatch_pending(state->display) < 0)
            return -1;
        if (stop_requested)
            break;

        poll_fd.revents = 0;
        result = poll(&poll_fd, 1, 100);
        if (result < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        if (result == 0) {
            if (++refresh_ticks >= 10) {
                refresh_outputs(state);
                refresh_ticks = 0;
            }
            continue;
        }
        if ((poll_fd.revents & (POLLERR | POLLHUP | POLLNVAL)) != 0)
            return -1;
        if ((poll_fd.revents & POLLIN) != 0 &&
            wl_display_dispatch(state->display) < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
    }

    return 0;
}

static void registry_add(void *data, struct wl_registry *registry, uint32_t name,
                         const char *interface, uint32_t version)
{
    struct state *state = data;

    if (strcmp(interface, wl_compositor_interface.name) == 0) {
        uint32_t bind_version = version < 4 ? version : 4;
        state->compositor = wl_registry_bind(registry, name, &wl_compositor_interface,
                                             bind_version);
    } else if (strcmp(interface, wl_shm_interface.name) == 0) {
        state->shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
    } else if (strcmp(interface, wl_output_interface.name) == 0) {
        struct output_surface *output = calloc(1, sizeof(*output));
        uint32_t bind_version = version < 2 ? version : 2;

        if (output == NULL)
            return;

        output->state = state;
        output->buffer_data = NULL;
        output->output = wl_registry_bind(registry, name, &wl_output_interface,
                                          bind_version);
        output->next = state->outputs;
        state->outputs = output;
    } else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
        uint32_t bind_version = version < 4 ? version : 4;
        state->layer_shell = wl_registry_bind(registry, name,
                                              &zwlr_layer_shell_v1_interface,
                                              bind_version);
    }
}

static void registry_remove(void *data, struct wl_registry *registry, uint32_t name)
{
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_add,
    .global_remove = registry_remove,
};

static void create_surface(struct output_surface *output)
{
    struct wl_region *region;

    output->surface = wl_compositor_create_surface(output->state->compositor);
    region = wl_compositor_create_region(output->state->compositor);
    wl_surface_set_input_region(output->surface, region);
    wl_region_destroy(region);

    output->layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        output->state->layer_shell, output->surface, output->output,
        ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "batocera-nightmode");
    zwlr_layer_surface_v1_add_listener(output->layer_surface, &layer_listener, output);
    zwlr_layer_surface_v1_set_anchor(
        output->layer_surface,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
            ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT |
            ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
            ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT);
    zwlr_layer_surface_v1_set_exclusive_zone(output->layer_surface, -1);
    zwlr_layer_surface_v1_set_keyboard_interactivity(
        output->layer_surface, ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE);
    zwlr_layer_surface_v1_set_size(output->layer_surface, 0, 0);
    wl_surface_commit(output->surface);
}

static void unmap_outputs(struct state *state)
{
    struct output_surface *output;
    int unmap_count = 0;

    for (output = state->outputs; output != NULL; output = output->next) {
        if (output->surface == NULL)
            continue;

        wl_surface_attach(output->surface, NULL, 0, 0);
        wl_surface_commit(output->surface);
        unmap_count++;
    }

    if (unmap_count > 0)
        wl_display_roundtrip(state->display);
}

static void cleanup(struct state *state)
{
    struct output_surface *output = state->outputs;

    while (output != NULL) {
        struct output_surface *next = output->next;

        destroy_buffer(output);
        if (output->layer_surface != NULL)
            zwlr_layer_surface_v1_destroy(output->layer_surface);
        if (output->surface != NULL)
            wl_surface_destroy(output->surface);
        if (output->output != NULL)
            wl_output_destroy(output->output);
        free(output);
        output = next;
    }

    if (state->layer_shell != NULL)
        zwlr_layer_shell_v1_destroy(state->layer_shell);
    if (state->shm != NULL)
        wl_shm_destroy(state->shm);
    if (state->compositor != NULL)
        wl_compositor_destroy(state->compositor);
    if (state->registry != NULL)
        wl_registry_destroy(state->registry);
    if (state->display != NULL) {
        wl_display_flush(state->display);
        wl_display_disconnect(state->display);
    }
}

int main(int argc, char **argv)
{
    struct sigaction action;
    struct output_surface *output;
    struct state state;

    memset(&state, 0, sizeof(state));
    state.intensity = parse_intensity(argc > 1 ? argv[1] : NULL);

    memset(&action, 0, sizeof(action));
    action.sa_handler = handle_signal;
    sigemptyset(&action.sa_mask);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGTERM, &action, NULL);

    state.display = wl_display_connect(NULL);
    if (state.display == NULL) {
        fprintf(stderr, "batocera-nightmode-overlay: failed to connect to Wayland display\n");
        return 1;
    }

    state.registry = wl_display_get_registry(state.display);
    wl_registry_add_listener(state.registry, &registry_listener, &state);
    wl_display_roundtrip(state.display);

    if (state.compositor == NULL || state.shm == NULL || state.layer_shell == NULL) {
        fprintf(stderr, "batocera-nightmode-overlay: compositor lacks required protocols\n");
        cleanup(&state);
        return 2;
    }

    for (output = state.outputs; output != NULL; output = output->next)
        create_surface(output);

    wl_display_roundtrip(state.display);
    if (state.mapped_outputs == 0) {
        fprintf(stderr, "batocera-nightmode-overlay: no output accepted overlay\n");
        cleanup(&state);
        return 3;
    }

    dispatch_until_stopped(&state);

    if (unmap_requested)
        unmap_outputs(&state);

    cleanup(&state);
    return 0;
}
