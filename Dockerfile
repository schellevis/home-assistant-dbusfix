# syntax=docker/dockerfile:1
# Officiële Home Assistant-image met uitsluitend aiohomekit vervangen door een
# gepatchte fork (fix voor lekkende D-Bus-verbindingen bij HomeKit over BLE).
# Alle build-args worden door de GitHub Action gezet vanuit pins.env.
ARG HA_VERSION
FROM ghcr.io/home-assistant/home-assistant:${HA_VERSION}

ARG HA_VERSION
ARG AIOHOMEKIT_REPO
ARG AIOHOMEKIT_REF

RUN set -eu; \
    test -n "${HA_VERSION}" && test -n "${AIOHOMEKIT_REPO}"; \
    echo "${AIOHOMEKIT_REF}" | grep -Eq '^[0-9a-f]{40}$' \
      || { echo "AIOHOMEKIT_REF moet een volledige commit-hash zijn" >&2; exit 1; }; \
    PIP_ROOT_USER_ACTION=ignore python3 -m pip install --no-cache-dir --no-deps --force-reinstall \
      "aiohomekit @ ${AIOHOMEKIT_REPO}/archive/${AIOHOMEKIT_REF}.tar.gz"; \
    python3 -c "import importlib.metadata as md, aiohomekit.controller.ble.pairing; \
d = md.distribution('aiohomekit'); u = d.read_text('direct_url.json') or ''; \
assert '${AIOHOMEKIT_REF}' in u, 'onverwachte aiohomekit-bron: ' + u; \
print('aiohomekit', d.version, 'uit ${AIOHOMEKIT_REF}')"

LABEL org.opencontainers.image.title="home-assistant-dbusfix" \
      org.opencontainers.image.description="Home Assistant ${HA_VERSION} met gepatchte aiohomekit (BLE D-Bus leak fix)" \
      org.opencontainers.image.version="${HA_VERSION}" \
      io.github.schellevis.aiohomekit.repo="${AIOHOMEKIT_REPO}" \
      io.github.schellevis.aiohomekit.ref="${AIOHOMEKIT_REF}"
