#define _GNU_SOURCE
#include <dlfcn.h>
#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static int ds_screen_width = 256;
static int ds_screen_height = 192;
static int last_x = -1;
static int last_y = -1;
static int xy_idx = 0;
static int phys_width = -1;
static int phys_height = -1;
static int logical_width = -1;
static int logical_height = -1;
static int actual_touch = 0;
static int num_displays = 0;
static SDL_Rect top_display_bounds = {0};
static SDL_Rect bottom_display_bounds = {0};

// Microphone monitoring
static SDL_AudioDeviceID mic_device = 0;
static int mic_key_held = 0;
static float mic_threshold = 0.0f;
static int mic_enabled = 0;
static float mic_baseline = 0.0f;
static int mic_baseline_samples = 0;
static int debug_render_logs_remaining = 0;
static int debug_touch_logs_remaining = 0;
static int panel_fill_mode = 0;
static int configured_touch_device_index = 0;
static int selected_touch_device = 0;
static int single_panel_orientation = -1;
static SDL_TouchID selected_touch_id = 0;
static const char* configured_top_output_name = NULL;
static const char* configured_bottom_output_name = NULL;

static SDL_Texture* screens[4];
static SDL_Texture* stylus_tex[2];
static SDL_Rect touch_rect_storage = {0};
static SDL_Rect* touch_rect = NULL;
static SDL_Renderer* renderer = NULL;
static SDL_Window* (*real_SDL_CreateWindow)(const char*, int, int, int, int, Uint32) = NULL;
static void (*real_SDL_SetWindowSize)(SDL_Window* window, int w, int h) = NULL;
static void (*real_SDL_SetWindowPosition)(SDL_Window* window, int x, int y) = NULL;
static SDL_Renderer* (*real_SDL_CreateRenderer)(SDL_Window*, int, Uint32) = NULL;
static int (*real_SDL_RenderSetLogicalSize)(SDL_Renderer*, int, int) = NULL;
static int (*real_SDL_RenderSetScale)(SDL_Renderer*, float, float) = NULL;
static int (*real_SDL_RenderSetViewport)(SDL_Renderer*, const SDL_Rect*) = NULL;
static void (*real_SDL_RenderGetScale)(SDL_Renderer*, float*, float*) = NULL;
static int (*real_SDL_GetNumTouchDevices)(void) = NULL;
static SDL_TouchID (*real_SDL_GetTouchDevice)(int) = NULL;
static const char* (*real_SDL_GetTouchName)(int) = NULL;
static SDL_Texture* (*real_SDL_CreateTexture)(SDL_Renderer*, Uint32, int, int, int) = NULL;
static int (*real_SDL_RenderCopy)(SDL_Renderer*, SDL_Texture*, const SDL_Rect*, const SDL_Rect*) = NULL;
static int (*real_SDL_PollEvent)(SDL_Event*) = NULL;
static int (*real_SDL_PushEvent)(SDL_Event*) = NULL;
static Uint32 (*real_SDL_WasInit)(Uint32) = NULL;
static int (*real_SDL_InitSubSystem)(Uint32) = NULL;
static SDL_AudioDeviceID (*real_SDL_OpenAudioDevice)(const char*, int, const SDL_AudioSpec*, SDL_AudioSpec*, int) = NULL;
static void (*real_SDL_PauseAudioDevice)(SDL_AudioDeviceID, int) = NULL;
static void (*real_SDL_CloseAudioDevice)(SDL_AudioDeviceID) = NULL;
static int (*real_SDL_GetNumAudioDevices)(int) = NULL;
static const char* (*real_SDL_GetAudioDeviceName)(int, int) = NULL;

static int is_dual_panel_mode(void) {
    return num_displays >= 2 &&
        phys_width > 0 &&
        phys_height > 0 &&
        top_display_bounds.h > 0 &&
        phys_height > top_display_bounds.h;
}

static void force_dual_panel_window_size(SDL_Window* window) {
    if (!window || !real_SDL_SetWindowSize || !is_dual_panel_mode()) {
        return;
    }

    real_SDL_SetWindowSize(window, phys_width, phys_height);
    if (real_SDL_SetWindowPosition) {
        real_SDL_SetWindowPosition(window, 0, 0);
    }
}

static void debug_log_render_copy(SDL_Texture* texture, const SDL_Rect* srcrect, const SDL_Rect* dstrect) {
    if (debug_render_logs_remaining <= 0 || !dstrect) {
        return;
    }

    int output_w = 0;
    int output_h = 0;
    float scale_x = 0.0f;
    float scale_y = 0.0f;
    if (renderer) {
        SDL_GetRendererOutputSize(renderer, &output_w, &output_h);
        if (real_SDL_RenderGetScale) {
            real_SDL_RenderGetScale(renderer, &scale_x, &scale_y);
        }
    }

    fprintf(stderr,
        "DSHOOK texture=%p src=%d,%d %dx%d dst=%d,%d %dx%d logical=%dx%d output=%dx%d scale=%.3fx%.3f phys=%dx%d screens=%p,%p,%p,%p\n",
        (void*)texture,
        srcrect ? srcrect->x : -1,
        srcrect ? srcrect->y : -1,
        srcrect ? srcrect->w : -1,
        srcrect ? srcrect->h : -1,
        dstrect->x,
        dstrect->y,
        dstrect->w,
        dstrect->h,
        logical_width,
        logical_height,
        output_w,
        output_h,
        scale_x,
        scale_y,
        phys_width,
        phys_height,
        (void*)screens[0],
        (void*)screens[1],
        (void*)screens[2],
        (void*)screens[3]);
    debug_render_logs_remaining--;
}

static void debug_log_touch_event(const char* phase, SDL_TouchID touch_id, float norm_x, float norm_y, int x, int y) {
    if (debug_touch_logs_remaining <= 0) {
        return;
    }

    fprintf(stderr,
        "DSHOOK_TOUCH %s touch=%lld norm=%.4f,%.4f phys=%d,%d rect=%d,%d %dx%d selected=%d id=%lld\n",
        phase,
        (long long)touch_id,
        norm_x,
        norm_y,
        x,
        y,
        touch_rect ? touch_rect->x : -1,
        touch_rect ? touch_rect->y : -1,
        touch_rect ? touch_rect->w : -1,
        touch_rect ? touch_rect->h : -1,
        selected_touch_device,
        (long long)selected_touch_id);
    debug_touch_logs_remaining--;
}

static SDL_Rect fit_rect_in_bounds(SDL_Rect bounds, int src_w, int src_h) {
    float scale_x = (float)bounds.w / (float)src_w;
    float scale_y = (float)bounds.h / (float)src_h;
    float scale = fminf(scale_x, scale_y);

    int dst_w = (int)lroundf((float)src_w * scale);
    int dst_h = (int)lroundf((float)src_h * scale);

    SDL_Rect dst = {
        .x = bounds.x + (bounds.w - dst_w) / 2,
        .y = bounds.y + (bounds.h - dst_h) / 2,
        .w = dst_w,
        .h = dst_h,
    };
    return dst;
}

static SDL_Rect cover_rect_in_bounds(SDL_Rect bounds, int src_w, int src_h) {
    float scale_x = (float)bounds.w / (float)src_w;
    float scale_y = (float)bounds.h / (float)src_h;
    float scale = fmaxf(scale_x, scale_y);

    int dst_w = (int)lroundf((float)src_w * scale);
    int dst_h = (int)lroundf((float)src_h * scale);

    SDL_Rect dst = {
        .x = bounds.x + (bounds.w - dst_w) / 2,
        .y = bounds.y + (bounds.h - dst_h) / 2,
        .w = dst_w,
        .h = dst_h,
    };
    return dst;
}

static SDL_Rect stretch_rect_in_bounds(SDL_Rect bounds) {
    return bounds;
}

static SDL_Rect physical_rect_to_logical_rect(SDL_Renderer* renderer, SDL_Rect physical_rect) {
    float logical_x1 = 0.0f;
    float logical_y1 = 0.0f;
    float logical_x2 = 0.0f;
    float logical_y2 = 0.0f;

    SDL_RenderWindowToLogical(renderer, physical_rect.x, physical_rect.y, &logical_x1, &logical_y1);
    SDL_RenderWindowToLogical(renderer, physical_rect.x + physical_rect.w, physical_rect.y + physical_rect.h, &logical_x2, &logical_y2);

    SDL_Rect logical_rect = {
        .x = (int)lroundf(logical_x1),
        .y = (int)lroundf(logical_y1),
        .w = (int)lroundf(logical_x2 - logical_x1),
        .h = (int)lroundf(logical_y2 - logical_y1),
    };
    return logical_rect;
}

static int has_native_ds_screens(void) {
    return ds_screen_width == 256 && screens[2] && screens[3];
}

static int has_hires_ds_screens(void) {
    return ds_screen_width == 512 && screens[0] && screens[1];
}

static int has_dual_panel_ds_screens(void) {
    return has_native_ds_screens() || has_hires_ds_screens();
}

static int should_split_thor_screens(const SDL_Rect* dstrect) {
    return dstrect &&
        has_dual_panel_ds_screens() &&
        num_displays >= 2 &&
        top_display_bounds.h > 0 &&
        bottom_display_bounds.h > 0 &&
        phys_height > top_display_bounds.h;
}

static int should_use_thor_touch_mode(void) {
    return num_displays >= 2 &&
        has_dual_panel_ds_screens() &&
        top_display_bounds.h > 0 &&
        bottom_display_bounds.h > 0 &&
        phys_height > top_display_bounds.h;
}

