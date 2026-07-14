#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec2 uRectOrigin;
uniform vec2 uRectSize;
uniform float uRadius;
uniform float uSpread;
uniform float uRefraction;
uniform float uChroma;
uniform float uSpecular;
uniform vec4 uTint;
uniform vec2 uLight;
uniform float uTintFeather;
uniform float uRimWidth;

uniform sampler2D uBackdrop;

out vec4 fragColor;

float roundedBoxSdf(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

vec2 surfaceNormal(vec2 p, vec2 halfSize, float radius) {
  vec2 unit = vec2(1.0, 0.0);
  float dx = roundedBoxSdf(p + unit.xy, halfSize, radius) -
             roundedBoxSdf(p - unit.xy, halfSize, radius);
  float dy = roundedBoxSdf(p + unit.yx, halfSize, radius) -
             roundedBoxSdf(p - unit.yx, halfSize, radius);
  return normalize(vec2(dx, dy) + vec2(1e-6));
}

const int TAPS = 5;

float displacement(float distance, float reach) {
  float bevel = 1.0 - clamp(-distance / reach, 0.0, 1.0);
  return uRefraction * bevel * bevel * (1.0 + bevel);
}

vec3 sampleBackdrop(vec2 coord) {
  vec2 uv = coord / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 halfSize = uRectSize * 0.5;
  vec2 center = uRectOrigin + halfSize;
  vec2 p = fragCoord - center;

  float radius = min(uRadius, min(halfSize.x, halfSize.y));
  float sd = roundedBoxSdf(p, halfSize, radius);

  if (sd > 0.0) {
    fragColor = vec4(sampleBackdrop(fragCoord), 1.0);
    return;
  }

  vec2 normal = surfaceNormal(p, halfSize, radius);
  float reach = max(uSpread * min(halfSize.x, halfSize.y), 1.0);
  float shift = displacement(sd, reach);
  float lens = shift / max(uRefraction, 1e-6);

  float slope = displacement(sd + 1.0, reach) - displacement(sd - 1.0, reach);
  float footprint = clamp(abs(1.0 + slope * 0.5), 1.0, 24.0);
  float aberration = uChroma * lens;

  vec3 refracted = vec3(0.0);
  for (int i = 0; i < TAPS; i++) {
    float offset = (float(i) / float(TAPS - 1) - 0.5) * footprint;
    vec2 base = fragCoord + normal * (shift + offset);
    if (aberration > 0.0) {
      refracted.r += sampleBackdrop(base + normal * shift * aberration).r;
      refracted.g += sampleBackdrop(base).g;
      refracted.b += sampleBackdrop(base - normal * shift * aberration).b;
    } else {
      refracted += sampleBackdrop(base);
    }
  }
  refracted /= float(TAPS);

  float veil = smoothstep(0.0, 1.0, clamp(-sd / max(uTintFeather, 1.0), 0.0, 1.0));
  vec3 color = mix(refracted, uTint.rgb, uTint.a * veil);

  vec2 light = normalize(uLight + vec2(1e-6));
  float facing = dot(normal, light);
  float rim = 1.0 - clamp(-sd / max(uRimWidth, 1.0), 0.0, 1.0);
  rim = rim * rim;
  float highlight = pow(max(facing, 0.0), 5.0) * rim * uSpecular;
  float shade = pow(max(-facing, 0.0), 4.0) * rim * uSpecular * 0.35;

  color += vec3(highlight);
  color = mix(color, color * 0.72, shade);

  fragColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
