/**
 * Asset-előkészítés a promóvideóhoz.
 *
 * Bemenet: source/{classic,prof,genius}.png (1600×2000, 4:5 poszterek)
 * Kimenet:
 *   public/assets/title-<id>.png     – főcím, alfa-unmixelt sárga (háttér nélkül)
 *   public/assets/subtitle-<id>.png  – alcím, ugyanígy
 *   public/assets/burger-<id>.png    – burger + doboz szögletes kivágása (narancs háttérrel)
 *   src/generated/assets.json        – lemintázott színek + kivágások poszterkoordinátái
 *
 * Futtatás: npx tsx prepare-assets.ts
 */
import sharp from "sharp";
import fs from "node:fs";
import path from "node:path";

const IDS = ["classic", "prof", "genius"] as const;
type RGB = [number, number, number];

const SRC = "source";
const OUT = "public/assets";
const GEN = "src/generated";

// A burgerkivágás felső széle poszter-pixelben: itt még biztosan tiszta háttér van
// (a burger a ~970. sorban kezdődik mindhárom poszteren).
const BURGER_TOP = 900;
// A tipográfia a poszter felső részében van; ez alatt már csak a fotó.
const TYPO_SEARCH_BOTTOM = 900;

const hex = (c: RGB) =>
  "#" + c.map((v) => Math.round(v).toString(16).padStart(2, "0")).join("").toUpperCase();
const dist = (a: RGB, b: RGB) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);

type Img = { data: Buffer; w: number; h: number };
const px = (img: Img, x: number, y: number): RGB => {
  const i = (y * img.w + x) * 3;
  return [img.data[i], img.data[i + 1], img.data[i + 2]];
};

async function load(file: string): Promise<Img> {
  const { data, info } = await sharp(file)
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  return { data, w: info.width, h: info.height };
}

function avg(img: Img, x0: number, y0: number, w: number, h: number): RGB {
  const s = [0, 0, 0];
  for (let y = y0; y < y0 + h; y++)
    for (let x = x0; x < x0 + w; x++) {
      const p = px(img, x, y);
      s[0] += p[0];
      s[1] += p[1];
      s[2] += p[2];
    }
  const n = w * h;
  return [s[0] / n, s[1] / n, s[2] / n].map(Math.round) as RGB;
}

/** Sorsávok (y-tartományok), ahol van háttértől eltérő pixel. */
function rowBands(img: Img, bg: RGB, y0: number, y1: number, thr = 40) {
  const bands: { top: number; bottom: number }[] = [];
  let cur: { top: number; bottom: number } | null = null;
  for (let y = y0; y < y1; y++) {
    let hit = false;
    for (let x = 0; x < img.w && !hit; x++) if (dist(px(img, x, y), bg) > thr) hit = true;
    if (hit) {
      if (cur && y - cur.bottom <= 20) cur.bottom = y;
      else bands.push((cur = { top: y, bottom: y }));
    }
  }
  return bands;
}

function colBounds(img: Img, bg: RGB, top: number, bottom: number, thr = 40) {
  let left = img.w,
    right = 0;
  for (let y = top; y <= bottom; y++)
    for (let x = 0; x < img.w; x++)
      if (dist(px(img, x, y), bg) > thr) {
        left = Math.min(left, x);
        right = Math.max(right, x);
      }
  return { left, right };
}

/** A szöveg „tömör” színe: a háttértől legtávolabbi pixelek átlaga. */
function sampleInk(img: Img, bg: RGB, box: Box): RGB {
  let max = 0;
  for (let y = box.top; y < box.top + box.height; y++)
    for (let x = box.left; x < box.left + box.width; x++) max = Math.max(max, dist(px(img, x, y), bg));
  const s = [0, 0, 0];
  let n = 0;
  for (let y = box.top; y < box.top + box.height; y++)
    for (let x = box.left; x < box.left + box.width; x++) {
      const p = px(img, x, y);
      if (dist(p, bg) >= max - 6) {
        s[0] += p[0];
        s[1] += p[1];
        s[2] += p[2];
        n++;
      }
    }
  return [s[0] / n, s[1] / n, s[2] / n].map(Math.round) as RGB;
}

type Box = { left: number; top: number; width: number; height: number };

/**
 * Kétszínű (háttér + tinta) szöveg alfa-szétválasztása: minden pixel
 * p = bg + a·(ink − bg), ebből a = vetület. A kimenet tiszta tinta-szín + alfa,
 * így ugyanarra a háttérre visszakomponálva bitre azonos a poszterrel.
 */
async function extractInk(img: Img, bg: RGB, ink: RGB, box: Box, file: string) {
  const out = Buffer.alloc(box.width * box.height * 4);
  const d: RGB = [ink[0] - bg[0], ink[1] - bg[1], ink[2] - bg[2]];
  const dd = d[0] * d[0] + d[1] * d[1] + d[2] * d[2];
  for (let y = 0; y < box.height; y++)
    for (let x = 0; x < box.width; x++) {
      const p = px(img, box.left + x, box.top + y);
      const a = Math.max(
        0,
        Math.min(1, ((p[0] - bg[0]) * d[0] + (p[1] - bg[1]) * d[1] + (p[2] - bg[2]) * d[2]) / dd),
      );
      const o = (y * box.width + x) * 4;
      out[o] = ink[0];
      out[o + 1] = ink[1];
      out[o + 2] = ink[2];
      out[o + 3] = Math.round(a * 255);
    }
  await sharp(out, { raw: { width: box.width, height: box.height, channels: 4 } })
    .png()
    .toFile(file);
}

/**
 * Színkulcs-próba: megnézzük, hány pixel esne ki a burger *belsejéből*, ha a
 * narancsot alfára kulcsoznánk. A belső lyuk = háttérközeli pixel, amely
 * soronként a burger bal és jobb széle között van.
 */
function keyHoleRatio(img: Img, bg: RGB, top: number) {
  let inside = 0,
    holes = 0;
  for (let y = top; y < img.h; y++) {
    let l = -1,
      r = -1;
    for (let x = 0; x < img.w; x++)
      if (dist(px(img, x, y), bg) > 40) {
        if (l < 0) l = x;
        r = x;
      }
    if (l < 0) continue;
    for (let x = l; x <= r; x++) {
      inside++;
      if (dist(px(img, x, y), bg) < 30) holes++;
    }
  }
  return holes / inside;
}

// Háttér-normalizálás küszöbei (RGB-távolság a lapos narancstól).
const FLAT_BELOW = 9; // a fotó-téglalap háttere mérten max 8 egységgel tér el → ez alatt tisztán lapos narancs
const KEEP_ABOVE = 15; // ennél távolabb: eredeti fotópixel; közte lineáris keverés (szűk sáv, hogy a buci árnyalata megmaradjon)

/**
 * A poszteren a burgerfotó egy saját téglalapban ül, amelynek háttere szemcsés és
 * néhány egységgel eltér a lapos narancstól. Állóképen alig látszik, de a push-in
 * közben a téglalap „kártyaként” mozogna. Ezért a háttérközeli pixeleket a lapos
 * narancsra húzzuk – alfa nélkül, így a buci narancs részei sem lyukadnak ki
 * (legfeljebb ~10 egységgel simulnak a háttérhez, ami láthatatlan).
 */
function normalizeBackground(img: Img, bg: RGB, box: Box) {
  const out = Buffer.alloc(box.width * box.height * 3);
  let flattened = 0;
  let maxBefore = 0;
  for (let y = 0; y < box.height; y++)
    for (let x = 0; x < box.width; x++) {
      const p = px(img, box.left + x, box.top + y);
      const d = dist(p, bg);
      const k = Math.max(0, Math.min(1, (d - FLAT_BELOW) / (KEEP_ABOVE - FLAT_BELOW)));
      if (k < 1) {
        flattened++;
        maxBefore = Math.max(maxBefore, d);
      }
      const o = (y * box.width + x) * 3;
      for (let c = 0; c < 3; c++) out[o + c] = Math.round(bg[c] + (p[c] - bg[c]) * k);
    }
  return { out, flattened, maxBefore };
}

