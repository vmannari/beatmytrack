# Build context is the repository root. Supply the exact Linux binary; no fallback.
FROM python:3.12.15-slim-bookworm@sha256:34386ef0cb081344d7ec1c103ba398e6e9f64e9ab3a1509accc92a4e24a07258 AS python-runtime
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app
COPY backend/requirements.lock /app/requirements.lock
RUN pip install --no-cache-dir --require-hashes --only-binary=:all: -r requirements.lock
COPY backend/pyproject.toml /app/pyproject.toml
COPY backend/bmt_backend /app/bmt_backend
COPY backend/README.md /app/README.md
COPY backend/deploy/object_archive.py /app/deploy/object_archive.py
COPY backend/deploy/check_godot.py /app/deploy/check_godot.py
RUN pip install --no-cache-dir --no-deps --no-build-isolation . \
    && groupadd --gid 10001 bmt \
    && useradd --uid 10001 --gid 10001 --home-dir /tmp/bmt --no-create-home bmt \
    && mkdir -p /var/lib/bmt/objects \
    && chown -R 10001:10001 /var/lib/bmt

FROM python-runtime AS verifier-project
COPY godot-version.txt /source/godot-version.txt
COPY game /source/game
COPY backend/deploy/stage_verifier.py /source/backend/deploy/stage_verifier.py
RUN python /source/backend/deploy/stage_verifier.py --repo /source --destination /opt/bmt/game

FROM python-runtime AS runtime
# This library is needed by the standard Godot Linux headless binary.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libasound2 libgl1 \
    && rm -rf /var/lib/apt/lists/*
COPY backend/deploy/vendor/godot /usr/local/bin/godot
COPY --from=verifier-project /opt/bmt /opt/bmt
COPY backend/tests/fixtures/verified_oval.json /opt/bmt/acceptance/verified_oval.json
ARG GODOT_SHA256
RUN test -n "$GODOT_SHA256" \
    && echo "$GODOT_SHA256  /usr/local/bin/godot" | sha256sum --check --strict \
    && chmod 0555 /usr/local/bin/godot \
    && python /app/deploy/check_godot.py --import-project /opt/bmt/game --fixture /opt/bmt/acceptance/verified_oval.json \
    && chmod -R a-w /opt/bmt
ENV HOME=/tmp/bmt BMT_GODOT_BIN=/usr/local/bin/godot BMT_GAME_PROJECT=/opt/bmt/game BMT_OBJECT_DIR=/var/lib/bmt/objects
USER 10001:10001
EXPOSE 8080
CMD ["uvicorn", "bmt_backend.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8080", "--no-proxy-headers", "--no-access-log", "--limit-concurrency", "24", "--timeout-keep-alive", "5"]
