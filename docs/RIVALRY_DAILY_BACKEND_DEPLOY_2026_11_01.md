# Rivalry and daily backend deployment — 1 November 2026

The retained `beat-my-track` cloud service now uses the current game verifier:
Godot 4.7.2, physics `arcade-planar-0.77`, and the five selectable cars
Compact, Kart, Forklift, Electric and Hovercraft. Schema migrations 0071 and
0072 are applied. Thirty published tracks have new immutable compatible
versions; older versions and their records remain in place.

Today's existing featured track was already pinned to the previous build. A
separate same-track build variant now supplies fixed targets for the current
build while preserving the original version, its targets and its standings.
The daily feed selects the new variant, and limits and standings requests for
the original version continue to work. The variant is written atomically only
after every current car has a verified flying lap. A locked transaction prevents
two publishers from choosing different targets.

The current-build targets were selected from **one verified simulated test
driver per car** on this development staging service. Consequently, each of a
car's nine percentile targets currently comes from that one driver's best lap;
they are not a representative player distribution. The fixed targets do not
change today when additional laps arrive. A low-priority, resumable local
test-driver process is preparing verified comparison histories for the other
current public tracks. It depends on this computer remaining on, and future
days can still lack targets for newly published or not-yet-seeded tracks. Its
history-only plans cover the 30 current public tracks and remain valid for seven
days. Test drivers remain in the existing explicitly enabled staging population.

The main release is image
`backend@sha256:ac96933019158207994bd88ff925ef1d7312de546d0503ada2dfe664af8f1fae`;
the public API revision is `bmt-stg-e7a444ab-api-00155-vec`, and the private
Studio revision is `bmt-stg-e7a444ab-studio-00029-hog`. The existing website
preview was rebuilt with its original website files and the matching backend.
The migration used a managed Cloud SQL backup `1793539995765`; the later
daily-variant write had a further managed backup `1793541242430`. The 166
pre-existing table counts, totalling 330,464 rows, matched before and after
the migrations. Aggregate counts do not prove byte-for-byte equality.

Validation performed:

- Exact Linux candidate: pinned engine import, Compact five-lap replay at
  12,757 ticks, and ten-second rewind all passed.
- Candidate daily/Rivalry tests: 39 passed. PostgreSQL migration and workload
  role checks: 36 passed; variant and row-lock concurrency: three additional
  PostgreSQL checks passed. A corrected isolated smoke fixture passed with the
  restricted API role. Scoped Ruff passed.
- Live worker: one ready worker, empty verification queue at release, and all
  16 discovery partitions ready. Native replay and storage smoke passed.
- The current Rivalry calendar had five tracks for each car. Actual isolated
  test-driver Rivalry tickets were issued and checked for all five cars. The
  game's own ticket validator accepted all 150 public track/car combinations.
  Isolated Rivalry races completed verification and returned result feedback
  for all five cars: Compact 15,493 ticks, Kart 8,120, Forklift 12,080,
  Electric 8,662 and Hovercraft 20,931.
- All five current daily limits returned successfully; repeated reads retained
  the same generations and nine cutoffs. The original Compact, Kart and
  Forklift targets were checked unchanged after the variant was published. All
  five lap-standings endpoints returned successfully after their caches warmed.
  The game's elimination rules and car configurations accepted the live
  responses in 15 checks with no failures.

The first exact-image test invocation used an incorrect test mount and failed
collection; it passed after mounting the fixtures at their expected path. The
first native candidate omitted track-specific fixture fields and was rebuilt
with those original fields retained. The initial PostgreSQL smoke test used an
administrator connection for an application assertion and failed the role
guard; the isolated corrected fixture supplies the restricted API engine. No
guards or runtime assertions were removed.

Runtime sources changed for the compatibility variant are
`backend/bmt_backend/daily_fixed_limits.py`, `daily_standings.py` and
`track_of_day.py`. `backend/deploy/stage_verifier.py` now includes the road
support cache required by the current verifier. The focused regression is
`backend/tests/test_daily_build_variant.py`. No physical-device test, real
player race, owner-game restart or installation was performed. Reload or
rebuild the game to use its matching client sources; owner gameplay acceptance
remains necessary.
