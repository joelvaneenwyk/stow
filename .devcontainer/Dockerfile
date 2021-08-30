# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.191.1/containers/debian/.devcontainer/base.Dockerfile

# [Choice] Debian version: bullseye, buster, stretch
ARG VARIANT="buster"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive

RUN apt-get -y install --no-install-recommends \
    wget curl unzip xclip \
    software-properties-common build-essential gcc g++ make automake autoconf \
    bzip2 \
    cpanminus \
    gawk \
    git \
    libssl-dev \
    make \
    patch \
    perlbrew \
    texinfo \
    texlive \
    texi2html
