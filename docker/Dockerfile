# =============================================================================
#  docker/Dockerfile — Arch build image for local Aegis OS ISO builds
# =============================================================================
#  Used by scripts/build-docker.sh. Pre-installs the archiso toolchain so the
#  in-container run of scripts/build-iso.sh starts fast. The actual build must
#  run with `docker run --privileged` (mkarchiso needs loop devices + mount).
# -----------------------------------------------------------------------------
FROM archlinux:latest

# Refresh keyring + base toolchain. build-iso.sh re-checks/installs as needed.
RUN pacman -Syu --noconfirm --needed \
        archlinux-keyring \
        archiso \
        base-devel \
        git \
        squashfs-tools \
        libisoburn \
        dosfstools \
        erofs-utils \
        grub \
        mtools \
        sudo \
        curl \
    && pacman -Scc --noconfirm

# Non-root build user for makepkg (build-iso.sh also ensures this exists).
RUN useradd -m -s /bin/bash builder \
    && echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/aegis-builder \
    && chmod 0440 /etc/sudoers.d/aegis-builder

WORKDIR /aegis
CMD ["bash", "scripts/build-iso.sh"]
