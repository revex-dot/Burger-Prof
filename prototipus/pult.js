/* Burger Prof. prototípus — pult-oldal (pult.html, fekvő tablet) */
(function () {
  'use strict';
  const D = BP.D;
  const ft = BP.ft;
  const esc = BP.esc;
  const $ = sel => document.querySelector(sel);

  let tab = 'active';
  let audioCtx = null;
  let soundOn = false;
  const ui = {};             // rendelésenként: { mode: 'eta' | 'reject', reason: '' }
  let knownIds = new Set(BP.orders().map(o => o.id));

  /* ---------- Segédek ---------- */
  let toastTimer;
  function toast(msg) {
    const t = $('#toast');
    t.textContent = msg;
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { t.hidden = true; }, 3000);
  }
  function ago(iso) {
    const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
    if (m < 1) return 'most';
    if (m < 60) return m + ' perce';
    return Math.floor(m / 60) + ' órája';
  }
  const STATUS = { new: 'Új', accepted: 'Elfogadva', done: 'Teljesítve', rejected: 'Elutasítva' };

  /* ---------- Hang (Web Audio) ---------- */
  function enableSound() {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) { toast('Ez a böngésző nem tud hangot adni.'); return; }
    if (!audioCtx) audioCtx = new AC();
    audioCtx.resume();
    soundOn = true;
    beep();
    renderSoundBtn();
  }
  function beep() {
    if (!audioCtx || !soundOn) return;
    const t0 = audioCtx.currentTime;
    [0, 0.2].forEach(off => {
      const o = audioCtx.createOscillator();
      const g = audioCtx.createGain();
      o.type = 'square';
      o.frequency.value = 1046;
      g.gain.setValueAtTime(0.0001, t0 + off);
      g.gain.exponentialRampToValueAtTime(0.25, t0 + off + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + off + 0.14);
      o.connect(g).connect(audioCtx.destination);
      o.start(t0 + off);
      o.stop(t0 + off + 0.16);
    });
  }
  function renderSoundBtn() {
    const b = $('#sound-btn');
    const waiting = BP.orders().some(o => o.status === 'new');
    b.textContent = soundOn ? '🔊 Hang BE' : '🔈 Hang bekapcsolása';
    b.classList.toggle('sound-on', soundOn);
    b.classList.toggle('attention', !soundOn && waiting);
  }
  // Csipogás 3 mp-enként, amíg van el nem fogadott új rendelés
  setInterval(() => {
    const ringing = BP.orders().some(o => o.status === 'new' && !(ui[o.id] && ui[o.id].mode === 'eta'));
    if (ringing) beep();
  }, 3000);

  /* ---------- Fejléc ---------- */
  function renderHeader() {
    const on = BP.settings().orderingEnabled;
    const sw = $('#ordering-switch');
    sw.setAttribute('aria-checked', String(on));
    $('#ordering-label').textContent = 'Online rendelés ' + (on ? 'BE' : 'KI');
    const active = BP.orders().filter(o => o.status === 'new' || o.status === 'accepted');
    const fresh = active.filter(o => o.status === 'new').length;
    const badge = $('#active-badge');
    badge.hidden = !active.length;
    badge.textContent = active.length;
    document.title = (fresh ? `(${fresh}) ÚJ — ` : '') + 'Pult — Burger Prof.';
    renderSoundBtn();
  }

  /* ---------- Rendelés-kártya ---------- */
  function orderCard(o) {
    const u = ui[o.id] || {};
    const phoneHref = o.phone.replace(/[^\d+]/g, '');
    const pay = o.payment === 'cash'
      ? '<div class="pay-badge pay-cash"><span class="pay-icon" aria-hidden="true">💵</span>KÉSZPÉNZ</div>'
      : '<div class="pay-badge pay-card"><span class="pay-icon" aria-hidden="true">💳</span>KÁRTYA</div>';

    let actions = '';
    if (o.status === 'new' && u.mode === 'eta') {
      actions = `<div class="eta-pick"><p>Mikorra ér oda?</p>
        <div class="order-actions">
          ${[30, 45, 60, 90].map(m => `<button type="button" class="act act-time" data-action="eta" data-id="${o.id}" data-min="${m}">${m}′</button>`).join('')}
          <button type="button" class="act act-cancel" data-action="cancel" data-id="${o.id}" aria-label="Mégse">✕</button>
        </div></div>`;
    } else if (o.status === 'new' && u.mode === 'reject') {
      actions = `<div class="reject-box">
        <label for="reason-${o.id}"><b>Miért utasítod el?</b></label>
        <textarea id="reason-${o.id}" data-reason="${o.id}" placeholder="pl. elfogyott a hús, túl messze van, nem értük el">${esc(u.reason || '')}</textarea>
        <div class="order-actions">
          <button type="button" class="act act-danger" data-action="reject-confirm" data-id="${o.id}">Elutasítás elküldése</button>
          <button type="button" class="act act-cancel" data-action="cancel" data-id="${o.id}">Mégse</button>
        </div></div>`;
    } else if (o.status === 'new') {
      actions = `<div class="order-actions">
        <button type="button" class="act act-accept" data-action="accept" data-id="${o.id}">✓ ELFOGAD</button>
        <button type="button" class="act act-reject" data-action="reject" data-id="${o.id}">Elutasít</button>
      </div>`;
    } else if (o.status === 'accepted') {
      actions = `<div class="order-actions">
        <button type="button" class="act act-done" data-action="done" data-id="${o.id}">Teljesítve</button>
      </div>`;
    }

    let eta = '';
    if (o.status === 'accepted' || (o.status === 'done' && o.etaMin)) {
      const at = new Date(new Date(o.acceptedAt).getTime() + o.etaMin * 60000);
      eta = `<div class="order-eta">Kiszállítás: ${o.etaMin} perc → ${BP.hhmm(at)}</div>`;
    }

    return `<article class="order is-${o.status}" id="o-${o.id}">
      <div class="order-head">
        <span class="order-num">#${esc(o.id)}</span>
        <span class="status status-${o.status}">${STATUS[o.status]}</span>
        <span class="order-time">${BP.hhmm(o.createdAt)} · ${ago(o.createdAt)}</span>
      </div>
      <div class="order-row">
        <div class="order-who">
          <span>${esc(o.town)}<span class="zone-chip">${esc(o.zone)}</span></span>
          <strong>${esc(o.name)}</strong>
          <span>${esc(o.address)}</span>
          <a href="tel:${esc(phoneHref)}">📞 ${esc(o.phone)}</a>
        </div>
        ${pay}
      </div>
      <ul class="order-items">${o.items.map(i => `<li><span><b>${i.qty}×</b> ${esc(i.name)}${i.extras.length ? `<small>+ ${esc(i.extras.join(', '))}</small>` : ''}</span><span>${ft(i.total)}</span></li>`).join('')}
        <li class="muted"><span>Szállítás</span><span>${ft(o.fee)}</span></li>
      </ul>
      ${o.note ? `<div class="order-note">💬 ${esc(o.note)}</div>` : ''}
      <div class="order-total"><span>Végösszeg</span><span>${ft(o.total)}</span></div>
      ${eta}
      ${o.status === 'rejected' ? `<div class="order-reason">Indok: ${esc(o.rejectReason || '—')}</div>` : ''}
      ${actions}
    </article>`;
  }

  /* ---------- Fülek ---------- */
  function renderActive() {
    const list = BP.orders()
      .filter(o => o.status === 'new' || o.status === 'accepted')
      .sort((a, b) => (a.status === 'new' ? 0 : 1) - (b.status === 'new' ? 0 : 1) || a.createdAt.localeCompare(b.createdAt));
    keepFocus(() => {
      $('#tab-active').innerHTML = list.length
        ? `<div class="orders">${list.map(orderCard).join('')}</div>`
        : '<div class="pult-empty">Nincs aktív rendelés. A lap forró, a pult csendes.</div>';
    });
  }

  function renderHistory() {
    const q = $('#search').value.trim().toLowerCase();
    const qDigits = q.replace(/\D/g, '');
    const list = BP.orders()
      .filter(o => o.status === 'done' || o.status === 'rejected')
      .filter(o => !q
        || o.name.toLowerCase().includes(q)
        || o.id.toLowerCase().includes(q)
        || (qDigits.length >= 3 && o.phone.replace(/\D/g, '').includes(qDigits)))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    $('#history-list').innerHTML = list.length
      ? `<div class="orders">${list.map(orderCard).join('')}</div>`
      : `<div class="pult-empty">${q ? 'Nincs találat.' : 'Még nincs lezárt rendelés.'}</div>`;
  }

  function renderMenuAdmin() {
    const prods = BP.products();
    $('#tab-menu').innerHTML = `<div class="menu-admin">${D.categories.map(cat => `
      <section>
        <h2>${esc(cat.name)}</h2>
        ${prods.filter(p => p.category === cat.id).map(p => `
          <div class="admin-row${p.soldOut || p.hidden ? ' is-off' : ''}">
            <div class="admin-name"><strong>${esc(p.name)}</strong><small>alapár (data.js): ${ft(p.basePrice)}</small></div>
            <label class="admin-price${p.price !== p.basePrice ? ' changed' : ''}">
              <input type="number" inputmode="numeric" min="0" step="10" value="${p.price}" data-price="${p.id}" aria-label="${esc(p.name)} ára forintban"> Ft
            </label>
            <button type="button" class="toggle t-soldout" aria-pressed="${p.soldOut}" data-action="soldout" data-id="${p.id}">Elfogyott</button>
            <button type="button" class="toggle t-hidden" aria-pressed="${p.hidden}" data-action="hidden" data-id="${p.id}">Rejtett</button>
          </div>`).join('')}
      </section>`).join('')}</div>`;
  }

  // Újrarajzoláskor ne vesszen el a begépelt indoklás és a fókusz
  function keepFocus(fn) {
    const a = document.activeElement;
    const reasonId = a && a.dataset ? a.dataset.reason : null;
    const pos = reasonId ? a.selectionStart : 0;
    fn();
    if (reasonId) {
      const el = document.querySelector(`[data-reason="${reasonId}"]`);
      if (el) { el.focus(); el.setSelectionRange(pos, pos); }
    }
  }

  function render() {
    renderHeader();
    $('#tab-active').hidden = tab !== 'active';
    $('#tab-history').hidden = tab !== 'history';
    $('#tab-menu').hidden = tab !== 'menu';
    document.querySelectorAll('.pult-tab').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    if (tab === 'active') renderActive();
    if (tab === 'history') renderHistory();
    if (tab === 'menu') renderMenuAdmin();
  }

  /* ---------- Teszt rendelés ---------- */
  const NAMES = ['Kovács Anna', 'Nagy Bence', 'Szabó Réka', 'Tóth Márk', 'Horváth Lili', 'Varga Dániel', 'Kiss Zsófi', 'Molnár Ádám'];
  const STREETS = ['Petőfi Sándor u. 12.', 'Arany János u. 4/B', 'Kossuth Lajos u. 31.', 'Jókai Mór u. 7., 2. em. 5.', 'Blaha Lujza u. 9.', 'Ady Endre u. 18.'];
  const NOTES = ['', '', 'Kapukód: 1234', 'Hagyma nélkül a Classicot', 'Csengő nem működik, hívjatok'];
  const pick = arr => arr[Math.floor(Math.random() * arr.length)];

  function testOrder() {
    const prods = BP.products().filter(BP.available);
    const burgers = prods.filter(p => p.category === 'burgerek');
    const rest = prods.filter(p => p.category !== 'burgerek');
    const town = pick(D.zones.flatMap(z => z.towns));
    const zone = BP.zoneForTown(town);
    const cart = [];
    const add = (p, extras) => {
      extras = extras || [];
      const key = p.id + '|' + extras.join(',');
      const l = cart.find(x => x.key === key);
      if (l) l.qty++; else cart.push({ key, id: p.id, extras, qty: 1 });
    };
    if (!prods.length) { toast('Nincs rendelhető termék az étlapon.'); return; }
    // Addig pakol, amíg eléri a zóna minimumát
    let guard = 0;
    while (BP.totals(cart, town).subtotal < zone.min && guard++ < 20) {
      if (burgers.length && (guard === 1 || Math.random() < 0.5)) {
        const b = pick(burgers);
        add(b, Math.random() < 0.3 && b.extras.length ? [pick(b.extras)] : []);
      } else if (rest.length) add(pick(rest));
      else add(pick(burgers));
    }
    const name = pick(NAMES);
    const order = BP.buildOrder(cart, {
      town,
      name,
      address: pick(STREETS),
      phone: '+36 ' + pick(['20', '30', '70']) + ' ' + (100 + Math.floor(Math.random() * 900)) + ' ' + (1000 + Math.floor(Math.random() * 9000)),
      email: 'teszt@example.com',
      payment: Math.random() < 0.5 ? 'cash' : 'card',
      note: pick(NOTES),
      marketing: false,
    });
    BP.addOrder(order);
    onOrdersChanged();
  }

  /* ---------- Új rendelés érkezett? ---------- */
  function onOrdersChanged() {
    const list = BP.orders();
    const fresh = list.filter(o => !knownIds.has(o.id) && o.status === 'new');
    knownIds = new Set(list.map(o => o.id));
    if (fresh.length) {
      beep();
      if (tab !== 'active') { tab = 'active'; }
      if (!soundOn) toast('Új rendelés. Kapcsold be a hangot.');
    }
    render();
    if (fresh.length) {
      const el = document.getElementById('o-' + fresh[fresh.length - 1].id);
      if (el) el.scrollIntoView({ block: 'nearest' });
    }
  }

  /* ---------- Események ---------- */
  document.addEventListener('click', e => {
    const el = e.target.closest('[data-action]');
    if (!el) return;
    const id = el.dataset.id;
    switch (el.dataset.action) {
      case 'toggle-ordering': {
        const on = !BP.settings().orderingEnabled;
        BP.setOrderingEnabled(on);
        renderHeader();
        toast(on ? 'Online rendelés BEKAPCSOLVA.' : 'Online rendelés KIKAPCSOLVA. A vendég-oldalon szünetel.');
        break;
      }
      case 'sound':
        if (soundOn) { soundOn = false; renderSoundBtn(); } else enableSound();
        break;
      case 'test-order': testOrder(); break;
      case 'tab': tab = el.dataset.tab; render(); break;
      case 'accept': ui[id] = { mode: 'eta' }; renderActive(); break;
      case 'reject': ui[id] = { mode: 'reject', reason: '' }; renderActive();
        { const t = document.querySelector(`[data-reason="${id}"]`); if (t) t.focus(); }
        break;
      case 'cancel': delete ui[id]; renderActive(); break;
      case 'eta':
        BP.updateOrder(id, { status: 'accepted', etaMin: Number(el.dataset.min), acceptedAt: new Date().toISOString() });
        delete ui[id];
        render();
        toast('Visszaigazolás elküldve a vendégnek (szimulált)');
        break;
      case 'reject-confirm': {
        const reason = ((ui[id] && ui[id].reason) || '').trim();
        if (!reason) {
          const t = document.querySelector(`[data-reason="${id}"]`);
          if (t) { t.focus(); t.setAttribute('aria-invalid', 'true'); }
          toast('Írd be röviden az indokot.');
          return;
        }
        BP.updateOrder(id, { status: 'rejected', rejectReason: reason, rejectedAt: new Date().toISOString() });
        delete ui[id];
        render();
        toast('Elutasítás elküldve a vendégnek (szimulált)');
        break;
      }
      case 'done':
        BP.updateOrder(id, { status: 'done', doneAt: new Date().toISOString() });
        render();
        break;
      case 'soldout': {
        const p = BP.product(id);
        BP.setOverride(id, { soldOut: !p.soldOut });
        renderMenuAdmin();
        break;
      }
      case 'hidden': {
        const p = BP.product(id);
        BP.setOverride(id, { hidden: !p.hidden });
        renderMenuAdmin();
        break;
      }
    }
  });

  document.addEventListener('input', e => {
    const rid = e.target.dataset.reason;
    if (rid && ui[rid]) { ui[rid].reason = e.target.value; e.target.removeAttribute('aria-invalid'); }
    if (e.target.id === 'search') renderHistory();
  });

  document.addEventListener('change', e => {
    const pid = e.target.dataset.price;
    if (!pid) return;
    const v = Math.round(Number(e.target.value));
    if (!isFinite(v) || v < 0) { renderMenuAdmin(); return; }
    BP.setOverride(pid, { price: v });
    renderMenuAdmin();
    toast(`${BP.product(pid).name}: ${ft(v)} — a vendég-oldalon már látszik.`);
  });
  // Enterre is mentsen az ár-mező
  document.addEventListener('keydown', e => {
    if (e.key === 'Enter' && e.target.dataset && e.target.dataset.price) e.target.blur();
  });

  // Másik fülről érkező változások
  BP.on(type => {
    if (type === 'orders') onOrdersChanged();
    else if (type === 'settings') renderHeader();
    else if (type === 'overrides' && tab === 'menu') renderMenuAdmin();
  });

  /* ---------- Indulás ---------- */
  render();
  setInterval(() => { if (tab === 'active') renderActive(); }, 30000); // "x perce" frissítés
})();
