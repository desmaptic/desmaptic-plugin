#!/bin/zsh
# A scene across a page of 1x1 Desmaptic buttons (8 x 4 with the phone in landscape). Paste the WHOLE file into the
# `startupScript` of ONE button of the page, after replacing CELLS with the page's real buttons.
# The four ideas it implements are explained in references/scenes.md: windows onto one world, a constant structure
# per window, the invisible jump, one loop on one connection.
#   zsh scene_template.zsh --dump out.json [step]   → the 32 frames of one moment (render and tile them to LOOK)
#   zsh scene_template.zsh --faces out.json         → light saved faces for the 32 buttons (`svgFace`)
#
# The scene itself is python — comfortable for 32 frames of gradients — and python3 is NOT on every Mac: it comes
# with the Command Line Tools (or Xcode). Without them /usr/bin/python3 is a stub that opens an install dialog each
# time it runs, and the agent restarts a failed script every minute. So these zsh lines look first — with
# xcode-select, never `command -v`, which finds the stub — and without the tools exit with the reason (the phone's
# list of errors shows it); with them they hand the rest of the file to that python3 and never touch the stub.
dev=$(xcode-select -p 2>/dev/null) && [[ -x $dev/usr/bin/python3 ]] || {
  print -u2 "This scene needs the Command Line Tools (python3): run xcode-select --install on this Mac"
  exit 1
}
exec "$dev/usr/bin/python3" -I - "$@" <<'PY'
import http.client, json, math, os, random, signal, sys, time

# (cellId, world column = the button's portrait row 0..7, world row = its portrait col 0..3; world row 0 is the BOTTOM)
CELLS = [("00000000-0000-0000-0000-%012d" % (cx * 4 + cy), cx, cy) for cx in range(8) for cy in range(4)]
PERIOD = 2.0                                # seconds between frames (a scene glides all the time: a showpiece)
GLIDE = 1.2                                 # every glide lasts 1.2 periods (1.2–1.35): over Wi-Fi frames come in bursts, up to ~0.15 s
                                            # late, and a glide still running is taken over at the same speed, while one that already
                                            # ended would stop the motion for a moment. The price: everything trails its frames by a fifth of a step.
GAP = 12.5                                  # the gap between two buttons in world units, a window being 100: main() takes it from
                                            # GET /api/view (100 x cellGap / cellSize); 12.5 is the phone's 10 pt gap on 80 pt cells
STORE = os.path.join(os.environ.get("DESMAPTIC_STORAGE") or os.path.expanduser("~/Library/Application Support/Desmaptic/ScriptStorage"), "scene")   # never /tmp


def n(v): return ("%.1f" % v).rstrip("0").rstrip(".")
def window(cx, cy):
    """The 100 x 100 part of the world button (cx, cy) shows. The windows lie as far apart as the buttons on screen, gap
    included: a mover crossing a gap is hidden behind it, as behind a window frame, and its halves line up. Windows laid
    edge to edge (cx * 100) would draw it on both sides of the gap at once, its halves a gap apart."""
    x, y = cx * (100 + GAP), (3 - cy) * (100 + GAP)
    return (x, y, x + 100, y + 100)
def touches(box, cell, pad=6): return not (box[2] < cell[0] - pad or box[0] > cell[2] + pad or box[3] < cell[1] - pad or box[1] > cell[3] + pad)