static int dual_panel_logical_width(void) {
    return ds_screen_width;
}

static int dual_panel_logical_height(void) {
    return ds_screen_height * 2;
}

static int single_panel_layout_width(const SDL_Rect* dstrect) {
    int screen_w = (dstrect && dstrect->w > 0) ? dstrect->w : ds_screen_width;

    if (single_panel_orientation == 1) {
        return screen_w * 2;
    }
    if (single_panel_orientation == 0) {
        return screen_w;
    }
    if (single_panel_orientation == 3) {
        return screen_w;
    }

    if (dstrect && dstrect->x + dstrect->w > screen_w) {
        return screen_w * 2;
    }
    if (logical_width > screen_w) {
        return logical_width;
    }
    return screen_w;
}

static int single_panel_layout_height(const SDL_Rect* dstrect) {
    int screen_h = (dstrect && dstrect->h > 0) ? dstrect->h : ds_screen_height;

    if (single_panel_orientation == 1) {
        return screen_h;
    }
    if (single_panel_orientation == 0) {
        return screen_h * 2;
    }
    if (single_panel_orientation == 3) {
        return screen_h;
    }

    if (dstrect && dstrect->y + dstrect->h > screen_h) {
        return screen_h * 2;
    }
    if (logical_height > screen_h) {
        return logical_height;
    }
    return screen_h * 2;
}

static int should_scale_single_panel_screens(const SDL_Rect* dstrect) {
    return dstrect &&
        num_displays == 1 &&
        has_dual_panel_ds_screens() &&
        phys_width > ds_screen_width &&
        phys_height > ds_screen_height &&
        top_display_bounds.w > 0 &&
        top_display_bounds.h > 0;
}

static SDL_Rect scale_single_panel_rect(SDL_Renderer* renderer, const SDL_Rect* dstrect) {
    int layout_w = single_panel_layout_width(dstrect);
    int layout_h = single_panel_layout_height(dstrect);
    int output_w = 0;
    int output_h = 0;

    if (renderer) {
        SDL_GetRendererOutputSize(renderer, &output_w, &output_h);
    }
    if (output_w <= 0 || output_h <= 0) {
        output_w = phys_width;
        output_h = phys_height;
    }

    SDL_Rect panel_bounds = {0, 0, output_w, output_h};
    SDL_Rect canvas;

    if (panel_fill_mode == 2) {
        canvas = stretch_rect_in_bounds(panel_bounds);
    } else if (panel_fill_mode == 1) {
        canvas = cover_rect_in_bounds(panel_bounds, layout_w, layout_h);
    } else {
        canvas = fit_rect_in_bounds(panel_bounds, layout_w, layout_h);
    }

    float scale_x = (float)canvas.w / (float)layout_w;
    float scale_y = (float)canvas.h / (float)layout_h;

    SDL_Rect dst = {
        .x = canvas.x + (int)lroundf((float)dstrect->x * scale_x),
        .y = canvas.y + (int)lroundf((float)dstrect->y * scale_y),
        .w = (int)lroundf((float)dstrect->w * scale_x),
        .h = (int)lroundf((float)dstrect->h * scale_y),
    };
    return dst;
}

static void discover_touch_device(void) {
    if (selected_touch_device || !real_SDL_GetNumTouchDevices || !real_SDL_GetTouchDevice) {
        return;
    }

    int num_touches = real_SDL_GetNumTouchDevices();
    if (num_touches <= 0) {
        return;
    }

    if (configured_touch_device_index < 0 || configured_touch_device_index >= num_touches) {
        configured_touch_device_index = 0;
    }

    selected_touch_id = real_SDL_GetTouchDevice(configured_touch_device_index);
    selected_touch_device = 1;

    if (debug_touch_logs_remaining > 0) {
        fprintf(stderr, "DSHOOK_TOUCH_DEVICES count=%d selected_index=%d selected_id=%lld\n",
            num_touches, configured_touch_device_index, (long long)selected_touch_id);
        for (int i = 0; i < num_touches; ++i) {
            SDL_TouchID touch_id = real_SDL_GetTouchDevice(i);
            const char* name = real_SDL_GetTouchName ? real_SDL_GetTouchName(i) : NULL;
            fprintf(stderr, "DSHOOK_TOUCH_DEVICE index=%d id=%lld name=%s\n",
                i, (long long)touch_id, name ? name : "(null)");
        }
    }
}

static int output_name_matches(const char* display_name, const char* configured_name) {
    return display_name &&
        configured_name &&
        configured_name[0] != '\0' &&
        strcmp(display_name, configured_name) == 0;
}

static void normalize_rect_to_canvas(SDL_Rect* rect, int min_x, int min_y) {
    if (!rect) {
        return;
    }

    rect->x -= min_x;
    rect->y -= min_y;
}

