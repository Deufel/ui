#!/usr/bin/env bash
#
# apply-system-css-refactor.sh
# Recreates the "view transitions + composition docs + terse API front-door"
# change in your LOCAL clone of Deufel/ui. Self-contained: the git patch is
# embedded below. Run it from anywhere inside your clone of the repo.
#
#   chmod +x apply-system-css-refactor.sh
#   ./apply-system-css-refactor.sh
#
set -euo pipefail

BRANCH="claude/ui-composition-docs-refactor-bk1t2i"

# --- sanity: inside the repo, clean tree ------------------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: run this from inside your local clone of the 'ui' repo." >&2
  exit 1
fi
cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: your working tree has uncommitted changes." >&2
  echo "Commit or 'git stash' them first, then re-run this script." >&2
  exit 1
fi

# --- get onto the target branch, based on origin ----------------------------
echo "> Fetching origin..."
git fetch origin "$BRANCH" 2>/dev/null || git fetch origin || true
if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
  git checkout -B "$BRANCH" "origin/$BRANCH"
else
  echo "> origin/$BRANCH not found; applying onto current branch: $(git branch --show-current)"
fi

# --- write the embedded patch -----------------------------------------------
PATCH="$(mktemp)"
trap 'rm -f "$PATCH"' EXIT
cat > "$PATCH" <<'PATCH_EOF'
From 6c814d237fe4372a9be39fdf5f7cc76519c05953 Mon Sep 17 00:00:00 2001
From: Claude <noreply@anthropic.com>
Date: Wed, 8 Jul 2026 12:25:10 +0000
Subject: [PATCH] Refine view transitions + composition docs; add terse API
 front-door
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit

Composition / view transitions (system.css):
- Add `.vt` primitive — names a view-transition group from `--vt` so a region
  morphs across a DOM change; specificity 0, inert until a transition runs.
- Add `data-vt="isolate"` mode — holds `root` still so only named regions
  animate. The portable way to scope a transition to what actually changes.
- Add `data-vt-shell` opt-in on `.page` — names every chrome slot so nav/header/
  aside/footer hold and only `.pg-main` morphs on any navigation.
- Document how Datastar drives it: the `__viewtransition` action modifier for
  frontend swaps, and SSE `useViewTransition` / `viewTransitionSelector` for
  backend idiomorph patches (only changed nodes mutate).

Docs:
- New one-page API front-door (sections/reference.html) modeled on the terse
  living-doc; wired as the default landing view with a START nav group. The
  section deep-dives stay as-is behind it.
- Rewrite the View transitions section to teach the model + Datastar recipes,
  with a live isolate-scoped morph demo.
- Calcify the layout section into an opinionated outside-in wireframing recipe;
  add `.vt` to the primitive catalog.
- Sync SKILL.md (view transitions + layout/wireframing guidance).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01UxrVhYFbtLuKqJ83YV1NvP
---
 SKILL.md                  |  31 +++++--
 docs.css                  |   6 ++
 index.html                | 143 ++++++++++++++++++++++----------
 sections/layout.html      |  32 +++++++-
 sections/reference.html   | 121 +++++++++++++++++++++++++++
 sections/transitions.html | 169 +++++++++++++++++++++++++++++++-------
 system.css                |  61 +++++++++++++-
 7 files changed, 478 insertions(+), 85 deletions(-)
 create mode 100644 sections/reference.html

diff --git a/SKILL.md b/SKILL.md
index c2635e3..55cb753 100644
--- a/SKILL.md
+++ b/SKILL.md
@@ -115,12 +115,17 @@ State rides ARIA — do not invent state classes.
 ## Layout
 
 Zero-specificity primitives (gap in `lh`) — anything you author beats them without a fight.
+These are also the **wireframing kit**: rough a screen outside-in — pick the frame
+(`.page` slots or `.hero`), fill each region by composing `.column`/`.row`/`.grid`/…
+(never hand-set padding), greybox content with `.card` + a `--bg` step, adapt with the
+gate classes below, and name anything that will animate with `.vt`.
 
 | Class | Shape |
 |---|---|
 | `.row` · `.column` | Horizontal (wraps) · vertical. |
 | `.split` · `.spread` · `.spread-column` · `.lcr` | Two equal · space-between row / column · left·center·right. |
 | `.flank` · `.grid` · `.stack` · `.track` | Fixed leader + fluid rest · auto-fit (`--grid-min`) · overlay · scroll row. |
+| `.vt` | Names a view-transition group via `--vt` (see View transitions). Inert until a transition runs. |
 | `.scroll-x` · `.scroll-y` | Scroll containers with contained overscroll. |
 | `.page` + `.pg-*` | Ten-slot app shell: `.pg-banner .pg-header .pg-subheader .pg-navigation .pg-toolbar .pg-main-header .pg-main .pg-main-footer .pg-aside .pg-footer`. Add a child, its slot appears; only nav/main/aside scroll. |
 | `.modal` · `.drawer .left/.right/.top/.bottom` · `.menu` · `.hud` | Native `<dialog>`/popover overlays — no z-index. `.hud` has nine slots `.tl .tc .tr · .cl .cc .cr · .bl .bc .br` (a `.card` in `.hud .tr` = toast; a `.fab-3` in `.br` = primary action). |
@@ -159,16 +164,32 @@ Set on `<html>` or any subtree; everything below re-resolves. Hue is separate fr
 
 ## View transitions
 
-Inert until you opt in. Set `data-vt` on `<html>`, then wrap a DOM change:
+Inert until you opt in. The browser snapshots the page before & after a DOM change and
+tweens between them — you make the change, it animates. Set `data-vt` on `<html>`, then
+wrap the change:
 
 ```js
-document.documentElement.dataset.vt = "slide-left"; // fade | slide-left | slide-right | scale | zoom
+document.documentElement.dataset.vt = "slide-left"; // fade|slide-left|slide-right|scale|zoom|isolate
 document.startViewTransition(() => render(next));
 ```
 
-Duration rides `--cfg-motion`, so `data-ui-motion` and `prefers-reduced-motion` govern
-it. Unique `view-transition-name` morphs a shared element. Cross-document (zero JS):
-`@view-transition { navigation: auto; }`.
+Duration rides `--cfg-motion`, so `data-ui-motion` and `prefers-reduced-motion` govern it.
+
+**Scope it to what changes** — don't crossfade the whole viewport for a one-word change:
+
+| Hook | Effect |
+|---|---|
+| `.vt` + `style="--vt:name"` | Names an element as its own snapshot group so it morphs across the change. Name must be unique per snapshot; keep it stable old→new to link the frames. |
+| `data-vt="isolate"` | Holds `root` (everything unnamed) still — only named regions animate. The portable way to scope today. |
+| `.page[data-vt-shell]` | Names every chrome slot; on any navigation the header/nav/aside/footer hold and only `.pg-main` morphs. |
+
+**With Datastar** (the intended runtime): the `__viewtransition` action modifier wraps a
+frontend swap — `data-on:click__viewtransition="$state = next"`. A backend
+`datastar-patch-elements` SSE frame with `useViewTransition true` (optionally
+`viewTransitionSelector <css>`) wraps a morph; its idiomorph patch mutates only changed
+nodes, so a named region tweens and the rest is untouched.
+
+Cross-document (zero JS): `@view-transition { navigation: auto; }`.
 
 ## The laws
 
diff --git a/docs.css b/docs.css
index f95d073..075604d 100644
--- a/docs.css
+++ b/docs.css
@@ -85,6 +85,12 @@ body { margin: 0; }
 .matrix .mh { font-family: var(--font-mono); --type: -2; --fg: -0.55; }
 @media (max-width: 640px) { .tagmatrix { grid-template-columns: 1fr; } }
 
+/* ============ reference (front-door) ============ */
+.mono { font-family: var(--font-mono); }
+.apicard { display: flex; flex-direction: column; gap: 0.4lh; padding: 0.6lh 0.7em; }
+.apicard pre { margin: 0; }
+.apicard .tag { --fg: -0.6; }
+
 /* ============ demos gallery ============ */
 .demogrid { display: flex; flex-wrap: wrap; gap: 1lh; }
 .democard { inline-size: 20rem; flex: 1 1 18rem; max-inline-size: 24rem; }
diff --git a/index.html b/index.html
index f2f4bae..45e3020 100644
--- a/index.html
+++ b/index.html
@@ -1,6 +1,6 @@
 <!DOCTYPE html>
 <html lang="en"
-  data-signals="{hue: 255, theme: 'light', size: 'md', skin: '', motion: 'on', width: 'centered', color: '2', radius: '', font: '', invert: '', section: 'type', zoom: 100}"
+  data-signals="{hue: 255, theme: 'light', size: 'md', skin: '', motion: 'on', width: 'centered', color: '2', radius: '', font: '', invert: '', section: 'reference', zoom: 100}"
   data-attr:data-ui-theme="$theme"
   data-attr:data-ui-size="$size"
   data-attr:data-ui-skin="$skin"
@@ -10,6 +10,8 @@
   data-attr:data-ui-font="$font"
   data-attr:data-ui-invert="$invert"
   data-style="{'--hue': $hue}">
+<!-- $section defaults to 'reference' — the one-page API front-door (sections/reference.html);
+     the sidebar sections are the deep-dives, fetched + morphed into #main on click. -->
 <head>
 <meta charset="utf-8">
 <meta name="viewport" content="width=device-width, initial-scale=1">
@@ -70,7 +72,9 @@
   </header>
 
   <nav class="pg-navigation column" style="gap: 0.1lh; padding: 0.4lh 0.35em; --scale:1">
-    <small style="--fg:-0.55; --type:-2; padding-inline:0.6em; margin-block-end:0.2lh">TYPE</small>
+    <small style="--fg:-0.55; --type:-2; padding-inline:0.6em; margin-block-end:0.2lh">START</small>
+    <a class="nav-item clickable" data-attr:aria-current="$section === 'reference' ? 'page' : 'false'" data-on:click="$section = 'reference'; @get('sections/reference.html')"><span>API reference</span></a>
+    <small style="--fg:-0.55; --type:-2; padding-inline:0.6em; margin-block: 0.4lh 0.2lh">TYPE</small>
     <a class="nav-item clickable" data-attr:aria-current="$section === 'type' ? 'page' : 'false'" data-on:click="$section = 'type'; @get('sections/type.html')"><span>How type works</span></a>
     <a class="nav-item clickable" data-attr:aria-current="$section === 'controls' ? 'page' : 'false'" data-on:click="$section = 'controls'; @get('sections/controls.html')"><span>Control heights</span></a>
     <small style="--fg:-0.55; --type:-2; padding-inline:0.6em; margin-block: 0.4lh 0.2lh">COLOR</small>
@@ -91,67 +95,120 @@
     <a class="nav-item clickable" data-attr:aria-current="$section === 'demos' ? 'page' : 'false'" data-on:click="$section = 'demos'; @get('sections/demos.html')"><span>Full pages</span></a>
   </nav>
 
-  <main class="pg-main" id="main" data-init="afterNav('type')">
+  <main class="pg-main" id="main" data-init="afterNav('reference')">
     <div class="doc">
 
       <header class="column" style="gap: 0.4lh">
-        <span class="tag inf" style="align-self:start">type</span>
-        <h1 style="--type: 6">Type is the system</h1>
-        <p style="--type:1; --fg:-0.7; max-inline-size: 52ch">One number per element — <code>--type</code> — sets its size, and from that same number the engine derives its leading, tracking, and weight. Spacing is a fraction of the line, so <em>everything</em> scales together. There are no pixel values to keep in sync.</p>
+        <span class="tag inf" style="align-self:start">reference</span>
+        <h1 style="--type: 6">system.css</h1>
+        <p style="--type:1; --fg:-0.7; max-inline-size: 54ch">The whole API on one page. Link the stylesheet, write plain HTML, and set a few signed custom properties instead of picking colors or spacing. Everything below is live in this doc — pick a topic in the sidebar for the long version.</p>
       </header>
 
       <section class="column" style="gap:0.5lh">
-        <h2 style="--type:3">One step, four outputs</h2>
-        <div class="four">
-          <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag suc">size</span><strong>fluid</strong></div><small style="--fg:-0.7">A modular ratio to the power of the step, fluidly interpolated between a phone and a desktop base. One <code>--cfg-ratio</code> for the whole scale.</small></div>
-          <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag">leading</span><strong>line-height</strong></div><small style="--fg:-0.7">Tightens as type grows, so display sizes don't sit on loose lines.</small></div>
-          <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag">tracking</span><strong>letter-spacing</strong></div><small style="--fg:-0.7">Negative at display sizes, a touch positive for small caps of text.</small></div>
-          <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag">weight</span><strong>optical</strong></div><small style="--fg:-0.7">Climbs above step 0, so headings carry more weight without a second knob.</small></div>
-        </div>
+        <h2 style="--type:3">1 · Setup</h2>
+        <pre><code class="html">&lt;link rel="stylesheet" href="system.css"&gt;
+&lt;html data-ui-theme="dark" style="--hue: 255"&gt;   &lt;!-- theme + brand hue --&gt;</code></pre>
+        <p style="--fg:-0.6; --type:-0.5">Load the theme webfonts (default Roboto + Roboto Mono). Then write bare HTML — a <code>&lt;button&gt;</code>, <code>&lt;table&gt;</code>, or a <code>&lt;label&gt;</code> in a <code>&lt;form&gt;</code> is already the styled component. Reach for a class only to <em>vary</em> an element.</p>
       </section>
 
-      <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
-        <div class="spread"><h2 style="--type:3">The live scale</h2><span class="tag inf">measured from the DOM · try S/M/L above</span></div>
-        <p style="--fg:-0.6; --type:-0.5">Each row is a real element at that <code>--type</code>. The readout is its <em>computed</em> size / line-height / weight — so it reflects the shipped engine and the current <code>data-ui-size</code>, not a formula copy.</p>
-        <div class="column" style="gap:0">
-          <div class="spec-row"><code style="--type:-1; --fg:-0.6">h1</code><div class="spec-samp" style="--type:5">Grumpy wizards</div><span class="spec-out">…</span></div>
-          <div class="spec-row"><code style="--type:-1; --fg:-0.6">h2</code><div class="spec-samp" style="--type:4">Grumpy wizards</div><span class="spec-out">…</span></div>
-          <div class="spec-row"><code style="--type:-1; --fg:-0.6">h3</code><div class="spec-samp" style="--type:3">Grumpy wizards</div><span class="spec-out">…</span></div>
-          <div class="spec-row"><code style="--type:-1; --fg:-0.6">h4</code><div class="spec-samp" style="--type:2">Grumpy wizards</div><span class="spec-out">…</span></div>
-          <div class="spec-row"><code style="--type:-1; --fg:-0.6">h5</code><div class="spec-samp" style="--type:1">Grumpy wizards</div><span class="spec-out">…</span></div>
-          <div class="spec-row"><code style="--type:-1; --fg:-0.6">body</code><div class="spec-samp" style="--type:0">Grumpy wizards</div><span class="spec-out">…</span></div>
-          <div class="spec-row"><code style="--type:-1; --fg:-0.6">small</code><div class="spec-samp" style="--type:-1">Grumpy wizards</div><span class="spec-out">…</span></div>
-          <div class="spec-row"><code style="--type:-1; --fg:-0.6">micro</code><div class="spec-samp" style="--type:-2">Grumpy wizards</div><span class="spec-out">…</span></div>
+      <section class="column" style="gap:0.6lh">
+        <h2 style="--type:3">2 · API</h2>
+
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">Color</strong><span class="tag" style="--type:-2">declare a position — the engine solves the OKLCH</span></div>
+          <pre><code class="css">--bg:  0    /* [-1..0..1]  surface depth — 0 base, − recedes, + advances */
+--fg:  0    /* [-1..0..1]  ink — − neutral/max-contrast, + chromatic     */
+--hue: 255  /* [0..360]    one number rotates the whole system           */
+--hue-shift: 0    /* ±deg   rotate every non-locked descendant           */
+--hue-lock:  —    /* pin hue against a shift (the semantic helpers set it)*/</code></pre>
+          <small style="--fg:-0.7"><code>--border</code> / <code>--focus</code> are derived from the surface — never set them.</small>
         </div>
-      </section>
 
