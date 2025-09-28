#!/bin/bash

# Optional arg
OVERRIDE_TARGET="$1"
# Default target
TARGET="x86_64-unknown-linux-gnu"

# Detect OS if no override
if [ -z "$OVERRIDE_TARGET" ]; then
    OS=$(uname -s)
    case "$OS" in
        Linux*)
            if grep -q Microsoft /proc/version 2>/dev/null; then
                echo "Running under WSL"
                TARGET="x86_64-unknown-linux-gnu"
            else
                echo "Running under Linux"
                TARGET="x86_64-unknown-linux-gnu"
            fi
            ;;
        Darwin*)
            echo "Running on macOS"
            TARGET="x86_64-apple-darwin"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "Running on Windows"
            TARGET="x86_64-pc-windows-gnu"
            ;;
        *)
            echo "Unknown OS: $OS"
            ;;
    esac
else
    case "$OVERRIDE_TARGET" in
        linux) TARGET="x86_64-unknown-linux-gnu" ;;
        windows) TARGET="x86_64-pc-windows-gnu" ;;
        macos) TARGET="x86_64-apple-darwin" ;;
        *) echo "Unknown override target: $OVERRIDE_TARGET"; exit 1 ;;
    esac
    echo "Override target: $TARGET"
fi

echo "Using target: $TARGET"

# Determine binary name based on OS
if [[ "$TARGET" == *windows* ]]; then
    BIN_NAME="renderer.exe"
else
    BIN_NAME="renderer"
fi

docker build --build-arg TARGET=$TARGET -t renderer .
container_id=$(docker create renderer)
docker cp $container_id:/usr/src/renderer/target/$TARGET/release/$BIN_NAME .
docker rm $container_id