static void force_thor_full_scale(SDL_Renderer* renderer) {
    if (!renderer || !real_SDL_RenderSetScale || !real_SDL_RenderSetViewport) {
        return;
    }

    if (num_displays < 2 || !has_dual_panel_ds_screens() || phys_height <= top_display_bounds.h) {
        return;
    }

    logical_width = dual_panel_logical_width();
    logical_height = dual_panel_logical_height();
    real_SDL_RenderSetViewport(renderer, NULL);
    real_SDL_RenderSetScale(renderer, (float)phys_width / (float)logical_width, (float)phys_height / (float)logical_height);
}

SDL_Window* SDL_CreateWindow(const char* title, int x, int y, int w, int h, Uint32 flags) {
    int sdl_num_displays = SDL_GetNumVideoDisplays();
    int last_width = 0;
    int last_height = 0;
    int have_bounds = 0;
    int min_x = 0;
    int min_y = 0;
    int max_x = 0;
    int max_y = 0;
    int top_idx = -1;
    int bottom_idx = -1;
    SDL_Rect top_by_position = {0};
    SDL_Rect bottom_by_position = {0};
    SDL_Rect top_by_name = {0};
    SDL_Rect bottom_by_name = {0};
    int top_name_idx = -1;
    int bottom_name_idx = -1;

    // Change window to total screen size
    // Prevents empty spacing on dual displays
    num_displays = sdl_num_displays;
    for (int i = 0; i < sdl_num_displays; ++i) {
        SDL_Rect bounds;
        if (SDL_GetDisplayBounds(i, &bounds) == 0) {
            const char* display_name = SDL_GetDisplayName(i);

            if (!have_bounds) {
                min_x = bounds.x;
                min_y = bounds.y;
                max_x = bounds.x + bounds.w;
                max_y = bounds.y + bounds.h;
                top_by_position = bounds;
                bottom_by_position = bounds;
                have_bounds = 1;
            } else {
                if (bounds.x < min_x) min_x = bounds.x;
                if (bounds.y < min_y) min_y = bounds.y;
                if (bounds.x + bounds.w > max_x) max_x = bounds.x + bounds.w;
                if (bounds.y + bounds.h > max_y) max_y = bounds.y + bounds.h;
            }

            last_width = bounds.w;
            last_height = bounds.h;
            if (top_idx < 0 || bounds.y < top_by_position.y) {
                top_by_position = bounds;
                top_idx = i;
            }
            if (bottom_idx < 0 || bounds.y > bottom_by_position.y) {
                bottom_by_position = bounds;
                bottom_idx = i;
            }
            if (output_name_matches(display_name, configured_top_output_name)) {
                top_by_name = bounds;
                top_name_idx = i;
            }
            if (output_name_matches(display_name, configured_bottom_output_name)) {
                bottom_by_name = bounds;
                bottom_name_idx = i;
            }
        }
    }

    // Record screen size for rect tracking/conversion
    if (have_bounds) {
        phys_width = max_x - min_x;
        phys_height = max_y - min_y;

        top_display_bounds = (top_name_idx >= 0) ? top_by_name : top_by_position;
        bottom_display_bounds = (bottom_name_idx >= 0) ? bottom_by_name : bottom_by_position;

        normalize_rect_to_canvas(&top_display_bounds, min_x, min_y);
        normalize_rect_to_canvas(&bottom_display_bounds, min_x, min_y);
    }

    // DraStic starts in the center of the native virtual screen
    last_x = 128;
    last_y = 96;

    // Check which screen side is longer for dual screens
    if (sdl_num_displays > 1)
        xy_idx = (last_width > last_height) ? 1 : 2;

    // Set window size to single screen to fix offsets when resizing
    SDL_Window* window = real_SDL_CreateWindow(title, 0, 0, last_width, last_height, flags);
    if (real_SDL_SetWindowPosition) {
        real_SDL_SetWindowPosition(window, 0, 0);
    }
    force_dual_panel_window_size(window);
    return window;
}

void SDL_SetWindowSize(SDL_Window* window, int w, int h) {
    static int init_resize = 2;

    if (is_dual_panel_mode()) {
        real_SDL_SetWindowSize(window, w, h);
        force_dual_panel_window_size(window);
        if (init_resize > 0) {
            init_resize -= 1;
            if (init_resize == 0) {
                init_resize = -1;
            }
        }
        return;
    }

    if (init_resize > 0) {
        real_SDL_SetWindowSize(window, w, h);
        init_resize -= 1;
    }

    // Force window size to fill AFTER DraStic does its weird init thing
    // Also check if this is a resize after init, if so, toggle a scale down to allow DraStic menu visibility
    if (init_resize == 0) {
        real_SDL_SetWindowSize(window, phys_width, phys_height);
        if (real_SDL_SetWindowPosition) {
            real_SDL_SetWindowPosition(window, 0, 0);
        }
        init_resize = -1;
    } else if (init_resize == -1) {
        if (xy_idx == 1)
            w = phys_width / 2;
        if (xy_idx == 2)
            h = phys_height / 2;

        real_SDL_SetWindowSize(window, w, h);
        if (real_SDL_SetWindowPosition) {
            real_SDL_SetWindowPosition(window, 0, 0);
        }
        init_resize = 0;
    }

}

SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, int index, Uint32 flags) {
    renderer = real_SDL_CreateRenderer(window, index, flags);
    // Just in case it's already set
    SDL_RenderGetLogicalSize(renderer, &logical_width, &logical_height);
    return renderer;
}

int SDL_RenderSetLogicalSize(SDL_Renderer* renderer, int w, int h) {
    logical_width = w;
    logical_height = h;

    if (renderer && real_SDL_RenderSetScale && real_SDL_RenderSetViewport && w > 0 && h > 0) {
        int output_w = 0;
        int output_h = 0;
        SDL_GetRendererOutputSize(renderer, &output_w, &output_h);
        if (output_w > 0 && output_h > 0) {
            real_SDL_RenderSetViewport(renderer, NULL);
            return real_SDL_RenderSetScale(renderer, (float)output_w / (float)w, (float)output_h / (float)h);
        }
    }

    return 0;
}

int SDL_RenderSetScale(SDL_Renderer* renderer, float scaleX, float scaleY) {
    if (renderer && real_SDL_RenderSetScale && num_displays >= 2 && phys_height > top_display_bounds.h) {
        int output_w = 0;
        int output_h = 0;
        SDL_GetRendererOutputSize(renderer, &output_w, &output_h);

        if (output_w > 0 && output_h == phys_height && ds_screen_width > 0 && ds_screen_height > 0) {
            logical_width = dual_panel_logical_width();
            logical_height = dual_panel_logical_height();
            return real_SDL_RenderSetScale(
                renderer,
                (float)output_w / (float)logical_width,
                (float)output_h / (float)logical_height
            );
        }
    }

    return real_SDL_RenderSetScale ? real_SDL_RenderSetScale(renderer, scaleX, scaleY) : 0;
}

SDL_Texture* SDL_CreateTexture(SDL_Renderer *renderer, Uint32 format, int type, int w, int h) {
	SDL_Texture* texture = real_SDL_CreateTexture(renderer, format, type, w, h);
	// Identify DS screen and stylus textures
	if (type == SDL_TEXTUREACCESS_STREAMING) {
		if (w == 512 && h == 384) {
            ds_screen_width = 512;
            ds_screen_height = 384;
			if (!screens[0]) screens[0] = texture;
			else if (!screens[1]) screens[1] = texture;
        } else if (w == 256 && h == 192 && !screens[0]) {
		    if (!screens[2]) screens[2] = texture;
		    else if (!screens[3]) screens[3] = texture;
        }
    }
    if (w == 32 && h == 32) {
		if (!stylus_tex[0]) stylus_tex[0] = texture;
		else if (!stylus_tex[1]) stylus_tex[1] = texture;
    }
	return texture;
}

