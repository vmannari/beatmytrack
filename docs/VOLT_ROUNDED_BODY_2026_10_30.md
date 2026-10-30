# Volt rounded hood and rear deck — 2026-10-30

The marked hood has a fuller longitudinal curve and front crown, easing into the existing windshield. The rear deck and tail shoulder are rounded, with the cabin join retained. The front and rear lamps follow the adjoining body panels. Handling and saved liveries are unchanged. The prepared geometry is in `electric_reference_rounded_body_v1`, leaving the previous prepared assets intact.

The pinned Godot 4.7.2 bake produced 221 full/simple meshes. The new rounded-body regression passed 75 checks, covering the profiles, panel joins, finite geometry and agreement of the prepared meshes with the current surfaces. The existing procedural and prepared nose checks each passed 64/64; the Compatibility model check passed 15/15. Full and simple models have 119,904 and 38,126 triangles respectively.

Five shadows, the Electric Garage scene, Garage and header pictures, 49 livery previews and the news image were regenerated. The direct isolated asset bakes exited successfully despite the sandbox certificate-store warning. No project-wide import was run.

Native Garage captures in [Compatibility](evidence/volt-rounded-body-2026-10-30/final-refined/) and [desktop Mobile](evidence/volt-rounded-body-2026-10-30/mobile/) each cover 16 views, including clean and worn finishes. The earlier `preview` and `final` folders record intermediate shapes. The first sandboxed bake failed on the Windows certificate store; the final bake and captures used isolated profiles with normal access. The development wrapper also encountered an unrelated concurrently locked log during build-identity calculation; direct pinned-engine checks succeeded.

Reload and owner appearance acceptance remain. The desktop Mobile renderer is not a physical-device test.
