# syntax=docker/dockerfile:1.7
# Workload image for an OpenShell sandbox that runs Orca server and its bots,
# with Claude Code and Codex. OpenShell's supervisor is not in this image: the
# gateway injects it. Build arguments come from scripts/resolve-versions; every
# download is checked against the SHA-256 given here before it is unpacked.

ARG BASE_IMAGE=nvcr.io/nvidia/base/ubuntu:24.04

FROM ${BASE_IMAGE} AS fetch
ARG TARGETARCH
ARG ORCA_VERSION CLAUDE_VERSION CODEX_VERSION GH_VERSION
ARG ORCA_SHA256_AMD64 ORCA_SHA256_ARM64
ARG CLAUDE_SHA256_AMD64 CLAUDE_SHA256_ARM64
ARG CODEX_SHA256_AMD64 CODEX_SHA256_ARM64
ARG GH_SHA256_AMD64 GH_SHA256_ARM64
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*
COPY --chmod=0755 docker/fetch /usr/local/bin/fetch
RUN fetch /out

FROM ${BASE_IMAGE}
ARG ORCA_VERSION CLAUDE_VERSION CODEX_VERSION GH_VERSION
ARG REVISION=unknown
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git jq procps \
  && rm -rf /var/lib/apt/lists/*

# One fixed numeric identity, home in the persistent workspace: Orca's pairing
# (~/.config/orca), bots (~/.orca) and the agents' state live on the volume and
# survive an image update. The gateway must run sandboxes as 1500:1500 too.
RUN groupadd --gid 1500 sandbox \
  && useradd --uid 1500 --gid 1500 --home-dir /sandbox --create-home --shell /bin/bash sandbox \
  && : > /etc/machine-id

# Binaries at fixed root-owned paths: OpenShell's network rules match the
# binary's real path, and the agents cannot replace or update them.
COPY --from=fetch /out/ /
COPY docker/codex-config.toml /etc/codex/config.toml
COPY --chmod=0755 docker/start-orca /usr/local/bin/start-orca
RUN ln -s /opt/orca-server/bin/orca-ide /usr/local/bin/orca \
  && claude --version && codex --version && gh --version && orca --version

ENV HOME=/sandbox \
    PATH=/usr/local/bin:/usr/bin:/bin \
    DISABLE_AUTOUPDATER=1 \
    GH_NO_UPDATE_NOTIFIER=1 \
    GH_NO_EXTENSION_UPDATE_NOTIFIER=1

LABEL org.opencontainers.image.source="https://github.com/alvistar/openshell-orca" \
      org.opencontainers.image.description="Orca server, Claude Code and Codex for OpenShell sandboxes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${REVISION}" \
      io.github.alvistar.openshell-orca.orca="${ORCA_VERSION}" \
      io.github.alvistar.openshell-orca.claude="${CLAUDE_VERSION}" \
      io.github.alvistar.openshell-orca.codex="${CODEX_VERSION}" \
      io.github.alvistar.openshell-orca.gh="${GH_VERSION}"

USER 1500:1500
WORKDIR /sandbox
# OpenShell replaces CMD with the command given to `openshell sandbox create --`.
CMD ["start-orca"]