int SDL_RenderCopy(SDL_Renderer *renderer, SDL_Texture *texture, const SDL_Rect *srcrect, const SDL_Rect *dstrect) {
    SDL_Rect remapped_dstrect_storage;
    const SDL_Rect* effective_dstrect = dstrect;

    force_thor_full_scale(renderer);

    if (should_split_thor_screens(dstrect)) {
        int output_w = 0;
        int output_h = 0;
        SDL_GetRendererOutputSize(renderer, &output_w, &output_h);

        if (output_w > 0 && output_h > 0) {
            SDL_Rect target_bounds;
            int source_w = ds_screen_width;
            int source_h = ds_screen_height;

            if ((has_hires_ds_screens() && texture == screens[1]) ||
                (has_native_ds_screens() && texture == screens[2])) {
                target_bounds = top_display_bounds;
            } else if ((has_hires_ds_screens() && texture == screens[0]) ||
                (has_native_ds_screens() && texture == screens[3])) {
                target_bounds = bottom_display_bounds;
            } else {
                target_bounds = (SDL_Rect){0};
            }

            if (target_bounds.w > 0 && target_bounds.h > 0) {
                SDL_Rect panel_rect;

                if (panel_fill_mode == 2) {
                    panel_rect = stretch_rect_in_bounds(target_bounds);
                } else if (panel_fill_mode == 1) {
                    panel_rect = cover_rect_in_bounds(target_bounds, source_w, source_h);
                } else {
                    panel_rect = fit_rect_in_bounds(target_bounds, source_w, source_h);
                }

                remapped_dstrect_storage = physical_rect_to_logical_rect(renderer, panel_rect);
                effective_dstrect = &remapped_dstrect_storage;
            }
        }
    } else if ((texture == screens[0] || texture == screens[1] || texture == screens[2] || texture == screens[3]) &&
        should_scale_single_panel_screens(dstrect)) {
        remapped_dstrect_storage = scale_single_panel_rect(renderer, dstrect);
        effective_dstrect = &remapped_dstrect_storage;
    }

    if (texture == screens[0] || texture == screens[1] || texture == screens[2] || texture == screens[3]) {
        debug_log_render_copy(texture, srcrect, effective_dstrect);
    }

    if ((screens[0] && texture == screens[0] && ds_screen_width == 512) ||
        (screens[3] && texture == screens[3] && ds_screen_width == 256)) {
        // Convert renderer coordinates to physical screen coordinates
        if (logical_width > 0 && logical_height > 0) {
            int window_x1 = 0;
            int window_y1 = 0;
            int window_x2 = 0;
            int window_y2 = 0;

            SDL_RenderLogicalToWindow(renderer, (float)effective_dstrect->x, (float)effective_dstrect->y, &window_x1, &window_y1);
            SDL_RenderLogicalToWindow(renderer, (float)(effective_dstrect->x + effective_dstrect->w), (float)(effective_dstrect->y + effective_dstrect->h), &window_x2, &window_y2);

            touch_rect_storage.x = window_x1;
            touch_rect_storage.y = window_y1;
            touch_rect_storage.w = window_x2 - window_x1;
            touch_rect_storage.h = window_y2 - window_y1;
        } else {
            // Fallback and hope they're right
            touch_rect_storage.x = effective_dstrect->x;
            touch_rect_storage.y = effective_dstrect->y;
            touch_rect_storage.w = effective_dstrect->w;
            touch_rect_storage.h = effective_dstrect->h;
        }
        touch_rect = &touch_rect_storage;
    }

    // Make stylus fully transparent for actual touchscreens
    if (actual_touch && (texture == stylus_tex[0] || texture == stylus_tex[1]))
        SDL_SetTextureAlphaMod(texture, 0);

    return real_SDL_RenderCopy(renderer, texture, srcrect, effective_dstrect);
}

void mic_audio_callback(void* userdata, Uint8* stream, int len) {
    if (!mic_enabled) return;

    Sint16* samples = (Sint16*)stream;
    int sample_count = len / 2;

    // Calculate RMS amplitude
    float sum = 0.0f;
    for (int i = 0; i < sample_count; i++) {
        float sample = samples[i] / 32768.0f; // Normalize to [-1.0..1.0]
        sum += sample * sample;
    }
    float rms = sqrtf(sum / sample_count);

    // Build ambient baseline over first ~3 seconds
    if (mic_baseline_samples < 60) {
        mic_baseline = (mic_baseline * mic_baseline_samples + rms) / (mic_baseline_samples + 1);
        mic_baseline_samples++;
        return; // Don't trigger during calibration
    }

    mic_baseline = mic_baseline * 0.999f + rms * 0.001f;

    // Trigger only if significantly above baseline
    float trigger_level = mic_baseline + mic_threshold;
    int should_hold = (rms > trigger_level);
    if (should_hold && !mic_key_held) {
        // Noise detected, press DraStic's configured fake microphone key.
        SDL_Event key_event = {0};
        key_event.type = SDL_KEYDOWN;
        key_event.key.state = SDL_PRESSED;
        key_event.key.keysym.scancode = SDL_SCANCODE_Y;
        key_event.key.keysym.sym = SDLK_y;
        real_SDL_PushEvent(&key_event);
        mic_key_held = 1;
    } else if (!should_hold && mic_key_held) {
        // Noise dropped below threshold, release DraStic's configured fake microphone key.
        SDL_Event key_event = {0};
        key_event.type = SDL_KEYUP;
        key_event.key.state = SDL_RELEASED;
        key_event.key.keysym.scancode = SDL_SCANCODE_Y;
        key_event.key.keysym.sym = SDLK_y;
        real_SDL_PushEvent(&key_event);
        mic_key_held = 0;
    }
}

