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
    float2 surfaceSize,
    float speed,
    float amplitude,
    float detail,
    float thickness,
    float depth,
    float roughness,
    float exposure,
    float rippleStrength,
    float tiltAmount
) {
    float2 safeSize = max(surfaceSize, float2(1.0));
    float2 uv = clamp(position / safeSize, float2(0.0), float2(1.0));
    float2 centered = uv * 2.0 - 1.0;

    float2 interactiveTilt = tilt * tiltAmount;
    float clock = time * speed;
    float detailScale = max(detail, 1.0);

    float driftA = sin(
        (centered.x * (1.5 + detailScale * 0.55)
        + centered.y * 0.72
        + clock * 0.42
        + interactiveTilt.x * 1.8) * 6.28318
    );
    float driftB = cos(
        (centered.y * (1.7 + detailScale * 0.70)
        - centered.x * 0.85
        - clock * 0.30
        + interactiveTilt.y * 1.6) * 6.28318
    );

    float radialDistance = length(centered - interactiveTilt * 0.3);
    float rippleWave = sin(
        radialDistance * (8.0 + detailScale * 2.2) - clock * 1.7
    ) * exp(-radialDistance * (1.2 + depth));

    float flow = ((driftA + driftB) * 0.5
        + rippleWave * rippleStrength * 0.22) * amplitude;

    float fineNoise = hash21(floor(position * 0.14) + floor(time * 0.35));
    float noiseLift = (fineNoise - 0.5) * mix(0.002, 0.035, saturate(roughness));

    float wavePosition = uv.y + flow * 0.075 * depth + interactiveTilt.y * 0.12;
    float bandSharpness = mix(8.0, 22.0, 1.0 - saturate(thickness));
    float chromeBand = pow(
        saturate(0.5 + 0.5 * cos((wavePosition * (4.2 + detailScale * 2.0)
        + interactiveTilt.x * 0.7) * 6.28318)),
        bandSharpness
    );
    float secondaryBand = pow(
        saturate(0.5 + 0.5 * sin((uv.x * 4.6 - uv.y * 2.1 + clock * 0.35) * 6.28318)),
        mix(8.0, 20.0, 1.0 - saturate(roughness))
    );
    float specularLine = pow(
        saturate(1.0 - abs(uv.y - 0.20 - flow * 0.035 - interactiveTilt.y * 0.09)),
        mix(12.0, 26.0, 1.0 - saturate(thickness))
    );
    float edgeReflection = pow(saturate(1.0 - abs(centered.x) * (0.65 + depth * 0.18)), 2.0);

    // Luminance-only output keeps the surface strictly black and white.
    float reflection = 0.14 + chromeBand * 0.44 + secondaryBand * 0.12 + specularLine * 0.36;
    float baseLuminance = variant < 0.5 ? 0.42 : (variant < 1.5 ? 0.10 : 0.68);
    float reflectedLuminance = variant < 0.5 ? 0.94 : (variant < 1.5 ? 0.48 : 1.0);
    float luminance = baseLuminance * (0.72 + flow * 0.12 + noiseLift);
    luminance = mix(luminance, reflectedLuminance, saturate(reflection * (0.55 + edgeReflection * 0.35)));
    luminance += edgeReflection * 0.025;
    luminance += saturate(interactiveTilt.x * 0.45 + 0.5) * specularLine * 0.025;

    float exposureGain = 1.0 + clamp(exposure, 0.0, 2.0) * 0.08;
    luminance = saturate(luminance * exposureGain);

    float pulse = 0.94 + 0.06 * sin(time * 1.256637 + flow * 2.0);
    float3 color = float3(luminance * pulse);
    color = clamp(color, float3(0.0), float3(1.0));

    float outputAlpha = float(sourceColor.a) * 0.72;
    return half4(half3(color * outputAlpha), half(outputAlpha));
}
