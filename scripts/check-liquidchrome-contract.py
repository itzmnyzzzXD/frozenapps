#!/usr/bin/env python3
"""Source-level contract checks for the native LiquidChrome Metal renderer."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
renderer = (root / "InstallerIntegration/LiquidChromeBackground.swift").read_text(encoding="utf-8")
shader = (root / "InstallerIntegration/SideStickLiquidMetal.metal").read_text(encoding="utf-8")
failures = []

def require(condition, message):
    if not condition:
        failures.append(message)

defaults = {
    "white color": r"color:\s*SIMD3<Float>\(1, 1, 1\)",
    "speed": r"speed:\s*0\.2",
    "amplitude": r"amplitude:\s*0\.8",
    "detail": r"detail:\s*2",
    "thickness": r"thickness:\s*0\.3",
    "interactive": r"interactive:\s*true",
    "depth": r"depth:\s*0\.8",
    "roughness": r"roughness:\s*0",
    "exposure": r"exposure:\s*2",
    "ripple strength": r"rippleStrength:\s*1\.4",
    "tilt": r"tilt:\s*0\.65",
}
for label, pattern in defaults.items():
    require(re.search(pattern, renderer) is not None, f"default parameter mismatch: {label}")

for label, token in (
    ("Reduce Motion interaction suppression", "interactionSuppressed = reduceMotion || lowPowerMode"),
    ("Reduce Transparency shader flag", "reduceTransparency ? 1 : 0"),
    ("Increase Contrast shader flag", "increasedContrast ? 1 : 0"),
    ("low-power simulation reset", "needsSimulationReset = true"),
    ("scene visibility policy", "refreshPlaybackPolicy()"),
    ("pixel budget", "parameters.pixelBudget"),
):
    require(token in renderer, f"missing renderer behavior: {label}")

for label, token in (
    ("GLSL/Metal texture origin conversion", "1.0 - glUV.y"),
    ("analytic x derivative", "dfdx(slope)"),
    ("analytic y derivative", "-dfdy(slope)"),
    ("angle-aware lighting", "atan2("),
    ("premultiplied grayscale output", "return float4(grayscale * outputAlpha, outputAlpha)"),
):
    require(token in shader, f"missing Metal behavior: {label}")

require("float3 grayscale = float3(luminance)" in shader, "shader output is not explicitly grayscale")
require("u.exposureRippleLight.w > 0.5" in shader, "Reduce Transparency is not applied in shader")
require("u.tint.w > 0.5" in shader, "Increase Contrast is not applied in shader")

swift_uniform = renderer.split("private struct LiquidChromeUniforms", 1)[-1].split("\n}", 1)[0]
metal_uniform = shader.split("struct LiquidChromeUniforms", 1)[-1].split("\n};", 1)[0]
require(swift_uniform.count("SIMD4<Float>") == 6, "Swift uniform layout changed")
require(metal_uniform.count("float4") == 6, "Metal uniform layout changed")

if failures:
    for item in failures:
        print("FAIL: " + item)
    raise SystemExit(f"FAIL: {len(failures)} LiquidChrome contract violation(s).")

print("PASS: exact LiquidChrome defaults: white, speed 0.2, amplitude 0.8, detail 2, thickness 0.3, depth 0.8, ripple 1.4, tilt 0.65.")
print("PASS: Reduce Motion, Reduce Transparency, Increase Contrast, low-power reset and visible-frame policy.")
print("PASS: GLSL/Metal UV origin, dfdx/dfdy, atan2, grayscale and premultiplied-alpha output.")
print("PASS: Swift/Metal uniform layout remains six aligned SIMD4/float4 members.")