int SDL_PollEvent(SDL_Event* event) {
    // Loop required to filter events we don't want to pass along
    while (1) {
        int result = real_SDL_PollEvent(event);
        if (!result) return 0;

        switch (event->type) {
            case SDL_FINGERDOWN: {
                if (!actual_touch)
                    actual_touch = 1;

                if (!touch_rect) {
                    return 0;
                }

                if (should_use_thor_touch_mode()) {
                    discover_touch_device();
                    if (selected_touch_device && event->tfinger.touchId != selected_touch_id) {
                        debug_log_touch_event("ignore-device-down", event->tfinger.touchId, event->tfinger.x, event->tfinger.y, -1, -1);
                        return 0;
                    }
                }

                int x = (int)(event->tfinger.x * phys_width);
                int y = (int)(event->tfinger.y * phys_height);
                if (!should_use_thor_touch_mode()) {
                    if (xy_idx == 1)
                        x *= 2;
                    if (xy_idx == 2)
                        y *= 2;
                }

                debug_log_touch_event("down", event->tfinger.touchId, event->tfinger.x, event->tfinger.y, x, y);

                if (x < touch_rect->x || x > touch_rect->x + touch_rect->w ||
                    y < touch_rect->y || y > touch_rect->y + touch_rect->h)
                    return 0; // Outside valid coords, don't convert

                // Scale to native virtual touchscreen
                x = ((x - touch_rect->x) * 256) / touch_rect->w;
                y = ((y - touch_rect->y) * 192) / touch_rect->h;

                // Queue click for after jump
                event->type = SDL_MOUSEBUTTONDOWN;
                event->button.button = SDL_BUTTON_LEFT;
                event->button.state = SDL_PRESSED;
                event->button.x = x;
                event->button.y = y;
                real_SDL_PushEvent(event);

                // Jump to new position
                event->type = SDL_MOUSEMOTION;
                event->motion.x = x;
                event->motion.y = y;
                event->motion.xrel = x - last_x;
                event->motion.yrel = y - last_y;

                // Update to keep position accurate
                last_x = x;
                last_y = y;
                break;
            }
            case SDL_FINGERMOTION: {
                if (!touch_rect) {
                    return 0;
                }

                if (should_use_thor_touch_mode()) {
                    discover_touch_device();
                    if (selected_touch_device && event->tfinger.touchId != selected_touch_id) {
                        debug_log_touch_event("ignore-device-motion", event->tfinger.touchId, event->tfinger.x, event->tfinger.y, -1, -1);
                        return 0;
                    }
                }

                int x = (int)(event->tfinger.x * phys_width);
                int y = (int)(event->tfinger.y * phys_height);
                if (!should_use_thor_touch_mode()) {
                    if (xy_idx == 1)
                        x *= 2;
                    if (xy_idx == 2)
                        y *= 2;
                }

                debug_log_touch_event("motion", event->tfinger.touchId, event->tfinger.x, event->tfinger.y, x, y);

                if (x < touch_rect->x || x > touch_rect->x + touch_rect->w ||
                    y < touch_rect->y || y > touch_rect->y + touch_rect->h)
                    return 0;

                x = ((x - touch_rect->x) * 256) / touch_rect->w;
                y = ((y - touch_rect->y) * 192) / touch_rect->h;
                int xrel = x - last_x;
                int yrel = y - last_y;

                // Motion is also used when already clicked but not moving
                // Always update it
                event->type = SDL_MOUSEMOTION;
                event->motion.x = x;
                event->motion.y = y;
                event->motion.xrel = xrel;
                event->motion.yrel = yrel;

                last_x = x;
                last_y = y;
                break;
            }
            case SDL_FINGERUP: {
                if (should_use_thor_touch_mode()) {
                    discover_touch_device();
                    if (selected_touch_device && event->tfinger.touchId != selected_touch_id) {
                        debug_log_touch_event("ignore-device-up", event->tfinger.touchId, event->tfinger.x, event->tfinger.y, -1, -1);
                        return 0;
                    }
                }

                debug_log_touch_event("up", event->tfinger.touchId, event->tfinger.x, event->tfinger.y, last_x, last_y);
                event->type = SDL_MOUSEBUTTONUP;
                event->button.button = SDL_BUTTON_LEFT;
                event->button.state = SDL_RELEASED;
                event->button.x = last_x;
                event->button.y = last_y;
                break;
            }
        }
        return result;
    }
}

