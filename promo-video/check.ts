/**
 * Render előtti ellenőrzés.
 *
 * 1. Legyártja a 6 állóképet (check/frame-<n>.png), mellé a zóna-overlayes
 *    (check/safezone/) és a „csak szöveg” (check/textonly/) változatot.
 * 2. Mér:
 *    - a narancs a videóban bitre egyezik-e a poszter hátterével,
 *    - minden szöveg a Reels biztonsági zónán belül van-e,
 *    - van-e egyenes varrat (a kivágás széle / fotó-téglalap) a narancs háttérben.
 * Hibánál 1-es kóddal lép ki.
 *
 * Futtatás: npx tsx check.ts   (zárt hálózaton: REMOTION_BROWSER=/path/to/headless_shell)
 */
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import sharp from "sharp";
import assets from "./src/generated/assets.json";

const FRAMES = [15, 60, 170, 275, 350, 440];
const ORANGE_FRAMES = new Set([60, 170, 275, 350, 440]);
const BURGER_FRAMES = new Set([60, 170, 275]);
const SAFE = { left: 80, right: 1000, top: 270, bottom: 1536 };

type RGB = [number, number, number];
const fromHex = (h: string): RGB => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)) as RGB;
const ORANGE = fromHex(assets.orange);

function still(frame: number, out: string, props: Record<string, boolean> = {}) {
  execFileSync(
    "npx",
    ["remotion", "still", "BurgerProfKarakterek", out, `--frame=${frame}`, "--image-format=png", "--log=error", `--props=${JSON.stringify(props)}`],
    { stdio: "inherit" },
  );
}

async function raw(file: string) {
  const { data, info } = await sharp(file).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  return { data, w: info.width, h: info.height, at: (x: number, y: number): RGB => {
    const i = (y * info.width + x) * 3;
    return [data[i], data[i + 1], data[i + 2]];
  } };
}

async function main() {
  for (const d of ["check", "check/safezone", "check/textonly"]) fs.mkdirSync(d, { recursive: true });
  let failed = false;
  const fail = (msg: string) => {
    failed = true;
    console.log(`  ✗ ${msg}`);
  };

  // A poszter háttere a forrásfájlból, összevetésül
  const poster = await raw("source/classic.png");
  const posterBg = poster.at(5, 5);
  console.log(`Poszter háttér (source/classic.png @5,5): rgb(${posterBg.join(", ")})  minta-hex: ${assets.orange}`);

  for (const f of FRAMES) {
    console.log(`\nframe ${f}`);
    still(f, `check/frame-${f}.png`);
    still(f, `check/safezone/frame-${f}.png`, { showSafeZone: true });
    still(f, `check/textonly/frame-${f}.png`, { textOnly: true });

    const img = await raw(`check/frame-${f}.png`);

    // 1. Narancs: tiszta háttérpontok, bitre egyezés
    if (ORANGE_FRAMES.has(f)) {
      const pts: [number, number][] = [[20, 20], [1060, 20], [20, 1900], [1060, 1900], [540, 1880], [1060, 1000]];
      const bad = pts.filter(([x, y]) => img.at(x, y).some((v, c) => v !== posterBg[c]));
      if (bad.length) fail(`narancs eltér: ${bad.map(([x, y]) => `(${x},${y})=rgb(${img.at(x, y).join(",")})`).join(" ")}`);
      else console.log(`  ✓ narancs bitre azonos a poszterrel (${pts.length} pont, rgb(${posterBg.join(", ")}))`);
    }

    // 2. Biztonsági zóna: a „csak szöveg” renderen minden nem-fekete pixel befoglalója
    const t = await raw(`check/textonly/frame-${f}.png`);
    let x0 = t.w, y0 = t.h, x1 = -1, y1 = -1;
    for (let y = 0; y < t.h; y++)
      for (let x = 0; x < t.w; x++) {
        const p = t.at(x, y);
        if (p[0] + p[1] + p[2] > 60) {
          x0 = Math.min(x0, x); x1 = Math.max(x1, x);
          y0 = Math.min(y0, y); y1 = Math.max(y1, y);
        }
      }
    if (x1 < 0) console.log("  · nincs szöveg ezen a frame-en");
    else {
      const box = `x ${x0}–${x1}, y ${y0}–${y1}`;
      if (x0 < SAFE.left || x1 > SAFE.right || y0 < SAFE.top || y1 > SAFE.bottom) fail(`szöveg kilóg a zónából: ${box}`);
      else console.log(`  ✓ szöveg a zónán belül: ${box}  (zóna: x 80–1000, y 270–1536)`);
    }

    // 3. Varrat / perem: a kivágás szélei és a poszter fotó-téglalapjának helye
    //    (poszterkoordinátában), az adott frame push-in skálájával a vászonra vetítve.
    //    Ezekben a sávokban minden pixelnek a lapos narancsnak kell lennie (±1 kerekítés).
    if (BURGER_FRAMES.has(f)) {
      const blockStart = f < 135 ? 30 : f < 240 ? 135 : 240;
      const scale = 1 + (0.08 * (f - blockStart)) / 102;
      const S = 1080 / 1600, top = 200 + 900 * S, w = 1080, h = 1100 * S;
      const toCanvas = (px: number, py: number): [number, number] => [
        w / 2 + (px * S - w / 2) * scale,
        top + h / 2 + ((py - 900) * S - h / 2) * scale,
      ];
      const bands: [string, number, number, number, number][] = [
        ["kivágás teteje + fotó-téglalap felső éle", 900, 1600, 900, 962],
        ["fotó-téglalap bal éle", 60, 125, 900, 2000],
        ["fotó-téglalap jobb éle", 1475, 1540, 900, 2000],
        ["kivágás alja + fotó-téglalap alsó éle", 0, 1600, 1915, 2000],
      ];
      for (const [name, bx0, bx1, by0, by1] of bands) {
        const [cx0, cy0] = toCanvas(bx0, by0);
        const [cx1, cy1] = toCanvas(bx1, by1);
        let n = 0, bad = 0, worst = 0;
        for (let y = Math.max(0, Math.ceil(cy0)); y <= Math.min(img.h - 1, Math.floor(cy1)); y++)
          for (let x = Math.max(0, Math.ceil(cx0)); x <= Math.min(img.w - 1, Math.floor(cx1)); x++) {
            const p = img.at(x, y);
            const d = Math.max(...p.map((v, c) => Math.abs(v - ORANGE[c])));
            n++;
            worst = Math.max(worst, d);
            if (d > 1) bad++;
          }
        if (bad) fail(`${name}: ${bad}/${n} px eltér a narancstól (max ${worst})`);
        else console.log(`  ✓ ${name}: ${n} px, max eltérés ${worst}`);
      }
    }
  }

  console.log(failed ? "\n✗ Az ellenőrzés elbukott – render előtt javítani kell." : "\n✓ Minden ellenőrzés rendben – mehet a render.");
  process.exit(failed ? 1 : 0);
}

main();
