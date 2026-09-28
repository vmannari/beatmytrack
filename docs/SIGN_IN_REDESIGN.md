# Provider-first sign-in — 2026-09-28

Requirements: B01/B19 authentication, R01 domain separation, V03 menu presentation,
Q01 verification, and the owner's supplied sign-in reference. This supersedes the
earlier username-before-Google menu. No unsupported Apple/email buttons are shown.

## Behavior and implementation

- The standalone scenic screen offers Google, temporary Development, and local guest play.
- Google browser start accepts an empty body. Only a newly authenticated identity
  receives `needs_username=true`; name selection then updates `/me`. Returning
  players keep their saved names, including after cancellation/reconnection.
- Migration `0003_profile_name` preserves existing profiles and defaults them to
  completed onboarding. Development always uses `developer`.
- Enter and the save button complete the name step. Errors keep the input available.
- Browser verification, nonce, single-use handoff, token isolation and development
  server gating remain in force. Guest play does not create an online identity.

Changed implementation: `game/ui/account_panel.gd`, `account_backdrop.gd`,
`game/core/app.gd`, `game/backend/account_controller.gd`; backend identity model,
auth/browser-auth routes, readiness migration check and new migration. Native and
backend account tests cover the new contract.

## Actual verification

- `scripts/dev.ps1 -Action Import` and `-Action CheckScript -ScriptPath res://core/app.gd`: passed using pinned Godot 4.7.2.
- `python -m pytest backend/tests/test_auth.py backend/tests/test_browser_auth.py -q`: 44 passed.
- `python -m pytest backend/tests -q -k 'not postgres'`: 112 passed, 31 deselected.
- `python -m pytest backend/tests/test_auth_postgres.py -q`: 4 passed against the local PostgreSQL test fixture; fixture stopped afterwards.
- `BMT_CAPTURE_ACCOUNT=docs/evidence/sign-in-redesign` with `python -m pytest backend/tests/test_account_client.py -q -s`: passed, 38 native checks. Repeated after divider and Enter fixes: passed.
- `scripts/dev.ps1 -Action CapturePCAccount`: 8 checks passed against the actual persistent PC API/PostgreSQL with installed game configuration.
- Stopped only the PC API/worker, then ran `scripts/dev.ps1 -Action BackendStart`: migration and readiness passed; API/worker left running with the configured Google client ID.

Screenshots reviewed at 1280×720 and 960×540:
[provider choice](evidence/sign-in-redesign/sign-in-1280.png),
[compact screen](evidence/sign-in-redesign/sign-in-960.png),
[name selection](evidence/sign-in-redesign/choose-name-960.png).
Actual PC captures: `docs/evidence/pc-sign-in/`.

Google identity is simulated in automated native integration tests. Real interactive
Google acceptance and Cloud Console origin setup still require owner testing.
No physical phone test, Android export, NAS or production deployment was performed.
Existing FastAPI test-client deprecation warning remains; no physics changes.

## Artwork provenance and prompt

Original scenic artwork generated with the built-in `image_gen` tool using the
imagegen skill. The supplied reference informed composition only; it is not shipped.
All controls and the existing game brand are editable Godot UI. Official Google
button provenance remains in `game/assets/auth/PROVENANCE.md`.

Final asset: `game/assets/menu/sign_in_alpine_v1.png` (1672×941).
Generation source: `C:/Users/ville/.codex/generated_images/01a0e7bc-f221-7ea3-864a-cfe0141f7382/exec-cf87867f-27fd-4302-a887-44aa9f94b5e5.png`.
Final edit source: same directory, `exec-bbe6cb99-1e33-4ca7-b997-16beda5fec69.png`.

Generation prompt:

> Use case: stylized-concept. Asset type: original background illustration for the Beat my track game's sign-in screen, landscape 16:9, high resolution. Create only the scenic artwork; absolutely NO text, lettering, logos, UI panels, buttons, symbols or watermarks. Mature illustrated cel-shaded driving-game art: a winding compact mountain road above a deep blue alpine lake, tall pines, rocky mountain peaks, warm afternoon sunlight and soft blue sky. One fictional unbranded cream-colored compact sports hatchback with believable proportions, seen small in the lower-left foreground on the curving road. Premium hand-inked graphic novel scenery, restrained natural colors, soft atmospheric distance, not a photograph and not toy-like. Composition must leave the central 45 percent as calm, lower-detail distant water and mountains, suitable behind an editable navy sign-in panel. Interesting road and pine scenery on left and right outer edges; no central focal object. This is menu-only scenery, not a gameplay camera. Original scene inspired by a scenic alpine racing sign-in reference, not a reproduction of any real car, game screenshot or logo.

Edit prompt:

> Keep the entire alpine lake, pine trees, road, mountains, composition, lighting and illustration unchanged. Edit only the small cream car in the lower left: remove every manufacturer emblem, badge and lettering, particularly the badge at the center of the rear hatch. Replace the badge location with uninterrupted plain cream painted metal. Give the rear lamps two simple rectangular red lamp shapes and a plain flat black rear bumper so this is a generic fictional compact hatchback, not an identifiable production vehicle. No logos or text anywhere.