__attribute__((constructor))
static void init(void) {
    real_SDL_CreateWindow = dlsym(RTLD_NEXT, "SDL_CreateWindow");
    real_SDL_SetWindowSize = dlsym(RTLD_NEXT, "SDL_SetWindowSize");
    real_SDL_SetWindowPosition = dlsym(RTLD_NEXT, "SDL_SetWindowPosition");
    real_SDL_CreateRenderer = dlsym(RTLD_NEXT, "SDL_CreateRenderer");
    real_SDL_RenderSetLogicalSize = dlsym(RTLD_NEXT, "SDL_RenderSetLogicalSize");
    real_SDL_RenderSetScale = dlsym(RTLD_NEXT, "SDL_RenderSetScale");
    real_SDL_RenderSetViewport = dlsym(RTLD_NEXT, "SDL_RenderSetViewport");
    real_SDL_RenderGetScale = dlsym(RTLD_NEXT, "SDL_RenderGetScale");
    real_SDL_GetNumTouchDevices = dlsym(RTLD_NEXT, "SDL_GetNumTouchDevices");
    real_SDL_GetTouchDevice = dlsym(RTLD_NEXT, "SDL_GetTouchDevice");
    real_SDL_GetTouchName = dlsym(RTLD_NEXT, "SDL_GetTouchName");
    real_SDL_CreateTexture = dlsym(RTLD_NEXT, "SDL_CreateTexture");
    real_SDL_RenderCopy = dlsym(RTLD_NEXT, "SDL_RenderCopy");
    real_SDL_PollEvent = dlsym(RTLD_NEXT, "SDL_PollEvent");
    real_SDL_PushEvent = dlsym(RTLD_NEXT, "SDL_PushEvent");
    real_SDL_WasInit = dlsym(RTLD_NEXT, "SDL_WasInit");
    real_SDL_InitSubSystem = dlsym(RTLD_NEXT, "SDL_InitSubSystem");
    real_SDL_OpenAudioDevice = dlsym(RTLD_NEXT, "SDL_OpenAudioDevice");
    real_SDL_PauseAudioDevice = dlsym(RTLD_NEXT, "SDL_PauseAudioDevice");
    real_SDL_CloseAudioDevice = dlsym(RTLD_NEXT, "SDL_CloseAudioDevice");
    real_SDL_GetNumAudioDevices = dlsym(RTLD_NEXT, "SDL_GetNumAudioDevices");
    real_SDL_GetAudioDeviceName = dlsym(RTLD_NEXT, "SDL_GetAudioDeviceName");

    const char* threshold_str = getenv("DSHOOK_MIC_THRESH");
    const char* debug_str = getenv("DSHOOK_DEBUG_RENDER");
    const char* debug_touch_str = getenv("DSHOOK_DEBUG_TOUCH");
    const char* fill_str = getenv("DSHOOK_PANEL_FILL");
    const char* touch_index_str = getenv("DSHOOK_TOUCH_DEVICE_INDEX");
    const char* single_orientation_str = getenv("DSHOOK_SINGLE_ORIENTATION");
    configured_top_output_name = getenv("DSHOOK_TOP_OUTPUT");
    configured_bottom_output_name = getenv("DSHOOK_BOTTOM_OUTPUT");
    if (debug_str && *debug_str) {
        debug_render_logs_remaining = atoi(debug_str);
        if (debug_render_logs_remaining <= 0) {
            debug_render_logs_remaining = 40;
        }
    }

    if (debug_touch_str && *debug_touch_str) {
        debug_touch_logs_remaining = atoi(debug_touch_str);
        if (debug_touch_logs_remaining <= 0) {
            debug_touch_logs_remaining = 40;
        }
    }

    if (fill_str && *fill_str) {
        if (strcmp(fill_str, "cover") == 0) {
            panel_fill_mode = 1;
        } else if (strcmp(fill_str, "stretch") == 0 || strcmp(fill_str, "fill") == 0) {
            panel_fill_mode = 2;
        }
    }

    if (touch_index_str && *touch_index_str) {
        configured_touch_device_index = atoi(touch_index_str);
        if (configured_touch_device_index < 0) {
            configured_touch_device_index = 0;
        }
    }

    if (single_orientation_str && *single_orientation_str) {
        single_panel_orientation = atoi(single_orientation_str);
    }

    if (threshold_str) {
        mic_threshold = atof(threshold_str);
        if (mic_threshold > 0.0f) {
            mic_enabled = 1;

            // Make sure SDL audio is ready, just in case
            if (real_SDL_WasInit(SDL_INIT_AUDIO) == 0)
                real_SDL_InitSubSystem(SDL_INIT_AUDIO);

            int num_devices = real_SDL_GetNumAudioDevices(1);
            const char* device_name = NULL;
            for (int i = 0; i < num_devices; i++) {
                const char* name = real_SDL_GetAudioDeviceName(i, 1);
                // Use first available device (or look for Built-in)
                if (name && (i == 0 || strstr(name, "Built-in"))) {
                    device_name = name;
                    break;
                }
            }

            // Configure audio capture
            SDL_AudioSpec desired_spec = {0};
            desired_spec.freq = 44100;
            desired_spec.format = AUDIO_S16SYS;
            desired_spec.channels = 1;
            desired_spec.samples = 2048;
            desired_spec.callback = mic_audio_callback;

            SDL_AudioSpec obtained_spec;
            mic_device = real_SDL_OpenAudioDevice(device_name, 1, &desired_spec, &obtained_spec, 0);

            if (mic_device > 0) // Opened, start capture
                real_SDL_PauseAudioDevice(mic_device, 0);
            else // Couldn't open, fallback to disable
                mic_enabled = 0;
        }
    }
}

__attribute__((destructor))
static void cleanup(void) {
    if (mic_device > 0 && real_SDL_CloseAudioDevice) {
        real_SDL_CloseAudioDevice(mic_device);
    }
}

// Major thanks/credit to Shaun Inman for providing the basis of this hook library!
