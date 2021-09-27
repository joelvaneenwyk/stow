# This file is part of GNU Stow.
#
# GNU Stow is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNU Stow is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/.

# Build docker image: `docker build -t stowtest`
# Run tests: (from stow src directory)
#    `docker run --rm -it -v $(pwd):$(pwd) -w $(pwd) stowtest`
ARG DEBIAN_VERSION=stretch
FROM debian:${DEBIAN_VERSION}

RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    autoconf bzip2 gawk git libssl-dev make patch wget curl ca-certificates \
    build-essential libssl-dev \
    perl cpanminus \
    texinfo texlive texi2html

# Set up perlbrew environment
ENV HOME=/root
ENV PERLBREW_HOME=${HOME}/.perlbrew
ENV PERLBREW_ROOT_DEFAULT=${HOME}/perl5/perlbrew
ENV PERLBREW_ROOT=/usr/local/perlbrew
ENV PERLBREW_PATH=${PERLBREW_ROOT}/bin
ENV PATH="${PERLBREW_ROOT_DEFAULT}:${PERLBREW_PATH}:${PATH}"

RUN mkdir -p "$HOME" "$PERLBREW_ROOT_DEFAULT" "$PERLBREW_ROOT"

RUN curl -k -L https://install.perlbrew.pl | bash
RUN echo 'source "$PERLBREW_ROOT/etc/bashrc"' >>".bash_profile"

RUN perlbrew init
RUN perlbrew install-cpanm
RUN perlbrew install-patchperl

# Archive of old versions which we install first so that we have to rebuild
# these infrequently
RUN perlbrew install-multiple -j 4 --notest \
    perl-5.20.3 \
    perl-5.18.4 \
    perl-5.16.3 \
    perl-5.14.4

# We then add new versions as needed
RUN perlbrew install-multiple -j 4 --notest perl-5.22.2
RUN perlbrew install-multiple -j 4 --notest perl-5.28.0
RUN perlbrew install-multiple -j 4 --notest perl-5.34.0

RUN perlbrew clean

COPY ./ /

WORKDIR /

# Bootstrap the perl environments
RUN ./bootstrap-perls.sh

# Clean up at the end after we bootstrap
RUN apt-get clean \
&& rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "/bin/bash", "-c" ]
CMD ["/run-stow-tests.sh"]