def cycle(index, count, step, steps):
    """A lane position that loops without ever being SEEN jumping. The visible run is 0, 1/steps, …, 1, and both of
    its ends lie where the mover cannot be seen (off-world). The jump home takes three frames:
      1. hidden in place — opacity 0 at 1, nothing else changes. A fade is not over when the next frame comes, so a
         move in this frame would be glided while the mover still shows: a ghost sliding back across the picture;
      2. moved home while hidden — 0, still opacity 0: the phone cuts what is left of the fade and moves it unseen;
      3. shown in place — 0 at opacity 1, the first slot of the run, and it carries on.
    All lanes share the span of steps + 3 slots, so their spacing never drifts. Returns (position, opacity)."""
    # Whole slots divided, not a float step added up: that lands on 0.9999… instead of 1.0 now and then, and the
    # mover would hide short of the edge, in sight.
    slots = steps + 3
    slot = (round(index * slots / count) + step) % slots
    if slot <= steps: return slot / steps, 1.0
    return (1.0, 0.0) if slot == steps + 1 else (0.0, 0.0)


rnd = random.Random(3)
STARS = {(cx, cy): [(rnd.uniform(8, 92), rnd.uniform(8, 92), rnd.uniform(0.8, 1.6), rnd.uniform(0, 6.28))   # x, y within the window
                    for _ in range(3 if cy >= 1 else 0)] for cx in range(8) for cy in range(4)}
CLOUDS = [(70, 170, 0), (150, 120, 1), (40, 95, 2)]     # y, width, lane index
CLOUD_STEPS = 25                                        # frames for a cloud to cross the sky
N_LINES, LINE_STEPS = 8, 5                              # ground lines coming at the viewer: one in each of the 8 slots, evenly spaced


