---
name: system-css
description: >-
  Build interfaces with system.css — a class-light, element-first CSS design
  system with an OKLCH color engine and type-driven spacing. Use when creating
  or editing UI (pages, components, mockups, prototypes, emails) that should
  follow this design system: link one stylesheet and write plain HTML, setting
  a few signed custom properties (--bg, --fg, --hue, --type) instead of picking
  colors or spacing. Covers the token API, component catalog, layout shell,
  runtime theme switches, and view transitions.
license: MIT
---

# system.css

Class-light, element-first. Link the stylesheet, write plain HTML — a bare
`<button>`, `<table>`, `<details>`, or a `<label>` inside a `<form>` is already
the styled component. Color, type, spacing, and state are **computed** from a
few signed custom properties. There is no palette to pick from and no spacing
scale to memorize.

## Setup

1. Copy `system.css` into the project and link it: `<link rel="stylesheet" href="system.css">`.
2. Load the theme's webfonts (default is Roboto + Roboto Mono via Google Fonts). Without them the type falls back.
3. Set theme/hue on `<html>`: `<html data-ui-theme="dark" style="--hue:255">`.
4. Write plain HTML. Reach for a class only to vary or emphasize an element.

Do **not** add a CSS framework, a client JS framework, or hand-written padding/
color values. The intended runtime is server-rendered HTML with Datastar for
interactivity — keep interactivity declarative.

## The color model — declare position, not color

Every element resolves its color from three inherited numbers. You set where it
sits; the engine solves the actual OKLCH for the live theme, hue, and host surface.

| Var | Axis | Range | Meaning |
|---|---|---|---|
| `--bg` | surface depth | −1 … 0 … +1 | 0 = base. Negative recedes (quieter). Positive advances toward the chromatic peak (louder). |
| `--fg` | ink | −1 … 0 … +1 | Negative → neutral contrast pole (max legibility). Positive → chromatic pole (colored ink). Contrast auto-solved against the host surface. |
| `--hue` | hue | 0 … 360 | One number rotates the whole system. |
| `--hue-shift` | subtree hue | ±deg | Adds into the live hue — rotates every non-locked descendant at once. |
| `--hue-lock` | pin | — | Pins hue against a shift; the semantic helpers set it so meaning never rotates. |

```html
<div class="card" style="--bg:-0.3">recessed panel</div>
<span style="--fg:0.8">chromatic text</span>
```

`--border` and `--focus` are **derived** from the surface automatically — never set them.

### Surfaces & separation

Paint with `.bg`, or use a named container. Nest by **lifting**, not by hand-picking
darker values — a lifted child steps off whatever hosts it, so it stays correct anywhere.

| Class | Separation |
|---|---|
| `.bg` | Paints its `--bg`; publishes lightness for child ink. |
| `.card` / `.Card` | Bordered panel — quiet line / vibrant line. |
| `.surface` / `.Surface` | A `--lift` step, no line — for grouping inside a card. |
| `--lift: n` | Sit `n` above the host surface (relative). What every control uses to read on any background. |

> Perceptual note: near black, equal lightness steps are imperceptible. Dark
> surfaces separate via a wider lightness range and/or a small chroma tint
> (`--neg-chroma`), not by tiny equal L steps. The skins already handle this.

## Type is the spacing system

One signed step `--type` sets size; leading, tracking, and weight derive from it.
Spacing is a fraction of the line (`lh`), so rhythm scales with type. No pixel grid.

| Step | Role |
|---|---|
| `5 … 1` | `h1 … h5` |
| `0` | body · UI · controls |
| `−1` | `small` |
| `−2` | micro (tags, captions) |

`--type` sizes one element (does not inherit). `--scale` zooms a whole region (inherits).

**Never hand-set padding.** Compose with `.row`/`.column`/`.grid` and their `lh`-based
`gap`; let each component keep its own `em`-based padding. Hand padding breaks
alignment the moment `--type` or `data-ui-size` changes.

## Components — bare-first

Height is shared: a `button`, field, `select`, and `.avatar` land on one height per `--type`.

| Write | Get |
|---|---|
| `<button>` · `.pri` · `.sec` | Button — default / primary / secondary. `.btn` on `<a>` for link semantics. |
| `<button aria-label="…">​<svg>` | Square icon button. **The `aria-label` is required** — it's the accessible name and the hook that makes the control square. |
| `.button-group` | Connected toggle row; the pressed one goes max-chroma. |
| `<form>` › `<label>` | A label in a form is a field: `<span>` + a fixed `<small>` slot + input. `<fieldset>` packs fields onto one row (`--row-width`). Form fields separate by surface, not outline. |
| `<table>` `<select>` `<details>` `<progress>` `<meter>` `<blockquote>` `<code>` `<kbd>` | Bare — styled, no class. |
| `.tag` · `.alert` · `.avatar` · `.badge` · `.count` | Label chip · standing message · monogram · corner count · trailing pill. |
| `.tabs` · `.tabs-underline` · `.crumbs` · `.nav-item` · `.nav-icon` | Segmented radio · underline tabs · breadcrumbs · nav rows. |
| `.fab-1/2/3` | Glass floating actions, ascending prominence. Place in a `.stack`/`.hud` as a sibling of scrolling content. |

