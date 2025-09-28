# Default target
$Target = "x86_64-pc-windows-gnu"

Write-Host "Override target: $Target"
}

Write-Host "Using target: $Target"

docker build --build-arg TARGET=$Target -t renderer .
$containerId = docker create renderer

$binName = "renderer"
if ($Target -eq "x86_64-pc-windows-gnu") { $binName = "renderer.exe" }

docker cp "${containerId}:/usr/src/renderer/target/$Target/release/$binName" .
docker rm $containerId
