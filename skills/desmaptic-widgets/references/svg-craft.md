# SVG craft: faces that glide

Contents: structure vs numbers · building blocks that never break the structure · sizes and text · recipes (ring, gauge, bar, needle, sparkline, ticker, gradient, clip, ticks and dots) · orientation · color · keeping the phone smooth

What the engine can draw — elements, attributes, what is approximated — is listed by `get_available_actions` with topic `svg` (`widgetFaces.svgReference`). This file is about using it well.

## Structure vs numbers

A frame is split in two. Its **structure**: the list of elements, their ids, each path's command letters, which paints are none / colors / `currentColor` / gradients (and a gradient's kind, units and stop count), line caps and joins, `fill-rule`, how many entries `stroke-dasharray` has, a clip's command letters, the viewBox *size*. Its **numbers**: every coordinate, size, color value, opacity, stroke width, dash length and offset, transform, gradient geometry and stops, clip points, the viewBox *origin*.

Two consecutive frames with the same structure **glide**: every number moves from what is on screen to its new value over `duration`. Frames with different structures **cross-fade**: the new frame fades in over the old one for `duration`, then the old one goes. A widget that cross-fades on every update looks like it is blinking — this is the single most common defect, and it always has the same cause: something in the template appears, disappears or changes kind.

Text *content* is neither: a label swaps instantly while the numbers around it glide. So "41%" → "42%" needs no care.

