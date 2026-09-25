# Burger Prof. – online rendelés, kattintható prototípus

Statikus HTML + CSS + vanilla JS. Nincs build, nincs backend, nincs valódi e-mail.

| Fájl | Mi ez |
|------|-------|
| `index.html` + `app.js` | Vendég-oldal (mobil, 375 px) |
| `pult.html` + `pult.js` | Pult-oldal (fekvő tablet, 1024×768) |
| `data.js` | **Minden adat**: étlap, árak, extrák, zónák, díjak, rendelési idő, szövegek |
| `kozos.js` | Közös réteg: localStorage + BroadcastChannel szinkron, összegszámítás, nyitvatartás |
| `style.css` | Közös stílus |

## Megnyitás
- Netlify Drop: húzd be az egész `prototipus` mappát a https://app.netlify.com/drop oldalra.
- A kapott címen nyisd meg: `/index.html` (vendég) és egy másik fülön `/pult.html` (pult), **ugyanabban a böngészőben**.
- Rendelési időn kívül a vendég-oldal zárva mutatja magát. Bemutatóhoz: `index.html?nyitva`.

## Hogyan működik a „szinkron”
A rendelések, a pulton átírt árak / elfogyott / rejtett jelölések és a BE/KI kapcsoló a böngésző
localStorage-ában vannak, a változásról BroadcastChannel üzenet megy a többi fülnek. Ezért csak
ugyanazon a gépen, ugyanabban a böngészőben látszik (ez szándékos: prototípus).
Mindent nullázni: böngésző fejlesztői eszközök → Application → Local Storage → törlés.

## Éles rendszerhez (fejlesztőnek)
A `kozos.js` függvényei (`orders`, `addOrder`, `updateOrder`, `setOverride`, `setOrderingEnabled`)
a helyek, ahol a localStorage helyett API-hívás jön.
