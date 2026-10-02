import React from "react";
import { AbsoluteFill } from "remotion";
import { HEIGHT, SAFE, WIDTH } from "../theme";

const shade = "rgba(0, 160, 255, 0.35)";

/** Debug: a Meta Reels UI által takart sávok + a szövegbiztos keret. */
export const SafeZone: React.FC = () => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    <div style={{ position: "absolute", left: 0, top: 0, width: WIDTH, height: SAFE.top, background: shade }} />
    <div style={{ position: "absolute", left: 0, top: SAFE.bottom, width: WIDTH, height: HEIGHT - SAFE.bottom, background: shade }} />
    <div
      style={{
        position: "absolute",
        left: SAFE.left,
        top: SAFE.top,
        width: SAFE.right - SAFE.left,
        height: SAFE.bottom - SAFE.top,
        outline: "3px dashed #00A0FF",
      }}
    />
  </AbsoluteFill>
);
