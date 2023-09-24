# syntax=docker/dockerfile:1.4
# Ignoring these here since we don't want to pin any versions and the Debian image removes apt-get content after use
# See: https://github.com/hadolint/hadolint/wiki/DL3008
# hadolint global ignore=DL3008,DL3009

# Node version to use, change with [--build-arg NODE_VERSION=]
ARG NODE_VERSION="20.7.0"

# Image to use for base, change with [--build-arg BASE_IMAGE=]
ARG BASE_IMAGE="debian:bookworm-slim"

# Image to use for node, change with [--build-arg NODE_IMAGE=]
ARG NODE_IMAGE="node:${NODE_VERSION}-bookworm-slim"

# Linux UID (user id) for the mastodon user, change with [--build-arg UID=1234]
ARG UID="991"

# Linux GID (group id) for the mastodon user, change with [--build-arg GID=1234]
ARG GID="991"

# Mastodon home directory for the mastodon user and project, change with [--build-arg MASTODON_HOME=/some/path]
ARG MASTODON_HOME="/opt/mastodon"

# Timezone used by the Docker container and runtime, change with [--build-arg TZ=Europe/Berlin]
ARG TZ="Etc/UTC"

# Use production settings for Yarn, Node and related nodejs based tools
#
# See: https://docs.joinmastodon.org/admin/config/#node_env
ARG NODE_ENV="production"

# Configure the IP to bind Mastodon to when serving traffic
#
# See: https://docs.joinmastodon.org/admin/config/#bind
ARG BIND="0.0.0.0"

########################################################################################################################
FROM ${NODE_IMAGE} as node

RUN set -eux; \
    rm /usr/local/bin/yarn* /usr/local/bin/docker-entrypoint.sh;

########################################################################################################################
FROM ${BASE_IMAGE} as base
ARG TARGETPLATFORM

RUN \
    --mount=type=cache,id=${TARGETPLATFORM}-/var/cache,target=/var/cache,sharing=locked \
    --mount=type=cache,id=${TARGETPLATFORM}-/var/lib/apt,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    set -eux; \
    # Remove /etc/apt/apt.conf.d/docker-clean for keeping caches
    rm -f /etc/apt/apt.conf.d/docker-clean; \
    # Update apt
    apt-get update; \
    # Upgrade packages
	apt-get -yq dist-upgrade; \
    # Install dependencies
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        # Dependencies for nodejs
        libatomic1 \
    ;

# Node image contains node on /usr/local without /usr/local/share
#
# See: https://github.com/nodejs/docker-node/blob/151ec75067877000120d634fc7fd2a18c544e3d4/20/bookworm-slim/Dockerfile
COPY --link --from=node /usr/local/bin /usr/local/bin
COPY --link --from=node /usr/local/include /usr/local/include
COPY --link --from=node /usr/local/lib /usr/local/lib

ENV COREPACK_HOME /usr/local/corepack

RUN set -eux; \
    corepack enable; \
    yarn set version classic; \
    # Smoke test for node, yarn
    node --version; \
    yarn --version; \
    # Remove tmp files from node
    rm -rf .yarn* /tmp/* /usr/local/share/.cache;

########################################################################################################################
FROM base as mastodon-base
ARG TARGETPLATFORM
ARG UID
ARG GID
ARG MASTODON_HOME
ARG TZ
ARG NODE_ENV

RUN \
    --mount=type=cache,id=${TARGETPLATFORM}-/var/cache,target=/var/cache,sharing=locked \
    --mount=type=cache,id=${TARGETPLATFORM}-/var/lib/apt,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    set -eux; \
    # Update apt
    apt-get update; \
    # Install dependencies
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        # Dependencies for mastodon runtime
        ca-certificates \
        file \
        tini \
        tzdata \
        wget \
    ;

RUN set -eux; \
    # Add mastodon group and user
    groupadd -g "${GID}" mastodon; \
    useradd -u "${UID}" -g "${GID}" -l -m -d "${MASTODON_HOME}" mastodon;

ENV MASTODON_HOME="${MASTODON_HOME}" \
    TZ="${TZ}" \
    NODE_ENV="${NODE_ENV}"

WORKDIR ${MASTODON_HOME}

########################################################################################################################
FROM mastodon-base as yarn-installer
ARG TARGETPLATFORM

RUN \
    --mount=type=cache,id=${TARGETPLATFORM}-/var/cache,target=/var/cache,sharing=locked \
    --mount=type=cache,id=${TARGETPLATFORM}-/var/lib/apt,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    set -eux; \
    # Update apt
    apt-get update; \
    # Install builder dependencies
    apt-get install -y --no-install-recommends \
        gcc \
        git \
        g++ \
        make \
        python3 \
    ;

ADD package.json yarn.lock ${MASTODON_HOME}/

RUN set -eux; \
    # Download and install yarn packages
    case "${NODE_ENV}" in \
        production) yarn install --frozen-lockfile --network-timeout 600000;; \
        *) yarn install --network-timeout 600000;; \
    esac; \
    yarn cache clean --all; \
    # Remove tmp files from node
    rm -rf .yarn* /tmp/* /usr/local/share/.cache;

########################################################################################################################
FROM mastodon-base
ARG BIND

# Copy the git source code into the image layer
COPY --link . ${MASTODON_HOME}

# Copy output of the "yarn install" build stage into this image layer
COPY --link --from=yarn-installer ${MASTODON_HOME}/node_modules ${MASTODON_HOME}/node_modules

# Set runtime envs
ENV BIND="${BIND}"

# Use the mastodon user from here on out
USER mastodon

# Set the work dir and the container entry point
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "./streaming"]
HEALTHCHECK CMD wget -q --spider --proxy=off localhost:4000/api/v1/streaming/health || exit 1

EXPOSE 4000
