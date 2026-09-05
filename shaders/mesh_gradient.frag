#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// #***! свёрл-дисторсия + радиально-взвешенное смешение цветов по опорным
// точкам — тот же принцип, что даёт "живой" анимированный фон в Telegram
// (portировано с их нативного generateGradient, image.cpp)

uniform vec2 uSize;
uniform float uColorCount;
uniform float uPhase;
uniform float uProgress;
uniform vec4 uColor0;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform vec4 uColor3;
uniform vec4 uColor4;
uniform vec4 uColor5;

out vec4 fragColor;

const int POSITIONS_COUNT = 8;

int mod8(int v) {
  return v - (v / POSITIONS_COUNT) * POSITIONS_COUNT;
}

vec2 rawPositionAt(int idx) {
  if (idx == 0) return vec2(0.80, 0.10);
  if (idx == 1) return vec2(0.60, 0.20);
  if (idx == 2) return vec2(0.35, 0.25);
  if (idx == 3) return vec2(0.25, 0.60);
  if (idx == 4) return vec2(0.20, 0.90);
  if (idx == 5) return vec2(0.40, 0.80);
  if (idx == 6) return vec2(0.65, 0.75);
  return vec2(0.75, 0.40);
}

vec2 positionFor(int colorIndex, int phase) {
  int idx = mod8(colorIndex * 2 + phase);
  vec2 pos = rawPositionAt(idx);
  return vec2(pos.x, 1.0 - pos.y);
}

vec4 colorAt(int i) {
  if (i == 0) return uColor0;
  if (i == 1) return uColor1;
  if (i == 2) return uColor2;
  if (i == 3) return uColor3;
  if (i == 4) return uColor4;
  return uColor5;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;

  int colorsCount = int(uColorCount);
  if (colorsCount <= 1) {
    fragColor = colorAt(0);
    return;
  }

  vec2 centerDistance = uv - 0.5;
  float centerDist = length(centerDistance);
  float swirlFactor = 0.35 * centerDist;
  float theta = swirlFactor * swirlFactor * 0.8 * 8.0;
  float sinTheta = sin(theta);
  float cosTheta = cos(theta);

  vec2 p = vec2(
    clamp(0.5 + centerDistance.x * cosTheta - centerDistance.y * sinTheta, 0.0, 1.0),
    clamp(0.5 + centerDistance.x * sinTheta + centerDistance.y * cosTheta, 0.0, 1.0)
  );

  int phase = mod8(int(uPhase));
  int nextPhase = mod8(phase + 1);

  float distanceSum = 0.0;
  vec3 accum = vec3(0.0);

  for (int i = 0; i < 6; i++) {
    if (i >= colorsCount) break;
    vec2 curPos = positionFor(i, phase);
    vec2 nextPos = positionFor(i, nextPhase);
    vec2 pos = mix(curPos, nextPos, uProgress);

    float d = max(0.0, 0.9 - distance(p, pos));
    d = d * d * d * d;
    distanceSum += d;
    accum += d * colorAt(i).rgb;
  }

  vec3 color = distanceSum > 0.0001 ? accum / distanceSum : colorAt(0).rgb;
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