### Meaning & state

Four semantic helpers lock a hue and commit ink to it, layer-independently.
State rides ARIA — do not invent state classes.

| Hook | Effect |
|---|---|
| `.suc .inf .wrn .dgr` | success · info · warning · danger — hue-locked, immune to `--hue-shift`. |
| `[aria-pressed="true"]` | Toggle on (button / nav). |
| `[aria-current="page"]` | Current destination. |
| `data-ui-state="on" / "off"` | Live-in-a-set accent / greyed. General — any element: `off` desaturates + dims a whole region (`.tag` keeps its own recipe). |
| `[aria-invalid]` `[required]` `[disabled]` | Field danger · asterisk · drained. |

## Layout

Zero-specificity primitives (gap in `lh`) — anything you author beats them without a fight.

| Class | Shape |
|---|---|
| `.row` · `.column` | Horizontal (wraps) · vertical. |
| `.split` · `.spread` · `.spread-column` · `.lcr` | Two equal · space-between row / column · left·center·right. |
| `.flank` · `.grid` · `.stack` · `.track` | Fixed leader + fluid rest · auto-fit (`--grid-min`) · overlay · scroll row. |
| `.scroll-x` · `.scroll-y` | Scroll containers with contained overscroll. |
| `.page` + `.pg-*` | Ten-slot app shell: `.pg-banner .pg-header .pg-subheader .pg-navigation .pg-toolbar .pg-main-header .pg-main .pg-main-footer .pg-aside .pg-footer`. Add a child, its slot appears; only nav/main/aside scroll. |
| `.modal` · `.drawer .left/.right/.top/.bottom` · `.menu` · `.hud` | Native `<dialog>`/popover overlays — no z-index. `.hud` has nine slots `.tl .tc .tr · .cl .cc .cr · .bl .bc .br` (a `.card` in `.hud .tr` = toast; a `.fab-3` in `.br` = primary action). |

### Viewport & pointer gates (layer-order dependent)

Each defaults to `display:none`; the matching query flips it to `display: revert-layer`,
restoring the element's natural display. This works **only** because these rules live
in the last cascade layer (`classAPI.media`). None is on by default — add one and the
element shows only in that range; they compose (`class="mobile desktop"` = phone + desktop, hidden on tablet).

| Classes | Gate | Breakpoints |
|---|---|---|
| `.mobile .tablet .desktop` | viewport width | <768 · 768–1024 · ≥1024px |
| `.small .medium .large` | container width (needs `container-type` ancestor) | <320 · 320–560 · ≥560px |
| `.fine .coarse` | pointer | mouse · touch |

### Utilities

`.glass` (frosted; `--glass-alpha`, `--glass-blur`) · `.truncate` · `.nowrap` ·
`.read` (65ch measure) · `.center` · `.fill` · `.num` (tabular figures on th/td) ·
`.smart` (on `<meter>`, hue by band) · `.badge` · `.vh` (visually hidden) ·
`.np` (no-print) · `.bw` (black & white — zeroes chroma for a subtree).

## Runtime switches

Set on `<html>` or any subtree; everything below re-resolves. Hue is separate from theme.

| Attribute | Values |
|---|---|
| `data-ui-theme` | `light` · `dark` (unset → OS) |
| `data-ui-size` | `sm · md · lg · xl` |
| `data-ui-skin` | *(default)* · `material` · `carbon` · `vivid` |
| `data-ui-motion` | `off · on · debug` |
| `style="--hue:n"` | 0 … 360 |

## View transitions

Inert until you opt in. Set `data-vt` on `<html>`, then wrap a DOM change:

```js
document.documentElement.dataset.vt = "slide-left"; // fade | slide-left | slide-right | scale | zoom
document.startViewTransition(() => render(next));
```

Duration rides `--cfg-motion`, so `data-ui-motion` and `prefers-reduced-motion` govern
it. Unique `view-transition-name` morphs a shared element. Cross-document (zero JS):
`@view-transition { navigation: auto; }`.

## The laws

1. Bare HTML is the component; add a class only to vary it.
2. Never name a color — declare a position (`--bg`/`--fg`) and let the engine solve it.
3. Shape follows content; height is shared; spacing is a fraction of the line — never hand-set padding.
4. State rides ARIA. Meaning rides the four semantic helpers.
5. Everything you author wins — the system ships at specificity 0.

## Deeper reference

- `system.css` — the stylesheet and single source of truth; read it for exact tokens and edge cases.
- `skill.html` — the same API as a rendered, browsable guide with live specimens.
- `demo-*.html` — full-page examples (dashboard, calendar, marketing, command palette).
