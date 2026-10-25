# Style guide

One look: black on white, shades made of dots, hard edges, hard shadows. The values live in `Sources/DesignSystem`. If it isn't here, it isn't in the app. The canvas boards F, G, H, and J show every piece.

## Rules

1. Two colors. `Retro.ink` and `Retro.paper`. Dark mode swaps them.
2. Grey is dots, never a grey fill. `Dither` is the one shade.
3. Every edge is hard. No blur, no gradient, no soft shadow.
4. State is never color. Use a word, a glyph, a fill, or a dash.
5. The number is always in the text. Bars and meters add to it.
6. Motion is short and it stops under Reduce Motion.

## Color and shade

| Name | Use |
| --- | --- |
| `Retro.ink` | Text, lines, fills. White in dark mode. |
| `Retro.paper` | Backgrounds. Black in dark mode. |
| `Dither` | A 50% checkerboard, one point per cell. Case, bars, the dry-run banner. Solid ink when Increase Contrast is on. |
| `RetroDesktop` | The dotted desktop, 6 pt apart. Plain paper when Increase Contrast is on. |

## Type

The system monospaced font, through text styles. `Retro.font` is body. Rows use callout for reasons and facts, caption for tags. No fixed point sizes, so the layout grows with the user's text size. The README banner draws its letters as paths.

## Edges and depth

- Line 2 pt (`Retro.line`). Rules 1 pt. Window line 2 pt.
- Window shadow 6 pt, button shadow 3 pt. One hard shadow per raised thing.
- Radius 6 on buttons. Zero everywhere else.
- Dashed means off, optional, or locked. Never only dimmed.

## Space

4, 8, 12, 16, 24, 32. Windows sit 28 from the edge. Grid rows are at least 40 tall. Anything you click is at least 24 pt, even when it draws smaller.

## Parts

| Part | Notes |
| --- | --- |
| `RetroButtonStyle` | Rest, hover, pressed, off (dashed), focus (dashed ring). Pressed drops into its shadow. |
| `RetroToggleStyle` | A 16 pt box with an X, in a 24 pt target. |
| `RetroTabStyle` | Inverted when chosen. |
| `RetroSegments` | A row of tabs in a box. |
| `RetroBanner` | Info, warning, admin, dry run. Each has a word and a glyph. Dry run sits on dither. |
| `RiskBadge` | SAFE, REVIEW (inverted), LOCKED (dashed). |
| `Bar` | Dither fill with a solid edge. |
| `RetroScroll` | The drawn scrollbar. See below. |
| `PlanGrid` | The Grid. See below. |
| `PatMascot` | The hand and the Mac. Pats while scanning, once when done, still when empty. |

## Toolbar and first run

`RetroToolbar` is the strip at the top of a screen: controls on one line, 12 across and 8 down, a rule under it. Every screen uses it, so the spacing never drifts. The first time you open a module, a note says what Scan looks at and that nothing changes until Run. **Got It** hides it for good.

## The scrollbar

A dither track, boxed arrows, a square thumb with grip lines. Hover adds an inner edge. Dragging inverts the thumb. Click the track to page. It is drawn over the real scroll view, which keeps its own bar hidden. Trackpad inertia, rubber-banding, paging keys, and VoiceOver scrolling all still work. It reads and sets the scroll position and nothing else. When nothing scrolls it fades and ignores clicks.

## The grid

- Columns: check, name, path, size, bar, modified, verdict. Check, name, size, and verdict never hide. A narrow window drops path, then modified, then bar. Below 900 pt wide the detail pane moves under the grid.
- Groups are ruled rows that fold. Headers sort inside each group. Size descending is the default, and each scan resets it.
- Under the name, one line of reason. Everything else is in the detail pane. Click a name to open it. The checkbox only toggles.
- Keys: arrows move the row, Space toggles it, Return opens the pane, Escape closes it.
- Show commands expands the command under every row.
- Plan menu: Scan (Command-R), Preview (Shift-Command-P), Show Commands (Shift-Command-K), Close Detail.
- While a scan runs, rows appear as targets finish, with a count and Cancel. While a run goes, the footer shows "Running 4 of 12" and Stop.

Clean, Startup Items, Uninstall, Optimize, and Analyze's Large and old tab use the grid. Sort and open groups are remembered between launches.

## Motion

All of it lives in `Motion`. Reduce Motion is read there, once.

| Token | Time | Use |
| --- | --- | --- |
| `quick` | 120 ms | Hover and press feedback. |
| `settle` | 220 ms | Collapse, banners, tab content fades. |
| `spring` | 350 ms, no bounce | Tabs, expand, the detail pane. |
| `release` | 350 ms, small bounce | A release after a press or drag. |
| `pat` | 1100 ms loop | The scan hand. Done is one pass. |

Nothing bounces unless the user threw something. Nothing blocks a click. Under Reduce Motion, changes are instant and slides become fades. The hand stays still. The marching outline on the chosen row stops.

## Accessibility

- Increase Contrast turns dither into solid ink and removes the desktop dots.
- Reduce Motion is covered above. Reduce Transparency has nothing to do, because nothing is translucent.
- Every state has a word or glyph. VoiceOver reads the badge, the sort direction, and the group state.
- The menu bar has real commands. Command-1 to 6 switch modules. Command-comma opens Settings.

## Do and don't

Do put the word on every state. Do show the exact command a step stands for. Do keep dashed for off.

Don't use grey fills, gradients, blur, or soft shadows. Don't use color to carry meaning. Don't add raster art to the app. Don't put a face on the computer or a brand mark anywhere.