-      <section class="split" style="gap:0.7lh; align-items:start">
-        <div class="column" style="gap:0.4lh">
-          <h2 style="--type:3">Spacing is a fraction of the line</h2>
-          <p style="--fg:-0.6">Layout gaps are <code>calc(0.25 · 1lh)</code> and control padding is in <code>em</code> — both relative to the type around them. Bump a region's <code>--type</code> (or the header's S/M/L) and its rhythm grows with it. No spacing scale to maintain.</p>
-          <pre><code class="css">:where(.row, .column) { gap: calc(0.25 * 1lh); }
-:where(button)        { padding: 0 0.8em; }   /* em → scales with --type */</code></pre>
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">Type &amp; space</strong><span class="tag" style="--type:-2">type is the spacing system</span></div>
+          <pre><code class="css">--type:  0    /* signed step; sets size → leading, tracking, weight derive.
+                 h1..h5 = 5..1 · body/controls = 0 · small = −1 · micro = −2
+                 sizes ONE element (does not inherit)                       */
+--scale: 1    /* zooms a whole region (inherits) — for a mini preview       */
+
+gap: calc(0.25 * 1lh)   /* every layout primitive; spacing = a fraction of the line */
+padding: 0 0.8em        /* controls pad in em → tracks --type. Never hand-set px.    */</code></pre>
+        </div>
+
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">Surfaces</strong><span class="tag" style="--type:-2">nest by lifting, not by picking darker values</span></div>
+          <pre><code class="css">.bg                 /* paints its --bg; publishes lightness for child ink */
+.card  / .Card      /* bordered panel — quiet line / vibrant line          */
+.surface / .Surface /* a --lift step, no line — group inside a card        */
+--lift: n           /* sit n above the host surface (what controls use)    */</code></pre>
+        </div>
+
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">Layout primitives</strong><span class="tag" style="--type:-2">specificity 0 · compose freely</span></div>
+          <pre><code class="css">.row  .column          /* horizontal (wraps) · vertical stack          */
+.split .spread .lcr    /* 1fr 1fr · space-between · left·center·right   */
+.flank .flank-end      /* fixed leader + fluid rest (icon · text)      */
+.grid  --grid-min      /* auto-fit tracks   .ngrid --cols --rows       */
+.stack .track .frame   /* overlay · scroll row · fixed aspect box      */
+.hero                  /* t/l/main/r/b app region (scrolls in main)    */
+.vt   --vt: name       /* name a view-transition group (a "mover")     */</code></pre>
+        </div>
+
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">Page shell &amp; overlays</strong><span class="tag" style="--type:-2">add a slot child, it appears; empty tracks collapse</span></div>
+          <pre><code class="css">.page  data-vt-shell   /* 10-slot app grid; only nav/main/aside scroll */
+  .pg-banner .pg-header .pg-subheader .pg-navigation .pg-toolbar
+  .pg-main-header .pg-main .pg-main-footer .pg-aside .pg-footer
+
+.modal  .drawer .left/.right/.top/.bottom   /* native &lt;dialog&gt; — no z-index */
+.menu   /* anchored popover */   .hud  .tl…​.br   /* 9-slot overlay (toasts, FABs) */</code></pre>
         </div>
-        <div class="column" style="gap:0.4lh">
-          <h2 style="--type:3">Set a step, or zoom a region</h2>
-          <p style="--fg:-0.6"><code>--type</code> is per-element (non-inheriting) — set it on one thing. <code>--scale</code> inherits, so it zooms a whole region (handy for a mini preview). <code>data-ui-size</code> reconfigures the base + ratio for the whole app.</p>
-          <pre><code class="html">&lt;h2 style="--type:4"&gt;Heading&lt;/h2&gt;
-&lt;small style="--type:-2"&gt;Micro caption&lt;/small&gt;
-&lt;div style="--scale:0.6"&gt;…mini version…&lt;/div&gt;</code></pre>
+
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">Responsive gates</strong><span class="tag" style="--type:-2">layer-order magic — none on by default</span></div>
+          <pre><code class="css">.mobile .tablet .desktop   /* viewport   &lt;768 · 768–1024 · ≥1024px */
+.small  .medium .large     /* container  needs a container-type ancestor */
+.fine   .coarse            /* pointer    mouse · touch */</code></pre>
+          <small style="--fg:-0.7">Each defaults to <code>display:none</code>; the matching query flips it back. They compose (<code>class="mobile desktop"</code> = phone + desktop).</small>
+        </div>
+
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">View transitions</strong><span class="tag" style="--type:-2">inert until you opt in</span></div>
+          <pre><code class="css">data-vt on &lt;html&gt;:  fade · slide-left · slide-right · scale · zoom
+                    isolate   /* hold root — only NAMED regions move */
+.vt style="--vt: x"          /* a mover: its own snapshot group      */
+.page[data-vt-shell]         /* chrome holds, only .pg-main morphs    */</code></pre>
+          <pre><code class="html">&lt;button data-on:click__viewtransition="$state = next"&gt;…&lt;/button&gt;
+&lt;!-- backend: SSE `useViewTransition true` + `viewTransitionSelector #x` --&gt;</code></pre>
+        </div>
+
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">Components</strong><span class="tag" style="--type:-2">bare-first · one height per --type</span></div>
+          <pre><code class="css">&lt;button&gt; .pri .sec        &lt;button aria-label&gt;&lt;svg&gt; = square icon
+.button-group             &lt;form&gt;›&lt;label&gt; = field   &lt;fieldset&gt; = field row
+&lt;table&gt; &lt;select&gt; &lt;details&gt; &lt;progress&gt; &lt;meter&gt; &lt;blockquote&gt; &lt;code&gt; &lt;kbd&gt;  /* bare */
+.tag .alert .avatar .badge .count      .tabs .crumbs .nav-item .fab-1/2/3</code></pre>
+        </div>
+
+        <div class="apicard card" style="--bg:0.02">
+          <div class="spread"><strong class="mono">Runtime switches</strong><span class="tag" style="--type:-2">set on &lt;html&gt; or any subtree — everything re-resolves</span></div>
+          <pre><code class="css">data-ui-theme  light · dark            data-ui-motion  off · on · debug
+data-ui-size   sm · md · lg · xl       data-ui-skin    material · carbon · vivid
+style="--hue:n"                        data-ui-state   on · off   (+ ARIA drives state)</code></pre>
         </div>
       </section>
 
-      <section class="alert suc" role="note">
-        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
+      <section class="alert inf" role="note">
+        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2 4 6v6c0 5 3.5 8 8 10 4.5-2 8-5 8-10V6z"/></svg>
         <div class="column" style="gap:0.15lh">
-          <strong>Because controls read the same scale, they stay one height.</strong>
-          <small style="--fg:-0.75">A field, button, select, and avatar all resolve to a single height at each <code>--type</code> — see <strong>Control heights</strong> for the live proof, and the <strong>Demos</strong> for the scale dressed up as three different products.</small>
+          <strong>The laws</strong>
+          <small style="--fg:-0.75">1 · Bare HTML is the component; add a class only to vary it. &nbsp;2 · Never name a color — declare a position and let the engine solve it. &nbsp;3 · Shape follows content; height is shared; spacing is a fraction of the line. &nbsp;4 · State rides ARIA; meaning rides <code>.suc .inf .wrn .dgr</code>. &nbsp;5 · Everything you author wins — the system ships at specificity 0.</small>
         </div>
       </section>
 
       <footer class="column" style="gap:0.3lh; --fg:-0.6">
         <hr>
-        <p style="--type:-0.5">Steps in use: <code>h1..h6</code> → <code>--type 5..0</code>, <code>small</code> → <code>-1</code>, plus <code>-2</code> for micro text (tags, icon-button captions).</p>
+        <p style="--type:-0.5">This page is the map. The sidebar sections are the territory — each is live and dogfooded: <strong>How type works</strong>, <strong>The engine</strong>, <strong>Page &amp; helpers</strong>, <strong>View transitions</strong>, <strong>Components</strong>, and the full-page <strong>Demos</strong>.</p>
       </footer>
 
     </div>
diff --git a/sections/layout.html b/sections/layout.html
index 69192ac..1670cee 100644
--- a/sections/layout.html
+++ b/sections/layout.html
@@ -3,10 +3,33 @@
 
     <header class="column" style="gap: 0.4lh">
       <span class="tag inf" style="align-self:start">layout</span>
