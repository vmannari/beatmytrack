"""Recover the earlier exact log after the wrapper reused its fixed output name."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
path = OUT / "standard-feature-parse-checked.log"
current = path.read_bytes()
original = current.replace("7aac39deacf24f1291b735bf98f40145".encode("utf-16-le"),
                           "790acef63c4bfd8847f2201ba8c61322".encode("utf-16-le"))
inventory = json.loads((OUT / "evidence-files.json").read_text())
expected = inventory["docs/evidence/loading-half-2026-11-06/standard-feature-parse-checked.log"]["sha256"]
assert hashlib.sha256(original).hexdigest() == expected, "Earlier log recovery must match its prior inventory hash"
accepted = OUT / "standard-accepted-feature-parse.log"
assert accepted.read_bytes() == b"", "Only replace the empty outer-command redirection"
accepted.write_bytes(current)
path.write_bytes(original)
(OUT / "parse-receipt-recovery.json").write_text(json.dumps({
    "earlier_log_sha256": expected,
    "recovered_byte_exact_against_prior_inventory": True,
    "accepted_log_sha256": hashlib.sha256(current).hexdigest(),
    "cause": "The standard wrapper redirected internally to a fixed name; the second outer redirection was empty.",
    "repair": "Separate final log retained; previous log recovered with exact prior SHA256; wrapper now rejects existing receipts."
}, indent=2) + "\n", encoding="utf-8")
print("Both parse receipts preserved; earlier log hash is byte-exact.")
