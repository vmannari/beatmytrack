FROM europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend-reuse@sha256:174b65b00b7f8f6b1236df0d20d235f1c7436387789df37b4e9c017d0aa97bf0
USER root
ENV PYTHONPATH=/app
COPY frozen/backend/bmt_backend /tmp/release-backend
COPY frozen/canonical/game /tmp/release-canonical
COPY frozen/godot-version.txt /opt/bmt/godot-version.txt
COPY frozen/backend/tests/fixtures/verified_oval.json /opt/bmt/acceptance/verified_oval.json
COPY frozen/backend/deploy/check_godot.py /app/deploy/check_godot.py
COPY frozen/backend/deploy/object_archive.py /app/deploy/object_archive.py
COPY install.py /tmp/release-install.py
RUN chmod -R u+w /opt/bmt && python /tmp/release-install.py && python /app/deploy/check_godot.py --import-project /opt/bmt/game --fixture /opt/bmt/acceptance/verified_oval.json && chmod -R a-w /opt/bmt && chown -R 10001:10001 /tmp/bmt
USER 10001:10001