/** A kivágás kerete mennyire tér el a háttértől (varrat-ellenőrzés). */
function borderMaxDiff(img: Img, bg: RGB, box: Box) {
  let m = 0;
  const check = (x: number, y: number) => {
    const p = px(img, x, y);
    m = Math.max(m, Math.abs(p[0] - bg[0]), Math.abs(p[1] - bg[1]), Math.abs(p[2] - bg[2]));
  };
  for (let x = box.left; x < box.left + box.width; x++) {
    check(x, box.top);
    check(x, box.top + box.height - 1);
  }
  for (let y = box.top; y < box.top + box.height; y++) {
    check(box.left, y);
    check(box.left + box.width - 1, y);
  }
  return m;
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  fs.mkdirSync(GEN, { recursive: true });

  const result: Record<string, unknown> = {};
  const bgs: RGB[] = [];
  const inks: RGB[] = [];

  for (const id of IDS) {
    const file = path.join(SRC, `${id}.png`);
    const img = await load(file);
    if (img.w !== 1600 || img.h !== 2000) throw new Error(`${file}: váratlan méret ${img.w}×${img.h}`);

    // 1. Háttér: bal felső 10×10 átlaga (+ kontroll a többi sarokban)
    const bg = avg(img, 0, 0, 10, 10);
    const corners = [avg(img, img.w - 10, 0, 10, 10), avg(img, 0, img.h - 10, 10, 10), avg(img, img.w - 10, img.h - 10, 10, 10)];
    const cornerDev = Math.max(...corners.map((c) => dist(c, bg)));

    // 2. Tipográfia: az első két sorsáv = főcím, alcím
    const bands = rowBands(img, bg, 0, TYPO_SEARCH_BOTTOM);
    if (bands.length !== 2) throw new Error(`${id}: ${bands.length} tipósáv a várt 2 helyett`);
    const PAD = 6;
    const boxes = bands.map((b) => {
      const c = colBounds(img, bg, b.top, b.bottom);
      return {
        left: c.left - PAD,
        top: b.top - PAD,
        width: c.right - c.left + 1 + 2 * PAD,
        height: b.bottom - b.top + 1 + 2 * PAD,
      };
    });
    const ink = sampleInk(img, bg, boxes[0]);
    const subInk = sampleInk(img, bg, boxes[1]);
    await extractInk(img, bg, ink, boxes[0], path.join(OUT, `title-${id}.png`));
    await extractInk(img, bg, ink, boxes[1], path.join(OUT, `subtitle-${id}.png`));

    // 3. Burger: kulcsolás vs. szögletes kivágás
    const holeRatio = keyHoleRatio(img, bg, BURGER_TOP);
    const burgerBox: Box = { left: 0, top: BURGER_TOP, width: img.w, height: img.h - BURGER_TOP };
    const seam = borderMaxDiff(img, bg, burgerBox);
    const norm = normalizeBackground(img, bg, burgerBox);
    await sharp(norm.out, { raw: { width: burgerBox.width, height: burgerBox.height, channels: 3 } })
      .png()
      .toFile(path.join(OUT, `burger-${id}.png`));

    console.log(`\n[${id}]`);
    console.log(`  háttér (bal felső 10×10):  ${hex(bg)}  rgb(${bg.join(", ")})   sarkak max eltérése: ${cornerDev.toFixed(1)}`);
    console.log(`  főcím sárga:               ${hex(ink)}  rgb(${ink.join(", ")})`);
    console.log(`  alcím sárga:               ${hex(subInk)}  rgb(${subInk.join(", ")})`);
    console.log(`  főcím doboz:  ${JSON.stringify(boxes[0])}`);
    console.log(`  alcím doboz:  ${JSON.stringify(boxes[1])}`);
    console.log(`  kulcs-próba: a burger belsejének ${(holeRatio * 100).toFixed(1)}%-a háttérszínű → kulcsolásnál kilyukadna`);
    console.log(`  szögletes kivágás kerete max ${seam} egységgel tér el a háttértől (0–2 = láthatatlan varrat)`);
    console.log(
      `  háttér-normalizálás: ${((norm.flattened / (burgerBox.width * burgerBox.height)) * 100).toFixed(1)}% pixel húzva a lapos narancsra ` +
        `(d < ${FLAT_BELOW}: teljesen, ${FLAT_BELOW}–${KEEP_ABOVE}: keverve; max eredeti eltérés ezekben: ${norm.maxBefore.toFixed(1)})`,
    );

    bgs.push(bg);
    inks.push(ink);
    result[id] = { bg: hex(bg), ink: hex(ink), title: boxes[0], subtitle: boxes[1], burger: burgerBox, keyHoleRatio: holeRatio, seam };
  }

  // A három poszter hátterének egyeznie kell – különben nem lehet közös narancs a videóban.
  const bgSpread = Math.max(...bgs.map((b) => dist(b, bgs[0])));
  const inkSpread = Math.max(...inks.map((b) => dist(b, inks[0])));
  if (bgSpread > 2) throw new Error(`A három poszter háttere eltér (${bgSpread.toFixed(1)}) – külön háttér kellene blokkonként`);

  const orange = hex(bgs[0]);
  const yellow = hex(inks[0]);
  console.log(`\nKözös narancs: ${orange} (eltérés a posztereken: ${bgSpread.toFixed(1)})`);
  console.log(`Közös sárga:   ${yellow} (eltérés a posztereken: ${inkSpread.toFixed(1)})`);
  console.log(`(Brandguide-hexek összevetésül: narancs #E74B23, sárga #EDCE08)`);

  const maxHole = Math.max(...IDS.map((id) => (result[id] as { keyHoleRatio: number }).keyHoleRatio));
  const method = maxHole > 0.005 ? "rect" : "key";
  console.log(
    `\nKivágási módszer: ${method === "rect" ? "SZÖGLETES (háttér megtartva)" : "színkulcs"} – ` +
      `a kulcs a burger belsejének akár ${(maxHole * 100).toFixed(1)}%-át kilyukasztaná (narancs alsó buci, buci-csúcsfények).`,
  );
  if (method !== "rect") throw new Error("A kompozíció jelenleg szögletes kivágásra épül – nézd át a döntést.");

  fs.writeFileSync(
    path.join(GEN, "assets.json"),
    JSON.stringify({ poster: { width: 1600, height: 2000 }, orange, yellow, method, ...result }, null, 2) + "\n",
  );
  console.log(`\n→ ${OUT}/*.png, ${GEN}/assets.json`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