-      <h1 style="--type: 6">Page, primitives &amp; overlays</h1>
-      <p style="--type:1; --fg:-0.7; max-inline-size: 52ch">Structure without a single hand-set pixel. The <code>.page</code> shell is a ten-slot application grid; the layout primitives are zero-specificity composition helpers whose gap derives from line-height; the overlays are native <code>&lt;dialog&gt;</code> / popover with the engine's paint. All spacing is <code>em</code>/<code>lh</code>, so it tracks type.</p>
+      <h1 style="--type: 6">Compose &amp; wireframe a screen</h1>
+      <p style="--type:1; --fg:-0.7; max-inline-size: 52ch">Structure without a single hand-set pixel. The <code>.page</code> shell is a ten-slot application grid; the layout primitives are zero-specificity composition helpers whose gap derives from line-height; the overlays are native <code>&lt;dialog&gt;</code> / popover with the engine's paint. All spacing is <code>em</code>/<code>lh</code>, so it tracks type. Together they are the wireframing kit — rough a whole screen out of them before you style a thing.</p>
     </header>
 
+    <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
+      <div class="spread"><h2 style="--type:3">The recommended path</h2><span class="tag suc">calcified</span></div>
+      <p style="--fg:-0.6; --type:-0.5">Five moves, outside-in. Follow them and a screen composes itself — no spacing scale, no media-query bookkeeping, no z-index.</p>
+      <div class="column" style="gap:0.4lh">
+        <div class="flank" style="gap:0.6em; align-items:start"><span class="tag inf" style="--type:-1">1</span><div class="column" style="gap:0.05lh"><strong>Pick the frame.</strong><small style="--fg:-0.7">A whole app → <code>.page</code> + the <code>pg-*</code> slots you need. A sub-view that owns its scroll → <code>.hero</code> (top / left / main / right / bottom). Leave a slot out and its track collapses.</small></div></div>
+        <div class="flank" style="gap:0.6em; align-items:start"><span class="tag inf" style="--type:-1">2</span><div class="column" style="gap:0.05lh"><strong>Fill each region by composing primitives.</strong><small style="--fg:-0.7">Reach for <code>.column</code> and <code>.row</code> first; <code>.grid</code> for cards, <code>.split</code> for two panes, <code>.spread</code>/<code>.lcr</code> for bars, <code>.flank</code> for icon·text. Nest them freely — they gap at <code>0.25lh</code>, so rhythm is automatic. <strong>Never hand-set padding.</strong></small></div></div>
+        <div class="flank" style="gap:0.6em; align-items:start"><span class="tag inf" style="--type:-1">3</span><div class="column" style="gap:0.05lh"><strong>Rough content in as bare boxes.</strong><small style="--fg:-0.7">A <code>.card</code> with a <code>--bg</code> step is a placeholder; a bare element at a <code>--type</code> is a label. You're wireframing in the real engine, so the greybox already has the right rhythm and color — it just gets replaced, never re-laid-out.</small></div></div>
+        <div class="flank" style="gap:0.6em; align-items:start"><span class="tag inf" style="--type:-1">4</span><div class="column" style="gap:0.05lh"><strong>Adapt with the gate classes, not new CSS.</strong><small style="--fg:-0.7">Show a sidebar only on <code>.desktop</code>, a bottom bar only on <code>.mobile</code>, a fatter target only on <code>.coarse</code>; let a component react to its own box with <code>.small</code>/<code>.medium</code>/<code>.large</code>. They compose and cost nothing — see below.</small></div></div>
+        <div class="flank" style="gap:0.6em; align-items:start"><span class="tag inf" style="--type:-1">5</span><div class="column" style="gap:0.05lh"><strong>Name what will move.</strong><small style="--fg:-0.7">If a region animates between states, give it <code>.vt style="--vt:name"</code> now — the wireframe becomes the transition storyboard for free. See <strong>View transitions</strong>.</small></div></div>
+      </div>
+      <pre><code class="html">&lt;div class="page"&gt;
+  &lt;header class="pg-header spread"&gt; brand · actions &lt;/header&gt;
+  &lt;nav class="pg-navigation desktop column"&gt; …links… &lt;/nav&gt;   &lt;!-- ≥1024 only --&gt;
+  &lt;main class="pg-main"&gt;
+    &lt;div class="grid" style="--grid-min:16rem"&gt;               &lt;!-- card wall --&gt;
+      &lt;div class="card column" style="--bg:0.02"&gt; placeholder &lt;/div&gt;
+      &lt;div class="card column" style="--bg:0.02"&gt; placeholder &lt;/div&gt;
+    &lt;/div&gt;
+  &lt;/main&gt;
+  &lt;nav class="pg-footer mobile spread"&gt; …tabs… &lt;/nav&gt;         &lt;!-- &lt;768 only --&gt;
+&lt;/div&gt;</code></pre>
+    </section>
+
     <section class="column" style="gap:0.5lh">
       <h2 style="--type:3">The <code>.page</code> shell</h2>
       <p style="--fg:-0.6; max-inline-size:60ch">Ten named slots. Add a <code>pg-*</code> child and it appears; leave it out and the track collapses. Only <code>nav</code>, <code>main</code> and <code>aside</code> scroll — the shell itself never does. This whole docs site <em>is</em> a <code>.page</code>.</p>
@@ -85,6 +108,11 @@
           <small style="--fg:-0.7">Horizontal scroll row of min-width cells.</small>
           <div class="demo"><div class="track" style="--track-min:3.5rem"><div class="box bg" style="--bg:0.3">1</div><div class="box bg" style="--bg:0.3">2</div><div class="box bg" style="--bg:0.3">3</div><div class="box bg" style="--bg:0.3">4</div><div class="box bg" style="--bg:0.3">5</div><div class="box bg" style="--bg:0.3">6</div></div></div>
         </div>
+        <div class="card helper-card" style="--bg:0.02; padding:0.5lh 0.6em">
+          <div class="spread"><span class="layer-name" style="font-family:var(--font-mono); font-weight:600">.vt</span><span class="tag" style="--type:-2">motion</span></div>
+          <small style="--fg:-0.7">Names a view-transition group via <code>--vt</code> — the element the browser morphs across a state change. Inert until a transition runs.</small>
+          <div class="demo"><div class="row" style="gap:0.5em"><div class="box bg" style="--bg:0.3">card</div><div class="box bg inf" style="--bg:0.4; --type:-2">--vt: hero</div></div></div>
+        </div>
       </div>
     </section>
 
