import { loadFont } from "@remotion/fonts";
import { staticFile } from "remotion";
import assets from "./generated/assets.json";

// Bricolage Grotesque ExtraBold – a márka eldöntött webfontja minden plusz szöveghez.
// Lokálisan csomagolva (public/fonts, OFL), hogy a render ne függjön a Google Fonts CDN-től.
export const fontFamily = "Bricolage Grotesque";
const LATIN =
  "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD";
const LATIN_EXT = // Ő, ő, Ű, ű (U+0150–0171) innen jön
  "U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF";
for (const [subset, unicodeRange] of [
  ["latin", LATIN],
  ["latin-ext", LATIN_EXT],
] as const) {
  loadFont({
    family: fontFamily,
    url: staticFile(`fonts/bricolage-grotesque-${subset}-800-normal.woff2`),
    weight: "800",
    unicodeRange,
  });
}

// A posztereken lemintázott színek (prepare-assets.ts → src/generated/assets.json).
// Nem a brandguide-hexek: a videónak a poszterekkel kell pixelre egyeznie.
export const ORANGE = assets.orange;
export const YELLOW = assets.yellow;
export const WHITE = "#FFFFFF";
export const BLACK = "#000000";

export const WIDTH = 1080;
export const HEIGHT = 1920;
export const FPS = 30;
export const DURATION = 450;

// Meta Reels biztonsági zóna: felső 14% és alsó 20% foglalt, oldalt 80 px margó.
export const SAFE = {
  top: 270, // 1920 × 14% = 268,8 → 270
  bottom: Math.round(HEIGHT * 0.8), // 1536
  left: 80,
  right: WIDTH - 80,
};

// A poszter 1:1 arányban kerül a vászonra (1600 → 1080 px széles),
// függőlegesen eltolva úgy, hogy a főcím a biztonsági zónán belül kezdődjön.
export const POSTER_SCALE = WIDTH / assets.poster.width; // 0.675
export const POSTER_Y = 200;
export const posterToCanvas = (box: { left: number; top: number; width: number; height: number }) => ({
  left: box.left * POSTER_SCALE,
  top: POSTER_Y + box.top * POSTER_SCALE,
  width: box.width * POSTER_SCALE,
  height: box.height * POSTER_SCALE,
});

export const BURGERS = {
  classic: assets.classic,
  prof: assets.prof,
  genius: assets.genius,
};
export type BurgerId = keyof typeof BURGERS;
