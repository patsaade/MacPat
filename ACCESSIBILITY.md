# Accessibility

The goal is every control usable with VoiceOver, the keyboard alone, and your system display settings. I aim for WCAG 2.2 AA and Apple's guidelines.

## What is in place

- Standard SwiftUI controls underneath, so VoiceOver, Full Keyboard Access, and Dynamic Type work by default.
- Verdicts are a word and a glyph, never color alone. Review is inverted, and locked is dashed.
- Banners say their kind out loud ("Dry run", "Warning", "Admin") and are announced to VoiceOver when they appear.
- Group checkboxes report "All on", "Some on", or "Off". Expand arrows say what they show.
- Meters in Status and Analyze read as a label and a value.
- Symbols that only decorate are hidden from VoiceOver.
- Light and dark follow the system. Text is pure black on white or white on black.
- Increase Contrast removes the dotted desktop and turns every dither solid.
- Disabled controls get a dashed outline, not only dimming. Selected tabs and segments are inverted and marked selected.
- Custom buttons and checkboxes are real controls, with a dashed focus ring for keyboard users.
- Motion is short and never blocks a click. Reduce Motion makes every change instant, turns slides into fades, and keeps the hand and the chosen-row outline still. The README banner's pat stops too.
- The Clean grid works from the keyboard: arrows move the row, Space toggles it, Return opens the detail pane, Escape closes it. Column headers say their sort direction.
- The drawn scrollbar sits on the real scroll view, so trackpad, paging keys, and VoiceOver scrolling work as usual.
- Click targets are at least 24 pt, even where the drawing is smaller.
- Command-1 to 6 switch modules. Command-comma opens Settings. The Plan menu has Scan, Preview, Show Commands, and Close Detail.
- Each grid row reads as one line: name, size, verdict, and whether it needs admin. Sort buttons say their direction. Segments say which one is chosen.
- A folder macOS won't let MacPat read is a locked "Needs access" row, not an empty list.

## Known gaps

- I have not yet done a full VoiceOver pass on a release build.
- The custom controls have not been tested with Full Keyboard Access.
- Long plans are one scroll view. Rotor navigation by group isn't there yet.
- The grid's row and column labels have not been checked with VoiceOver on a release build.

## Report a barrier

Report it privately through the Security tab (see [SECURITY.md](SECURITY.md)). Say what you use and what failed. These get fixed before features.