diff --git a/sections/reference.html b/sections/reference.html
new file mode 100644
index 0000000..d854cf4
--- /dev/null
+++ b/sections/reference.html
@@ -0,0 +1,121 @@
+<main class="pg-main" id="main" data-init="afterNav('reference')">
+  <div class="doc">
+
+    <header class="column" style="gap: 0.4lh">
+      <span class="tag inf" style="align-self:start">reference</span>
+      <h1 style="--type: 6">system.css</h1>
+      <p style="--type:1; --fg:-0.7; max-inline-size: 54ch">The whole API on one page. Link the stylesheet, write plain HTML, and set a few signed custom properties instead of picking colors or spacing. Everything below is live in this doc — pick a topic in the sidebar for the long version.</p>
+    </header>
+
+    <!-- 1 · SETUP ─────────────────────────────────────────────── -->
+    <section class="column" style="gap:0.5lh">
+      <h2 style="--type:3">1 · Setup</h2>
+      <pre><code class="html">&lt;link rel="stylesheet" href="system.css"&gt;
+&lt;html data-ui-theme="dark" style="--hue: 255"&gt;   &lt;!-- theme + brand hue --&gt;</code></pre>
+      <p style="--fg:-0.6; --type:-0.5">Load the theme webfonts (default Roboto + Roboto Mono). Then write bare HTML — a <code>&lt;button&gt;</code>, <code>&lt;table&gt;</code>, or a <code>&lt;label&gt;</code> in a <code>&lt;form&gt;</code> is already the styled component. Reach for a class only to <em>vary</em> an element.</p>
+    </section>
+
+    <!-- 2 · API ──────────────────────────────────────────────── -->
+    <section class="column" style="gap:0.6lh">
+      <h2 style="--type:3">2 · API</h2>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">Color</strong><span class="tag" style="--type:-2">declare a position — the engine solves the OKLCH</span></div>
+        <pre><code class="css">--bg:  0    /* [-1..0..1]  surface depth — 0 base, − recedes, + advances */
+--fg:  0    /* [-1..0..1]  ink — − neutral/max-contrast, + chromatic     */
+--hue: 255  /* [0..360]    one number rotates the whole system           */
+--hue-shift: 0    /* ±deg   rotate every non-locked descendant           */
+--hue-lock:  —    /* pin hue against a shift (the semantic helpers set it)*/</code></pre>
+        <small style="--fg:-0.7"><code>--border</code> / <code>--focus</code> are derived from the surface — never set them.</small>
+      </div>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">Type &amp; space</strong><span class="tag" style="--type:-2">type is the spacing system</span></div>
+        <pre><code class="css">--type:  0    /* signed step; sets size → leading, tracking, weight derive.
+                 h1..h5 = 5..1 · body/controls = 0 · small = −1 · micro = −2
+                 sizes ONE element (does not inherit)                       */
+--scale: 1    /* zooms a whole region (inherits) — for a mini preview       */
+
+gap: calc(0.25 * 1lh)   /* every layout primitive; spacing = a fraction of the line */
+padding: 0 0.8em        /* controls pad in em → tracks --type. Never hand-set px.    */</code></pre>
+      </div>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">Surfaces</strong><span class="tag" style="--type:-2">nest by lifting, not by picking darker values</span></div>
+        <pre><code class="css">.bg                 /* paints its --bg; publishes lightness for child ink */
+.card  / .Card      /* bordered panel — quiet line / vibrant line          */
+.surface / .Surface /* a --lift step, no line — group inside a card        */
+--lift: n           /* sit n above the host surface (what controls use)    */</code></pre>
+      </div>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">Layout primitives</strong><span class="tag" style="--type:-2">specificity 0 · compose freely</span></div>
+        <pre><code class="css">.row  .column          /* horizontal (wraps) · vertical stack          */
+.split .spread .lcr    /* 1fr 1fr · space-between · left·center·right   */
+.flank .flank-end      /* fixed leader + fluid rest (icon · text)      */
+.grid  --grid-min      /* auto-fit tracks   .ngrid --cols --rows       */
+.stack .track .frame   /* overlay · scroll row · fixed aspect box      */
+.hero                  /* t/l/main/r/b app region (scrolls in main)    */
+.vt   --vt: name       /* name a view-transition group (a "mover")     */</code></pre>
+      </div>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">Page shell &amp; overlays</strong><span class="tag" style="--type:-2">add a slot child, it appears; empty tracks collapse</span></div>
+        <pre><code class="css">.page  data-vt-shell   /* 10-slot app grid; only nav/main/aside scroll */
+  .pg-banner .pg-header .pg-subheader .pg-navigation .pg-toolbar
+  .pg-main-header .pg-main .pg-main-footer .pg-aside .pg-footer
+
+.modal  .drawer .left/.right/.top/.bottom   /* native &lt;dialog&gt; — no z-index */
+.menu   /* anchored popover */   .hud  .tl…​.br   /* 9-slot overlay (toasts, FABs) */</code></pre>
+      </div>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">Responsive gates</strong><span class="tag" style="--type:-2">layer-order magic — none on by default</span></div>
+        <pre><code class="css">.mobile .tablet .desktop   /* viewport   &lt;768 · 768–1024 · ≥1024px */
+.small  .medium .large     /* container  needs a container-type ancestor */
+.fine   .coarse            /* pointer    mouse · touch */</code></pre>
+        <small style="--fg:-0.7">Each defaults to <code>display:none</code>; the matching query flips it back. They compose (<code>class="mobile desktop"</code> = phone + desktop).</small>
+      </div>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">View transitions</strong><span class="tag" style="--type:-2">inert until you opt in</span></div>
+        <pre><code class="css">data-vt on &lt;html&gt;:  fade · slide-left · slide-right · scale · zoom
+                    isolate   /* hold root — only NAMED regions move */
+.vt style="--vt: x"          /* a mover: its own snapshot group      */
+.page[data-vt-shell]         /* chrome holds, only .pg-main morphs    */</code></pre>
+        <pre><code class="html">&lt;button data-on:click__viewtransition="$state = next"&gt;…&lt;/button&gt;
+&lt;!-- backend: SSE `useViewTransition true` + `viewTransitionSelector #x` --&gt;</code></pre>
+      </div>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">Components</strong><span class="tag" style="--type:-2">bare-first · one height per --type</span></div>
+        <pre><code class="css">&lt;button&gt; .pri .sec        &lt;button aria-label&gt;&lt;svg&gt; = square icon
+.button-group             &lt;form&gt;›&lt;label&gt; = field   &lt;fieldset&gt; = field row
+&lt;table&gt; &lt;select&gt; &lt;details&gt; &lt;progress&gt; &lt;meter&gt; &lt;blockquote&gt; &lt;code&gt; &lt;kbd&gt;  /* bare */
+.tag .alert .avatar .badge .count      .tabs .crumbs .nav-item .fab-1/2/3</code></pre>
+      </div>
+
+      <div class="apicard card" style="--bg:0.02">
+        <div class="spread"><strong class="mono">Runtime switches</strong><span class="tag" style="--type:-2">set on &lt;html&gt; or any subtree — everything re-resolves</span></div>
+        <pre><code class="css">data-ui-theme  light · dark            data-ui-motion  off · on · debug
+data-ui-size   sm · md · lg · xl       data-ui-skin    material · carbon · vivid
+style="--hue:n"                        data-ui-state   on · off   (+ ARIA drives state)</code></pre>
+      </div>
+    </section>
+
+    <!-- 3 · LAWS ─────────────────────────────────────────────── -->
+    <section class="alert inf" role="note">
+      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2 4 6v6c0 5 3.5 8 8 10 4.5-2 8-5 8-10V6z"/></svg>
+      <div class="column" style="gap:0.15lh">
+        <strong>The laws</strong>
+        <small style="--fg:-0.75">1 · Bare HTML is the component; add a class only to vary it. &nbsp;2 · Never name a color — declare a position and let the engine solve it. &nbsp;3 · Shape follows content; height is shared; spacing is a fraction of the line. &nbsp;4 · State rides ARIA; meaning rides <code>.suc .inf .wrn .dgr</code>. &nbsp;5 · Everything you author wins — the system ships at specificity 0.</small>
+      </div>
+    </section>
+
+    <footer class="column" style="gap:0.3lh; --fg:-0.6">
+      <hr>
+      <p style="--type:-0.5">This page is the map. The sidebar sections are the territory — each is live and dogfooded: <strong>How type works</strong>, <strong>The engine</strong>, <strong>Page &amp; helpers</strong>, <strong>View transitions</strong>, <strong>Components</strong>, and the full-page <strong>Demos</strong>.</p>
+    </footer>
+
+  </div>
+</main>
diff --git a/sections/transitions.html b/sections/transitions.html
index 6691326..329d1ba 100644
--- a/sections/transitions.html
+++ b/sections/transitions.html
@@ -1,15 +1,15 @@
-<main class="pg-main" id="main" data-init="afterNav('transitions'); $vtsupport = !!document.startViewTransition" data-signals="{vtn: 1, vtdir: 'slide-left', vtsupport: true}">
+<main class="pg-main" id="main" data-init="afterNav('transitions'); $vtsupport = !!document.startViewTransition" data-signals="{vtn: 1, vtdir: 'slide-left', vtsupport: true, tab: 'list', pick: 1}">
   <div class="doc">
 
     <header class="column" style="gap: 0.4lh">
       <span class="tag inf" style="align-self:start">layout · motion</span>
       <h1 style="--type: 6">View transitions</h1>
-      <p style="--type:1; --fg:-0.7; max-inline-size: 54ch">A plain CSS <code>transition</code> animates one property on one element that stays put. The <strong>View Transitions API</strong> generalizes that to a whole DOM change — elements that appear, move, or leave — by snapshotting before &amp; after and animating between them. <code>system.css</code> wraps it in four direction helpers, gated by your motion switch.</p>
+      <p style="--type:1; --fg:-0.7; max-inline-size: 56ch">A plain CSS <code>transition</code> animates one property on one element that stays put. The <strong>View Transitions API</strong> generalizes that to a whole DOM change — elements that appear, move, or leave — by snapshotting the page before &amp; after and animating between the two frames. You don't write the animation; you make the change, and the browser tweens. <code>system.css</code> adds the direction helpers, a <strong>scoped</strong> mode, and the wiring so <strong>Datastar</strong> drives it.</p>
     </header>
 
     <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
