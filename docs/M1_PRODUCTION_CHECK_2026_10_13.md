# M1 deployed-runtime check — 2026-10-13

Requirement IDs: B01, B05, B07, Q01 (backend communication review follow-up). Scope: read-only inspection of the live retained Cloud Run environment and isolated inspection of its exact image. No application code, dependency, deployment or production data changes.

## Result

The dependency component of M1 is present in the deployed backend. The local Windows OpenSSL 1.1.1t finding does **not** describe production's HTTPS runtime. No reachable exploit for the four originally identified cryptography advisories was demonstrated; inspection found no application calls to the affected PKCS#7 decryption or custom X.509 chain-verification APIs. Retain medium priority for dependency maintenance, rather than claiming an active compromise or a cause of `RATE_LIMITED`.

At 2026-10-13T18:12:16Z, API revision `bmt-stg-e7a444ab-api-00049-tey` receives 100% traffic. The API and ready worker deployment pin image index `sha256:1433fd6c63329c0869b48ae56d891cbf830ec73517c1a6e2e1e1bba99c1cc3b3`. Registry manifests prove that its Linux amd64 child is the API's resolved serving digest `sha256:d90aa36e7edd929f00e690c01754c1dec2f59409d0f4f1c955958d0c992a95c8`; the locally cached image has the identical repository digest. Initial diagnostic assertions incorrectly compared the image index with its child digest; reading and hashing both manifests established their exact relationship before inspecting any runtime.

The isolated image probe reports:

| Component | Deployed version |
| --- | --- |
| Python | 3.12.15 |
| cryptography | 46.0.7 |
| OpenSSL bundled with cryptography | 3.5.6 |
| Python outbound HTTPS OpenSSL | 3.0.22 |
| Debian system libssl3 / openssl | 3.0.22-1~deb12u1 |

The HTTPS adapter uses Python's `ssl.SSLContext`; `urllib3.util.ssl_.IS_PYOPENSSL` is false. Inbound HTTPS terminates at Cloud Run, per the [Cloud Run container contract](https://docs.cloud.google.com/run/docs/container-contract#transport_layer_encryption_tls).

## Advisory reachability

- [GHSA-537c-gmf6-5ccf](https://github.com/pyca/cryptography/security/advisories/GHSA-537c-gmf6-5ccf): the deployed wheel bundles an affected OpenSSL. The underlying [CVE-2026-34180](https://openssl-library.org/news/secadv/20260609.txt) concerns OpenSSL decoding ASN.1 primitive contents over 2 GiB on 64-bit Unix. Inspected authentication accepts bounded ID tokens and obtains signing certificates from Google's fixed HTTPS endpoint; AdMob public keys also come from a fixed Google endpoint with bounded response handling. No application path was found for attacker-supplied multi-gigabyte ASN.1 decoding. This is a reachability assessment, not proof that every embedded OpenSSL path is safe.
- [GHSA-g6cj-pr64-35w5](https://github.com/pyca/cryptography/security/advisories/GHSA-g6cj-pr64-35w5): affected version installed, but no `pkcs7_decrypt_der`, `pkcs7_decrypt_pem` or `pkcs7_decrypt_smime` application use found.
- [GHSA-jwv3-5hgf-82ww](https://github.com/pyca/cryptography/security/advisories/GHSA-jwv3-5hgf-82ww) and [GHSA-m2h6-j472-rp4c](https://github.com/pyca/cryptography/security/advisories/GHSA-m2h6-j472-rp4c): affected version installed, but no `cryptography.x509.verification` / `PolicyBuilder` application use found. Google token verification uses signature verification with provider-supplied certificates, rather than those certificate-chain builders. Python HTTPS uses its separate system OpenSSL.

The source still pins `cryptography==46.0.7` and constrains it to `<47`. Fixing M1 requires changing that constraint and lock, checking authentication/provider-proof compatibility, rebuilding and explicitly authorizing deployment. The maintainer's [changelog](https://github.com/pyca/cryptography/blob/main/CHANGELOG.rst) lists 50.0.2 as the latest released version at this check; 50.0.0 fixes the last of the four original advisories. No upgrade was performed for this question.

## Actual verification and files

Commands executed with the repository backend Python:

```powershell
& .tools/backend-venv/Scripts/python.exe build/m1-production-check-2026-10-13/inspect_runtime.py
& .tools/backend-venv/Scripts/python.exe build/m1-production-check-2026-10-13/inspect_manifests.py
& .tools/backend-venv/Scripts/python.exe build/m1-production-check-2026-10-13/inspect_runtime.py
```

The first runtime inspection stopped at the index/child comparison; the manifest inspection and corrected full runtime inspection passed. Additional isolated Docker inspection confirmed the TLS adapter and read the deployed `security.py` and `provider_proofs.py`. Containers ran with `--network=none --read-only --cap-drop=ALL --security-opt=no-new-privileges`, without production environment variables, secrets or database access. Cloud commands only described services, worker pools and serving revisions; registry requests only read manifests. Access credentials were captured privately and never written to evidence or printed.

Changed files for this follow-up: this document and the M1 follow-up fields in the existing review artifact. Nonshipping diagnostic scripts and evidence are under `build/m1-production-check-2026-10-13/`: `inspect_runtime.py`, `inspect_manifests.py`, `metadata.json`, `manifests.json`, `result.json`, `reachability.json`.

Limits: this verifies the live retained environment named above, not an independently configured deployment elsewhere; no exploit, exhaustive container vulnerability scan, dependency upgrade, phone test or deployment was performed. The original regression suite was not rerun because product code was unchanged. M1 remains unfixed until a reviewed dependency update reaches the live image.
