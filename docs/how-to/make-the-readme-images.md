# Make the README images

```sh
./scripts/snapshots.sh
```

It builds a Debug copy, launches it with `-MacPatDemo docs/media`, and quits. Each module renders with made-up data under `/Users/pat`, in light and dark, through its real view. The app draws its own off-screen window, so no screen recording permission is needed.

Look at every image before you commit. They are the only raster files the repo allows, and only in `docs/media`, at 2 MB or less each.

The banner and icon are SVG and drawn by hand. Edit `docs/media/icon.svg` and the layers in `App/AppIcon.icon/Assets` together.
