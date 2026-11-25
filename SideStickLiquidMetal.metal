#include <metal_stdlib>
using namespace metal;

struct LiquidChromeVertexOut { float4 position [[position]]; };

vertex LiquidChromeVertexOut liquidChromeVertex(uint vertexID [[vertex_id]]) {
    const float2 corners[3] = {
        float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0)
    };
    LiquidChromeVertexOut output;
    output.position = float4(corners[vertexID], 0.0, 1.0);
    return output;
}

constexpr sampler linearClampSampler(coord::normalized, address::clamp_to_edge, filter::linear);

struct LiquidChromeSimUniforms { float4 size; float4 stroke; float4 impulse; };
struct LiquidChromeSlopeUniforms { float4 size; };
struct LiquidChromeUniforms {
    float4 resolutionUnitTime;
    float4 amplitudeFrequencyDepth;
    float4 detailSharpnessPresenceRoughness;
    float4 exposureRippleLight;
    float4 tint;
    float4 shiftAndSlopeSize;
};

static float liquidChromeSegment(float2 p, float2 a, float2 b) {
    float2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    return length(p - a - ab * t);
}

fragment float4 liquidChromeSimulation(
    float4 position [[position]],
    texture2d<float> stateTexture [[texture(0)]],
    constant LiquidChromeSimUniforms& u [[buffer(0)]]
) {
    float2 size = u.size.xy;
    float2 texel = 1.0 / size;
    float2 frag = float2(position.x, size.y - position.y);
    float2 uv = frag * texel;
    float2 state = stateTexture.sample(linearClampSampler, uv).rg;
    float2 around =
        stateTexture.sample(linearClampSampler, uv - float2(texel.x, 0.0)).rg +
        stateTexture.sample(linearClampSampler, uv + float2(texel.x, 0.0)).rg +
        stateTexture.sample(linearClampSampler, uv - float2(0.0, texel.y)).rg +
        stateTexture.sample(linearClampSampler, uv + float2(0.0, texel.y)).rg -
        4.0 * state;
    float next = state.r + (state.r - state.g) * 0.982
        + 0.3 * around.r + 0.08 * (around.r - around.g);
    next *= 0.998;
    if (u.impulse.x != 0.0) {
        float d = liquidChromeSegment(frag, u.stroke.xy, u.stroke.zw) / max(u.impulse.y, 1e-4);
        next += u.impulse.x * exp(-d * d);
    }
    return float4(next, state.r, 0.0, 1.0);
}

fragment float4 liquidChromeSlope(
    float4 position [[position]],
    texture2d<float> stateTexture [[texture(0)]],
    constant LiquidChromeSlopeUniforms& u [[buffer(0)]]
) {
    float2 size = u.size.xy;
    float2 texel = 1.0 / size;
    float2 frag = float2(position.x, size.y - position.y);
    float2 uv = frag * texel;
    float left = stateTexture.sample(linearClampSampler, uv - float2(texel.x, 0.0)).r;
    float right = stateTexture.sample(linearClampSampler, uv + float2(texel.x, 0.0)).r;
    float down = stateTexture.sample(linearClampSampler, uv - float2(0.0, texel.y)).r;
    float up = stateTexture.sample(linearClampSampler, uv + float2(0.0, texel.y)).r;
    return float4((right - left) * 0.5, (up - down) * 0.5, 0.0, 1.0);
}

static float2 liquidChromeSlopeAt(float2 uv, texture2d<float> slopeTexture, float2 slopeSize) {
    float2 st = uv * slopeSize - 0.5;
    float2 i = floor(st);
    float2 f = st - i;
    float2 f2 = f * f;
    float2 f3 = f2 * f;
    float2 w0 = (-f3 + 3.0 * f2 - 3.0 * f + 1.0) / 6.0;
    float2 w1 = (3.0 * f3 - 6.0 * f2 + 4.0) / 6.0;
    float2 w2 = (-3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0) / 6.0;
    float2 w3 = f3 / 6.0;
    float2 g0 = w0 + w1;
    float2 g1 = w2 + w3;
    float2 h0 = (i - 0.5 + w1 / g0) / slopeSize;
    float2 h1 = (i + 1.5 + w3 / g1) / slopeSize;
    float2 a = slopeTexture.sample(linearClampSampler, float2(h0.x, h0.y)).rg;
    float2 b = slopeTexture.sample(linearClampSampler, float2(h1.x, h0.y)).rg;
    float2 c = slopeTexture.sample(linearClampSampler, float2(h0.x, h1.y)).rg;
    float2 d = slopeTexture.sample(linearClampSampler, float2(h1.x, h1.y)).rg;
    return g0.y * (g0.x * a + g1.x * b) + g1.y * (g0.x * c + g1.x * d);
}

