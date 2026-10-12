# Weekly Rivalry loading evidence

See [requirements, diagnosis, applied scaling change, commands/outcomes and costs](../../RIVALRY_LOADING_2026_10_06.md).

- cloud-timings.json: owned min/max settings, same digest, post-change verified HTTPS samples and sanitized actual authenticated rivalry logs, including the initial 15.917747-second frontend request.
- idle-cost.json: regional EUR minimum-instance CPU/memory rates and €0.3799872/day idle calculation.
- scaling.xml: 27 passing staging orchestration/guard checks.
- native-cloud.log: actual pinned Windows cloud client, 21 checks passed, no saved player session loaded.
- loading-ui-probe.log: isolated 50 ms response clears the adapter and visible page busy state; diagnostic source was removed.
- before-* files, scoped-change.patch and source-hashes.json: task-only source/docs checkpoint preserving previous shared work.

The 95.96 ms post-change rivalry probe is unauthenticated and correctly receives 401. Real authenticated 200 response timings are independent log observations. No claims of changed player membership, scores, provider SSO or forced cold-start benchmarking are made.
