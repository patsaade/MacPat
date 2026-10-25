# Add a module

1. Add a target in `Package.swift`. Depend on `MacPatCore` and `DesignSystem`.
2. Keep the engine free of UI. Put views in the same target, next to it.
3. Conform to `MacPatModule` and return your view from `makeView()`.
4. Add the module to the `modules` list in `App/MacPatApp.swift`. The sidebar picks it up.
5. Add the product to `project.yml` and run `xcodegen generate`.
6. If it deletes anything, send it through `Cleaner`. Do not call the file manager yourself.
