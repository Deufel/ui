// Tiny helpers for the static docs site. All navigation + toggles are Datastar;
// this file only holds the DOM-measurement demos that genuinely need to read the
// live computed CSS (type scale, control heights, resolved OKLCH colors).

function measureType() {
  const samples = [...document.querySelectorAll('.spec-samp')];
  const outs = [...document.querySelectorAll('.spec-out')];
  samples.forEach((el, i) => {
    const cs = getComputedStyle(el);
    const px = parseFloat(cs.fontSize).toFixed(1);
    const lh = (parseFloat(cs.lineHeight) / parseFloat(cs.fontSize)).toFixed(2);
    if (outs[i]) outs[i].textContent = `${px}px · lh ${lh} · ${cs.fontWeight}`;
  });
}

function measureControls() {
  const byStep = {};
  document.querySelectorAll('[data-step]').forEach((el) => {
    const t = el.getAttribute('data-step');
    (byStep[t] = byStep[t] || []).push(el.getBoundingClientRect().height);
  });
  Object.keys(byStep).forEach((t) => {
    const hs = byStep[t];
    const min = Math.min(...hs), max = Math.max(...hs);
    const matched = (max - min) < 0.6;
    const tag = document.querySelector(`[data-step-readout="${t}"]`);
    if (tag) {
      tag.textContent = matched ? `all ${max.toFixed(1)}px ✓` : `${min.toFixed(1)}–${max.toFixed(1)}px ✗`;
      tag.className = 'tag ' + (matched ? 'suc' : 'dgr');
    }
  });
  const rowHs = [...document.querySelectorAll('[data-fam="default"] [data-ctl]')]
    .map((el) => el.getBoundingClientRect().height);
  const rt = document.getElementById('row-readout');
  if (rt && rowHs.length) {
    const min = Math.min(...rowHs), max = Math.max(...rowHs);
    const matched = (max - min) < 0.6;
    rt.textContent = matched ? `all ${max.toFixed(1)}px ✓` : `off by ${(max - min).toFixed(1)}px`;
    rt.className = 'tag ' + (matched ? 'suc' : 'dgr');
  }
}

// Resolved-color readout for the engine playground. Reads the live swatch's
// computed background/ink, plus two hidden probes painted with --border / --focus
// (which are calc() props that only become real colors as a background).
function readColor() {
  requestAnimationFrame(() => {
    const sw = document.getElementById('color-swatch');
    if (!sw) return;
    const cs = getComputedStyle(sw);
    const bp = document.getElementById('probe-border');
    const fp = document.getElementById('probe-focus');
    const set = (id, val) => {
      const e = document.getElementById(id);
      if (e) e.textContent = val;
      const s = document.getElementById(id + '-sw');
      if (s) s.style.background = val;
    };
    set('res-bg', cs.backgroundColor);
    set('res-fg', cs.color);
    set('res-border', bp ? getComputedStyle(bp).backgroundColor : '—');
    set('res-focus', fp ? getComputedStyle(fp).backgroundColor : '—');
  });
}

// Fills the surface-ramp L readouts on the Themes/personalities page.
function measureThemes() {
  document.querySelectorAll('.rampbar').forEach((bar) => {
    bar.querySelectorAll('.rc').forEach((el) => {
      const l = parseFloat(getComputedStyle(el).getPropertyValue('--_bg-l'));
      const rl = el.querySelector('.rl');
      if (rl && !isNaN(l)) rl.textContent = l.toFixed(1) + '%';
    });
  });
}

// Called from each section's data-init after Datastar morphs it in.
function afterNav(section) {
  const run = () => {
    if (window.highlightAll) window.highlightAll(document);
    if (section === 'type') measureType();
    if (section === 'controls') measureControls();
    if (section === 'color') readColor();
    if (section === 'themes') measureThemes();
    if (section === 'popover-lab') checkPopovers();
  };
  requestAnimationFrame(run);
  [120, 400].forEach((d) => setTimeout(run, d));
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(run);
}

// Re-measure when the density switch (S/M/L) changes the live scale.
function remeasure() { measureType(); measureControls(); }

// Popover composition lab: read each .menu[popover]'s CLOSED computed display and
// badge it. The display guard must collapse every one to `none`, whatever layout
// classes it carries — otherwise the invisible closed panel overlays its trigger.
function checkPopovers() {
  document.querySelectorAll('[data-pop-check]').forEach((badge) => {
    const pop = document.getElementById(badge.getAttribute('data-pop-check'));
    if (!pop) return;
    const disp = getComputedStyle(pop).display;
    if (pop.matches(':popover-open')) { badge.textContent = 'open · ' + disp; badge.className = 'tag inf'; }
    else { const ok = disp === 'none'; badge.textContent = 'closed · ' + disp + (ok ? ' ✓' : ' ✗'); badge.className = 'tag ' + (ok ? 'suc' : 'dgr'); }
  });
}

window.measureType = measureType;
window.measureControls = measureControls;
window.readColor = readColor;
window.measureThemes = measureThemes;
window.checkPopovers = checkPopovers;
window.afterNav = afterNav;
window.remeasure = remeasure;