-      <div class="spread"><h2 style="--type:3">Try it</h2><span data-attr:class="$vtsupport ? 'tag suc' : 'tag wrn'" data-text="$vtsupport ? 'supported in this browser' : 'not supported — swaps instantly'"></span></div>
-      <p style="--fg:-0.6; --type:-0.5">Pick a direction, then swap the panel. Set the header's motion to <strong>Debug</strong> to watch it in slow motion — the duration rides <code>--cfg-motion</code>.</p>
+      <div class="spread"><h2 style="--type:3">Try it</h2><span data-attr:class="$vtsupport ? 'tag suc' : 'tag wrn'" data-text="$vtsupport ? 'supported here' : 'not supported — swaps instantly'"></span></div>
+      <p style="--fg:-0.6; --type:-0.5">Pick a direction, then swap the panel. Set the header's motion to <strong>Debug</strong> to watch it in slow motion — duration rides <code>--cfg-motion</code>.</p>
       <div class="vt-stage" style="--bg:0">
         <div class="vt-panel" data-style="{'--hue': $vtn === 1 ? 255 : $vtn === 2 ? 25 : $vtn === 3 ? 150 : 285}" style="--bg:0.12; background-color: var(--_bg)">
           <span class="vt-big" data-text="$vtn"></span>
@@ -22,25 +22,40 @@
           <button data-attr:aria-pressed="$vtdir === 'slide-left' ? 'true' : 'false'" data-on:click="$vtdir = 'slide-left'">slide-left</button>
           <button data-attr:aria-pressed="$vtdir === 'slide-right' ? 'true' : 'false'" data-on:click="$vtdir = 'slide-right'">slide-right</button>
           <button data-attr:aria-pressed="$vtdir === 'scale' ? 'true' : 'false'" data-on:click="$vtdir = 'scale'">scale</button>
+          <button data-attr:aria-pressed="$vtdir === 'zoom' ? 'true' : 'false'" data-on:click="$vtdir = 'zoom'">zoom</button>
         </div>
         <button class="pri nowrap" data-on:click__viewtransition="document.documentElement.dataset.vt = $vtdir; $vtn = ($vtn % 4) + 1">Swap panel →</button>
       </div>
     </section>
 
-    <section class="split" style="gap:0.7lh; align-items:start">
-      <div class="column" style="gap:0.4lh">
-        <h2 style="--type:3">The whole API is one call</h2>
-        <p style="--fg:-0.6">Wrap any state change. The browser freezes the old frame, runs your callback, then crossfades to the new frame. No library, no manual FLIP math.</p>
-        <pre><code class="js">document.documentElement.dataset.vt = "slide-left";
+    <section class="column" style="gap:0.5lh">
+      <h2 style="--type:3">One call — that's the whole API</h2>
+      <p style="--fg:-0.6; max-inline-size:62ch">Wrap any DOM change in <code>startViewTransition</code>. The browser freezes the old frame, runs your callback, then crossfades to the new frame. No library, no manual FLIP math. Unsupported browsers just run the callback with no animation — safe to ship today.</p>
+      <div class="split" style="gap:0.7lh; align-items:start">
+        <div class="column" style="gap:0.4lh">
+          <strong style="--type:0">Raw JS</strong>
+          <pre><code class="js">document.documentElement.dataset.vt = "slide-left";
 document.startViewTransition(() =&gt; {
-  // any DOM mutation — swap a route, re-render a list…
-  render(nextState);
+  render(nextState);   // any DOM mutation
 });</code></pre>
-        <p style="--fg:-0.6; --type:-0.5">Unsupported browsers just run the callback with no animation — so it's safe to ship today.</p>
+        </div>
+        <div class="column" style="gap:0.4lh">
+          <strong style="--type:0">Datastar — the same thing, declaratively</strong>
+          <pre><code class="html">&lt;button
+  data-on:click__viewtransition="
+    document.documentElement.dataset.vt = 'slide-left';
+    $panel = next"&gt;
+  Next
+&lt;/button&gt;</code></pre>
+        </div>
       </div>
+      <p style="--fg:-0.6; --type:-0.5">The <code>__viewtransition</code> modifier wraps the expression's DOM changes in a transition for you — this is what the <strong>Swap panel</strong> button above uses.</p>
+    </section>
+
+    <section class="split" style="gap:0.7lh; align-items:start">
       <div class="column" style="gap:0.4lh">
         <h2 style="--type:3">Directions ship as helpers</h2>
-        <p style="--fg:-0.6">Set <code>data-vt</code> on <code>&lt;html&gt;</code> before you start; <code>system.css</code> keys the keyframes off it.</p>
+        <p style="--fg:-0.6">Set <code>data-vt</code> on <code>&lt;html&gt;</code> before you start; <code>system.css</code> keys the root keyframes off it.</p>
         <div class="table-scroll" style="--bg:0">
           <table>
             <thead><tr><th><code>data-vt</code></th><th>motion</th></tr></thead>
