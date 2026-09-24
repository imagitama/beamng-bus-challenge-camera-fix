# BeamNG Bus Challenge Camera Fix mod

A simple BeamNG.drive mod that prevents the camera from switching to "onboard rider" when you stop at a bus stop.

- Tested in 0.39 (Sep 2026)
- Tested in VR

## Install

1. Download the ZIP and place it into `%LOCALAPPDATA%\BeamNG\BeamNG.drive\current\mods`

## Development

1. Run `deploy.ps1` to place it into your mods folder - the game will load it automatically
2. In-game either press Ctrl+L to reload all Lua scripts (will break bus challenge) or manually reload the mod from the console `~`:

   ```
   core_modmanager.deactivateMod("BusChallengeCameraFix")
   core_modmanager.activateMod("BusChallengeCameraFix")
   ```

## Distribution

1. Run `package.ps1` and upload the ZIP in `dist`
