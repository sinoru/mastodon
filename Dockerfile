# syntax=docker/dockerfile:1.4
# Ignoring these here since we don't want to pin any versions and the Debian image removes apt-get content after use
# See: https://github.com/hadolint/hadolint/wiki/DL3008
# hadolint global ignore=DL3008,DL3009

# Ruby image to use for building and runtime, change with [--build-arg RUBY_VERSION=]
ARG RUBY_VERSION="3.2.2"

# Node image to use for building and runtime, change with [--build-arg NODE_VERSION=]
ARG NODE_VERSION="20.6.0"

# Linux UID (user id) for the mastodon user, change with [--build-arg UID=1234]
ARG UID="991"

# Linux GID (group id) for the mastodon user, change with [--build-arg GID=1234]
ARG GID="991"

# Timezone used by the Docker container and runtime, change with [--build-arg TZ=Europe/Berlin]
#
# NOTE: This will also be written to /etc/localtime
#
# See: https://blog.packagecloud.io/set-environment-variable-save-thousands-of-system-calls/
ARG TZ="Etc/UTC"

# Allow specifying your own version prerelease, change with [--build-arg MASTODON_VERSION_PRERELEASE="hello"]
ARG MASTODON_VERSION_PRERELEASE=""

# Allow specifying your own version metadata, change with [--build-arg MASTODON_VERSION_METADATA="world"]
ARG MASTODON_VERSION_METADATA=""

# Use production settings for Ruby on Rails (and thus, Mastodon)
#
# See: https://docs.joinmastodon.org/admin/config/#rails_env
# See: https://guides.rubyonrails.org/configuring.html#rails-environment-settings
ARG RAILS_ENV="production"

# Use production settings for Yarn, Node and related nodejs based tools
#
# See: https://docs.joinmastodon.org/admin/config/#node_env
ARG NODE_ENV="production"

# Allow Ruby on Rails to serve static files
#
# See: https://docs.joinmastodon.org/admin/config/#rails_serve_static_files
ARG RAILS_SERVE_STATIC_FILES="true"

# Configure the IP to bind Mastodon to when serving traffic
#
# See: https://docs.joinmastodon.org/admin/config/#bind
ARG BIND="0.0.0.0"

########################################################################################################################
FROM node:${NODE_VERSION}-bookworm-slim as node

########################################################################################################################
FROM ruby:${RUBY_VERSION}-slim-bookworm as base

COPY --link --from=node /usr/local /usr/local
COPY --link --from=node /opt /opt

# Smoke test for node, yarn
RUN node --version; \
    yarn --version; \
    rm -rf /tmp/*;

# Install Runtime dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        ffmpeg \
        file \
        imagemagick \
        libicu72 \
        libidn12 \
        libjemalloc2 \
        libpq5 \
        libssl3 \
        tini \
        tzdata \
        wget \
        zlib1g \
    ; \
    rm -rf /var/lib/apt/lists/*;

RUN set -eux; \
    bundle config set --local deployment 'true'; \
    bundle config set --local without 'development test';

WORKDIR /opt/mastodon

########################################################################################################################
FROM base as base-builder 

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends build-essential; \
    rm -rf /var/lib/apt/lists/*;

########################################################################################################################
FROM base-builder as ruby-builder

# Install gems
#
# NOTE: Instead of copying Gemfile and Gemfile.lock, we bind them to the container at build time
# this avoids the issue of the files "changing" (e.g. a newline) invalidating the cache,
# even though the "parsed" content is the same, and makes the file read-only and immutable
# inside the build step, preventing "quiet" changes to the files
RUN \
    --mount=type=bind,source=Gemfile,target=Gemfile \
    --mount=type=bind,source=Gemfile.lock,target=Gemfile.lock \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git \
        libicu-dev \
        libidn-dev \
        libpq-dev \
        libssl-dev \
        zlib1g-dev \
    ; \
    bundle install --no-cache;

########################################################################################################################
FROM base-builder as node-builder

# Download and install yarn packages
#
# Note: Instead of copying package.json and yarn.lock, we bind them to the container at build time
# this avoids the issue of the files "changing" (e.g. a newline) invalidating the cache,
# even though the "parsed" content is the same, and makes the file read-only and immutable
# inside the build step, preventing "quiet" changes to the files
RUN \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=yarn.lock,target=yarn.lock \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        python3 \
    ; \
    yarn install --immutable; \
    yarn cache clean --all;

########################################################################################################################
FROM base
ARG UID
ARG GID
ARG TZ
ARG RAILS_ENV
ARG NODE_ENV
ARG RAILS_SERVE_STATIC_FILES
ARG MASTODON_VERSION_PRERELEASE
ARG MASTODON_VERSION_METADATA

RUN set -eux; \
    echo "${TZ}" > /etc/localtime; \
    groupadd -g "${GID}" mastodon; \
    useradd -l -u "$UID" -g "${GID}" -m -d /opt/mastodon mastodon; \
    # Symlink /opt/mastodon to /mastodon
    ln -s /opt/mastodon /mastodon;

# [1/3] Copy the git source code into the image layer
COPY --link . /opt/mastodon
# [2/3] Copy output of the "bundle install" build stage into this layer
COPY --link --from=ruby-builder /opt/mastodon /opt/mastodon
# [3/3] Copy output of the "yarn install" build stage into this image layer
COPY --link --from=node-builder /opt/mastodon /opt/mastodon

RUN mkdir /opt/mastodon/tmp && chown mastodon:mastodon /opt/mastodon/tmp

ENV PATH="${PATH}:/opt/mastodon/bin" \
    LD_PRELOAD="libjemalloc.so.2" \
    TZ="${TZ}" \
    RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    RAILS_SERVE_STATIC_FILES="${RAILS_SERVE_STATIC_FILES}" \
    BIND="${BIND}" \
    MASTODON_VERSION_PRERELEASE="${MASTODON_VERSION_PRERELEASE}" \
    MASTODON_VERSION_METADATA="${MASTODON_VERSION_METADATA}"

# Precompile assets
RUN set -eux; \
    OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder rails assets:precompile; \
    rm -rf /tmp/*;

# Use the mastodon user from here on out
USER mastodon

# Set the work dir and the container entry point
ENTRYPOINT ["/usr/bin/tini", "--"]

EXPOSE 3000 4000
