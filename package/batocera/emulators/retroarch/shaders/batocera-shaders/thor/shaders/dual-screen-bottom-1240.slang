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
    const float bottom_left = 340.0 / 1920.0;
    const float bottom_width = 1240.0 / 1920.0;
    const float bottom_right = bottom_left + bottom_width;

    vec2 coord = vTexCoord;

    if (coord.y > split_y) {
        if (coord.x < bottom_left || coord.x > bottom_right) {
            FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        coord.x = (coord.x - bottom_left) / bottom_width;
    }

    FragColor = vec4(texture(Source, coord).rgb, 1.0);
}
