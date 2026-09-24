$version = "$(Get-Content -Path ./VERSION.txt -TotalCount 1)".Trim()

$dirPath = "./dist"
$zipPath = "$dirPath/BusChallengeCameraFix-$VERSION.zip"

Write-Host "Packaging..."

Remove-Item -Path $dirPath -Recurse -Force

mkdir $dirPath


Compress-Archive -Path ./mod -DestinationPath $zipPath -Update

$files = @("README.md", "LICENSE", "VERSION.txt")
Compress-Archive -Path $files -DestinationPath $zipPath -Update

Write-Host "Packaged to $zipPath"