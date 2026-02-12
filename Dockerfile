FROM debian:13-slim

ARG MAKEFS_REF=tags/r13          # or can use heads/master
ARG FUSE_ARCHIVE_REF=tags/v1.16  # or can use heads/main

RUN apt-get update && \
    apt-get install -y wget jq libfuse3-4 libarchive13t64 gcc g++ make pkg-config pandoc libc6-dev libboost-container-dev libfuse3-dev libarchive-dev && \
    wget -O - https://github.com/kusumi/makefs/archive/refs/${MAKEFS_REF}.tar.gz | tar -xz -C / && \
    cd /makefs-${MAKEFS_REF##*/} && \
    make USE_HAMMER2=0 USE_EXFAT=0 && \
    make install && \
    wget -O - https://github.com/google/fuse-archive/archive/refs/${FUSE_ARCHIVE_REF}.tar.gz | tar -xz -C / && \
    FUSE_DIR=${FUSE_ARCHIVE_REF##*/} && \
    cd /fuse-archive-${FUSE_DIR#v} && \
    make && \
    make install && \
    cd / && \
    apt-get autoremove --purge -y wget gcc g++ make pkg-config pandoc libc6-dev libboost-container-dev libfuse3-dev libarchive-dev && \
    apt-get clean && \
    rm -rf /makefs-${MAKEFS_REF##*/} /fuse-archive-${FUSE_DIR#v} /var/lib/apt/lists/*
    
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]