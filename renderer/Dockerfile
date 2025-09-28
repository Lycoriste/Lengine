# Build stage
FROM rust:1.90.0 AS builder

ARG TARGET=x86_64-pc-windows-gnu
ENV TARGET=$TARGET

WORKDIR /usr/src/renderer
COPY Cargo.toml Cargo.lock ./
COPY src src/
COPY res /usr/local/bin/res

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pkg-config libssl-dev libx11-dev libxcursor-dev libxi-dev libglvnd-dev libwayland-dev libvulkan-dev mesa-common-dev \
        $(if [ "$TARGET" = "x86_64-pc-windows-gnu" ]; then echo "mingw-w64"; fi ) \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "$TARGET" = "x86_64-pc-windows-gnu" ]; then \
        rustup target add $TARGET; \
    fi \
    && cargo build --release --target $TARGET