static float liquidChromeLamp(float2 p, float2 center, float2 size, float soft) {
    float2 grown = size + soft;
    float2 q = (p - center) / grown;
    q *= q;
    float d = sqrt(sqrt(dot(q, q)));
    float edge = soft / min(grown.x, grown.y);
    float shape = (1.0 - smoothstep(1.0 - edge, 1.0 + edge, d))
        * (1.0 - 0.45 * d * d);
    return shape * size.x * size.y / (grown.x * grown.y);
}

static float3 liquidChromeStudio(float3 r, float blur, constant LiquidChromeUniforms& u) {
    float2 p = r.xy / max(r.z + 1.0, 0.05);
    p += u.shiftAndSlopeSize.xy * smoothstep(0.3, 1.0, length(p));
    float radius = length(p);
    float soft = 0.008 + blur;
    float2 dir = p / max(radius, 1e-3);
    float key = liquidChromeLamp(p, float2(-0.25, 0.42), float2(0.3, 0.12), soft);
    float side = liquidChromeLamp(p, float2(0.48, 0.12), float2(0.06, 0.3), soft);
    float ground = liquidChromeLamp(p, float2(-0.1, -0.55), float2(0.45, 0.06), soft);
    float rise = smoothstep(-1.0, 1.0, dir.y);
    if (u.exposureRippleLight.z > 0.5) {
        float edge = 0.008 + blur * 0.8;
        float lobe = smoothstep(0.15, 0.85, 0.5 + 0.5 * sin(atan2(dir.y, dir.x) * 2.0 + 0.9));
        float tone = mix(2.4, 0.95, smoothstep(0.5 - edge, 1.0 + edge, radius));
        tone = mix(tone, 0.02, smoothstep(0.98 - edge, 1.12 + edge, radius));
        tone = mix(tone, mix(0.03, 0.3, lobe) * (0.8 + 0.4 * rise),
            smoothstep(1.15 - edge, 1.3 + edge, radius));
        float width = 0.035 + edge;
        tone += 2.4 * exp(-pow((radius - 1.4) / width, 2.0))
            * min(1.0, 0.06 / width) * (0.6 + 0.4 * rise);
        return float3(tone) * (1.0 - 0.5 * side) * (1.0 - 0.3 * ground) + 0.8 * key;
    }
    float width = 0.015 + soft * 2.0;
    float rim = exp(-abs(radius - 1.0) / width) * 0.031 / width
        * (0.8 + smoothstep(-0.5, 0.8, p.y));
    float band = 1.0 - 0.95 * smoothstep(1.04 - soft, 1.12 + soft, radius);
    float wall = smoothstep(1.25, 1.55, radius) * (0.6 + 0.4 * rise);
    float streak = smoothstep(0.2, 0.8, 0.5 + 0.5 * sin(atan2(dir.y, dir.x) * 3.0 + 0.6));
    float3 color = float3(0.004, 0.004, 0.005) + 0.02 * smoothstep(-0.4, 0.6, p.y);
    color += float3(1.0, 0.97, 0.94) * key * 4.0 + float3(0.9, 0.95, 1.0) * side * 3.0 + ground * 1.2;
    color += float3(1.0, 0.98, 0.95) * rim;
    color *= band;
    return color + float3(mix(0.45, 1.8, streak)) * wall;
}

