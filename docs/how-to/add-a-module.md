# Add a module

1. Add a target in `Package.swift`. Depend on `MacPatCore` and `DesignSystem`.
2. Keep the scanning code free of UI. Put views in the same target, next to it.
3. Turn what you find into `Step`s with a group, a verdict, a reason, and facts.
4. Show them with `PlanView` and a `PlanModel`. Run them with an `Executor`. Don't call the file manager or start processes yourself.
5. Need a new command? Add a factory to `Command` in `Sources/MacPatCore/Exec.swift`, with an argument check and a test, and list it in [commands](../reference/commands.md).
6. Conform to `MacPatModule`, add it to `modules` in `App/MacPatApp.swift`, and add the product to `project.yml`.
7. Add a `Demo` enum with fixture data so the README images cover it.
