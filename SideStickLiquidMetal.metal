#include <metal_stdlib>
using namespace metal;

static float hash21(float2 point) {
    float value = dot(point, float2(127.1, 311.7));
    return fract(sin(value) * 43758.5453123);
}

[[ stitchable ]] half4 sideStickLiquidMetal(
    float2 position,
    half4 sourceColor,
    float time,
    float2 tilt,
    float variant,
    float2 surfaceSize
) {
    float2 safeSize = max(surfaceSize, float2(1.0));
    float2 uv = clamp(position / safeSize, float2(0.0), float2(1.0));
    float2 centered = uv * 2.0 - 1.0;

    float driftA = sin((centered.x * 2.8 + centered.y * 1.2 + time * 0.075 + tilt.x * 1.8) * 6.28318);
    float driftB = cos((centered.y * 3.6 - centered.x * 0.9 - time * 0.052 + tilt.y * 1.7) * 6.28318);
    float flow = (driftA + driftB) * 0.5;
    float fineNoise = hash21(floor(position * 0.14) + floor(time * 0.35));

    float wavePosition = uv.y + flow * 0.075 + tilt.y * 0.12;
    float chromeBand = pow(saturate(0.5 + 0.5 * cos((wavePosition * 8.5 + tilt.x * 0.7) * 6.28318)), 13.0);
    float secondaryBand = pow(saturate(0.5 + 0.5 * sin((uv.x * 4.6 - uv.y * 2.1 + time * 0.035) * 6.28318)), 20.0);
    float specularLine = pow(saturate(1.0 - abs(uv.y - 0.20 - flow * 0.035 - tilt.y * 0.09)), 22.0);
    float edgeReflection = pow(saturate(1.0 - abs(centered.x) * 0.78), 2.0);

    float3 baseColor;
    float3 reflectedColor;
    if (variant < 0.5) {
        baseColor = float3(0.31, 0.37, 0.48);
        reflectedColor = float3(0.94, 0.97, 1.00);
    } else if (variant < 1.5) {
        baseColor = float3(0.075, 0.095, 0.145);
        reflectedColor = float3(0.39, 0.52, 0.72);
    } else {
        baseColor = float3(0.57, 0.62, 0.72);
        reflectedColor = float3(1.00, 0.98, 0.93);
    }

    float reflection = 0.18 + chromeBand * 0.40 + secondaryBand * 0.12 + specularLine * 0.35;
    float noiseLift = (fineNoise - 0.5) * 0.035;
    float3 color = baseColor * (0.72 + flow * 0.12 + noiseLift);
    color = mix(color, reflectedColor, saturate(reflection * (0.55 + edgeReflection * 0.35)));
    color += float3(0.17, 0.20, 0.30) * edgeReflection * 0.12;
    color += float3(0.17, 0.22, 0.34) * saturate(tilt.x * 0.45 + 0.5) * specularLine * 0.12;

    float pulse = 0.94 + 0.06 * sin(time * 1.256637 + flow * 2.0);
    color *= pulse;
    color = clamp(color, float3(0.0), float3(1.0));

    return half4(half3(color), sourceColor.a * half(0.72));
}