Rules that keep the structure fixed:
- One template function; branches change numbers, not elements.
- Hide with `opacity="0"`. Never omit. Outside the viewBox or at zero size is not hidden: a shape moved from there glides across in sight. Showing it again in place is always safe. To put a hidden element somewhere else, hide it where it is in one frame and move it in a later one, still at `opacity="0"`: a fade is not over when the next frame comes, so a move in the frame that hides it is glided while it still shows — a ghost sliding across (`scenes.md` §3).
- Fade with `fill-opacity`, not by switching `fill="none"` ↔ a color (that changes the paint's kind). An outline is the same: no stroke ↔ a stroke changes the structure, so keep the `stroke` in every frame and hide it with `stroke-opacity="0"`. A `<text>` is the exception: fade, hide and jump it with `opacity`, never `fill-opacity` — the phone counts only a text's `opacity` as hidden (an emoji keeps its own colors at `fill-opacity="0"`), so a label hidden by `fill-opacity` and moved glides in from part-way.
- Keep the point count of every `polyline` / `polygon` / `path` constant. While a history fills up, pad it with the last value.
- Put a rotation's center in the call — `rotate(a cx cy)` — not into the path's points. It then turns rigidly around that center, by the shortest arc (350° → 10° is +20°), so one glide turns at most half a turn: `rotate(0)` → `rotate(1074)` turns −6°, not three turns. To turn further, send several frames less than 180° apart. Only one rotate of an element may change between frames: a moon whose own turn and its planet's both change cuts straight across instead of circling — move it around the planet by its own position. A rotate that stays the same is fine: a label with its own `rotate(30 x y)` in a turning wheel goes round with the wheel. A group of several parts that turns together (a fish: body, fins, eye) names its center too — `translate(x y) rotate(a 0 0)`, never `rotate(a)`: the phone glides every element on its own about the center the transform names, and without one each part turns about its own middle and the parts drift apart mid-glide.
- Give elements `id`s. They are part of the match between frames, and they make a 400 readable.

## Building blocks that never break the structure

`rect`, `circle`, `ellipse`, `line` always become the same commands, whatever their numbers — a bar may shrink to width 0, a circle to radius 0. Prefer them. A `rect`, `circle` or `ellipse` glides exactly, and a flat-colored one is the lightest thing a moving face can hold. A `line` is a path: it glides exactly while it only moves or keeps its direction, but a line whose direction changes bends on the way — turn a needle with `rotate()` (below), never by moving its end. The same goes for a `path`, `polyline` or `polygon` whose points change: it glides, but a straight segment that changes direction bends a little on the way (the ends are exact; with the default `easeInOut` so is the halfway frame, the bend is in the quarters) — fine for a shape that breathes, wrong for data: a chart scrolls (below), a level is a `rect` or a dash. A `rect`'s `rx` may change freely, but keep it either zero/absent or non-zero in all frames. An arc (`A`) inside a path is always four curve segments at any sweep, so it may grow through 90°/180°/270° — still, for rings the dash technique below is more exact on big jumps.

## Sizes and text

| Button | viewBox | Drawn at | Holds | Minimum text |
|---|---|---|---|---|
| 1×1 | `0 0 200 200` | ≈ 0.40× | ONE value + one short label | 28 (value 56–64) |
| 2×1 | `0 0 400 200` | ≈ 0.40× | value + trend, or two values | 28 |
| 1×2 | `0 0 200 400` | ≈ 0.40× | a vertical gauge, value below | 28 |
| 2×2 | `0 0 200 200` | ≈ 0.88× | a rich widget: ring + bar + sparkline, a clock, a heatmap | 16 labels, 22 values |

Match the viewBox aspect to the button or the face is letterboxed. Text is one run per `<text>` in the system font with fixed-width digits (a changing number does not jitter); a line break inside it reads as a space. Center a value with `text-anchor="middle"` and `dominant-baseline="middle"`. Every `<text>` is drawn **above every shape**, whatever the order in the document — a shape cannot cover a label; hide the label with `opacity="0"` instead. The string swaps at once; position, size, color and opacity glide. Leave 6–8 units of air at the edges: the button has rounded corners.

## Recipes

**Ring (the default for a percentage).** A track circle and a progress circle with a dash pattern as long as the circumference `C = 2πr`:

```xml
<circle id="track" cx="100" cy="100" r="78" fill="none" stroke="#FFFFFF" stroke-opacity="0.15" stroke-width="16"/>
<circle id="ring"  cx="100" cy="100" r="78" fill="none" stroke="#34C759" stroke-width="16" stroke-linecap="round"
        stroke-dasharray="490.09 490.09" stroke-dashoffset="137.22" transform="rotate(-90 100 100)"/>
```
`stroke-dashoffset = C · (1 − fraction)`. The offset runs along the circle, so a jump from 10 % to 90 % sweeps the long way round, correctly. The progress is one dash, as light as a plain stroke.

**Gauge.** The same dash technique on an open arc path (`M 30 120 A 70 70 0 0 1 170 120`), dash length = the arc's length.

**Bar.** A track `rect` and a `rect` whose `width` (or `height` + `y` for a bar growing upwards) changes.

**Needle, clock hand.** A `line` drawn pointing up, `transform="rotate(angle cx cy)"`; only the angle changes, and the line turns rigidly.

**Color by level.** Change the color value between frames. The color glides channel by channel (red, green, blue, alpha) — green to red passes through a muddy olive, not through orange — so pick each frame's color from the level (green → orange → red) and let the glide run between neighbours.

**Sparkline / history — must scroll, not morph.** Re-sending a series shifted by one sample makes the phone move point *i* from its old height to its new one: the line wobbles like liquid. Instead keep N+1 points, the newest parked in a slot just outside the right edge of the viewBox (the viewBox clips it), all inside `<g id="scroll" transform="translate(0 0)">`. Per sample send TWO frames back to back:
1. `rest` — the re-indexed points, `translate(0 0)`, `duration: 0.01`. It looks identical to where the previous slide ended.
2. `slide` — the same points, `translate(-step 0)`, `easing: "linear"`, `duration` = the loop's *measured* period (sampling + generation + sleep) × 1.0–1.1, never shorter, with a period of 1 s or more.

Why not the 1.25 of other continuous motion (below): the next `rest` frame snaps whatever is left of the slide — 1 − period/duration of a step, 9 % at 1.1 but 20 % at 1.25 — and a bigger snap shows as a jerk. Shorter than the period leaves a pause and reads as a stutter. What covers a frame that Wi-Fi brings late is the slack, (factor − 1) × the period — 0.1 s at 1 s × 1.1 — so keep the period at 1 s or more.

**Ticker, spinner, anything that never stops.** `easing: "linear"` and a `duration` of 1.25 × the frame interval (1.2–1.35×), so each frame takes over a glide that is still running, at the same speed. Over Wi-Fi the phone gets frames in bursts, up to ~0.15 s late; at 1.0–1.1× a late frame finds the glide over, and the motion stops for a moment. The price is a steady lag of a quarter step behind the frames. Let an ever-growing number grow (a dash offset, an x position) rather than wrapping it — a wrap from 360 back to 0 glides backwards through the whole picture. When something must jump (a lane that loops), use the invisible jump in `scenes.md`. To fade out something that keeps moving — a spinner when its task ends, a cloud drifting off at dusk — hold its numbers still for a few frames after the one that sets `opacity="0"`, and only then move it on: a frame that moves a hidden element — shifts or turns it, changes its dash offset, or moves a `<g>` around it — cuts what is left of its fade at once (`scenes.md` §3). How many frames for your glide length: `get_available_actions` topic `svg` → `widgetFaces.svgReference.recipes` → "ticker / spinner (continuous motion)".

**Gradient.** Glides when kind, `gradientUnits` and the number of stops stay the same: geometry, its transform, every stop's offset, color and opacity interpolate. Two uses worth knowing:
- the area under a sparkline — a closed path filled with a vertical gradient from `stop-opacity="0.5"` to `0` (under a sparkline that scrolls all the time, a flat fill at `fill-opacity="0.2"` instead);
- a sheen — `gradientTransform="rotate(angle cx cy)"` with a changing angle.

For a **stroke** on anything that can be straight — a horizontal `line`, a level line, a series that went flat — write `gradientUnits="userSpaceOnUse"` with coordinates in the viewBox. The default (`objectBoundingBox`) has no box to map onto there; the engine then paints the last stop color and warns.

Where a gradient goes: on the shapes that carry the look. A gradient ring or sparkline that moves every few seconds is fine. On shapes that change all the time (a scene, a ticker) use flat colors, or a gradient-filled square-cornered `rect` (a horizontal line is a thin `rect` too): no gradient strokes there, no rounded or rotating gradient `rect`s, and no gradient on a `path`, `polygon`, `circle` or `ellipse` whose shape changes or that moves under a gradient that stays put. A gradient that only moves with its shape (`objectBoundingBox` units, the shape shifted or turned whole) is fine anywhere its shape is.

**Clip.** A `clip-path` glides too: a `<clipPath>` rect whose width changes reveals a bar or an image smoothly, and a clip on a moving group travels with it. Keep the clip's shapes the same between frames. On a face that moves all the time clip only with one upright rectangle that stands still; a clip that moves or resizes (the bar reveal), or has any other shape, belongs on faces that move now and then.

**Ticks and dots.** `stroke-dasharray` with a short dash and gap: `2 6` along an arc draws ticks, `stroke-linecap="round"` with a `0` dash draws dots. A pattern that is too fine or has too many dashes is drawn as a **solid** stroke: keep ticks to a few dozen per face and a dash plus its gap at 3 units or more. The exact limits: `get_available_actions` topic `svg` → `widgetFaces.svgReference.recipes.dashes`. `render_preview` shows a pattern that turned solid on its button; the limit for the whole page it cannot see.

## Orientation

In landscape the grid turns 90°: a 2×1 button becomes 1×2 and back; squares stay square. A fixed viewBox letterboxed into the transposed cell shrinks to half size. For every rectangular widget send the same data laid out for the other shape — `landscapeSource` in each live frame, `svgFaceLandscape` for a saved face ("value left, chart right" becomes "value on top, chart below"). The phone keeps both, draws the one whose aspect fits, cross-fades on rotation. No second layout → choose a square size.

## Color

`currentColor` is the button's own color (`color` in the config, or in the same live request). Draw the accent parts in `currentColor` and the widget follows whatever color the user picks in the editor; `{"color":"#FF453A","svg":{…}}` recolors all of them at once. The face sits on dark glass with a transparent background: white text at 0.6–1.0 opacity, tracks as white at 0.12–0.18, saturated system colors for data (`#34C759` `#FF9F0A` `#FF453A` `#0A84FF` `#BF5AF2`).

## Keeping the phone smooth

Every rule here has exact limits in `get_available_actions` topic `svg` → `widgetFaces.budget`: read it before a scene, a ticker or a page of moving widgets.

- **Count the cells that glide at the same moment.** With `duration` well under the frame interval a widget rests most of the time, and dozens per page are fine. Continuous motion (a ticker, a scroll, a spinner, a scene) keeps a cell gliding all the time — a handful per page, not a wall.
- **Glide lengths.** `duration` 0 for a jump, 0.3 s or more for a move the user should see: a shorter glide shows as a few steps on older devices and in Low Power Mode.
- **On a face that moves all the time:** text, flat-colored `rect`, `circle` and `ellipse` at any size, and square-cornered gradient `rect`s. Keep masks (`<mask>`), gradient strokes, gradients on shapes that change, rounded or rotating gradient `rect`s and clips that move or are not one upright rectangle off it (Gradient and Clip above).
- **Paths** — every `path`, `polygon`, `polyline` and `line`, any dashed stroke, and what counts as one: a stroked `ellipse` whose radii differ, a `rect` with `rx` ≠ `ry`, a square-cornered stroked `rect` with `stroke-linejoin` round or bevel (leave the join at its default miter, or give the rect `rx`). In a cell that glides, each one stays within one cell (everything it draws, also past the viewBox), a face holds only a few, and none changes its points, colors, stroke width, dashes or gradient during the glide — move or turn it whole by `transform` instead. Cut long shapes (a ridge, a seabed across a scene) to each cell and draw large areas as `rect`s. A dashed ring that should spin turns by `rotate()`, never by a growing `stroke-dashoffset`. A widget that rests between its frames may change its paths freely.
- **Pages off screen** cost the phone nothing: the agent keeps their newest frames and sends them, shown at once, when the page opens. The script on the Mac keeps running — an ordinary widget simply keeps drawing, an expensive loop rests (`live-widgets.md`).
- **Frame rates.** More than 2–3 frames per second to one cell is wasted unless the motion is continuous: the glide fills the frames in between, and the phone keeps only the newest two frames waiting per cell. 1 frame/s for clocks and timers; 2–5 s for system metrics; 30–300 s for weather, prices, builds.