@@ -49,30 +64,120 @@ document.startViewTransition(() =&gt; {
               <tr><td><code>slide-left</code></td><td>New content enters from the right</td></tr>
               <tr><td><code>slide-right</code></td><td>New content enters from the left</td></tr>
               <tr><td><code>scale</code></td><td>Subtle zoom crossfade</td></tr>
+              <tr><td><code>zoom</code></td><td>Pronounced zoom crossfade</td></tr>
+              <tr><td><code>isolate</code></td><td>Hold the page still — only <em>named</em> regions move</td></tr>
             </tbody>
           </table>
         </div>
       </div>
+      <div class="column" style="gap:0.4lh">
+        <h2 style="--type:3">It obeys the motion switch — free</h2>
+        <p style="--fg:-0.6">Duration is <code>calc(var(--cfg-motion) * 0.28s)</code>, so <code>data-ui-motion</code> off → instant swap, debug → slow, and <code>prefers-reduced-motion</code> zeroes it.</p>
+        <div class="alert inf" role="note" style="margin-block-start:0.2lh">
+          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8h.01M11 12h1v4h1"/></svg>
+          <small style="--fg:-0.75">The transition pseudo-elements live on <code>:root</code>, so set <code>data-ui-motion</code> and <code>data-vt</code> on <code>&lt;html&gt;</code> — not an inner wrapper — so the value reaches them.</small>
+        </div>
+      </div>
     </section>
 
-    <section class="alert inf" role="note">
-      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8h.01M11 12h1v4h1"/></svg>
-      <div class="column" style="gap:0.15lh">
-        <strong>It obeys the motion switch — for free.</strong>
-        <small style="--fg:-0.75">Duration is <code>calc(var(--cfg-motion) * 0.28s)</code>, so <code>data-ui-motion</code> off → instant swap, debug → 10× slow, and <code>prefers-reduced-motion</code> zeroes it. Because the transition pseudo-elements live on <code>:root</code>, set <code>data-ui-motion</code> on <code>&lt;html&gt;</code> (not just an inner wrapper) so the value reaches them.</small>
+    <!-- ═══ the part that matters: scope to what changes ═══ -->
+    <section class="column" style="gap:0.5lh">
+      <div class="spread"><h2 style="--type:3">Animate only what changes</h2><span class="tag suc">the pattern to reach for</span></div>
+      <p style="--fg:-0.6; max-inline-size:64ch">By default a transition captures the <strong>whole viewport</strong> as one group called <code>root</code> and crossfades it — so even a one-word change flashes the entire page. To scope the motion to the regions that actually change, do two things:</p>
+      <div class="grid" style="--grid-min:15rem; gap:0.6lh">
+        <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag inf">1</span><strong>Name the movers</strong></div><small style="--fg:-0.7">Give each region that should animate its own <code>view-transition-name</code> — the <code>.vt</code> helper reads it from <code>--vt</code>. A named element becomes its own group and tweens between frames.</small></div>
+        <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag inf">2</span><strong>Hold the rest</strong></div><small style="--fg:-0.7">Set <code>data-vt="isolate"</code> so <code>root</code> — everything you didn't name — swaps with <em>no</em> animation. No whole-page crossfade; only your named regions move.</small></div>
       </div>
+      <pre><code class="html">&lt;html data-vt="isolate"&gt;                &lt;!-- root holds still --&gt;
+
+&lt;aside class="pg-navigation"&gt;…&lt;/aside&gt;   &lt;!-- unnamed → instant, no flash --&gt;
+&lt;main&gt;
+  &lt;article class="vt card" style="--vt: detail"&gt;   &lt;!-- named → morphs --&gt;
+    …content that changes…
+  &lt;/article&gt;
+&lt;/main&gt;</code></pre>
+      <p style="--fg:-0.6; --type:-0.5">A name must be <strong>unique per snapshot</strong>; keeping the <em>same</em> name on an element across the change is what links its old and new frame so it tweens instead of crossfading. Reuse a name on two visible elements and the browser skips the transition.</p>
+    </section>
+
+    <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
+      <div class="spread"><h2 style="--type:3">Scoped morph — live</h2><span class="tag inf">isolate + a named region</span></div>
+      <p style="--fg:-0.6; --type:-0.5">The title bar and tabs are <em>unnamed</em>, so they hold. Only the body carries <code>--vt: scoped-body</code>, so only it morphs when you switch. Swap under <strong>Debug</strong> motion to see the chrome stay put.</p>
+      <div class="card column" style="--bg:0; gap:0; padding:0; overflow:hidden">
+        <div class="spread" style="--bg:-0.4; background-color:var(--_bg); padding:0.35lh 0.6em">
+          <strong style="--type:0">Orbit</strong>
+          <div class="button-group" role="group" aria-label="View">
+            <button data-attr:aria-pressed="$tab === 'list' ? 'true' : 'false'" data-on:click__viewtransition="document.documentElement.dataset.vt = 'isolate'; $tab = 'list'">List</button>
+            <button data-attr:aria-pressed="$tab === 'detail' ? 'true' : 'false'" data-on:click__viewtransition="document.documentElement.dataset.vt = 'isolate'; $tab = 'detail'">Detail</button>
+          </div>
+        </div>
+        <div class="vt" style="--vt: scoped-body; padding:0.7lh 0.8em; min-block-size:9lh">
+          <div class="column" data-show="$tab === 'list'" style="gap:0.3lh">
+            <div class="flank card" style="--bg:0.03; padding:0.35lh 0.5em"><span class="avatar" style="--type:-1">A</span><span>Aurora — <small style="--fg:-0.6">shipped</small></span></div>
+            <div class="flank card" style="--bg:0.03; padding:0.35lh 0.5em"><span class="avatar" style="--type:-1">B</span><span>Basalt — <small style="--fg:-0.6">in review</small></span></div>
+            <div class="flank card" style="--bg:0.03; padding:0.35lh 0.5em"><span class="avatar" style="--type:-1">C</span><span>Cobalt — <small style="--fg:-0.6">draft</small></span></div>
+          </div>
+          <div class="column" data-show="$tab === 'detail'" style="gap:0.3lh">
+            <div class="row" style="gap:0.5em"><span class="avatar" style="--type:2">A</span><div class="column" style="gap:0"><strong style="--type:1">Aurora</strong><small style="--fg:-0.6">shipped · 3 collaborators</small></div></div>
+            <p style="--fg:-0.7; --type:-0.5">A single record expanded in place. Only this body snapshot animated — the title bar above never flinched, because it isn't a named group.</p>
+          </div>
+        </div>
+      </div>
+      <pre><code class="html">&lt;header class="spread"&gt;…&lt;/header&gt;              &lt;!-- unnamed: holds --&gt;
+&lt;div class="vt" style="--vt: scoped-body"&gt;…&lt;/div&gt;
+
+&lt;button data-on:click__viewtransition="
+  document.documentElement.dataset.vt = 'isolate';
+  $tab = 'detail'"&gt;Detail&lt;/button&gt;</code></pre>
+    </section>
+
+    <!-- ═══ full-page morphs from the backend ═══ -->
+    <section class="column" style="gap:0.5lh">
+      <h2 style="--type:3">Full-page morphs, from the server</h2>
+      <p style="--fg:-0.6; max-inline-size:64ch">When Datastar patches the DOM from a backend <code>datastar-patch-elements</code> event it uses <strong>idiomorph</strong> — it walks the incoming HTML against the live DOM and mutates only the nodes that differ, leaving everything else untouched. Ask it to wrap that morph in a view transition and you get the same scoping for free: unchanged nodes don't re-render, and the regions you named animate.</p>
+      <div class="table-scroll" style="--bg:0">
+        <table>
+          <thead><tr><th>SSE option</th><th>on <code>datastar-patch-elements</code></th></tr></thead>
+          <tbody>
+            <tr><td><code>useViewTransition</code></td><td>Boolean. <code>true</code> wraps the patch in <code>startViewTransition</code> (when the browser supports it). Default <code>false</code>.</td></tr>
+            <tr><td><code>viewTransitionSelector</code></td><td>A CSS selector naming the element the transition should center on — the scope hint for the patch.</td></tr>
+          </tbody>
+        </table>
+      </div>
+      <div class="split" style="gap:0.7lh; align-items:start">
+        <div class="column" style="gap:0.4lh">
+          <strong style="--type:0">Server sends (SSE)</strong>
+          <pre><code class="txt">event: datastar-patch-elements
+data: useViewTransition true
+data: viewTransitionSelector #board
+data: mode inner
+data: selector #board
+data: elements &lt;div id="board"&gt;…new cards…&lt;/div&gt;</code></pre>
+        </div>
+        <div class="column" style="gap:0.4lh">
+          <strong style="--type:0">Client already scoped it</strong>
+          <pre><code class="html">&lt;html data-vt="isolate"&gt;
+&lt;div id="board" class="vt" style="--vt: board"&gt;
+  &lt;!-- idiomorph swaps only the cards that changed;
+       #board is a named group, so just it morphs --&gt;
+&lt;/div&gt;</code></pre>
+        </div>
+      </div>
+      <p style="--fg:-0.6; --type:-0.5">So the two halves meet: the <em>server</em> decides a morph should transition (<code>useViewTransition</code>); the <em>stylesheet</em> decides what actually moves (a name + <code>isolate</code>). You can fat-morph a whole page and still animate a single card.</p>
     </section>
 
     <section class="split" style="gap:0.7lh; align-items:start">
       <div class="column" style="gap:0.4lh">
-        <h2 style="--type:3">Morph a shared element</h2>
-        <p style="--fg:-0.6">Give an element a unique <code>view-transition-name</code> and it becomes its own group — the browser tweens its old and new size/position, so a list card grows into a detail view. This page's demo panel is named <code>vt-demo</code>; the docs shell names its header/nav/footer so they stay put while the content slides.</p>
-        <pre><code class="css">.card-hero { view-transition-name: hero; }
-/* must be UNIQUE per snapshot */</code></pre>
+        <h2 style="--type:3">Persistent app shell</h2>
+        <p style="--fg:-0.6">Add <code>data-vt-shell</code> to a <code>.page</code> and every chrome slot gets a stable name, so on any navigation the header/nav/aside/footer are their own groups and hold while only <code>.pg-main</code> morphs — the app-shell form of <code>isolate</code>, named once.</p>
+        <pre><code class="html">&lt;div class="page" data-vt-shell&gt;
+  &lt;header class="pg-header"&gt;…&lt;/header&gt;   &lt;!-- holds --&gt;
+  &lt;nav class="pg-navigation"&gt;…&lt;/nav&gt;    &lt;!-- holds --&gt;
+  &lt;main class="pg-main"&gt;…&lt;/main&gt;        &lt;!-- morphs --&gt;
+&lt;/div&gt;</code></pre>
       </div>
       <div class="column" style="gap:0.4lh">
         <h2 style="--type:3">Across separate pages, zero JS</h2>
-        <p style="--fg:-0.6">For multi-page sites, one at-rule opts every same-origin navigation into a transition — no script at all. Style it with the same pseudo-elements.</p>
+        <p style="--fg:-0.6">For real multi-page navigations, one at-rule opts every same-origin load into a transition — no script. Pair it with <code>data-vt-shell</code> and the shell persists across page loads.</p>
         <pre><code class="css">@view-transition { navigation: auto; }</code></pre>
         <p style="--fg:-0.6; --type:-0.5">Left off by default in <code>system.css</code> so multi-page sites opt in deliberately.</p>
       </div>
@@ -80,20 +185,22 @@ document.startViewTransition(() =&gt; {
 
     <section class="column" style="gap:0.4lh">
       <h2 style="--type:3">What the stylesheet defines</h2>
-      <p style="--fg:-0.6">The helper block at the end of <code>system.css</code> — pseudo-elements on the document root, keyframes keyed to <code>data-vt</code>:</p>
-      <pre><code class="css">::view-transition-group(*) {
-  animation-duration: calc(var(--cfg-motion) * 0.28s);
-}
-::view-transition-old(root) { animation-name: vt-fade-out; }  /* default */
+      <p style="--fg:-0.6">Root pseudo-elements + keyframes keyed to <code>data-vt</code>, the <code>.vt</code> name hook, and the shell opt-in:</p>
+      <pre><code class="css">::view-transition-group(*) { animation-duration: calc(var(--cfg-motion) * 0.28s); }
+::view-transition-old(root) { animation-name: vt-fade-out; }   /* default */
 ::view-transition-new(root) { animation-name: vt-fade-in; }
 :root[data-vt="slide-left"]::view-transition-old(root) { animation-name: vt-out-left; }
-:root[data-vt="slide-left"]::view-transition-new(root) { animation-name: vt-in-right; }
-/* …slide-right, scale… */</code></pre>
+/* …slide-right, scale, zoom… */
+:root[data-vt="isolate"]::view-transition-old(root),
+:root[data-vt="isolate"]::view-transition-new(root) { animation: none; }  /* hold root */
+
+.vt { view-transition-name: var(--vt, none); }                 /* name a mover */
+.page[data-vt-shell] > .pg-main { view-transition-name: pg-main; }  /* + each slot */</code></pre>
     </section>
 
     <footer class="column" style="gap:0.3lh; --fg:-0.6">
       <hr>
-      <p style="--type:-0.5">Support: Chromium (same- &amp; cross-document), Safari (recent), Firefox (partial) — and a graceful instant swap everywhere else. Only one transition runs at a time.</p>
+      <p style="--type:-0.5">Support: Chromium (same- &amp; cross-document), Safari (recent), Firefox (partial) — and a graceful instant swap everywhere else. Only one transition runs at a time. Element-scoped <code>element.startViewTransition()</code> is Chromium-only for now, so <code>isolate</code> + names is the portable way to scope today.</p>
     </footer>
 
   </div>
diff --git a/system.css b/system.css
index c48d210..27a2b70 100644
--- a/system.css
+++ b/system.css
@@ -643,6 +643,26 @@
     & > :where(.pg-footer)      { grid-area: f  }
   }
 
+  /* persistent shell for view transitions — opt in with data-vt-shell on the .page.
+     Each chrome slot gets a stable view-transition-name, so across ANY transition (a
+     Datastar morph, a route swap, cross-document navigation) the header/nav/aside/footer
+     are their own groups and hold their position while only .pg-main morphs. Because
+     every slot is now a NAMED group, `root` is left near-empty — so the rest of the app
+     never does a whole-page crossfade. This is the app-shell counterpart to data-vt=
+     "isolate": name the frame once and every navigation is automatically scoped to the
+     content region. Opt-in (not on by default) so a page with two shells, or one that
+     wants a plain whole-page fade, is unaffected. Names must be unique in the document. */
+  :where(.page[data-vt-shell]) {
+    & > :where(.pg-banner)      { view-transition-name: pg-banner }
+    & > :where(.pg-header)      { view-transition-name: pg-header }
+    & > :where(.pg-subheader)   { view-transition-name: pg-subheader }
+    & > :where(.pg-navigation)  { view-transition-name: pg-navigation }
+    & > :where(.pg-toolbar)     { view-transition-name: pg-toolbar }
+    & > :where(.pg-main)        { view-transition-name: pg-main }
+    & > :where(.pg-aside)       { view-transition-name: pg-aside }
+    & > :where(.pg-footer)      { view-transition-name: pg-footer }
+  }
+
   /* .drawer — edge-anchored overlay (<dialog> or popover), composite-only slide */
   :where(.drawer) {
     --_dur: calc(var(--cfg-motion) * 0.25s);
@@ -790,6 +810,18 @@
   :where(.stack) { display: grid; grid-template-areas: "stack"; & > * { grid-area: stack } }
   :where(.track) { display: grid; grid-auto-flow: column; grid-auto-columns: minmax(var(--track-min, 6rem), max-content); gap: calc(0.25 * 1lh); overflow-x: auto; }
 
+  /* .vt — name an element so it becomes its OWN view-transition group: the browser
+     morphs it (position/size/content) between the old and new frame while the rest of
+     the page is captured as `root`. This is how you scope a transition to the parts
+     that actually change — give each changing region a UNIQUE name and pair it with
+     data-vt="isolate" on <html> so the untouched chrome holds still. The name comes
+     from --vt (a <custom-ident>), so you compose it inline like every other position:
+       <article class="vt card" style="--vt: detail"> … </article>
+     A name must be unique per snapshot; keeping it stable across the old→new frame is
+     what links the two frames of the SAME element so it tweens instead of crossfading.
+     Inert until a transition is running. */
+  :where(.vt) { view-transition-name: var(--vt, none); }
+
   :where(.hero) {
     display: grid;
     grid-template: "t t t" auto "l m r" 1fr "b b b" auto / auto 1fr auto;
@@ -2311,10 +2343,23 @@
    document.startViewTransition(update) (same-document) — nothing here runs
    otherwise, so it's inert until you opt in. Direction is chosen by setting
    data-vt on <html> right before starting: "fade" (default) · "slide-left" ·
-   "slide-right" · "scale" (subtle) · "zoom" (pronounced). Duration rides --cfg-motion, so data-ui-motion
-   (off/on/debug) and prefers-reduced-motion already govern it — at motion 0
-   the animation is 0s (an instant swap). @keyframes live outside @layer (they
-   are global by name); the pseudos are on the document root.
+   "slide-right" · "scale" (subtle) · "zoom" (pronounced) · "isolate" (hold the whole
+   page still so ONLY named regions move — the scoped/targeted mode). Duration rides
+   --cfg-motion, so data-ui-motion (off/on/debug) and prefers-reduced-motion already
+   govern it — at motion 0 the animation is 0s (an instant swap). @keyframes live
+   outside @layer (they are global by name); the pseudos are on the document root.
+
+   Two ways to SCOPE a transition to the parts that actually change (rather than
+   crossfading the whole viewport):
+     · name the changing region(s) with `.vt` / a view-transition-name AND set
+       data-vt="isolate" so `root` (everything else) does not animate; or
+     · put data-vt-shell on a .page — every chrome slot becomes a named group that
+       holds still, so only .pg-main morphs on any navigation.
+   Datastar drives the DOM change: the `__viewtransition` action modifier wraps a
+   frontend swap, and a `datastar-patch-elements` SSE frame with `useViewTransition
+   true` (optionally `viewTransitionSelector <css>`) wraps a backend morph — its
+   idiomorph patch only mutates changed nodes, so a named region tweens and the rest
+   is untouched.
 
    Cross-DOCUMENT transitions (between same-origin page loads, zero JS) are one
    line away — add `@view-transition { navigation: auto; }` — left off by
@@ -2347,3 +2392,11 @@
 :root[data-vt="scale"]::view-transition-new(root)       { animation-name: vt-in-scale; }
 :root[data-vt="zoom"]::view-transition-old(root)        { animation-name: vt-out-zoom; }
 :root[data-vt="zoom"]::view-transition-new(root)        { animation-name: vt-in-zoom; }
+/* isolate — hold the whole page still so ONLY named regions (a `.vt` element, a named
+   .pg-* shell slot, or anything with its own view-transition-name) animate. This is the
+   recommended pairing for a SCOPED transition — a Datastar fat morph, or any swap, where
+   just one region visibly changes: set data-vt="isolate" on <html>, name the region(s)
+   that should move, and the untouched chrome swaps with no whole-page crossfade flash.
+   `root` still captures the rest; killing its animation is what makes the swap targeted. */
+:root[data-vt="isolate"]::view-transition-old(root),
+:root[data-vt="isolate"]::view-transition-new(root)     { animation: none; }
-- 
2.43.0

PATCH_EOF

# --- apply: as a commit (preferred), else into the working tree -------------
echo "> Applying patch..."
if git am --3way "$PATCH"; then
  echo
  echo "SUCCESS — applied as a signed-by-you commit."
  echo "Review:  git show --stat    (7 files changed)"
else
  git am --abort 2>/dev/null || true
  echo "> 'git am' didn't apply cleanly; dropping changes into the working tree instead."
  git apply --3way "$PATCH"
  git add -A
  echo
  echo "SUCCESS — changes staged (not yet committed)."
  echo "Commit:  git commit -m 'Refine view transitions + composition docs; add terse API front-door'"
fi

echo
echo "Then push:  git push origin $BRANCH"
