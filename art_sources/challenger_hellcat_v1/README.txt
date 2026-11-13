Retained Challenger source geometry

Richerworld ? Dodge Challenger HellCat - Rigged
https://blendswap.com/blend/26927
CC BY 4.0: https://creativecommons.org/licenses/by/4.0/

The owner deleted the original download during the hood/side refinement.
This data copy was measured earlier from that supplied source. It is outside
the Godot project and is not a runtime/exported game asset. provenance.json
records the original source digest and hashes of the retained inputs.

source-panels.npz contains co (fitted body positions), tri (original triangle
indices), mi (material indices), component (connected-component IDs).
components.npz contains the original per-vertex component labels.
source-facts.json retains the fitting transform, original wheel centres and
material names. Original wheel geometry, rig and textures are not retained.

Use scripts/prepare_challenger.py with this NPZ and components.npz. The tool
removes cabin floors and unused details, creates game materials and exports
two GLB tiers. Game attribution remains in legal/challenger_hellcat_notices.txt.
