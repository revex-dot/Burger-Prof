import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Wipe, SlideUp } from "./motion";
import { BLACK, BURGERS, BurgerId, fontFamily, ORANGE, posterToCanvas, SAFE, WHITE, WIDTH, YELLOW } from "../theme";

export type DebugProps = { textOnly: boolean };

const type: React.CSSProperties = {
  fontFamily,
  fontWeight: 800,
  letterSpacing: "-0.01em",
  margin: 0,
};

/** 0–27: HOOK fekete alapon. */
export const Hook: React.FC<DebugProps> = () => {
  const big: React.CSSProperties = { ...type, color: YELLOW, fontSize: 176, lineHeight: 0.92, textAlign: "center", whiteSpace: "nowrap" };
  return (
    <AbsoluteFill style={{ backgroundColor: BLACK, justifyContent: "center", alignItems: "center" }}>
      <div style={{ width: SAFE.right - SAFE.left, display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Wipe at={0}>
          <p style={big}>HÁROM</p>
          <p style={big}>BURGER.</p>
        </Wipe>
        <Wipe at={15} style={{ marginTop: 28 }}>
          <p style={{ ...big, fontSize: 92 }}>HÁROM KARAKTER.</p>
        </Wipe>
      </div>
    </AbsoluteFill>
  );
};

const COPY_BOTTOM = 790; // a copy-sor alja: a felnagyított buci teteje (~830 px) fölött

/** Egy burger-blokk: poszterkompozíció, folyamatos push-in, tipó wipe-pal, copy-sor becsúszással. */
export const BurgerBlock: React.FC<DebugProps & { id: BurgerId; copy: [string, string]; copyAt: number }> = ({
  id,
  copy,
  copyAt,
  textOnly,
}) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const b = BURGERS[id];
  const burger = posterToCanvas(b.burger);
  const title = posterToCanvas(b.title);
  const subtitle = posterToCanvas(b.subtitle);
  // Lineáris 1.00 → 1.08 a blokk teljes hosszán; a kép soha nem áll meg.
  const scale = interpolate(frame, [0, durationInFrames - 1], [1, 1.08]);

  return (
    <AbsoluteFill style={{ backgroundColor: textOnly ? BLACK : ORANGE }}>
      {!textOnly && (
        <Img
          src={staticFile(`assets/burger-${id}.png`)}
          style={{
            position: "absolute",
            left: burger.left,
            top: burger.top,
            width: burger.width,
            height: burger.height,
            transform: `scale(${scale})`,
            transformOrigin: "50% 50%",
          }}
        />
      )}
      <Wipe at={0} style={{ position: "absolute", left: title.left, top: title.top }}>
        <Img src={staticFile(`assets/title-${id}.png`)} style={{ width: title.width, height: title.height, display: "block" }} />
      </Wipe>
      <Wipe at={8} style={{ position: "absolute", left: subtitle.left, top: subtitle.top }}>
        <Img src={staticFile(`assets/subtitle-${id}.png`)} style={{ width: subtitle.width, height: subtitle.height, display: "block" }} />
      </Wipe>
      <SlideUp at={copyAt} style={{ position: "absolute", left: SAFE.left, right: WIDTH - SAFE.right, bottom: 1920 - COPY_BOTTOM }}>
        <p style={{ ...type, color: WHITE, fontSize: 58, lineHeight: 1.1 }}>
          {copy[0]}
          <br />
          {copy[1]}
        </p>
      </SlideUp>
    </AbsoluteFill>
  );
};

const BAND_HEIGHT = 132;

/** 345–449: PAYOFF, tiszta tipográfia három ütemben. */
export const Payoff: React.FC<DebugProps> = ({ textOnly }) => (
  <AbsoluteFill style={{ backgroundColor: textOnly ? BLACK : ORANGE }}>
    <Wipe at={0} style={{ position: "absolute", left: SAFE.left, top: 760 }}>
      <p style={{ ...type, color: YELLOW, fontSize: 106, lineHeight: 0.95 }}>
        HÁROM BURGER.
        <br />
        NEM TÖBB.
      </p>
    </Wipe>
    <Wipe at={45} style={{ position: "absolute", left: SAFE.left, top: 1030 }}>
      <p style={{ ...type, color: WHITE, fontSize: 60, lineHeight: 1.1 }}>Smash Burgers for Geniuses.</p>
    </Wipe>
    <Wipe
      at={70}
      style={{
        position: "absolute",
        left: 0,
        width: WIDTH,
        top: SAFE.bottom - BAND_HEIGHT,
        height: BAND_HEIGHT,
        backgroundColor: textOnly ? "transparent" : BLACK,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <p style={{ ...type, color: YELLOW, fontSize: 48, lineHeight: 1 }}>BALATONFÜRED · 71-ES ÚT</p>
    </Wipe>
  </AbsoluteFill>
);
