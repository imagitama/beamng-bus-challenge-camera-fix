$version = "$(Get-Content -Path ./VERSION.txt -TotalCount 1)".Trim()

$dirPath = "./dist"
$zipPath = "$dirPath/BusChallengeCameraFix-$VERSION.zip"

Write-Host "Packaging..."

mkdir $dirPath

Compress-Archive -Path ./mod -DestinationPath $zipPath -Force

Write-Host "Packaged to $zipPath"