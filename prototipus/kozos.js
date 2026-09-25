/* Burger Prof. prototípus — közös réteg a vendég- és a pult-oldalnak.
   Tárolás: localStorage. Élő szinkron a fülek között: BroadcastChannel
   (ha nincs, a localStorage "storage" eseménye a tartalék).
   Adatot NE ide írj, hanem a data.js-be. */
(function () {
  'use strict';
  const D = window.BP_DATA;

  const KEYS = {
    orders: 'bp_orders',
    overrides: 'bp_overrides',
    settings: 'bp_settings',
    counter: 'bp_counter',
  };
  const TYPE_BY_KEY = {};
  Object.keys(KEYS).forEach(t => { TYPE_BY_KEY[KEYS[t]] = t; });

  function read(key, def) {
    try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : def; }
    catch (e) { return def; }
  }
  function write(key, val) {
    try { localStorage.setItem(key, JSON.stringify(val)); } catch (e) { /* privát mód */ }
  }

  /* ---------- Szinkron ---------- */
  const channel = 'BroadcastChannel' in window ? new BroadcastChannel('burgerprof') : null;
  const listeners = [];
  function emit(type) { if (channel) channel.postMessage({ type }); }
  function on(fn) { listeners.push(fn); }
  if (channel) channel.onmessage = e => listeners.forEach(fn => fn(e.data && e.data.type));
  window.addEventListener('storage', e => {
    if (channel) return; // BroadcastChannel már szól
    const type = TYPE_BY_KEY[e.key];
    if (type) listeners.forEach(fn => fn(type));
  });

  /* ---------- Formázás ---------- */
  function ft(n) {
    const s = String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    return s + ' Ft';
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  function hhmm(date) {
    const d = new Date(date);
    return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
  }

  /* ---------- Beállítások ---------- */
  function settings() {
    return Object.assign({}, D.settings, read(KEYS.settings, {}));
  }
  function setOrderingEnabled(on) {
    const s = read(KEYS.settings, {});
    s.orderingEnabled = !!on;
    write(KEYS.settings, s);
    emit('settings');
  }

  /* ---------- Termékek (data.js + pult felülírásai) ---------- */
  function overrides() { return read(KEYS.overrides, {}); }
  function setOverride(id, patch) {
    const all = overrides();
    all[id] = Object.assign({}, all[id], patch);
    write(KEYS.overrides, all);
    emit('overrides');
  }
  function products() {
    const ov = overrides();
    return D.products.map(p => {
      const o = ov[p.id] || {};
      return Object.assign({}, p, {
        basePrice: p.price,
        price: typeof o.price === 'number' && o.price >= 0 ? o.price : p.price,
        soldOut: !!o.soldOut,
        hidden: !!o.hidden,
      });
    });
  }
  function product(id) { return products().find(p => p.id === id); }
  function extra(id) { return D.extras.find(x => x.id === id); }
  function available(p) { return p && !p.soldOut && !p.hidden; }

  /* ---------- Zónák ---------- */
  function zoneForTown(town) {
    return D.zones.find(z => z.towns.indexOf(town) !== -1) || null;
  }
  function lowestMinZone() {
    return D.zones.slice().sort((a, b) => a.min - b.min)[0];
  }

  /* ---------- Kosár-számítás ----------
     cart: [{ key, id, extras: [extraId], qty }] */
  function lineUnit(line, prods) {
    const p = (prods || products()).find(x => x.id === line.id);
    if (!p) return 0;
    return p.price + (line.extras || []).reduce((s, id) => s + ((extra(id) || {}).price || 0), 0);
  }
  function totals(cart, town) {
    const prods = products();
    const subtotal = cart.reduce((s, l) => s + lineUnit(l, prods) * l.qty, 0);
    const count = cart.reduce((s, l) => s + l.qty, 0);
    const zone = zoneForTown(town);
    const minZone = zone || lowestMinZone();
    const fee = zone ? zone.fee : 0;
    return {
      subtotal, count, zone, fee,
      min: minZone.min,
      missing: Math.max(0, minZone.min - subtotal),
      total: subtotal + fee,
    };
  }

  /* ---------- Nyitvatartás ---------- */
  function toMin(t) { const [h, m] = t.split(':').map(Number); return h * 60 + m; }
  function openState(now) {
    now = now || new Date();
    const s = settings();
    const force = /[?&]nyitva\b/.test(location.search);
    const day = now.getDay();
    const today = D.openingHours[day];
    const mins = now.getHours() * 60 + now.getMinutes();
    const openNow = !!(today.open && mins >= toMin(today.open) && mins < toMin(today.close));

    let info;
    if (openNow) info = 'Ma nyitva ' + today.close + '-ig';
    else if (today.open) info = 'Ma ' + today.open + '–' + today.close;
    else info = 'Ma zárva';

    if (!s.orderingEnabled) {
      return { canOrder: false, info, message: D.texts.pausedText };
    }
    if (!s.checkOpeningHours || force || openNow) {
      return { canOrder: true, info, message: '' };
    }
    // Következő nyitás
    let message = '';
    for (let i = 0; i < 8; i++) {
      const d = D.openingHours[(day + i) % 7];
      if (!d.open) continue;
      if (i === 0 && mins >= toMin(d.open)) continue; // mára már zártunk
      if (i === 0) message = 'Még nem sütünk. Ma ' + d.open + '-tól rendelhetsz.';
      else if (i === 1) message = 'Ma már nem sütünk. Holnap ' + d.open + '-tól rendelhetsz.';
      else message = 'Ma már nem sütünk. ' + d.day + ' ' + d.open + '-tól rendelhetsz.';
      break;
    }
    return { canOrder: false, info, message: message || D.texts.pausedText };
  }

  /* ---------- Rendelések ---------- */
  function orders() { return read(KEYS.orders, []); }
  function saveOrders(list, silent) {
    write(KEYS.orders, list);
    if (!silent) emit('orders');
  }
  function nextNumber() {
    const s = settings();
    const n = Math.max(read(KEYS.counter, 0), s.orderNumberStart - 1) + 1;
    write(KEYS.counter, n);
    return s.orderNumberPrefix + String(n).padStart(4, '0');
  }
  /* Kosár + űrlap -> rendelés (pillanatkép az akkori árakról) */
  function buildOrder(cart, form) {
    const prods = products();
    const t = totals(cart, form.town);
    const items = cart.map(l => {
      const p = prods.find(x => x.id === l.id);
      const unit = lineUnit(l, prods);
      return {
        id: l.id,
        name: p ? p.name : l.id,
        extras: (l.extras || []).map(id => (extra(id) || {}).name).filter(Boolean),
        qty: l.qty,
        unit,
        total: unit * l.qty,
      };
    });
    return {
      id: nextNumber(),
      createdAt: new Date().toISOString(),
      status: 'new',
      town: form.town,
      zone: t.zone ? t.zone.name : '',
      name: form.name,
      address: form.address,
      phone: form.phone,
      email: form.email,
      payment: form.payment, // 'cash' | 'card'
      note: form.note || '',
      marketing: !!form.marketing,
      items,
      subtotal: t.subtotal,
      fee: t.fee,
      total: t.total,
    };
  }
  function addOrder(order) {
    const list = orders();
    list.push(order);
    saveOrders(list);
    return order;
  }
  function updateOrder(id, patch) {
    const list = orders();
    const o = list.find(x => x.id === id);
    if (!o) return null;
    Object.assign(o, patch);
    saveOrders(list);
    return o;
  }

  window.BP = {
    D, read, write, emit, on, ft, esc, hhmm,
    settings, setOrderingEnabled,
    overrides, setOverride, products, product, extra, available,
    zoneForTown, totals, lineUnit, openState,
    orders, addOrder, updateOrder, buildOrder,
  };
})();
