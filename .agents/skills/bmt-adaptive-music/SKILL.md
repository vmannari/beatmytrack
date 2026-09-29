---
name: bmt-adaptive-music
description: Develop and iteratively improve Beat my track game music, including musical concepts, Magenta RT2 generation, adaptive arrangements, biome identities, audition reviews, and Godot-ready music assets. Use for composition, music prompting, feedback-driven revisions, adaptive music design, and soundtrack export; not for vehicle SFX unless the task explicitly connects them to the music system.
---

# Beat my track music development

Create music the user wants to hear repeatedly while driving. Treat musical taste as iterative evidence, not as something a prompt can infer once and permanently encode.

## 1. Establish the current source of truth

Read `docs/music/STATE.md` first. If absent, initialize it from `assets/STATE.template.md` after reconciling project records and available user feedback. Template placeholders do not revoke existing approvals. Uncertain approval history stays unverified. Inspection-only tasks do not require state creation.

Then inspect only what the task needs:
- Current artistic direction or a new concept: `references/project-direction.md`
- Composition or musical diagnosis: `references/music-craft.md`
- User feedback / iteration: `references/iteration.md`
- Magenta RT2 generation or WSL: `references/mrt2-wsl.md`
- Adaptive layers, collision response, loops, export: `references/adaptive-delivery.md`
- Research justification: `references/evidence.md`

When present, inspect the project's current music documents and tooling before changing them, especially:
- `docs/MUSIC_MODULAR_BANK.md`
- `docs/music/`
- `tools/music_generator/`
- the actual Godot music controller / runtime code

Newer explicit user feedback overrides older proposals. Existing project behaviour is not permission to change it.

Keep `STATE.md` concise (target <= 600 words). Store detailed round feedback in separate records.

## 2. Hard rules vs current preferences

### Hard rules
- The user makes artistic approvals. Do not call music good, approved, compatible, production-ready, or listened-to without evidence.
- Do not claim subjective listening if no audio-perception route is available. Technical audio analysis is not listening.
- Keep approvals scoped: approval of an opening does not approve drums, climax, mix, variants, or runtime behaviour.
- Preserve accepted material during focused revisions unless the user asks for a broader rewrite.
- Preserve source renders. Create revisions/exports as new files.
- Distinguish **complete mixes**, **isolated stems**, and **additive runtime layers**. Independent generated mixes are not automatically compatible layers.
- Keep generation free/local unless the user explicitly changes that constraint.
- Do not silently alter existing collision/reset/recovery behaviour. Verify the current contract in docs/code first.
- Before shipping an asset, record provenance and applicable licensing using `assets/provenance.template.json`.

### Current artistic preferences
These belong in `STATE.md`, not here as permanent law. The current starting direction is organic/instrumental and unobtrusive, with electronic/EDM character and an aggressive distorted-rock finale previously disliked. Treat this as an active preference to refine, not an immutable genre mandate.

## 3. Classify the task before acting

Use the smallest workflow that fits:

**Explore** — unclear direction or new family.  
Generate 2–3 meaningfully different concepts by default.

**Focused refine** — user requests a specific correction.  
One revised candidate is sufficient by default. Use A/B only when a real uncertainty is worth testing.

**Technical** — install, inspect, validate, analyze, debug, convert, or export.  
Do the technical task directly. Do not manufacture musical alternatives or a listening question.

**Integrate** — turn an accepted musical family into adaptive/game-ready assets.  
Inspect runtime requirements first, then change only what integration requires.

## 4. Musical development loop

For artistic work:

1. **Orient** — identify the exact baseline/version, what is approved, what is rejected, and what remains unknown.
2. **Diagnose** — separate composition, performance/timbre, mix, repetition/fatigue, and adaptive behaviour. Change the most likely cause.
3. **Design** — define the musical identity before generating variants: motif/gesture, phrase shape, harmonic movement, rhythmic character, ensemble roles, and intended emotional development.
4. **Render a bounded experiment** — use the existing `tools/music_generator/` workflow where possible. Keep prompts concise and discriminative.
5. **Inspect** — verify files technically. If actual listening is available, compare like with like at comparable audition loudness and note concrete timestamps. Otherwise leave subjective quality pending the user's review.
6. **Deliver** — provide the smallest useful set of playable outputs and explain only the differences that matter.
7. **Learn** — record the user's exact preference and its scope. Update keep/change/avoid and the next hypothesis. “B is better” is a preference, not final approval.

Do not keep changing seeds or adding adjectives after repeated failure. Reconsider the composition, conditioning, renderer, or adaptive architecture.

## 5. What good music means in this project

Judge dimensions independently; do not reduce them to one score.

- **Identity** — a recognizable idea/gesture appears early enough to give the piece character.
- **Phrase direction** — repetition, response, contrast, silence, tension and return feel intentional.
- **Timbre/performance** — attacks, sustain, articulation and human variation serve the idea instead of becoming distracting.
- **Motion** — the music supports driving energy without imposing a mechanically repetitive pulse or competing with steering/braking timing.
- **Development** — later intensity grows from material already established; density/loudness alone is not development.
- **Restraint** — background music leaves room for engine, tyres, impacts and concentration.
- **Replay** — the low state survives repeated restarts; the high state has internal breathing room.
- **Game fit** — evaluate in actual driving, including imperfect runs, phone speakers and mono when practical.

The opening does not have to be sparse, guitar-led, rock, or climax-oriented forever. It must fit the current approved direction in `STATE.md`.

## 6. Magenta RT2 discipline

Use `tools/music_generator/` as the project entry point. Verify the installed MRT2 version and supported controls from the local CLI/API before relying on them.

If the installed generation controls cannot preserve a melody, timing, harmony, or additive compatibility:
- do not pretend prompting solved it;
- do not expand the bank;
- keep the best whole-mix reference;
- use verified audio/MIDI conditioning if available;
- or recreate/render the required parts deterministically.

A shared key, BPM, seed, prompt, or phrase like “same theme” is insufficient evidence that independently generated files can be layered.

## 7. Adaptive behaviour

Music adaptation is part of the game design, not a fixed rule in this skill.

Preserve the project's current collision/reset/recovery behaviour unless the user asks to redesign it. When redesigning, separate:
- immediate SFX feedback,
- musical intensity state,
- clean-streak/momentum state,
- transition timing,
- musical clock continuity.

Proposals such as proportional collision energy loss are experiments until explicitly accepted.

## 8. Shipping gate

Before calling an asset production-ready, require:
- explicit approval scope recorded;
- source and export versions traceable;
- model/tool/version + prompts/conditioning/parameters recorded;
- source-reference licences and model/output terms recorded;
- loop/timing/channel/sample-rate requirements validated;
- runtime behaviour tested in Godot;
- mix checked against vehicle/tyre/impact audio.

Use `assets/round.template.json` for iteration records and `assets/provenance.template.json` for generated/exported assets.

For audition comparisons use `scripts/review_pack.py` with a fresh output directory. Each invocation is one comparison group: compare equivalent sections and arrangements. FFmpeg is required; the helper lowers the common loudness target to preserve true-peak headroom without limiting.
