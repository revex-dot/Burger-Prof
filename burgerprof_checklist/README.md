# BurgerProf Feladatlista

Egyfájlos webes felület a Burger Prof napi nyitó / záró feladatlistáihoz, a
nyomtatott ellenőrző lapok (Reggeli Pult v3.0, Esti Pult v3.0, Konyha esti záró
v1.0) helyett.

## Mit tud

* **Ma** – a három lista (Reggeli feladatok · Pult, Esti feladatok · Pult,
  Esti záró feladatok · Konyha) aznapi állapota, körgyűrűs haladással.
* **Lista** – nagy, ujjal pipálható tételek; az elvégző neve és az időpont
  automatikusan rögzül. Tételenként fotó (telefon kamerából), megjegyzés.
  A heti feladatok csak a megadott napokon jelennek meg (a PDF-ek szerint).
* **Két aláírási mód** (sablononként állítható, `perItem` mező):
  * *Egy felelős a listára* (pult) – a lista tetején egy „A nap felelőse” név,
    minden pipa az övé, a tételeknél csak az időpont látszik.
  * *Feladatonként külön személy* (konyha) – minden sorban külön névmező.
    Pipáláskor az aktuális felhasználó neve kerül oda, de bármelyik soron
    átírható, és üres névmezőre koppintva egyszerre lehet személyt választani
    és késznek jelölni.
* **Aláírás** – rajzolt aláírás + név a lista végén, ez váltja a papír
  aláírását. Ha minden kész és alá van írva, a lista „Lezárva”.
* **Előzmények** – az utolsó 45 nap, naponként a három lista státusza
  (kész / nincs aláírva / részben / nem töltötték ki), megnyitva a fotókkal
  és aláírásokkal. Korábbi napot csak vezető módosíthat.
* **Hiánytalanság kikényszerítése** – aláírni csak akkor lehet, ha minden
  feladat le van zárva. Ami nem készült el, ahhoz írásos indok kell, és az
  bekerül a vezetői ellenőrzésbe. A `required` tételeket nem lehet kihagyni,
  a `photo` tételeket csak fotóval lehet kipipálni. Listánként `dueBy`
  határidő, utána a lista „késésben”.
* **Ellenőrzés fül (csak vezetőknek)** – figyelmet igénylő tételek 8 napra,
  14 napos napi áttekintő mátrix, szúrópróba (feladatonként rendben/kifogás
  + megjegyzés, `audits/` alá mentve), 30 napos teljesítési statisztika,
  CSV export.
* **Beállítások (csak vezetőknek)** – dolgozók névsora, sablonok szerkesztése
  (szöveg, sorrend, heti napok, kötelező, fotó kell, határidő, aláírási mód).

## Hogyan fut

A fájl a claude.ai Artifact futtatókörnyezetére épül:

* `db` képesség – közös, valós idejű adatbázis (`templates/*`, `settings/app`,
  `shifts/<dátum>_<lista>`, `photos/*`).
* `assets` képesség – fotók tárolása teljes méretben (csak szerkesztési joggal
  megosztott nézőknek; enélkül a fotó kicsinyítve az adatbázisba kerül).
* `downloads` képesség – CSV export.

### Hozzáférés

A vezetői jogot nem PIN adja, hanem a platform megosztási szintje. A db
szabályai:

| útvonal | olvasás | írás |
|---|---|---|
| `` (gyökér: `shifts`, `photos`) | interact | interact |
| `templates`, `settings` | interact | admin |
| `audits`, `admin` | admin | admin |

A dolgozók „megtekintheti” (interact) joggal kapják a linket: kitöltik a
listákat, de a sablonokat nem írhatják át, és az ellenőrzéseket nem is
látják. A vezetők „szerkesztheti” (admin) joggal kapják.

A felület az `admin/marker` dokumentum olvasásával dönti el, vezető-e a
néző: dolgozói szinten ez nemlétezőnek látszik, ezért az Ellenőrzés fül
meg sem jelenik.

Ha a fájlt önállóan, `window.claude` nélkül nyitod meg, ugyanaz a felület
`localStorage`-ba ment – csak azon az egy eszközön látszik.

## Közzététel / frissítés

A `index.html`-t az Artifact eszközzel kell közzétenni
`capabilities: {db: {}, assets: {}}` beállítással. Az alap sablonok a fájlban
is benne vannak (`DEFAULT_TEMPLATES`), de a közös adatbázisba is be vannak
töltve, hogy a Beállításokban szerkeszthetők legyenek.
