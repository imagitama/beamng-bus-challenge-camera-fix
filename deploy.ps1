$TARGET="$env:LOCALAPPDATA\BeamNG\BeamNG.drive\current\mods\unpacked\buschallengecamerafix"

echo "Copying to $TARGET"

Copy-Item -Path ".\mod\*" -Destination $TARGET -Recurse -Force