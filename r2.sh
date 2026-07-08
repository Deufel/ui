#!/usr/bin/env bash
#
# apply-vt-docs-rework.sh
# Incremental update to the View transitions docs (simpler model + more demos).
# Touches only: sections/transitions.html, docs.css
# Apply it ON TOP of the earlier system.css refactor. Run from inside your clone.
#
set -euo pipefail
BRANCH="claude/ui-composition-docs-refactor-bk1t2i"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: run inside your 'ui' clone." >&2
  exit 1
}
cd "$(git rev-parse --show-toplevel)"
[ -z "$(git status --porcelain)" ] || {
  echo "ERROR: commit or stash your changes first." >&2
  exit 1
}

echo "> On branch: $(git branch --show-current)"
PATCH="$(mktemp)"
trap 'rm -f "$PATCH"' EXIT
cat >"$PATCH" <<'PATCH_EOF'
From 58f16c9ee4502a1cd74eba94a78545b8e934d1b2 Mon Sep 17 00:00:00 2001
From: Claude <noreply@anthropic.com>
Date: Wed, 8 Jul 2026 13:10:48 +0000
Subject: [PATCH] Rework view-transitions docs: simpler model + more demos
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit

- Lead with the two-move model (wrap + name); make clear you usually need
  neither data-vt nor isolate.
- Add a "what actually animates" explainer (root vs named group) — explains
  why a scoped change moves only one box and the page holds.
