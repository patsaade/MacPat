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
- The app has no animation. The README banner's pat stops under Reduce Motion.

## Known gaps

- I have not yet done a full VoiceOver pass on a release build.
- The custom controls have not been tested with Full Keyboard Access.
- Long plans are one scroll view. Rotor navigation by group isn't there yet.

## Report a barrier

Open an issue with the label `accessibility`. Say what you use and what failed. These get fixed before features.
