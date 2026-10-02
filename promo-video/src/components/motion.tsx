import React from "react";
import { Easing, interpolate, useCurrentFrame } from "remotion";

const ease = Easing.out(Easing.cubic);

/** 0→1 haladás `duration` frame alatt; már az első frame-en látszik (nincs üres frame). */
const progress = (frame: number, start: number, duration: number) =>
  ease(interpolate(frame - start + 1, [0, duration], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));

/**
 * Tipográfia-belépés: egy frame alatt 100% opacitás, alulról felfelé
 * clip-path wipe 6 frame alatt. Nincs fade, nincs blur.
 */
export const Wipe: React.FC<{ at: number; style?: React.CSSProperties; children: React.ReactNode }> = ({ at, style, children }) => {
  const frame = useCurrentFrame();
  if (frame < at) return null;
  const p = progress(frame, at, 6);
  // A felső inset 100%-ról (semmi) −30%-ra (ékezetekkel együtt minden) fut; az alsó/oldalsó
  // negatív inset, hogy a sorközből kilógó ékezet/ereszték se vágódjon le.
  const top = interpolate(p, [0, 1], [100, -30]);
  return <div style={{ ...style, clipPath: `inset(${top}% -10% -30% -10%)` }}>{children}</div>;
};

/** Copy-sor: alulról csúszik be 24 px-ről, 8 frame alatt. Nincs fade. */
export const SlideUp: React.FC<{ at: number; style?: React.CSSProperties; children: React.ReactNode }> = ({ at, style, children }) => {
  const frame = useCurrentFrame();
  if (frame < at) return null;
  const p = progress(frame, at, 8);
  return <div style={{ ...style, transform: `translateY(${24 * (1 - p)}px)` }}>{children}</div>;
};
