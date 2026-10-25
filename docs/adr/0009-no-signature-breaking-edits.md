# No edits inside app bundles

MacPat won't strip language files, slim universal binaries, or remove launch plists inside an app bundle. Each one changes a signed bundle, which breaks its code signature. macOS may then refuse to open the app, and the next update restores the files anyway. Items inside apps are shown, with where to turn them off. Rejected: editing a copy and verifying the signature after, which means more code and more risk for little space. Cost: some space and some launch jobs stay out of reach.
