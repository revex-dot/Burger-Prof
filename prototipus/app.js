/* Burger Prof. prototípus — vendég-oldal (index.html) */
(function () {
  'use strict';
  const D = BP.D;
  const ft = BP.ft;
  const esc = BP.esc;
  const $ = sel => document.querySelector(sel);
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  /* ---------- Állapot ---------- */
  let cart = BP.read('bp_cart', []);          // [{ key, id, extras: [], qty }]
  let town = BP.read('bp_town', '');
  let lastOrderId = BP.read('bp_last_order', '');
  let draft = BP.read('bp_checkout_draft', {}); // pénztár űrlap félkész értékei
  let view = 'menu';
  let menuScroll = 0;
  let extraFor = null;
  let extraSel = [];
  let lastCanOrder = null;

  function saveCart() { BP.write('bp_cart', cart); }
  function saveTown(t) { town = t; BP.write('bp_town', t); }

  /* ---------- Segédek ---------- */
  function lineKey(id, extras) { return id + '|' + extras.slice().sort().join(','); }
  function qtyOf(id) { return cart.filter(l => l.id === id).reduce((s, l) => s + l.qty, 0); }
  function canOrder() { return BP.openState().canOrder; }
  function tetel(n) { return n + ' tétel'; }

  function photoHTML(obj, cls) {
    if (obj.image) {
      return `<div class="ph ${cls || ''}"><img src="${esc(obj.image)}" alt="${esc(obj.name || '')}" loading="lazy"></div>`;
    }
    return `<div class="ph ${cls || ''}" style="--c:${esc(obj.color || '#222')}" aria-hidden="true">
      <span class="ph-emoji">${obj.emoji || '🍔'}</span><span class="ph-label">FOTÓ HELYE</span></div>`;
  }

  function pop(el) {
    if (!el || reduceMotion.matches) return;
    el.classList.remove('pop');
    void el.offsetWidth; // újraindítja az animációt
    el.classList.add('pop');
  }

  let toastTimer;
  function toast(msg) {
    const t = $('#toast');
    t.textContent = msg;
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { t.hidden = true; }, 2400);
  }

  /* ---------- Kosár műveletek ---------- */
  function addToCart(id, extras) {
    extras = extras || [];
    const p = BP.product(id);
    if (!canOrder() || !BP.available(p)) return;
    const key = lineKey(id, extras);
    const line = cart.find(l => l.key === key);
    if (line) line.qty += 1;
    else cart.push({ key, id, extras: extras.slice(), qty: 1 });
    saveCart();
    feedback(id);
  }

  function decProduct(id) {
    const lines = cart.filter(l => l.id === id);
    if (!lines.length) return;
    const line = lines.find(l => !l.extras.length) || lines[lines.length - 1];
    changeLine(line.key, -1, true);
    renderAfterChange(id);
  }

  function changeLine(key, delta, silent) {
    const line = cart.find(l => l.key === key);
    if (!line) return;
    line.qty += delta;
    if (line.qty <= 0) cart = cart.filter(l => l !== line);
    saveCart();
    if (!silent) {
      if (delta > 0) feedback(line.id);
      else renderAfterChange(line.id);
    }
  }

  function doSwap() {
    const from = cart.find(l => l.id === D.swap.from && !l.extras.length);
    if (!from || !BP.available(BP.product(D.swap.to))) return;
    changeLine(from.key, -1, true);
    addToCart(D.swap.to);
  }

  /* Visszajelzés hozzáadáskor: pop + rezgés + számláló ugrás */
  function feedback(id) {
    if (navigator.vibrate) { try { navigator.vibrate(15); } catch (e) { /* nem támogatott */ } }
    renderAfterChange(id);
    pop(document.querySelector(`[data-ctrl="${id}"]`));
    pop($('#bar-count'));
    pop(document.querySelector(`[data-upsell="${id}"]`));
  }

  function renderAfterChange(id) {
    if (id) updateCtrl(id);
    renderCartBar();
    if (!$('#cart-sheet').hidden) renderCart();
    if (view === 'checkout') updateCheckoutTotals();
  }

  /* ---------- Státusz (nyitva / szünetel) ---------- */
  function renderStatus() {
    const st = BP.openState();
    const bar = $('#closed-bar');
    bar.hidden = st.canOrder;
    bar.textContent = st.message;
    document.body.classList.toggle('ordering-off', !st.canOrder);
    $('#hero-info').textContent = st.info + ' · kiszállítás ' + D.settings.deliveryAreaShort;
    $('#hero-cta').textContent = st.canOrder ? D.texts.heroCta : 'ÉTLAP';
    if (lastCanOrder !== null && lastCanOrder !== st.canOrder) renderMenu();
    lastCanOrder = st.canOrder;
  }

  /* ---------- Étlap ---------- */
  function renderStatic() {
    $('#tagline').textContent = D.texts.tagline;
    $('#hero-title').textContent = D.texts.heroTitle;
    $('#hero-photo').outerHTML = photoHTML(Object.assign({ name: 'Burger Prof. smash burger' }, D.hero), 'ph-hero');
    $('#cat-tabs').innerHTML = D.categories.map((c, i) =>
      `<button type="button" class="cat-tab${i === 0 ? ' active' : ''}" data-action="tab" data-cat="${c.id}">${esc(c.name)}</button>`).join('');
    const c = D.contact;
    $('#footer').innerHTML = `
      <div class="logo logo-sm">BURGER<span>PROF.</span></div>
      <p>${esc(c.address)}</p>
      <p><a href="tel:${esc(c.phone.replace(/\s/g, ''))}">${esc(c.phone)}</a></p>
      <p class="footer-links"><a href="${esc(c.aszfUrl)}">ÁSZF</a> · <a href="${esc(c.privacyUrl)}">Adatkezelés</a></p>
      <p class="muted">${esc(D.texts.tagline)}</p>`;
  }

  function ctrlHTML(p) {
    if (p.soldOut) return '<span class="soldout-tag">Elfogyott</span>';
    if (!canOrder()) return '';
    const q = qtyOf(p.id);
    if (!q) {
      return `<button type="button" class="plus" data-action="add" data-id="${p.id}" aria-label="${esc(p.name)} a kosárba">+</button>`;
    }
    return `<div class="stepper">
      <button type="button" data-action="dec" data-id="${p.id}" aria-label="Eggyel kevesebb ${esc(p.name)}">–</button>
      <span class="qty" aria-label="${q} darab a kosárban">${q}</span>
      <button type="button" data-action="add" data-id="${p.id}" aria-label="Még egy ${esc(p.name)}">+</button>
    </div>`;
  }

  function updateCtrl(id) {
    const el = document.querySelector(`[data-ctrl="${id}"]`);
    const p = BP.product(id);
    if (el && p) el.innerHTML = ctrlHTML(p);
  }

  function renderMenu() {
    const prods = BP.products().filter(p => !p.hidden);
    $('#etlap').innerHTML = D.categories.map(cat => {
      const items = prods.filter(p => p.category === cat.id);
      if (!items.length) return '';
      return `<section class="menu-section layout-${cat.layout || 'row'}" id="cat-${cat.id}" data-cat="${cat.id}">
        <h2>${esc(cat.name)}</h2>
        <div class="cards">${items.map(p => cardHTML(p, cat.layout)).join('')}</div>
      </section>`;
    }).join('');
    observeSections();
  }

  function cardHTML(p, layout) {
    const extraLink = p.extras && p.extras.length && !p.soldOut
      ? `<button type="button" class="extra-link" data-action="extra" data-id="${p.id}">Extra +</button>` : '';
    return `<article class="card card-${layout || 'row'}${p.soldOut ? ' is-soldout' : ''}">
      ${photoHTML(p)}
      <div class="card-body">
        <div class="card-text">
          <h3>${esc(p.name)}</h3>
          <p class="desc">${esc(p.desc)}</p>
          ${extraLink}
        </div>
        <div class="card-foot">
          <span class="price">${ft(p.price)}</span>
          <div class="ctrl" data-ctrl="${p.id}">${ctrlHTML(p)}</div>
        </div>
      </div>
    </article>`;
  }

  let sectionObserver;
  function observeSections() {
    if (!('IntersectionObserver' in window)) return;
    if (sectionObserver) sectionObserver.disconnect();
    sectionObserver = new IntersectionObserver(entries => {
      entries.forEach(e => {
        if (e.isIntersecting) setActiveTab(e.target.dataset.cat);
      });
    }, { rootMargin: '-70px 0px -70% 0px' });
    document.querySelectorAll('.menu-section').forEach(s => sectionObserver.observe(s));
  }
  function setActiveTab(cat) {
    document.querySelectorAll('.cat-tab').forEach(b => b.classList.toggle('active', b.dataset.cat === cat));
    const active = document.querySelector('.cat-tab.active');
    if (active) active.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }

  /* ---------- Progress (minimum rendelés) ---------- */
  function progressState() {
    const t = BP.totals(cart, town);
    const pct = t.min ? Math.min(100, (t.subtotal / t.min) * 100) : 100;
    const text = t.missing > 0
      ? `Még ${ft(t.missing)} a minimum rendelésig${t.zone ? ' (' + t.zone.name + ')' : ''}`
      : 'Mehet.';
    return { t, pct, text, done: t.missing === 0 };
  }

  /* ---------- Kosár-sáv ---------- */
  function renderCartBar() {
    const bar = $('#cart-bar');
    const show = cart.length > 0 && canOrder() && view === 'menu' && $('#cart-sheet').hidden;
    bar.hidden = !show;
    document.body.classList.toggle('has-cart-bar', show);
    if (!cart.length) return;
    const ps = progressState();
    $('#bar-count').textContent = tetel(ps.t.count);
    $('#bar-total').textContent = '· ' + ft(ps.t.subtotal);
    $('#bar-progress-text').textContent = ps.text;
    $('#bar-progress').classList.toggle('done', ps.done);
    $('#bar-progress-fill').style.width = ps.pct + '%';
  }

  /* ---------- Kosár panel ---------- */
  function townSelectHTML(id, name, autocomplete) {
    return `<select id="${id}" name="${name}" class="select" ${autocomplete ? `autocomplete="${autocomplete}"` : ''} data-bind="town">
      <option value="">Válassz települést</option>
      ${D.zones.map(z => `<optgroup label="${esc(z.name)} · szállítás ${ft(z.fee)} · min. ${ft(z.min)}">
        ${z.towns.map(tw => `<option${tw === town ? ' selected' : ''}>${esc(tw)}</option>`).join('')}
      </optgroup>`).join('')}
    </select>`;
  }

  function zoneInfo() {
    const z = BP.zoneForTown(town);
    return z ? `${esc(z.name)} · szállítás ${ft(z.fee)} · minimum ${ft(z.min)}`
             : 'A szállítási díj a település kiválasztása után azonnal látszik.';
  }

  function renderCart() {
    const body = $('#cart-body');
    const foot = $('#cart-foot');
    if (!cart.length) {
      body.innerHTML = `<div class="empty"><p>${esc(D.texts.emptyCart)}</p>
        <button type="button" class="btn btn-red" data-action="close-cart">Vissza az étlaphoz</button></div>`;
      foot.innerHTML = '';
      return;
    }
    const prods = BP.products();
    const ps = progressState();
    const t = ps.t;

    const lines = cart.map(l => {
      const p = prods.find(x => x.id === l.id) || { name: l.id };
      const unit = BP.lineUnit(l, prods);
      const ex = l.extras.map(id => (BP.extra(id) || {}).name).filter(Boolean);
      return `<li class="line">
        <div class="line-text">
          <strong>${esc(p.name)}</strong>
          ${ex.length ? `<span class="line-extras">+ ${esc(ex.join(', '))}</span>` : ''}
          <span class="line-price">${ft(unit * l.qty)}</span>
        </div>
        <div class="stepper stepper-sm">
          <button type="button" data-action="line-dec" data-key="${esc(l.key)}" aria-label="Eggyel kevesebb ${esc(p.name)}">–</button>
          <span class="qty">${l.qty}</span>
          <button type="button" data-action="line-inc" data-key="${esc(l.key)}" aria-label="Még egy ${esc(p.name)}">+</button>
        </div>
      </li>`;
    }).join('');

    // Csereajánlat: sima hasáb -> Cheezy
    let swap = '';
    const fromP = BP.product(D.swap.from);
    const toP = BP.product(D.swap.to);
    if (cart.some(l => l.id === D.swap.from && !l.extras.length) && BP.available(toP) && fromP) {
      swap = `<button type="button" class="swap" data-action="swap">
        <span>${esc(D.swap.label)}</span><strong>+${ft(toP.price - fromP.price)}</strong></button>`;
    }

    // Tedd mellé (ami még nincs a kosárban)
    const ups = D.upsell.map(id => prods.find(p => p.id === id))
      .filter(p => BP.available(p));
    const upsell = ups.length ? `<div class="upsell">
      <h3>Tedd mellé</h3>
      <div class="upsell-row">${ups.map(p => `
        <button type="button" class="upsell-card" data-action="add" data-id="${p.id}" data-upsell="${p.id}" aria-label="${esc(p.name)} a kosárba, ${ft(p.price)}">
          ${photoHTML(p, 'ph-sm')}
          <span class="upsell-name">${esc(p.name)}</span>
          <span class="upsell-foot"><span>${ft(p.price)}</span>${qtyOf(p.id)
            ? `<span class="plus plus-sm in-cart" aria-hidden="true">✓${qtyOf(p.id)}</span>`
            : '<span class="plus plus-sm" aria-hidden="true">+</span>'}</span>
        </button>`).join('')}
      </div></div>` : '';

    body.innerHTML = `
      <ul class="lines">${lines}</ul>
      ${swap}
      <div class="zone-pick">
        <label class="field-label" for="cart-town">Hová vigyük?</label>
        ${townSelectHTML('cart-town', 'town')}
        <p class="hint">${zoneInfo()}</p>
      </div>
      <div class="progress progress-inline${ps.done ? ' done' : ''}">
        <div class="progress-text">${esc(ps.text)}</div>
        <div class="progress-track"><div class="progress-fill" style="width:${ps.pct}%"></div></div>
      </div>
      ${upsell}
      ${totalsHTML(t)}`;

    foot.innerHTML = t.missing > 0
      ? `<button type="button" class="btn btn-red btn-xl" disabled>Még ${ft(t.missing)} a minimumig</button>`
      : `<button type="button" class="btn btn-red btn-xl" data-action="checkout">Tovább · ${ft(t.total)}</button>`;
  }

  function totalsHTML(t) {
    return `<dl class="totals">
      <div><dt>Részösszeg</dt><dd>${ft(t.subtotal)}</dd></div>
      <div><dt>Szállítás</dt><dd>${t.zone ? ft(t.fee) : '<span class="muted">válassz települést</span>'}</dd></div>
      <div class="grand"><dt>Végösszeg</dt><dd>${ft(t.total)}</dd></div>
    </dl>`;
  }

  /* ---------- Extra panel ---------- */
  function openExtra(id) {
    const p = BP.product(id);
    if (!BP.available(p) || !canOrder()) return;
    extraFor = id;
    extraSel = [];
    $('#extra-title').textContent = p.name + ' — extra';
    renderExtra();
    openSheet('#extra-sheet');
  }
  function renderExtra() {
    const p = BP.product(extraFor);
    if (!p) return;
    $('#extra-body').innerHTML = `<p class="muted">${esc(p.desc)}</p>
      <div class="extra-list">${p.extras.map(id => BP.extra(id)).filter(Boolean).map(x => `
        <label class="check-row">
          <input type="checkbox" value="${x.id}" data-bind="extra"${extraSel.indexOf(x.id) !== -1 ? ' checked' : ''}>
          <span class="check-label">${esc(x.name)}</span><span class="check-price">+${ft(x.price)}</span>
        </label>`).join('')}</div>`;
    renderExtraFoot();
  }
  function renderExtraFoot() {
    const p = BP.product(extraFor);
    const price = BP.lineUnit({ id: p.id, extras: extraSel });
    $('#extra-foot').innerHTML = `<button type="button" class="btn btn-red btn-xl" data-action="extra-add">Kosárba · ${ft(price)}</button>`;
  }

  /* ---------- Panelek ---------- */
  let lastFocus = null;
  function openSheet(sel) {
    lastFocus = document.activeElement;
    const s = $(sel);
    s.hidden = false;
    document.body.classList.add('locked');
    renderCartBar();
    const close = s.querySelector('.icon-btn');
    if (close) close.focus({ preventScroll: true });
  }
  function closeSheet(sel) {
    const s = $(sel);
    if (s.hidden) return;
    s.hidden = true;
    if ($('#cart-sheet').hidden && $('#extra-sheet').hidden) document.body.classList.remove('locked');
    renderCartBar();
    if (lastFocus && document.contains(lastFocus)) lastFocus.focus({ preventScroll: true });
  }

  /* ---------- Útvonalak (#kosar, #penztar, #kesz) ---------- */
  function nav(hash, replace) {
    const url = hash || (location.pathname + location.search);
    history[replace ? 'replaceState' : 'pushState']({ bp: hash }, '', url);
    route();
  }

  function showView(name) {
    if (view === 'menu' && name !== 'menu') menuScroll = window.scrollY;
    const prev = view;
    view = name;
    $('#view-menu').hidden = name !== 'menu';
    $('#view-checkout').hidden = name !== 'checkout';
    $('#view-success').hidden = name !== 'success';
    if (name === 'menu' && prev !== 'menu') window.scrollTo(0, menuScroll);
    if (name !== 'menu' && prev !== name) window.scrollTo(0, 0);
  }

  function route() {
    const h = location.hash;
    if (h === '#penztar' && cart.length && canOrder()) {
      closeSheet('#cart-sheet');
      showView('checkout');
      renderCheckout();
    } else if (h === '#kesz' && lastOrderId) {
      closeSheet('#cart-sheet');
      showView('success');
      renderSuccess();
    } else {
      showView('menu');
      if (h === '#kosar') { renderCart(); openSheet('#cart-sheet'); }
      else closeSheet('#cart-sheet');
    }
    renderCartBar();
  }

  function closeCart() {
    if (history.state && history.state.bp === '#kosar') history.back();
    else nav('', true);
  }

  /* ---------- Pénztár ---------- */
  function renderCheckout() {
    const c = D.contact;
    const v = k => esc(draft[k] || '');
    $('#view-checkout').innerHTML = `
      <header class="topbar">
        <button type="button" class="back" data-action="back-to-cart">← Kosár</button>
        <span class="logo logo-sm">BURGER<span>PROF.</span></span>
      </header>
      <form id="co-form" class="checkout" novalidate>
        <h1>Rendelés</h1>

        <div class="field">
          <label for="co-town">Település</label>
          ${townSelectHTML('co-town', 'town', 'address-level2')}
          <p class="hint" id="co-zone">${zoneInfo()}</p>
          <p class="err" data-err="town"></p>
        </div>

        <div class="field">
          <label for="co-name">Név</label>
          <input id="co-name" name="name" type="text" autocomplete="name" value="${v('name')}" required>
          <p class="err" data-err="name"></p>
        </div>

        <div class="field">
          <label for="co-address">Cím</label>
          <input id="co-address" name="address" type="text" autocomplete="street-address"
                 placeholder="utca, házszám, emelet, ajtó" value="${v('address')}" required>
          <p class="err" data-err="address"></p>
        </div>

        <div class="field">
          <label for="co-phone">Telefon</label>
          <input id="co-phone" name="phone" type="tel" inputmode="tel" autocomplete="tel"
                 placeholder="+36 30 123 4567" value="${v('phone')}" required>
          <p class="err" data-err="phone"></p>
        </div>

        <div class="field">
          <label for="co-email">E-mail</label>
          <input id="co-email" name="email" type="email" inputmode="email" autocomplete="email"
                 autocapitalize="off" spellcheck="false" value="${v('email')}" required>
          <p class="err" data-err="email"></p>
        </div>

        <fieldset class="field pay">
          <legend>Fizetés átvételkor</legend>
          <div class="pay-options">
            <label class="pay-opt">
              <input type="radio" name="payment" value="cash"${draft.payment === 'cash' ? ' checked' : ''}>
              <span><span class="pay-icon" aria-hidden="true">💵</span>Készpénz<small>átvételkor</small></span>
            </label>
            <label class="pay-opt">
              <input type="radio" name="payment" value="card"${draft.payment === 'card' ? ' checked' : ''}>
              <span><span class="pay-icon" aria-hidden="true">💳</span>Bankkártya<small>átvételkor</small></span>
            </label>
          </div>
          <p class="err" data-err="payment"></p>
        </fieldset>

        <details class="note"${draft.note ? ' open' : ''}>
          <summary>Megjegyzés (nem kötelező)</summary>
          <textarea id="co-note" name="note" rows="3" placeholder="kapukód, csengő, hagyma nélkül…">${v('note')}</textarea>
        </details>

        <label class="check-row">
          <input type="checkbox" name="marketing"${draft.marketing ? ' checked' : ''}>
          <span class="check-label small">Kérek e-mailt új burgerekről és ajánlatokról. Bármikor leiratkozhatok.</span>
        </label>

        <label class="check-row">
          <input type="checkbox" name="aszf" required${draft.aszf ? ' checked' : ''}>
          <span class="check-label small">Elfogadom az <a href="${esc(c.aszfUrl)}" target="_blank">ÁSZF</a>-et és az <a href="${esc(c.privacyUrl)}" target="_blank">adatkezelési tájékoztatót</a>.</span>
        </label>
        <p class="err" data-err="aszf"></p>

        <div class="summary" id="co-summary"></div>
        <div class="co-min" id="co-min" hidden></div>

        <div class="co-submit">
          <button type="submit" class="btn btn-red btn-xl" id="co-submit"></button>
        </div>
      </form>`;
    updateCheckoutTotals();
  }

  function updateCheckoutTotals() {
    const sum = $('#co-summary');
    if (!sum) return;
    const t = BP.totals(cart, town);
    const prods = BP.products();
    sum.innerHTML = `<h2>Összesítő</h2>
      <ul class="sum-lines">${cart.map(l => {
        const p = prods.find(x => x.id === l.id) || { name: l.id };
        const ex = l.extras.map(id => (BP.extra(id) || {}).name).filter(Boolean);
        return `<li><span>${l.qty}× ${esc(p.name)}${ex.length ? ' <small>+ ' + esc(ex.join(', ')) + '</small>' : ''}</span>
          <span>${ft(BP.lineUnit(l, prods) * l.qty)}</span></li>`;
      }).join('')}</ul>
      ${totalsHTML(t)}`;
    const zoneEl = $('#co-zone');
    if (zoneEl) zoneEl.innerHTML = zoneInfo();
    const minEl = $('#co-min');
    const btn = $('#co-submit');
    if (t.zone && t.missing > 0) {
      minEl.hidden = false;
      minEl.innerHTML = `Ide a minimum ${ft(t.min)}. Még ${ft(t.missing)} hiányzik.
        <button type="button" class="btn btn-ghost" data-action="back-to-cart">Vissza a kosárhoz</button>`;
      btn.disabled = true;
    } else {
      minEl.hidden = true;
      btn.disabled = false;
    }
    btn.textContent = t.zone ? `Rendelés elküldése · ${ft(t.total)}` : 'Rendelés elküldése';
  }

  function readForm(form) {
    const fd = new FormData(form);
    return {
      town: fd.get('town') || '',
      name: (fd.get('name') || '').trim(),
      address: (fd.get('address') || '').trim(),
      phone: (fd.get('phone') || '').trim(),
      email: (fd.get('email') || '').trim(),
      payment: fd.get('payment') || '',
      note: (fd.get('note') || '').trim(),
      marketing: fd.get('marketing') === 'on',
      aszf: fd.get('aszf') === 'on',
    };
  }

  function validate(f) {
    const e = {};
    if (!BP.zoneForTown(f.town)) e.town = 'Válaszd ki, hová vigyük.';
    if (f.name.length < 2) e.name = 'Kell egy név a csengőhöz.';
    if (f.address.length < 4) e.address = 'Utca és házszám kell.';
    if (f.phone.replace(/\D/g, '').length < 9) e.phone = 'Ezen a számon hív a futár. Ellenőrizd.';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email)) e.email = 'Ez nem tűnik e-mail címnek.';
    if (!f.payment) e.payment = 'Készpénz vagy kártya?';
    if (!f.aszf) e.aszf = 'Az ÁSZF elfogadása kell a rendeléshez.';
    return e;
  }

  function submitOrder(form) {
    const f = readForm(form);
    const errs = validate(f);
    form.querySelectorAll('.err').forEach(el => { el.textContent = errs[el.dataset.err] || ''; });
    form.querySelectorAll('[name]').forEach(el => {
      el.toggleAttribute('aria-invalid', !!errs[el.name]);
    });
    const firstBad = Object.keys(errs)[0];
    if (firstBad) {
      const el = form.querySelector(`[name="${firstBad}"]`);
      if (el) { el.focus(); el.scrollIntoView({ block: 'center', behavior: reduceMotion.matches ? 'auto' : 'smooth' }); }
      return;
    }
    if (!canOrder()) { toast(BP.openState().message); return; }
    const t = BP.totals(cart, f.town);
    if (t.missing > 0) return;

    const order = BP.addOrder(BP.buildOrder(cart, f));
    lastOrderId = order.id;
    BP.write('bp_last_order', order.id);
    cart = [];
    saveCart();
    draft = { town: f.town, name: f.name, address: f.address, phone: f.phone, email: f.email };
    BP.write('bp_checkout_draft', draft);
    renderMenu();
    nav('#kesz', true);
    confetti();
  }

  /* ---------- Jutalom-képernyő ---------- */
  function statusLine(o) {
    const phone = D.contact.phone;
    if (o.status === 'accepted') {
      const eta = new Date(new Date(o.acceptedAt).getTime() + o.etaMin * 60000);
      return `<strong>Elfogadva.</strong> Kb. ${o.etaMin} perc, ${BP.hhmm(eta)} körül nálad.`;
    }
    if (o.status === 'done') return '<strong>Kész.</strong> Jó étvágyat, professzor.';
    if (o.status === 'rejected') {
      return `<strong>Ezt most nem tudjuk vállalni.</strong> ${esc(o.rejectReason || '')}
        Hívj: <a href="tel:${esc(phone.replace(/\s/g, ''))}">${esc(phone)}</a>`;
    }
    return 'A pult már látja. Mindjárt visszaigazoljuk az időt.';
  }

  function renderSuccess() {
    const o = BP.orders().find(x => x.id === lastOrderId);
    if (!o) { nav('', true); return; }
    $('#view-success').innerHTML = `
      <div class="success">
        <p class="success-kicker">Rendelés elküldve</p>
        <div class="success-num">#${esc(o.id)}</div>
        <h1>${esc(D.texts.successTitle)}</h1>
        <p class="success-status st-${o.status}" aria-live="polite">${statusLine(o)}</p>

        <div class="summary">
          <h2>Összesítő</h2>
          <ul class="sum-lines">${o.items.map(i => `<li><span>${i.qty}× ${esc(i.name)}${i.extras.length ? ' <small>+ ' + esc(i.extras.join(', ')) + '</small>' : ''}</span><span>${ft(i.total)}</span></li>`).join('')}</ul>
          <dl class="totals">
            <div><dt>Részösszeg</dt><dd>${ft(o.subtotal)}</dd></div>
            <div><dt>Szállítás (${esc(o.town)})</dt><dd>${ft(o.fee)}</dd></div>
            <div class="grand"><dt>Végösszeg</dt><dd>${ft(o.total)}</dd></div>
          </dl>
          <dl class="meta">
            <div><dt>Fizetés</dt><dd>${o.payment === 'cash' ? 'Készpénz átvételkor' : 'Bankkártya átvételkor'}</dd></div>
            <div><dt>Cím</dt><dd>${esc(o.town)}, ${esc(o.address)}</dd></div>
            <div><dt>Telefon</dt><dd>${esc(o.phone)}</dd></div>
          </dl>
        </div>
        <button type="button" class="btn btn-ghost btn-xl" data-action="home">Vissza az étlaphoz</button>
      </div>`;
  }

  /* Konfetti: ~1 mp, márkaszínek. prefers-reduced-motion esetén nincs. */
  function confetti() {
    if (reduceMotion.matches) return;
    const cv = $('#confetti');
    const ctx = cv.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const W = window.innerWidth, H = window.innerHeight;
    cv.width = W * dpr; cv.height = H * dpr;
    ctx.scale(dpr, dpr);
    cv.classList.add('on');
    const colors = ['#E52E32', '#EDCE08', '#F2A900', '#FFFFFF'];
    const parts = Array.from({ length: 110 }, () => {
      const a = -Math.PI / 2 + (Math.random() - 0.5) * 1.6;
      const sp = 7 + Math.random() * 9;
      return {
        x: W / 2, y: H * 0.34,
        vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
        w: 6 + Math.random() * 6, h: 3 + Math.random() * 5,
        r: Math.random() * Math.PI, vr: (Math.random() - 0.5) * 0.4,
        c: colors[(Math.random() * colors.length) | 0],
      };
    });
    const start = performance.now();
    const DUR = 1100;
    (function frame(now) {
      const el = now - start;
      ctx.clearRect(0, 0, W, H);
      ctx.globalAlpha = el > DUR - 300 ? Math.max(0, (DUR - el) / 300) : 1;
      parts.forEach(p => {
        p.vy += 0.35; p.vx *= 0.985; p.x += p.vx; p.y += p.vy; p.r += p.vr;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.r);
        ctx.fillStyle = p.c; ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
        ctx.restore();
      });
      if (el < DUR) requestAnimationFrame(frame);
      else { ctx.clearRect(0, 0, W, H); cv.classList.remove('on'); ctx.setTransform(1, 0, 0, 1, 0, 0); }
    })(start);
  }

  /* ---------- Események ---------- */
  document.addEventListener('click', e => {
    const el = e.target.closest('[data-action]');
    if (!el) return;
    const a = el.dataset.action;
    const id = el.dataset.id;
    switch (a) {
      case 'add': addToCart(id); break;
      case 'dec': decProduct(id); break;
      case 'line-inc': changeLine(el.dataset.key, 1); break;
      case 'line-dec': changeLine(el.dataset.key, -1); break;
      case 'swap': doSwap(); break;
      case 'extra': openExtra(id); break;
      case 'extra-add': closeSheet('#extra-sheet'); addToCart(extraFor, extraSel); break;
      case 'close-extra': closeSheet('#extra-sheet'); break;
      case 'open-cart': nav('#kosar'); break;
      case 'close-cart': closeCart(); break;
      case 'checkout': nav('#penztar', true); break;
      case 'back-to-cart': nav('#kosar', true); break;
      case 'home': nav('', false); break;
      case 'tab': {
        const sec = document.getElementById('cat-' + el.dataset.cat);
        if (sec) sec.scrollIntoView({ behavior: reduceMotion.matches ? 'auto' : 'smooth' });
        setActiveTab(el.dataset.cat);
        break;
      }
    }
  });

  $('#hero-cta').addEventListener('click', e => {
    e.preventDefault();
    $('#cat-tabs').scrollIntoView({ behavior: reduceMotion.matches ? 'auto' : 'smooth' });
  });

  document.addEventListener('change', e => {
    const el = e.target;
    if (el.dataset.bind === 'town') {
      saveTown(el.value);
      if (view === 'checkout') {
        draft.town = el.value;
        updateCheckoutTotals();
      } else {
        renderCart();
        renderCartBar();
        const sel = $('#cart-town');
        if (sel) sel.focus({ preventScroll: true });
      }
    } else if (el.dataset.bind === 'extra') {
      extraSel = Array.from(document.querySelectorAll('#extra-body input:checked')).map(i => i.value);
      renderExtraFoot();
    }
  });

  document.addEventListener('input', e => {
    const form = e.target.form;
    if (!form || form.id !== 'co-form') return;
    const f = readForm(form);
    draft = Object.assign({}, draft, f);
    BP.write('bp_checkout_draft', draft);
    const err = form.querySelector(`[data-err="${e.target.name}"]`);
    if (err && err.textContent) { err.textContent = ''; e.target.removeAttribute('aria-invalid'); }
  });
  document.addEventListener('change', e => {
    if (e.target.form && e.target.form.id === 'co-form') {
      draft = Object.assign({}, draft, readForm(e.target.form));
      BP.write('bp_checkout_draft', draft);
      const err = e.target.form.querySelector(`[data-err="${e.target.name}"]`);
      if (err) err.textContent = '';
    }
  });

  document.addEventListener('submit', e => {
    if (e.target.id === 'co-form') { e.preventDefault(); submitOrder(e.target); }
  });

  document.addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;
    if (!$('#extra-sheet').hidden) closeSheet('#extra-sheet');
    else if (!$('#cart-sheet').hidden) closeCart();
  });

  window.addEventListener('popstate', route);

  /* Élő frissítés a pultról (másik fül) */
  BP.on(type => {
    if (type === 'overrides') {
      const before = cart.length;
      const gone = cart.filter(l => !BP.available(BP.product(l.id)));
      if (gone.length) {
        cart = cart.filter(l => BP.available(BP.product(l.id)));
        saveCart();
        const names = gone.map(l => (BP.product(l.id) || { name: l.id }).name);
        toast(names.join(', ') + ' elfogyott. Kivettük a kosárból.');
      }
      renderMenu();
      renderCartBar();
      if (!$('#cart-sheet').hidden) renderCart();
      if (view === 'checkout') {
        if (!cart.length && before) nav('', true);
        else updateCheckoutTotals();
      }
    } else if (type === 'settings') {
      renderStatus();
      renderMenu();
      renderCartBar();
      if (!$('#cart-sheet').hidden) renderCart();
      if (view === 'checkout' && !canOrder()) { toast(BP.openState().message); nav('', true); }
    } else if (type === 'orders') {
      if (view === 'success') renderSuccess();
    }
  });

  /* ---------- Indulás ---------- */
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
  // Kosárban maradt, azóta elfogyott / rejtett tételek kiszűrése
  cart = cart.filter(l => BP.available(BP.product(l.id)));
  saveCart();
  renderStatic();
  renderStatus();
  renderMenu();
  route();
  setInterval(renderStatus, 30000);
})();
