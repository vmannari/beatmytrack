# Free Race version repair — 1 November 2026

After the physics/backend rollout, the default Free Race discovery feed still
returned the prior build's frozen track versions. The ordinary catalogue's
current heads were compatible, but every one of the first 20 default-feed
entries was old and could not obtain a ticket from the current verifier.

The live daily discovery selection was repaired after a managed database
backup and a read-only preflight. A single transaction replaced all 30 version
references with their validated canonical build-transfer revisions. The track
IDs, ordering, other selection fields, source document hashes, compiler,
compiled geometry hashes, and route lengths were checked unchanged. Historical
versions and their results remain intact. Existing client-side cached lists and
selected cards may require a refresh or restart.

After the repair, the public default feed returned 20 current versions. The
actual backend issued ordinary-race tickets to isolated test identities for
Compact, Kart, Forklift, Electric and Hovercraft. The current desktop game's
ticket validator accepted 150 combinations of the 30 current published tracks
and five cars. These checks do not establish that an owner's particular running
game has reloaded its selection or finished a race.

For future build refreshes, `backend/bmt_backend/catalog_builds.py` now advances
today's frozen selection in the same transaction as its validated replacement
versions. It preserves selection metadata and rejects mismatched track pins;
it also stops a refresh while the day's selection is being prepared. This
operator-side safeguard is in the workspace and must be included in the next
catalogue-maintenance image. It is not yet in the deployed image.

The scoped SQLite catalogue tests passed (8 passed, 8 PostgreSQL cases
deselected), including selection preservation, rollback on a bad pin, and the
in-progress selection guard. The PostgreSQL fixture was unavailable locally;
an initial attempt timed out connecting to its configured disposable server.
Scoped Ruff and the source whitespace check passed.
