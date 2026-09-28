/* ==========================================================================
   BURGER PROF. — PROTOTÍPUS ADATOK
   --------------------------------------------------------------------------
   Minden ár, termék, zóna, díj és rendelési idő ITT van. Csak ezt a fájlt
   kell átírni, a többihez nem kell nyúlni.

   Szabályok átíráskor:
   - Az árak egész számok, szóköz és "Ft" nélkül:  2990  (nem "2 990 Ft").
   - A szövegek idézőjelek között vannak: 'Classic'. Az idézőjelet hagyd meg.
   - Minden sor végén vessző van. Ha új sort másolsz, a vesszőt is másold.
   - Az "id" mezőt ne írd át (erre hivatkozik a kosár és a pult).
   - Mentés után frissítsd az oldalt a böngészőben.

   // ELLENŐRIZENDŐ = helyőrző vagy még jóváhagyásra váró érték.
   ========================================================================== */

window.BP_DATA = {

  /* ---------- Általános beállítások ---------- */
  settings: {
    orderingEnabled: true,        // Online rendelés alapból BE. (A pulton felülírható.)
    checkOpeningHours: true,      // true = rendelési időn kívül nem lehet rendelni.
                                  // Bemutatóhoz: nyisd meg így: index.html?nyitva
    orderNumberPrefix: 'BP-',     // Rendelési szám eleje: BP-0001
    orderNumberStart: 1,          // Első rendelési szám
    deliveryAreaShort: 'Füred + környék',
  },

  /* ---------- Szövegek (márkahang) ---------- */
  texts: {
    heroTitle: 'Smash burger, zseniknek.',
    heroCta: 'RENDELJ MOST',
    tagline: 'Smash burgers for geniuses.',
    pausedText: 'Az online rendelés jelenleg szünetel.',
    successTitle: 'Megkaptuk. A lap már forró.',
    emptyCart: 'Üres. Egy Classickal nem lősz mellé.',
  },

  /* ---------- Rendelési idő ---------- // ELLENŐRIZENDŐ (helyőrző)
     Formátum: 'ÓÓ:PP'. Zárt nap: open: null, close: null.
     A sorrend kötött: vasárnappal kezdődik (így számol a böngésző). */
  openingHours: [
    { day: 'Vasárnap',  open: '12:00', close: '21:00' },
    { day: 'Hétfő',     open: '17:00', close: '21:00' },
    { day: 'Kedd',      open: '17:00', close: '21:00' },
    { day: 'Szerda',    open: '17:00', close: '21:00' },
    { day: 'Csütörtök', open: '17:00', close: '21:00' },
    { day: 'Péntek',    open: '17:00', close: '21:00' },
    { day: 'Szombat',   open: '12:00', close: '21:00' },
  ],

  /* ---------- Szállítási zónák ---------- // ELLENŐRIZENDŐ (helyőrző értékek)
     fee = szállítási díj (Ft), min = minimum rendelési érték (Ft, szállítás nélkül) */
  zones: [
    {
      id: 1,
      name: '1. zóna',
      fee: 490,     // ELLENŐRIZENDŐ
      min: 4000,    // ELLENŐRIZENDŐ
      towns: ['Balatonfüred'],
    },
    {
      id: 2,
      name: '2. zóna',
      fee: 990,     // ELLENŐRIZENDŐ
      min: 6000,    // ELLENŐRIZENDŐ
      towns: ['Csopak', 'Paloznak', 'Tihany', 'Aszófő', 'Balatonszőlős'],
    },
  ],

  /* ---------- Kategóriák (a fülek sorrendje) ---------- */
  categories: [
    { id: 'burgerek', name: 'Burgerek', layout: 'large' },
    { id: 'koretek',  name: 'Köretek',  layout: 'row' },
    { id: 'szoszok',  name: 'Szószok',  layout: 'row' },
    { id: 'italok',   name: 'Italok',   layout: 'row' },
  ],

  /* ---------- Extrák (burgerekhez) ---------- */
  extras: [
    { id: 'extra-hus', name: 'Extra hús', price: 1190 },  // ELLENŐRIZENDŐ
    { id: 'jalapeno',  name: 'Jalapeño',  price: 490 },   // ELLENŐRIZENDŐ
  ],

  /* ---------- Termékek ----------
     image: ide jön majd a valódi fotó útvonala, pl. 'img/classic.jpg' (4:3 arány).
            Amíg üres (''), helyőrző látszik (emoji + szín + „FOTÓ HELYE”).
     color: a helyőrző háttérszíne.
     extras: melyik extrák kérhetők hozzá (üres = nincs „Extra” link). */
  products: [
    // Burgerek
    { id: 'classic', category: 'burgerek', name: 'Classic', price: 2990, // ELLENŐRIZENDŐ
      desc: 'dupla hús, sajt, ketchup, mustár, hagyma, uborka',
      emoji: '🍔', color: '#3b2314', image: '', extras: ['extra-hus', 'jalapeno'] },
    { id: 'prof', category: 'burgerek', name: 'Prof.', price: 2990, // ELLENŐRIZENDŐ
      desc: 'dupla hús, dupla sajt, PROF. szósz, hagyma, uborka',
      emoji: '🍔', color: '#40300a', image: '', extras: ['extra-hus', 'jalapeno'] },
    { id: 'genius', category: 'burgerek', name: 'Genius', price: 3990, // ELLENŐRIZENDŐ
      desc: 'dupla hús, dupla sajt, málnás bacon jam, ranch, hagyma, uborka',
      emoji: '🍔', color: '#3d141a', image: '', extras: ['extra-hus', 'jalapeno'] },
    { id: 'method', category: 'burgerek', name: 'Method', price: 3990, // ELLENŐRIZENDŐ
      desc: 'dupla hús, dupla sajt, bacon, cheddar szósz, PROF. szósz, jalapeño, uborka',
      emoji: '🍔', color: '#2e2a12', image: '', extras: ['extra-hus', 'jalapeno'] },

    // Köretek
    { id: 'hasab', category: 'koretek', name: 'Hasáb', price: 1190, // ELLENŐRIZENDŐ
      desc: 'ropogós hasábburgonya',
      emoji: '🍟', color: '#3a300c', image: '', extras: [] },
    { id: 'cheezy-fries', category: 'koretek', name: 'Cheezy fries', price: 1890, // ELLENŐRIZENDŐ
      desc: 'cheddar szósz, parmezán',
      emoji: '🍟', color: '#44340a', image: '', extras: [] },
    { id: 'full-fries', category: 'koretek', name: 'Full fries', price: 2490, // ELLENŐRIZENDŐ
      desc: 'cheddar szósz, parmezán, bacon, pirított hagyma, PROF. szósz',
      emoji: '🍟', color: '#472a0e', image: '', extras: [] },

    // Szószok — ELLENŐRIZENDŐ (helyőrző lista)
    { id: 'ranch', category: 'szoszok', name: 'Ranch', price: 590,
      desc: 'hűvös, fűszeres', emoji: '🥣', color: '#2b2b24', image: '', extras: [] },
    { id: 'hot-honey-ranch', category: 'szoszok', name: 'Hot honey ranch', price: 590,
      desc: 'édes, csípős', emoji: '🍯', color: '#3d2a0a', image: '', extras: [] },
    { id: 'baconnaise', category: 'szoszok', name: 'Baconnaise', price: 590,
      desc: 'bacon + majonéz', emoji: '🥓', color: '#3a1c16', image: '', extras: [] },
    { id: 'truffel-mayo', category: 'szoszok', name: 'Truffel mayo', price: 590,
      desc: 'szarvasgombás majonéz', emoji: '🍄', color: '#2a2418', image: '', extras: [] },
    { id: 'cheddar-szosz', category: 'szoszok', name: 'Cheddar szósz', price: 590,
      desc: 'meleg, sűrű', emoji: '🧀', color: '#40340a', image: '', extras: [] },
    { id: 'ketchup', category: 'szoszok', name: 'Ketchup', price: 390,
      desc: 'a klasszikus', emoji: '🍅', color: '#3d1414', image: '', extras: [] },
    { id: 'mayo', category: 'szoszok', name: 'Mayo', price: 390,
      desc: 'a másik klasszikus', emoji: '🥚', color: '#2e2c20', image: '', extras: [] },

    // Italok — ELLENŐRIZENDŐ (helyőrző)
    { id: 'coca-cola', category: 'italok', name: 'Coca-Cola 0,33 l', price: 690,
      desc: 'dobozos', emoji: '🥤', color: '#3a1012', image: '', extras: [] },
    { id: 'coca-cola-zero', category: 'italok', name: 'Coca-Cola Zero 0,33 l', price: 690,
      desc: 'dobozos', emoji: '🥤', color: '#1f1f1f', image: '', extras: [] },
    { id: 'fanta', category: 'italok', name: 'Fanta narancs 0,33 l', price: 690,
      desc: 'dobozos', emoji: '🥤', color: '#402a08', image: '', extras: [] },
  ],

  /* ---------- „Tedd mellé” a kosárban (2–3 termék id-je) ---------- */
  upsell: ['cheezy-fries', 'ranch', 'coca-cola'],

  /* ---------- Csereajánlat a kosárban ----------
     Ha "from" van a kosárban: „Cheezy-re cseréled? +700 Ft” (a különbözetet magától számolja) */
  swap: { from: 'hasab', to: 'cheezy-fries', label: 'Cheezy-re cseréled?' },

  /* ---------- Főoldali kép (hero) ---------- */
  hero: { emoji: '🍔', color: '#2b1a10', image: '' },

  /* ---------- Elérhetőség, lábléc ---------- */
  contact: {
    address: '8230 Balatonfüred, Széchenyi István u. 43.',
    phone: '+36 30 732 4620',
    aszfUrl: '#aszf',          // ELLENŐRIZENDŐ (helyőrző link)
    privacyUrl: '#adatkezeles', // ELLENŐRIZENDŐ (helyőrző link)
  },
};
