#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-gamma-control-unstable-v1-client-protocol.h"

struct state;

struct output_control {
    struct state *state;
    struct wl_output *output;
    struct zwlr_gamma_control_v1 *gamma;
    uint32_t gamma_size;
    int failed;
    struct output_control *next;
};

struct state {
    struct wl_display *display;
    struct wl_registry *registry;
    struct zwlr_gamma_control_manager_v1 *manager;
    struct output_control *outputs;
    int intensity;
    int configured_outputs;
};

static volatile sig_atomic_t stop_requested;
static volatile sig_atomic_t reset_requested;

static void handle_signal(int signal_number)
{
    (void)signal_number;
    reset_requested = 1;
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

static uint16_t scaled_value(uint32_t index, uint32_t size, double scale)
{
    double base;
    unsigned int value;

    if (size <= 1)
        base = 65535.0;
    else
        base = ((double)index * 65535.0) / (double)(size - 1);

    value = (unsigned int)((base * scale) + 0.5);
    if (value > 65535U)
        value = 65535U;

    return (uint16_t)value;
}

static int write_all(int fd, const void *buffer, size_t bytes)
{
    const char *cursor = buffer;

    while (bytes > 0) {
        ssize_t written = write(fd, cursor, bytes);

        if (written < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }

        cursor += written;
        bytes -= (size_t)written;
    }

    return 0;
}

static int create_gamma_fd(uint32_t size, int intensity)
{
    char template[] = "/tmp/batocera-nightmode-gamma.XXXXXX";
    uint16_t *table = NULL;
    double amount = (double)intensity / 100.0;
    double green_scale = 1.0 - (0.06 * amount);
    double blue_scale = 1.0 - (0.18 * amount);
    size_t entries;
    int fd;
    uint32_t i;

    if (size == 0)
        return -1;

    entries = (size_t)size * 3U;
    table = calloc(entries, sizeof(uint16_t));
    if (table == NULL)
        return -1;

    for (i = 0; i < size; i++) {
        table[i] = scaled_value(i, size, 1.0);
        table[size + i] = scaled_value(i, size, green_scale);
        table[(size * 2U) + i] = scaled_value(i, size, blue_scale);
    }

    fd = mkstemp(template);
    if (fd < 0) {
        free(table);
        return -1;
    }
    unlink(template);

    if (write_all(fd, table, entries * sizeof(uint16_t)) != 0 || lseek(fd, 0, SEEK_SET) < 0) {
        close(fd);
        free(table);
        return -1;
    }

    free(table);
    return fd;
}

static void gamma_size(void *data, struct zwlr_gamma_control_v1 *gamma, uint32_t size)
{
    struct output_control *control = data;

    (void)gamma;
    control->gamma_size = size;
}

static void gamma_failed(void *data, struct zwlr_gamma_control_v1 *gamma)
{
    struct output_control *control = data;

    (void)gamma;
    control->failed = 1;
    stop_requested = 1;
}

static const struct zwlr_gamma_control_v1_listener gamma_listener = {
    .gamma_size = gamma_size,
    .failed = gamma_failed,
};

static int dispatch_until_stopped(struct wl_display *display)
{
    struct pollfd poll_fd = {
        .fd = wl_display_get_fd(display),
        .events = POLLIN,
    };

    while (!stop_requested) {
        int result;

        if (wl_display_dispatch_pending(display) < 0)
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
        if (result == 0)
            continue;
        if ((poll_fd.revents & (POLLERR | POLLHUP | POLLNVAL)) != 0)
            return -1;
        if ((poll_fd.revents & POLLIN) != 0 && wl_display_dispatch(display) < 0) {
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

    if (strcmp(interface, wl_output_interface.name) == 0) {
        struct output_control *control = calloc(1, sizeof(*control));
        uint32_t bind_version = version < 2 ? version : 2;

        if (control == NULL)
            return;

        control->state = state;
        control->output = wl_registry_bind(registry, name, &wl_output_interface, bind_version);
        control->next = state->outputs;
        state->outputs = control;
    } else if (strcmp(interface, zwlr_gamma_control_manager_v1_interface.name) == 0) {
        state->manager = wl_registry_bind(
            registry, name, &zwlr_gamma_control_manager_v1_interface, 1);
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

static int configure_output(struct output_control *control, int intensity)
{
    int fd;

    if (control->gamma == NULL || control->gamma_size == 0 || control->failed)
        return 0;

    fd = create_gamma_fd(control->gamma_size, intensity);
    if (fd < 0)
        return -1;

    zwlr_gamma_control_v1_set_gamma(control->gamma, fd);
    close(fd);
    return 1;
}

static void reset_outputs(struct state *state)
{
    struct output_control *control;
    int reset_count = 0;

    for (control = state->outputs; control != NULL; control = control->next) {
        int result = configure_output(control, 0);

        if (result > 0)
            reset_count += result;
    }

    /* Some compositors retain the last gamma table after control is destroyed. */
    if (reset_count > 0)
        wl_display_roundtrip(state->display);
}

static void cleanup(struct state *state)
{
    struct output_control *control = state->outputs;

    while (control != NULL) {
        struct output_control *next = control->next;

        if (control->gamma != NULL)
            zwlr_gamma_control_v1_destroy(control->gamma);
        if (control->output != NULL)
            wl_output_destroy(control->output);
        free(control);
        control = next;
    }

    if (state->manager != NULL)
        zwlr_gamma_control_manager_v1_destroy(state->manager);
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
    struct output_control *control;
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
        fprintf(stderr, "batocera-nightmode-gamma: failed to connect to Wayland display\n");
        return 1;
    }

    state.registry = wl_display_get_registry(state.display);
    wl_registry_add_listener(state.registry, &registry_listener, &state);
    wl_display_roundtrip(state.display);

    if (state.manager == NULL) {
        fprintf(stderr, "batocera-nightmode-gamma: compositor has no gamma-control manager\n");
        cleanup(&state);
        return 2;
    }

    for (control = state.outputs; control != NULL; control = control->next) {
        control->gamma = zwlr_gamma_control_manager_v1_get_gamma_control(
            state.manager, control->output);
        zwlr_gamma_control_v1_add_listener(control->gamma, &gamma_listener, control);
    }

    wl_display_roundtrip(state.display);

    for (control = state.outputs; control != NULL; control = control->next) {
        int result = configure_output(control, state.intensity);

        if (result < 0) {
            fprintf(stderr, "batocera-nightmode-gamma: failed to configure gamma table\n");
            cleanup(&state);
            return 3;
        }
        state.configured_outputs += result;
    }

    if (state.configured_outputs == 0) {
        fprintf(stderr, "batocera-nightmode-gamma: no output accepted gamma control\n");
        cleanup(&state);
        return 4;
    }

    wl_display_flush(state.display);

    dispatch_until_stopped(state.display);

    if (reset_requested)
        reset_outputs(&state);

    cleanup(&state);
    return 0;
}
