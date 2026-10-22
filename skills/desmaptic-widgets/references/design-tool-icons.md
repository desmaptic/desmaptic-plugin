# Icons and artwork from design tools

An icon exported from Figma, Sketch or Illustrator, a logo downloaded as SVG, a glyph from an icon set — any of them can be a button's **saved face**: pass the document as `svgFace` (plus `svgFaceFit`, and `svgFaceLandscape` for a non-square button). No script is involved; the picture is stored with the button and syncs with the profile. In the app the user can do the same by hand: button editor → Icon → SVG Drawing → Paste, or Import from File…

Such files usually work as they are: the engine reads what exports are made of — compound paths with `fill-rule="evenodd"`, linear and radial gradients (including the elliptical ones Figma writes as a unit circle under a `gradientTransform`), a `<defs>` block at the end of the file, the `clip-path` around the artboard, solid "use as mask" masks.

## Procedure

1. Get the document as text. Limit: 64 KB — export the icon's frame alone, without hidden elements; run it through an optimizer (SVGO) if it is large.
2. Deliver it with `add_buttons_to_client` / `update_buttons_by_uuid`. The tool parses it first: a broken document fails with the line and the reason; whatever the engine will not draw comes back as **warnings in the result's `notes`**. Read them and tell the user what is missing, in their words.
3. Still set `label`, an icon and a `color`: the label names the button; the color is what `currentColor` resolves to.

## What an export can contain that is not drawn

| In the file | What happens | What to do |
|---|---|---|
| `filter` — drop shadow, blur, glow | the shape appears without the effect | flatten the effect in the design tool, or draw the shadow as a second, darker, offset shape |
| image fill (`<pattern>` + `<image>`) | the shape is left unpainted | use a vector fill, or accept the gap |
| `<use>` instances of a `<symbol>` / a shape in `<defs>` | nothing is drawn for them | expand instances on export (Illustrator, Sketch do this more than Figma) |
| CSS: `<style>` block and `class=` | styles are ignored, shapes fall back to black | export with "presentation attributes" / inline styles |
| mask with a soft edge or partial opacity | clipped to the mask's outline, hard edge | fine for most icons; otherwise redraw |
| `<text>` | drawn in the system font, single run, above every shape whatever its place in the file | convert text to outlines on export |
| radial gradient focal point (`fx`/`fy`), `spreadMethod` reflect/repeat | centered / padded instead | usually invisible |

Check the authoritative list in `get_available_actions` before promising anything.

## Making an imported icon feel native

- A monochrome icon: replace its fill color with `currentColor` so it follows the button's color.
- The button is dark glass with rounded corners. An icon that brings its own opaque square background usually looks better with that background removed, or with `svgFaceFit: "cover"` so it fills the button.
- Want it to react — pulse on an event, show a badge, fill up? Keep the imported artwork as the saved face and send live frames of the **same document with changed numbers** on top. Same structure → it glides. An event that glides for a moment (a pulse, a badge, a fill) is fine over any artwork. Motion that never stops over a heavy export (many large shapes) is not: animate a few simple shapes over a still icon, not every shape of the icon, and before you do, make the artwork lighter — large areas as `rect`s, same-colored shapes merged, each path within one cell (`svg-craft.md` → Keeping the phone smooth).
