# Command-line interface

Build the `DMGStudio` scheme, then run its `dmgstudio` product:

```sh
dmgstudio create --app /Applications/Example.app
dmgstudio create --app /Applications/Example.app --background /tmp/background.jpg --volume-icon /tmp/icon.png --output /tmp/Example.dmg --app-x 0.25 --applications-x 0.75
```

`--app` is required. Optional arguments are `--background`, `--volume-icon`, `--volume-name`, `--output`, `--app-x`, and `--applications-x`. Positions are normalized values from `0` to `1`; the GUI uses a visual grid, while the CLI accepts the precise values you provide. Run `dmgstudio --help` for the current synopsis.

Without `--output`, the CLI writes `output.dmg` in the current working directory. An explicit `--output` path takes precedence. An existing DMG at that path is replaced only after the new image has been compressed and verified. The CLI reports validation and `hdiutil` failures to standard error. It uses the main screen’s visible size and the creator Mac’s current light/dark appearance when generating default artwork.
