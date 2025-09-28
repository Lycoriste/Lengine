# Build stage
FROM rust:1.90.0 AS builder

WORKDIR /usr/src/renderer

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pkg-config libssl-dev libx11-dev libxcursor-dev libxi-dev libglvnd-dev libwayland-dev libvulkan-dev mesa-common-dev \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock ./
COPY src src/
COPY res /usr/local/bin/res
RUN cargo build --release 