- Fix the "Try it" demo so the direction buttons actually animate the panel
  (docs.css points the root direction keyframes at the demo's own group).
- Add two demos: grow/morph one element, and scale-off/on enter-leave (poof).
- Note reactive naming via data-style (free alternative to Pro
  data-view-transition), the __viewtransition trigger set, and an honest
  static-hosting (GitHub Pages) fetch recipe.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01UxrVhYFbtLuKqJ83YV1NvP
---
 docs.css                  |  22 ++++
 sections/transitions.html | 266 +++++++++++++++++++-------------------
 2 files changed, 152 insertions(+), 136 deletions(-)

diff --git a/docs.css b/docs.css
index 075604d..88a4e81 100644
--- a/docs.css
+++ b/docs.css
@@ -55,6 +55,28 @@ body { margin: 0; }
 .vt-panel { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 0.2lh; view-transition-name: vt-demo; }
 .vt-big { --type: 6; font-weight: 800; letter-spacing: -0.02em; }
 
+/* "Try it" — point the root direction keyframes at the panel's OWN group so each
+   direction is visible inside the box. In a real app you set data-vt and the whole
+   page (root) animates; here the same keyframes are scoped to one name so you can
+   watch them. (fade is the default group animation, so it needs no rule.) */
+:root[data-vt="slide-left"]::view-transition-old(vt-demo)  { animation-name: vt-out-left; }
+:root[data-vt="slide-left"]::view-transition-new(vt-demo)  { animation-name: vt-in-right; }
+:root[data-vt="slide-right"]::view-transition-old(vt-demo) { animation-name: vt-out-right; }
+:root[data-vt="slide-right"]::view-transition-new(vt-demo) { animation-name: vt-in-left; }
+:root[data-vt="scale"]::view-transition-old(vt-demo)       { animation-name: vt-out-scale; }
+:root[data-vt="scale"]::view-transition-new(vt-demo)       { animation-name: vt-in-scale; }
+:root[data-vt="zoom"]::view-transition-old(vt-demo)        { animation-name: vt-out-zoom; }
+:root[data-vt="zoom"]::view-transition-new(vt-demo)        { animation-name: vt-in-zoom; }
+
+/* grow morph — one element, stable name, box changes → the browser tweens it */
+.growbox { display: grid; place-items: center; inline-size: 9rem; block-size: 4lh; border-radius: var(--cfg-radius); --bg: 0.12; background-color: var(--_bg); cursor: pointer; view-transition-name: growbox; user-select: none; }
+.growbox.big { inline-size: 100%; block-size: 11lh; --bg: 0.06; }
+
+/* poof — scale an element down as it leaves, up as it enters (its own group) */
+:root::view-transition-old(poof) { animation-name: vt-out-zoom; }
+:root::view-transition-new(poof) { animation-name: vt-in-zoom; }
+.poofbox { display: grid; place-items: center; min-block-size: 4lh; padding: 0.4lh 0.8em; border-radius: var(--cfg-radius); --bg: 0.14; background-color: var(--_bg); view-transition-name: poof; }
+
 /* ============ components ============ */
 .comp { display: flex; flex-direction: column; gap: 0.45lh; padding-block: 0.8lh 1.1lh; border-block-end: 1px solid var(--border); scroll-margin-top: 0.5lh; }
 .comp-demo { display: flex; flex-wrap: wrap; gap: 0.7em; align-items: center; padding: 0.8lh 0.9em; border: 1px dashed var(--border); border-radius: var(--cfg-radius); }
diff --git a/sections/transitions.html b/sections/transitions.html
index 329d1ba..7dddc3e 100644
--- a/sections/transitions.html
+++ b/sections/transitions.html
@@ -1,19 +1,84 @@
-<main class="pg-main" id="main" data-init="afterNav('transitions'); $vtsupport = !!document.startViewTransition" data-signals="{vtn: 1, vtdir: 'slide-left', vtsupport: true, tab: 'list', pick: 1}">
+<main class="pg-main" id="main" data-init="afterNav('transitions'); $vtsupport = !!document.startViewTransition" data-signals="{vtn: 1, vtdir: 'slide-left', vtsupport: true, tab: 'list', grow: false, poof: true}">
   <div class="doc">
 
     <header class="column" style="gap: 0.4lh">
       <span class="tag inf" style="align-self:start">layout · motion</span>
       <h1 style="--type: 6">View transitions</h1>
-      <p style="--type:1; --fg:-0.7; max-inline-size: 56ch">A plain CSS <code>transition</code> animates one property on one element that stays put. The <strong>View Transitions API</strong> generalizes that to a whole DOM change — elements that appear, move, or leave — by snapshotting the page before &amp; after and animating between the two frames. You don't write the animation; you make the change, and the browser tweens. <code>system.css</code> adds the direction helpers, a <strong>scoped</strong> mode, and the wiring so <strong>Datastar</strong> drives it.</p>
+      <p style="--type:1; --fg:-0.7; max-inline-size: 56ch">You don't write the animation — you make the DOM change, and the browser tweens the before and after for you. With <strong>Datastar</strong> that's two things: <strong>wrap</strong> the change so the browser snapshots it, and <strong>name</strong> the element that should move. Everything else on this page is elaboration on those two moves.</p>
     </header>
 
+    <!-- ═══ the one idea ═══ -->
     <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
-      <div class="spread"><h2 style="--type:3">Try it</h2><span data-attr:class="$vtsupport ? 'tag suc' : 'tag wrn'" data-text="$vtsupport ? 'supported here' : 'not supported — swaps instantly'"></span></div>
-      <p style="--fg:-0.6; --type:-0.5">Pick a direction, then swap the panel. Set the header's motion to <strong>Debug</strong> to watch it in slow motion — duration rides <code>--cfg-motion</code>.</p>
+      <div class="spread"><h2 style="--type:3">The whole thing, in two moves</h2><span data-attr:class="$vtsupport ? 'tag suc' : 'tag wrn'" data-text="$vtsupport ? 'supported here' : 'not supported — swaps instantly'"></span></div>
+      <div class="split" style="gap:0.7lh; align-items:start">
+        <div class="column" style="gap:0.3lh">
+          <div class="row" style="gap:0.5em"><span class="tag inf">1</span><strong>Wrap the change</strong></div>
+          <small style="--fg:-0.7">Add <code>__viewtransition</code> to the Datastar action that changes the DOM. It runs your change inside <code>document.startViewTransition()</code> — the browser freezes the old frame, applies the change, and crossfades to the new one. No library.</small>
+          <pre style="margin:0"><code class="html">&lt;button data-on:click__viewtransition="$open = true"&gt;</code></pre>
+        </div>
+        <div class="column" style="gap:0.3lh">
+          <div class="row" style="gap:0.5em"><span class="tag inf">2</span><strong>Name what should move</strong></div>
+          <small style="--fg:-0.7">Give the element a <code>view-transition-name</code> (the <code>.vt</code> helper reads it from <code>--vt</code>). Named elements morph independently; everything unnamed is captured together as <code>root</code>.</small>
+          <pre style="margin:0"><code class="html">&lt;article class="vt" style="--vt: hero"&gt;…&lt;/article&gt;</code></pre>
+        </div>
+      </div>
+      <div class="alert suc" role="note">
+        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
+        <small style="--fg:-0.8">That's the simplest correct usage — and it's all frontend, so it works on static hosting (GitHub Pages) with no server. You do <strong>not</strong> need <code>data-vt</code>, <code>isolate</code>, or a build step for the common case. Those are the extras further down.</small>
+      </div>
+    </section>
+
+    <!-- ═══ what actually animates — answers "why doesn't the whole page move?" ═══ -->
+    <section class="column" style="gap:0.5lh">
+      <h2 style="--type:3">What actually animates</h2>
+      <p style="--fg:-0.6; max-inline-size:64ch">This is the one rule that explains everything — including why some changes move the whole page and some move only one box:</p>
+      <div class="grid" style="--grid-min:16rem; gap:0.6lh">
+        <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag">root</span><strong>everything unnamed</strong></div><small style="--fg:-0.7">The whole viewport, minus the named elements, captured as one group. Animates <em>only if something in it changed</em> — or if you force it with a <code>data-vt</code> direction.</small></div>
+        <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag inf">named</span><strong>each <code>.vt</code> element</strong></div><small style="--fg:-0.7">Pulled out of <code>root</code> into its own group and matched old→new by name. Morphs (position, size, content) when that element changed.</small></div>
+        <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag suc">what you see</span><strong>groups that differ</strong></div><small style="--fg:-0.7">A group only animates when its before-picture ≠ its after-picture. Unchanged groups hold perfectly still, even mid-transition.</small></div>
+      </div>
+      <p style="--fg:-0.6; --type:-0.5">So if you change one named region and nothing else, only that region moves — <code>root</code> is identical before and after, so it just holds. That is the effect you want, and it's the default. You reach for the extras below only to <em>override</em> this: to animate the whole page on purpose, or to freeze <code>root</code> when it did change.</p>
+    </section>
+
+    <!-- ═══ DEMO: grow morph — the simplest, no data-vt ═══ -->
+    <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
+      <div class="spread"><h2 style="--type:3">Demo · morph one element</h2><span class="tag inf">just wrap + name</span></div>
+      <p style="--fg:-0.6; --type:-0.5">One element with a stable name. Clicking only changes its size — so the browser tweens its old box into its new box. No <code>data-vt</code>, no isolate; the rest of the page holds because nothing else changed. Try it under <strong>Debug</strong> motion.</p>
+      <div class="row" style="justify-content:center; padding:0.5lh 0">
+        <div class="growbox" data-class:big="$grow" data-on:click__viewtransition="$grow = !$grow">
+          <span data-text="$grow ? 'click to shrink ↙' : 'click to grow ↗'"></span>
+        </div>
+      </div>
+      <pre><code class="html">&lt;div class="growbox"                       &lt;!-- has view-transition-name: growbox --&gt;
+     data-class:big="$grow"                &lt;!-- .big just changes its width/height --&gt;
+     data-on:click__viewtransition="$grow = !$grow"&gt;
+  grow / shrink
+&lt;/div&gt;</code></pre>
+    </section>
+
+    <!-- ═══ DEMO: poof — scale off on leave, on on enter ═══ -->
+    <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
+      <div class="spread"><h2 style="--type:3">Demo · scale off &amp; on</h2><span class="tag inf">enter / leave</span></div>
+      <p style="--fg:-0.6; --type:-0.5">When a named element <em>appears</em> or <em>leaves</em> (here via <code>data-show</code>), the browser plays its enter/leave animation. This one is pointed at <code>zoom</code>, so it scales down as it goes and pops up as it returns — exactly the "scales down and disappears" you asked about.</p>
+      <div class="row" style="gap:0.7em; align-items:center; padding:0.4lh 0">
+        <button class="pri" data-on:click__viewtransition="$poof = !$poof" data-text="$poof ? 'Remove ✕' : 'Add ✚'" style="min-inline-size:7em"></button>
+        <div class="poofbox" data-show="$poof"><strong>poof</strong></div>
+      </div>
+      <pre><code class="css">/* the element's group is named `poof`; assign the enter/leave keyframes to it */
+::view-transition-old(poof) { animation-name: vt-out-zoom; }  /* scales down + fades */
+::view-transition-new(poof) { animation-name: vt-in-zoom;  }  /* scales up on return */</code></pre>
+      <pre><code class="html">&lt;button data-on:click__viewtransition="$poof = !$poof"&gt;Toggle&lt;/button&gt;
+&lt;div class="vt" style="--vt: poof" data-show="$poof"&gt;poof&lt;/div&gt;</code></pre>
+    </section>
+
+    <!-- ═══ DEMO: whole-page directions (fixed) ═══ -->
+    <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
+      <div class="spread"><h2 style="--type:3">Demo · whole-page directions</h2><span class="tag wrn">this is what <code>data-vt</code> is for</span></div>
+      <p style="--fg:-0.6; --type:-0.5">Set <code>data-vt</code> on <code>&lt;html&gt;</code> to give <code>root</code> — the <em>whole page</em> — a direction instead of a plain crossfade. Pick one and swap; the panel below plays it. (In a real app the entire viewport does this on a route change; here the keyframes are scoped to the demo panel so you can watch each one.)</p>
       <div class="vt-stage" style="--bg:0">
         <div class="vt-panel" data-style="{'--hue': $vtn === 1 ? 255 : $vtn === 2 ? 25 : $vtn === 3 ? 150 : 285}" style="--bg:0.12; background-color: var(--_bg)">
           <span class="vt-big" data-text="$vtn"></span>
-          <small style="--fg:-0.6" data-text="$vtn === 1 ? 'Panel one' : $vtn === 2 ? 'Panel two' : $vtn === 3 ? 'Panel three' : 'Panel four'"></small>
+          <small style="--fg:-0.6" data-text="'Panel ' + $vtn"></small>
         </div>
       </div>
       <div class="spread" style="gap:0.6em; flex-wrap:wrap">
@@ -26,82 +91,23 @@
         </div>
         <button class="pri nowrap" data-on:click__viewtransition="document.documentElement.dataset.vt = $vtdir; $vtn = ($vtn % 4) + 1">Swap panel →</button>
       </div>
-    </section>
-
-    <section class="column" style="gap:0.5lh">
-      <h2 style="--type:3">One call — that's the whole API</h2>
-      <p style="--fg:-0.6; max-inline-size:62ch">Wrap any DOM change in <code>startViewTransition</code>. The browser freezes the old frame, runs your callback, then crossfades to the new frame. No library, no manual FLIP math. Unsupported browsers just run the callback with no animation — safe to ship today.</p>
-      <div class="split" style="gap:0.7lh; align-items:start">
-        <div class="column" style="gap:0.4lh">
-          <strong style="--type:0">Raw JS</strong>
-          <pre><code class="js">document.documentElement.dataset.vt = "slide-left";
-document.startViewTransition(() =&gt; {
-  render(nextState);   // any DOM mutation
-});</code></pre>
-        </div>
-        <div class="column" style="gap:0.4lh">
-          <strong style="--type:0">Datastar — the same thing, declaratively</strong>
-          <pre><code class="html">&lt;button
-  data-on:click__viewtransition="
-    document.documentElement.dataset.vt = 'slide-left';
-    $panel = next"&gt;
-  Next
-&lt;/button&gt;</code></pre>
-        </div>
-      </div>
-      <p style="--fg:-0.6; --type:-0.5">The <code>__viewtransition</code> modifier wraps the expression's DOM changes in a transition for you — this is what the <strong>Swap panel</strong> button above uses.</p>
-    </section>
-
-    <section class="split" style="gap:0.7lh; align-items:start">
-      <div class="column" style="gap:0.4lh">
-        <h2 style="--type:3">Directions ship as helpers</h2>
-        <p style="--fg:-0.6">Set <code>data-vt</code> on <code>&lt;html&gt;</code> before you start; <code>system.css</code> keys the root keyframes off it.</p>
-        <div class="table-scroll" style="--bg:0">
-          <table>
-            <thead><tr><th><code>data-vt</code></th><th>motion</th></tr></thead>
-            <tbody>
-              <tr><td><code>fade</code></td><td>Crossfade (the default if unset)</td></tr>
-              <tr><td><code>slide-left</code></td><td>New content enters from the right</td></tr>
-              <tr><td><code>slide-right</code></td><td>New content enters from the left</td></tr>
-              <tr><td><code>scale</code></td><td>Subtle zoom crossfade</td></tr>
-              <tr><td><code>zoom</code></td><td>Pronounced zoom crossfade</td></tr>
-              <tr><td><code>isolate</code></td><td>Hold the page still — only <em>named</em> regions move</td></tr>
-            </tbody>
-          </table>
-        </div>
-      </div>
-      <div class="column" style="gap:0.4lh">
-        <h2 style="--type:3">It obeys the motion switch — free</h2>
-        <p style="--fg:-0.6">Duration is <code>calc(var(--cfg-motion) * 0.28s)</code>, so <code>data-ui-motion</code> off → instant swap, debug → slow, and <code>prefers-reduced-motion</code> zeroes it.</p>
-        <div class="alert inf" role="note" style="margin-block-start:0.2lh">
-          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8h.01M11 12h1v4h1"/></svg>
-          <small style="--fg:-0.75">The transition pseudo-elements live on <code>:root</code>, so set <code>data-ui-motion</code> and <code>data-vt</code> on <code>&lt;html&gt;</code> — not an inner wrapper — so the value reaches them.</small>
-        </div>
-      </div>
-    </section>
-
-    <!-- ═══ the part that matters: scope to what changes ═══ -->
-    <section class="column" style="gap:0.5lh">
-      <div class="spread"><h2 style="--type:3">Animate only what changes</h2><span class="tag suc">the pattern to reach for</span></div>
-      <p style="--fg:-0.6; max-inline-size:64ch">By default a transition captures the <strong>whole viewport</strong> as one group called <code>root</code> and crossfades it — so even a one-word change flashes the entire page. To scope the motion to the regions that actually change, do two things:</p>
-      <div class="grid" style="--grid-min:15rem; gap:0.6lh">
-        <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag inf">1</span><strong>Name the movers</strong></div><small style="--fg:-0.7">Give each region that should animate its own <code>view-transition-name</code> — the <code>.vt</code> helper reads it from <code>--vt</code>. A named element becomes its own group and tweens between frames.</small></div>
-        <div class="card column" style="--bg:0.02; gap:0.2lh"><div class="row" style="gap:0.5em"><span class="tag inf">2</span><strong>Hold the rest</strong></div><small style="--fg:-0.7">Set <code>data-vt="isolate"</code> so <code>root</code> — everything you didn't name — swaps with <em>no</em> animation. No whole-page crossfade; only your named regions move.</small></div>
+      <div class="table-scroll" style="--bg:0">
+        <table>
+          <thead><tr><th><code>data-vt</code> on <code>&lt;html&gt;</code></th><th>root motion</th></tr></thead>
+          <tbody>
+            <tr><td><code>fade</code></td><td>Crossfade (the default if unset)</td></tr>
+            <tr><td><code>slide-left</code> · <code>slide-right</code></td><td>New content enters from the right / left</td></tr>
+            <tr><td><code>scale</code> · <code>zoom</code></td><td>Subtle / pronounced zoom crossfade</td></tr>
+            <tr><td><code>isolate</code></td><td>Hold <code>root</code> still — only named groups move (see below)</td></tr>
+          </tbody>
+        </table>
       </div>
-      <pre><code class="html">&lt;html data-vt="isolate"&gt;                &lt;!-- root holds still --&gt;
-
-&lt;aside class="pg-navigation"&gt;…&lt;/aside&gt;   &lt;!-- unnamed → instant, no flash --&gt;
-&lt;main&gt;
-  &lt;article class="vt card" style="--vt: detail"&gt;   &lt;!-- named → morphs --&gt;
-    …content that changes…
-  &lt;/article&gt;
-&lt;/main&gt;</code></pre>
-      <p style="--fg:-0.6; --type:-0.5">A name must be <strong>unique per snapshot</strong>; keeping the <em>same</em> name on an element across the change is what links its old and new frame so it tweens instead of crossfading. Reuse a name on two visible elements and the browser skips the transition.</p>
     </section>
 
+    <!-- ═══ DEMO: scoped region with isolate ═══ -->
     <section class="Card column" style="--bg:0.05; gap:0.5lh; padding:0.7lh 0.8em">
-      <div class="spread"><h2 style="--type:3">Scoped morph — live</h2><span class="tag inf">isolate + a named region</span></div>
-      <p style="--fg:-0.6; --type:-0.5">The title bar and tabs are <em>unnamed</em>, so they hold. Only the body carries <code>--vt: scoped-body</code>, so only it morphs when you switch. Swap under <strong>Debug</strong> motion to see the chrome stay put.</p>
+      <div class="spread"><h2 style="--type:3">Demo · hold the chrome, morph one region</h2><span class="tag inf">data-vt="isolate"</span></div>
+      <p style="--fg:-0.6; --type:-0.5">Here the title bar <em>and</em> the body both change (the pressed tab is part of the chrome). Without help, <code>root</code> would crossfade the whole card. <code>data-vt="isolate"</code> freezes <code>root</code>, so only the named body morphs while the bar holds. This is the escape hatch for when the surroundings change but you don't want them to.</p>
       <div class="card column" style="--bg:0; gap:0; padding:0; overflow:hidden">
         <div class="spread" style="--bg:-0.4; background-color:var(--_bg); padding:0.35lh 0.6em">
           <strong style="--type:0">Orbit</strong>
@@ -118,89 +124,77 @@ document.startViewTransition(() =&gt; {
           </div>
           <div class="column" data-show="$tab === 'detail'" style="gap:0.3lh">
             <div class="row" style="gap:0.5em"><span class="avatar" style="--type:2">A</span><div class="column" style="gap:0"><strong style="--type:1">Aurora</strong><small style="--fg:-0.6">shipped · 3 collaborators</small></div></div>
-            <p style="--fg:-0.7; --type:-0.5">A single record expanded in place. Only this body snapshot animated — the title bar above never flinched, because it isn't a named group.</p>
+            <p style="--fg:-0.7; --type:-0.5">One record expanded in place. Only this body snapshot animated — the title bar above never flinched.</p>
           </div>
         </div>
       </div>
-      <pre><code class="html">&lt;header class="spread"&gt;…&lt;/header&gt;              &lt;!-- unnamed: holds --&gt;
-&lt;div class="vt" style="--vt: scoped-body"&gt;…&lt;/div&gt;
+    </section>
 
-&lt;button data-on:click__viewtransition="
-  document.documentElement.dataset.vt = 'isolate';
-  $tab = 'detail'"&gt;Detail&lt;/button&gt;</code></pre>
+    <!-- ═══ naming reactively ═══ -->
+    <section class="split" style="gap:0.7lh; align-items:start">
+      <div class="column" style="gap:0.4lh">
+        <h2 style="--type:3">Name it reactively</h2>
+        <p style="--fg:-0.6">A name must be <strong>unique</strong> among visible elements per snapshot. To make one card the mover only when it's the active one, toggle the name with <code>data-style</code> — the free equivalent of Datastar's Pro <code>data-view-transition</code>.</p>
+        <pre><code class="html">&lt;div class="vt"
+     data-style="{'--vt': $open === id ? 'hero' : 'none'}"&gt;</code></pre>
+        <p style="--fg:-0.6; --type:-0.5">Give the same name to the outgoing card and the incoming detail and the browser morphs one into the other.</p>
+      </div>
+      <div class="column" style="gap:0.4lh">
+        <h2 style="--type:3">Where <code>__viewtransition</code> lives</h2>
+        <p style="--fg:-0.6">The modifier wraps the DOM change for any of these Datastar triggers — pick whichever fires your change:</p>
+        <div class="table-scroll" style="--bg:0">
+          <table>
+            <thead><tr><th>trigger</th><th>fires on</th></tr></thead>
+            <tbody>
+              <tr><td><code>data-on:click__viewtransition</code></td><td>a user event</td></tr>
+              <tr><td><code>data-init__viewtransition</code></td><td>element enters the DOM</td></tr>
+              <tr><td><code>data-on-interval__viewtransition</code></td><td>a timer</td></tr>
+              <tr><td><code>data-on-intersect__viewtransition</code></td><td>scrolls into view</td></tr>
+            </tbody>
+          </table>
+        </div>
+      </div>
     </section>
 
-    <!-- ═══ full-page morphs from the backend ═══ -->
+    <!-- ═══ fetch / server honesty ═══ -->
     <section class="column" style="gap:0.5lh">
-      <h2 style="--type:3">Full-page morphs, from the server</h2>
-      <p style="--fg:-0.6; max-inline-size:64ch">When Datastar patches the DOM from a backend <code>datastar-patch-elements</code> event it uses <strong>idiomorph</strong> — it walks the incoming HTML against the live DOM and mutates only the nodes that differ, leaving everything else untouched. Ask it to wrap that morph in a view transition and you get the same scoping for free: unchanged nodes don't re-render, and the regions you named animate.</p>
-      <div class="table-scroll" style="--bg:0">
-        <table>
-          <thead><tr><th>SSE option</th><th>on <code>datastar-patch-elements</code></th></tr></thead>
-          <tbody>
-            <tr><td><code>useViewTransition</code></td><td>Boolean. <code>true</code> wraps the patch in <code>startViewTransition</code> (when the browser supports it). Default <code>false</code>.</td></tr>
-            <tr><td><code>viewTransitionSelector</code></td><td>A CSS selector naming the element the transition should center on — the scope hint for the patch.</td></tr>
-          </tbody>
-        </table>
+      <h2 style="--type:3">Fetching content — what works on GitHub Pages</h2>
+      <p style="--fg:-0.6; max-inline-size:64ch">A <code>@get('/fragment.html')</code> is a plain GET, so a static file <em>is</em> your "server" — Datastar fetches it and morphs it in (idiomorph, so only changed nodes move). Two honest caveats on transitioning that:</p>
+      <div class="grid" style="--grid-min:17rem; gap:0.6lh">
+        <div class="card column" style="--bg:0.02; gap:0.2lh"><strong style="--type:0">Frontend swaps → simple</strong><small style="--fg:-0.7">A change you drive with signals (show/hide, class, <code>data-style</code>) is synchronous, so <code>__viewtransition</code> wraps it cleanly. This is the path to prefer on static hosting.</small></div>
+        <div class="card column" style="--bg:0.02; gap:0.2lh"><strong style="--type:0">Async fetch → needs the server</strong><small style="--fg:-0.7"><code>__viewtransition</code> can't wrap a fetch that resolves later. The clean way to transition a morph is the SSE flag <code>useViewTransition true</code> — but that needs a <em>streaming</em> backend, which a static file can't be.</small></div>
       </div>
-      <div class="split" style="gap:0.7lh; align-items:start">
-        <div class="column" style="gap:0.4lh">
-          <strong style="--type:0">Server sends (SSE)</strong>
-          <pre><code class="txt">event: datastar-patch-elements
-data: useViewTransition true
-data: viewTransitionSelector #board
-data: mode inner
-data: selector #board
-data: elements &lt;div id="board"&gt;…new cards…&lt;/div&gt;</code></pre>
-        </div>
-        <div class="column" style="gap:0.4lh">
-          <strong style="--type:0">Client already scoped it</strong>
-          <pre><code class="html">&lt;html data-vt="isolate"&gt;
-&lt;div id="board" class="vt" style="--vt: board"&gt;
-  &lt;!-- idiomorph swaps only the cards that changed;
-       #board is a named group, so just it morphs --&gt;
-&lt;/div&gt;</code></pre>
-        </div>
+      <div class="alert inf" role="note">
+        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8h.01M11 12h1v4h1"/></svg>
+        <small style="--fg:-0.8">Practical recipe for a static site: fetch the data into a hidden region with <code>@get</code>, then reveal it with a <em>signal</em> change wrapped in <code>__viewtransition</code> and named with <code>.vt</code>. You get the morph, and the "server" is just a file. When you later move to a streaming backend, add <code>useViewTransition true</code> to the patch and the same names light up automatically.</small>
       </div>
-      <p style="--fg:-0.6; --type:-0.5">So the two halves meet: the <em>server</em> decides a morph should transition (<code>useViewTransition</code>); the <em>stylesheet</em> decides what actually moves (a name + <code>isolate</code>). You can fat-morph a whole page and still animate a single card.</p>
     </section>
 
     <section class="split" style="gap:0.7lh; align-items:start">
       <div class="column" style="gap:0.4lh">
         <h2 style="--type:3">Persistent app shell</h2>
-        <p style="--fg:-0.6">Add <code>data-vt-shell</code> to a <code>.page</code> and every chrome slot gets a stable name, so on any navigation the header/nav/aside/footer are their own groups and hold while only <code>.pg-main</code> morphs — the app-shell form of <code>isolate</code>, named once.</p>
-        <pre><code class="html">&lt;div class="page" data-vt-shell&gt;
-  &lt;header class="pg-header"&gt;…&lt;/header&gt;   &lt;!-- holds --&gt;
-  &lt;nav class="pg-navigation"&gt;…&lt;/nav&gt;    &lt;!-- holds --&gt;
-  &lt;main class="pg-main"&gt;…&lt;/main&gt;        &lt;!-- morphs --&gt;
-&lt;/div&gt;</code></pre>
+        <p style="--fg:-0.6">Add <code>data-vt-shell</code> to a <code>.page</code> and every chrome slot gets a stable name — so on any navigation the header/nav/footer hold and only <code>.pg-main</code> morphs. Isolate, but named once for the whole shell.</p>
+        <pre><code class="html">&lt;div class="page" data-vt-shell&gt; … &lt;/div&gt;</code></pre>
       </div>
       <div class="column" style="gap:0.4lh">
-        <h2 style="--type:3">Across separate pages, zero JS</h2>
-        <p style="--fg:-0.6">For real multi-page navigations, one at-rule opts every same-origin load into a transition — no script. Pair it with <code>data-vt-shell</code> and the shell persists across page loads.</p>
+        <h2 style="--type:3">Real page-to-page, zero JS</h2>
+        <p style="--fg:-0.6">For multi-page navigations, one at-rule opts every same-origin load into a transition — works on plain static hosting.</p>
         <pre><code class="css">@view-transition { navigation: auto; }</code></pre>
-        <p style="--fg:-0.6; --type:-0.5">Left off by default in <code>system.css</code> so multi-page sites opt in deliberately.</p>
+        <p style="--fg:-0.6; --type:-0.5">Off by default in <code>system.css</code> so you opt in deliberately.</p>
       </div>
     </section>
 
-    <section class="column" style="gap:0.4lh">
-      <h2 style="--type:3">What the stylesheet defines</h2>
-      <p style="--fg:-0.6">Root pseudo-elements + keyframes keyed to <code>data-vt</code>, the <code>.vt</code> name hook, and the shell opt-in:</p>
-      <pre><code class="css">::view-transition-group(*) { animation-duration: calc(var(--cfg-motion) * 0.28s); }
-::view-transition-old(root) { animation-name: vt-fade-out; }   /* default */
-::view-transition-new(root) { animation-name: vt-fade-in; }
-:root[data-vt="slide-left"]::view-transition-old(root) { animation-name: vt-out-left; }
-/* …slide-right, scale, zoom… */
-:root[data-vt="isolate"]::view-transition-old(root),
-:root[data-vt="isolate"]::view-transition-new(root) { animation: none; }  /* hold root */
-
-.vt { view-transition-name: var(--vt, none); }                 /* name a mover */
-.page[data-vt-shell] > .pg-main { view-transition-name: pg-main; }  /* + each slot */</code></pre>
+    <section class="alert inf" role="note">
+      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8h.01M11 12h1v4h1"/></svg>
+      <div class="column" style="gap:0.15lh">
+        <strong>Motion is governed for you.</strong>
+        <small style="--fg:-0.75">Every transition's duration is <code>calc(var(--cfg-motion) * 0.28s)</code>, so <code>data-ui-motion</code> off → instant, debug → slow, and <code>prefers-reduced-motion</code> zeroes it. Set <code>data-ui-motion</code> and <code>data-vt</code> on <code>&lt;html&gt;</code> — the transition pseudo-elements live on <code>:root</code>.</small>
+      </div>
     </section>
 
     <footer class="column" style="gap:0.3lh; --fg:-0.6">
       <hr>
-      <p style="--type:-0.5">Support: Chromium (same- &amp; cross-document), Safari (recent), Firefox (partial) — and a graceful instant swap everywhere else. Only one transition runs at a time. Element-scoped <code>element.startViewTransition()</code> is Chromium-only for now, so <code>isolate</code> + names is the portable way to scope today.</p>
+      <p style="--type:-0.5">Support: Chromium (same- &amp; cross-document), Safari (recent), Firefox (partial) — with a graceful instant swap everywhere else. Only one transition runs at a time. Element-scoped <code>element.startViewTransition()</code> is Chromium-only for now, so naming + <code>isolate</code> is the portable way to scope today.</p>
     </footer>
 
   </div>
-- 
2.43.0

PATCH_EOF

echo "> Applying..."
if git am --3way "$PATCH"; then
  echo "SUCCESS — applied as a commit. Review: git show --stat"
else
  git am --abort 2>/dev/null || true
  echo "> 'git am' didn't apply; staging into the working tree instead."
  git apply --3way "$PATCH"
  git add -A
  echo "SUCCESS — staged. Commit with your own message when ready."
fi
echo
echo "Then push:  git push origin $BRANCH"