def frame(cx, cy, step, still=False):
    """One window. WHAT it contains is decided statically — by where an element can ever be, not where it is now —
    so every frame of this cell has the same structure and glides. All coordinates are WORLD coordinates; the
    viewBox does the cutting, and userSpaceOnUse gradients run across button borders without a seam. This template
    draws only rects, circles and ellipses; a path, polygon, polyline or line you add is cut to each window and keeps
    its shape (references/scenes.md)."""
    cell = window(cx, cy)
    W, H, HORIZON = window(7, 0)[2], window(0, 0)[3], window(0, 0)[1]       # the world's size; the horizon tops the ground row
    defs, e = [], []
    defs.append(f'<linearGradient id="sky" x1="0" y1="0" x2="0" y2="{n(HORIZON)}" gradientUnits="userSpaceOnUse">'
                '<stop stop-color="#0B1033"/><stop offset="0.6" stop-color="#3A2A6B"/><stop offset="1" stop-color="#FF8A5C"/></linearGradient>')
    e.append(f'<rect id="sky" x="-20" y="-20" width="{n(W + 40)}" height="{n(HORIZON + 40)}" fill="url(#sky)"/>')
    for i, (sx, sy, r, phase) in enumerate([] if still else STARS[(cx, cy)]):
        e.append(f'<circle id="star{i}" cx="{n(cell[0] + sx)}" cy="{n(cell[1] + sy)}" r="{n(r)}" fill="#FFFFFF" fill-opacity="{n(0.5 + 0.5 * math.sin(step * 1.3 + phase))}"/>')

    sun = (W / 2, HORIZON - 40 - 30 * math.sin(step * 0.15))                  # a sun that breathes above the horizon
    if touches((sun[0] - 170, HORIZON - 70 - 170, sun[0] + 170, HORIZON + 40), cell):   # everywhere its halo can ever reach
        defs.append(f'<radialGradient id="halo" cx="{n(sun[0])}" cy="{n(sun[1])}" r="170" gradientUnits="userSpaceOnUse">'
                    '<stop stop-color="#FFD27A" stop-opacity="0.7"/><stop offset="1" stop-color="#FFD27A" stop-opacity="0"/></radialGradient>')
        # The halo moves with the sun under a world-space gradient. A few such movers per scene are fine; draw the rest
        # flat or as square-cornered gradient-filled rects (the sky, the ground and the lines below).
        e.append(f'<circle id="halo" cx="{n(sun[0])}" cy="{n(sun[1])}" r="170" fill="url(#halo)"/>')
        e.append(f'<circle id="sun" cx="{n(sun[0])}" cy="{n(sun[1])}" r="34" fill="#FFE9A8"/>')

    if cy >= 2 and not still:                                                 # clouds cross the two upper rows
        for y, width, lane in CLOUDS:
            v, alpha = cycle(lane, len(CLOUDS), step, CLOUD_STEPS)
            x = -width + (W + width) * v                                      # v = 0 and v = 1 are both off-world: it enters, leaves and jumps unseen
            defs.append(f'<linearGradient id="cloud{lane}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#FFFFFF" stop-opacity="0.9"/>'
                        '<stop offset="1" stop-color="#FFB38A" stop-opacity="0.45"/></linearGradient>')
            e.append(f'<ellipse id="cloud{lane}" cx="{n(x + width / 2)}" cy="{n(y)}" rx="{n(width / 2)}" ry="{n(width * 0.16)}" fill="url(#cloud{lane})" opacity="{n(alpha)}"/>')

    if cy == 0:                                                               # the ground row
        defs.append(f'<linearGradient id="ground" x1="0" y1="{n(HORIZON)}" x2="0" y2="{n(H)}" gradientUnits="userSpaceOnUse">'
                    '<stop stop-color="#2A1A4A"/><stop offset="1" stop-color="#05030F"/></linearGradient>')
        e.append(f'<rect id="ground" x="-20" y="{n(HORIZON)}" width="{n(W + 40)}" height="{n(H - HORIZON + 20)}" fill="url(#ground)"/>')
        # The lines never stop moving, so each is a thin square-cornered <rect> FILLED with the gradient, never a <line>
        # with a gradient STROKE (references/svg-craft.md → Keeping the phone smooth).
        # User space, so one gradient runs across all eight windows of the row.
        defs.append(f'<linearGradient id="line" x1="0" y1="0" x2="{n(W)}" y2="0" gradientUnits="userSpaceOnUse">'
                    '<stop stop-color="#FF5CA8"/><stop offset="0.5" stop-color="#5CE1FF"/><stop offset="1" stop-color="#FF5CA8"/></linearGradient>')
        for i in range(N_LINES):
            z, alpha = cycle(i, N_LINES, 0 if still else step, LINE_STEPS)
            y = HORIZON + (H - HORIZON + 15) * z ** 2.0                       # perspective: lines spread towards the viewer; z = 1 is below the world's edge
            width = 0.6 + 2.2 * z
            e.append(f'<rect id="line{i}" x="-20" y="{n(y - width / 2)}" width="{n(W + 40)}" height="{n(width)}" fill="url(#line)" opacity="{n(alpha * min(1.0, z * 3))}"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{n(cell[0])} {n(cell[1])} 100 100"><defs>{"".join(defs)}</defs>{"".join(e)}</svg>'


class Sender:
    """One keep-alive connection for all cells. A tick's 32 frames are built first and then posted back to back, in well
    under 100 ms, so the windows change together; whether they always reach the phone within one of its ticks is not
    verified (references/scenes.md §4)."""
    def __init__(self):
        self.connection = None
        self.headers = {"Authorization": "Bearer " + os.environ.get("DESMAPTIC_TOKEN", ""), "Content-Type": "application/json"}

    def call(self, method, path, data=None):
        """→ (status, body text); (0, "") when the agent cannot be reached."""
        for _ in (0, 1):                                                      # one reconnect
            try:
                if self.connection is None: self.connection = http.client.HTTPConnection("127.0.0.1", 9848, timeout=5)
                self.connection.request(method, path, body=data, headers=self.headers)
                response = self.connection.getresponse()
                return response.status, response.read().decode()
            except Exception:
                try: self.connection.close()
                except Exception: pass
                self.connection = None
        return 0, ""

    def post(self, payload):
        """True when the agent says "dropped": the phone or the link to it does not keep up — the loop slows down."""
        status, text = self.call("POST", "/api/update-button", json.dumps(payload))
        if status == 400: sys.stderr.write(text[:300] + "\n")
        try:
            return status == 200 and json.loads(text).get("dropped") is True
        except Exception:
            return False

    def view(self, cells):
        """→ (shown, gap) from one cheap request per tick instead of 32 frames nobody sees. shown is False only when the
        phone SAYS none of these buttons is shown (another page, the app in the background); unknown — no phone, an
        older app — counts as shown. gap is 100 x cellGap / cellSize of the deck window holding these buttons (an iPad
        may show several side by side, `windows`), None when the phone does not say."""
        try:
            view = json.loads(self.call("GET", "/api/view")[1]).get("view") or {}
        except Exception:
            return True, None
        mine = {c.upper() for c in cells}
        holds = lambda grid: not mine.isdisjoint(i.upper() for i in grid.get("visibleCellIds") or [])
        grid = next((w for w in view.get("windows") or [] if holds(w)), view)
        size, gap = grid.get("cellSize"), grid.get("cellGap")
        shown = view.get("visibleCellIds") is None or holds(view) or grid is not view
        return shown, (100 * gap / size if size and gap is not None else None)


def main():
    global GAP
    sender = Sender()
    def stop(*_):
        for cell, _, _ in CELLS: sender.post({"cellId": cell, "svg": {"remove": True}})   # back to the saved faces
        sys.exit(0)
    signal.signal(signal.SIGTERM, stop)
    os.makedirs(STORE, exist_ok=True)
    taps = os.path.join(STORE, "taps"); seen = os.path.getsize(taps) if os.path.exists(taps) else 0
    step, paused, pace = 0, False, PERIOD
    while True:
        tick = time.time()
        shown, gap = sender.view([cell for cell, _, _ in CELLS])
        if not shown:                                                         # the page is not on the phone's screen:
            time.sleep(1.0); continue                                         # the world stands still, the Mac rests
        if gap is not None: GAP = gap                                         # the buttons' spacing, for window()
        size = os.path.getsize(taps) if os.path.exists(taps) else 0
        if size != seen: seen, paused = size, not paused                      # every button of the page appends to this file on tap
        behind = False
        if not paused:
            # Every window on one clock: a frame at every tick, all with the same duration and easing. Each cell takes over
            # its own glide, so a window with another glide length, or a tick late, draws its half of a cloud apart at the seam.
            frames = [{"cellId": cell, "svg": {"source": frame(cx, cy, step), "duration": round(pace * GLIDE, 3), "easing": "linear", "fit": "stretch"}}
                      for cell, cx, cy in CELLS]
            answers = [sender.post(payload) for payload in frames]           # every frame, back to back
            behind = any(answers)
            step += 1
        time.sleep(max(0.05, pace - (time.time() - tick)))
        # "dropped": the phone cannot keep up — it keeps only each button's last frame until it reads again: send less,
        # resend nothing. The glides stretch with the pace, so the motion slows instead of stopping between frames. With a
        # current phone app it comes with the page in front (in the background the view lists no cell, and the loop rests
        # above), so the scene costs too much: keep this back-off, and make the scene cheaper (scenes.md §4).
        pace = max(2.0, PERIOD * 2) if behind else PERIOD


if __name__ == "__main__":
    if len(sys.argv) > 1 and not (len(sys.argv) >= 3 and sys.argv[1] in ("--dump", "--faces")):
        sys.exit("usage: scene_template.zsh [--dump out.json [step] | --faces out.json]")   # a typo must not start the endless loop
    if len(sys.argv) >= 3 and sys.argv[1] in ("--dump", "--faces"):
        step = int(sys.argv[3]) if len(sys.argv) > 3 else 5
        json.dump([{"cellId": cell, "cx": cx, "cy": cy, "svg": frame(cx, cy, step, still=sys.argv[1] == "--faces")} for cell, cx, cy in CELLS], open(sys.argv[2], "w"))
    else:
        main()
PY
