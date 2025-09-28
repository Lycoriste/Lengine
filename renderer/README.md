# Build Instructions for dummies
Make sure to have Docker installed and running.

## Windows
```powershell
.\build.ps1
```
Always build an executable for Windows only.

## Linux/MacOS/Windows
```bash
./build.sh [target]
```

Optional [target] parameter (overrides automatic OS detection):
- windows
- linux
- macos
