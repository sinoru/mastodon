# syntax=docker/dockerfile:1.4
ARG BASE_IMAGE="gchr.io/mastodon/mastodon/base"
ARG NODE_VERSION="20"

FROM ${BASE_IMAGE}
ARG NODE_VERSION

RUN \
    --mount=type=cache,target=/var/cache,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    # Update apt due to /var/lib/apt/lists is empty
    apt-get update; \
    # Install builder dependencies
    apt-get install -y --no-install-recommends \
        # Dependencies for runtime
        file \
        libjemalloc2 \
        tzdata \
        # Dependencies for node-gyp, ruby gem native extensions
        gcc \
        git \
        g++ \
        make \
        python3 \
        # Dependencies for ruby gems
        libicu-dev \
        libidn-dev \
        libpq-dev \
    ;

COPY --link welcome-message.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt
