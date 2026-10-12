FROM europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:d16a4a17e3cb64db4d1d654c818f2076a3b633399ede76a19f75d563987d872d
USER root
COPY source /tmp/studio-source
COPY baseline.json /tmp/studio-baseline.json
COPY patch.py /tmp/studio-patch.py
RUN python /tmp/studio-patch.py
USER 10001:10001
