# Burger Prof – „Három burger. Három karakter.” (9:16, 15 mp)

Néma, feliratos Reels/Stories hirdetés a három poszterből (Classic, Prof., Genius).
1080×1920, 30 fps, 450 frame, H.264 / yuv420p / CRF 18 / bt709.

```bash
npm i
npm run prepare-assets   # source/*.png → public/assets/*.png + src/generated/assets.json (színminták, kivágások)
npm run dev              # Remotion Studio – Inspectorban: showSafeZone / textOnly kapcsoló
npm run check            # 6 still a check/ mappába + szín-, zóna- és varratellenőrzés
npm run render           # → out/burgerprof-karakterek-9x16.mp4
```

Zárt hálózaton (ha a Remotion nem tudja letölteni a saját Chromiumát) egy helyi
headless böngésző adható meg: `REMOTION_BROWSER=/path/to/headless_shell npm run render`.

## Felépítés

- `prepare-assets.ts` – a posztereken lemintázza a narancsot és a sárgát, a főcímet/alcímet
  alfa-szétválasztással kivágja (bitre visszaadja a posztert ugyanazon a narancson), a burgert
  szögletesen vágja ki, és a fotó-téglalap szemcsés hátterét a lapos narancsra normalizálja.
- `src/theme.ts` – színek (a mintákból), méretek, Reels biztonsági zóna, poszter→vászon leképezés.
- `src/components/motion.tsx` – `Wipe` (6 frame, alulról, clip-path) és `SlideUp` (24 px, 8 frame).
- `src/components/blocks.tsx` – Hook, burger-blokk, Payoff.
- `src/Video.tsx` – frame-pontos idővonal; a blokkok közti 2 fekete frame-et a fekete alap adja.

## Források

- `source/` – a három poszter (a feltöltött `1.webp` = PROF., `2.webp` = GENIUS, `3.webp` = CLASSIC,
  a főcím alapján azonosítva; libwebp-vel PNG-be dekódolva).
- `public/fonts/` – Bricolage Grotesque ExtraBold (latin + latin-ext), SIL OFL 1.1.
