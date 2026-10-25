# Raster images only as generated README media

The art stays vector: the icon is an Icon Composer bundle of SVG layers, and the banner is SVG. README screenshots and GIFs have to be raster. They are rendered by the app itself in a Debug-only demo mode, from the real views with made-up data, and land in `docs/media`. CI allows raster files only there, at 2 MB or less each. Rejected: hand-drawn SVG mock screens, which drift from the real UI and misrepresent it; manual screen recordings, which aren't reproducible and can leak real paths. Cost: the images need regenerating when the UI changes.
