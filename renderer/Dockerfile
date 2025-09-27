# build stage
FROM rust:latest AS builder

WORKDIR /usr/src/renderer

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pkg-config libssl-dev libx11-dev libxcursor-dev libxi-dev libglvnd-dev libwayland-dev libvulkan-dev mesa-common-dev \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock ./

COPY src src/

RUN cargo build --release 

# runtime
FROM archlinux:base AS runtime

RUN pacman-key --init \
    && pacman -Syu --noconfirm mesa vulkan-icd-loader libx11 wayland libglvnd \
    && pacman -Scc --noconfirm

WORKDIR /usr/local/bin

COPY --from=builder /usr/src/renderer/target/release/renderer .

COPY res /usr/local/res

CMD ["./renderer"]
