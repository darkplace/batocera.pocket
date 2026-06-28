#version 450

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    const float split_y = 0.5;
    const float top_source_left = 0.0;
    const float top_source_width = 1.0;
    const float panel_left = 400.0 / 1920.0;
    const float panel_top = 1200.0 / 2160.0;
    const float panel_width = 1120.0 / 1920.0;
    const float panel_height = 840.0 / 2160.0;
    const float panel_right = panel_left + panel_width;
    const float panel_bottom = panel_top + panel_height;
    const float bottom_source_left = 40.0 / 400.0;
    const float bottom_source_width = 320.0 / 400.0;

    vec2 coord = vTexCoord;

    if (coord.y <= split_y) {
        coord.x = top_source_left + coord.x * top_source_width;
    } else {
        if (coord.x < panel_left || coord.x > panel_right ||
                coord.y < panel_top || coord.y > panel_bottom) {
            FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        coord.x = bottom_source_left + ((coord.x - panel_left) / panel_width) * bottom_source_width;
        coord.y = split_y + ((coord.y - panel_top) / panel_height) * split_y;
    }

    FragColor = vec4(texture(Source, coord).rgb, 1.0);
}
