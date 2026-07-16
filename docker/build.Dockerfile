FROM debian:trixie-slim

ARG UID=1000
ARG GID=$UID
ARG NODE_VERSION="22"

# set deb to non-interactive mode and upgrade packages
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && export DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && apt-get -y upgrade

# install latest nodejs lts version
RUN apt-get install -y apt-transport-https ca-certificates curl gnupg &&\
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
RUN apt-get -y update && apt-get -y install nodejs

# base packages for fetching and building chromium for android;
# the rest is installed by src/build/install-build-deps.py --android
# from inside the checkout (the builder user has passwordless sudo)
RUN apt-get -y install bison file flex git gperf lsb-release ninja-build \
  pkg-config python3 python3-pip python3-setuptools python3-httplib2 \
  python3-pyparsing python3-six python3-pillow python3-requests \
  python-is-python3 rsync sudo unzip uuid-dev vim wdiff xz-utils zip

# install sccache
ARG SCCACHE_VERSION=0.10.0

RUN curl --fail -Lo /tmp/sccache.tar.gz \
    https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz

RUN tar --strip-components=1 -xvzf /tmp/sccache.tar.gz \
    -C /usr/bin --wildcards '*/sccache'

# create builder user with passwordless sudo (needed by install-build-deps)
RUN groupadd -g ${GID} builder && useradd -d /home/builder -g ${GID} -u ${UID} -m builder && \
    echo 'builder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/builder

USER builder
WORKDIR /repo
