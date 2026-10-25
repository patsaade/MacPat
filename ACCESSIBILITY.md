# Accessibility

The goal is every control usable with VoiceOver, the keyboard alone, and your system display settings. I aim for WCAG 2.2 AA and Apple's guidelines.

## What is in place

- Standard SwiftUI controls, so VoiceOver, Full Keyboard Access, and Dynamic Type work by default.
- Rows read as one item: name, size, count, and risk.
- Color is never the only signal. Risk is written out.
- Symbols that only decorate are hidden from VoiceOver.
- Light and dark follow the system. Text is pure black on white or white on black, the highest contrast possible.
- Increase Contrast removes the dotted desktop.
- Disabled controls get a dashed outline, not only dimming. Selected tabs are inverted and marked selected for VoiceOver.
- Custom buttons and checkboxes are real controls underneath, with a dashed focus ring for keyboard users.
- No animation, so Reduce Motion has nothing to turn off.

## Known gaps

- I have not yet done a full VoiceOver pass on a release build.
- The menu bar item has only been checked by eye.
- The custom controls and focus ring have not been tested with Full Keyboard Access yet.

## Report a barrier

Open an issue with the label `accessibility`. Say what you use and what failed. These get fixed before features.