static float3 liquidChromeShade(float2 slope, float3 view, float blur, float3 f0,
                                constant LiquidChromeUniforms& u) {
    float steep = length(slope);
    slope *= 3.0 * tanh(steep / 3.0) / max(steep, 1e-6);
    float3 normal = normalize(float3(-slope, 1.0));
    float3 reflected = reflect(view, normal);
    float facing = clamp(dot(normal, -view), 0.0, 1.0);
    return liquidChromeStudio(reflected, blur, u)
        * (f0 + (1.0 - f0) * pow(1.0 - facing, 5.0));
}

static float3 liquidChromeACES(float3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

fragment float4 liquidChromeComposite(
    float4 position [[position]],
    texture2d<float> slopeTexture [[texture(0)]],
    constant LiquidChromeUniforms& u [[buffer(0)]]
) {
    float2 resolution = u.resolutionUnitTime.xy;
    float unit = u.resolutionUnitTime.z;
    float time = u.resolutionUnitTime.w;
    float2 frag = float2(position.x, resolution.y - position.y);
    float2 uv = (2.0 * frag - resolution) / unit;
    float2 p = uv;
    float2 rowX = float2(1.0, 0.0);
    float2 rowY = float2(0.0, 1.0);
    float amplitude = u.amplitudeFrequencyDepth.x * u.detailSharpnessPresenceRoughness.z;
    for (float i = 1.0; i < 9.0; i += 1.0) {
        if (i > u.detailSharpnessPresenceRoughness.x) break;
        float a = amplitude / i;
        float soften = exp(0.3 - 0.3 * i);
        float argX = i * u.amplitudeFrequencyDepth.y * p.y + time;
        p.x += a * cos(argX);
        rowX -= a * sin(argX) * i * u.amplitudeFrequencyDepth.y * soften * rowY;
        float argY = i * u.amplitudeFrequencyDepth.z * p.x + time;
        p.y += a * cos(argY);
        rowY -= a * sin(argY) * i * u.amplitudeFrequencyDepth.z * soften * rowX;
    }

    float phase = time - p.x - p.y;
    float2 field = -(rowX + rowY);
    float density = max(length(field), 1e-3);
    float2 across = field / density;
    float k = u.detailSharpnessPresenceRoughness.y;
    float sn = sin(phase);
    float cs = cos(phase);
    float th = tanh(k * sn);
    float bevel = (1.0 - th * th) / tanh(k);
    float fade = smoothstep(3.0, 9.0, 3.14159 * unit / density);
    float weight = u.amplitudeFrequencyDepth.w * u.detailSharpnessPresenceRoughness.z * fade;
    float2 slope = k * cs * bevel * weight * across
        + liquidChromeSlopeAt(frag / resolution, slopeTexture, u.shiftAndSlopeSize.zw)
        * u.exposureRippleLight.y;
    float2 sweep = -k * bevel * (sn + 2.0 * k * cs * cs * th)
        * weight * density * 2.0 / unit * across;
    float2 stepX = dfdx(slope);
    float2 stepY = dfdy(slope);
    float2 crease = dot(stepX, stepX) > dot(stepY, stepY) ? stepX : stepY;
    if (dot(crease, crease) > dot(sweep, sweep)) sweep = crease;
    float bend = length(sweep);
    float alpha = smoothstep(0.0, 0.1, length(slope));
    float3 f0 = mix(float3(1.0), u.tint.xyz, smoothstep(0.05, 0.6, length(slope))) * 0.92;
    float3 view = normalize(float3(uv * 0.08, -1.0));
    float blur = u.detailSharpnessPresenceRoughness.w * 0.35;
    float3 light;
    if (bend < 0.01) {
        light = liquidChromeShade(slope, view, blur + bend * 0.5, f0, u);
    } else {
        light = float3(0.0);
        for (float t = -0.375; t < 0.4; t += 0.25) {
            light += liquidChromeShade(slope + sweep * t, view, blur + bend * 0.15, f0, u);
        }
        light *= 0.25;
    }

    float3 color = pow(liquidChromeACES(light * u.exposureRippleLight.x), float3(1.0 / 2.2));
    float grain = fract(52.9829189 * fract(dot(frag, float2(0.06711056, 0.00583715))));
    color += (grain - 0.5) / 255.0;
    color = clamp(color, 0.0, 1.0);
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    float3 grayscale = float3(luminance);
    return float4(grayscale * alpha, alpha);
}
