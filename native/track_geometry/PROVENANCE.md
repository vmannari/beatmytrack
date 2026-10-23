# Device track geometry

`track_geometry.cpp` is original project code porting the existing cosmetic Desert subdivision, field sampling and normal transformation from `game/track/desert_road_relief.gd`. The frozen original fixture remains the independent comparison. The simulation step and race rules never call this extension.

`road_geometry.hpp` additionally ports the existing presentation-only shoulder overlap solver, road/fringe UV sampling, exposed-edge sampling and mesh finishing from `shoulder_mesh.gd`, `desert_road_union.gd`, `road_fringe_mesh.gd`, `native_track_visual.gd` and `editor/road_preparation.gd`. It keeps ordered clipping ownership, original scalar/vector rounding boundaries, subdivision, winding, material attributes and the engine's triangulation/intersection/indexing. Grass stones and blades retain their original GDScript emission.

`road_engine_api.hpp` uses the official godot-cpp typed ptrcall convention and method hashes from the pinned checkout's `gdextension/extension_api.json`. These headers are original project integration code; no new library or SDK is introduced. Native road jobs have cancellation and a retained scalar fallback. Windows rebuilds use content-addressed DLL names so an already running editor can retain its loaded library while new processes use the new build.


`winter_geometry.hpp` ports the original snowbank row profiles, finite-difference normals, winding-preserving section emission and Winter marker selection from `native_track_visual.gd` and `winter_scenery.gd`. The pinned engine Noise API retains the original FastNoiseLite field. Existing snow deposits, materials and canonical snow contacts remain unchanged.

`raster_geometry.hpp` ports the original compiler road/shoulder coverage and ordered paint-cell loops plus editor RGB/L8 mask packing. Small stroke smoothing stays shared in GDScript. Compiler output participates in canonical track identity, so independent exact full-track comparisons and retained compiler goldens fence this optional implementation; the compiler version remains 27. Unsupported platforms and unavailable feature versions retain the original scalar compiler. These are local CPU changes with no server cache, network request or service cost.

The build reuses the already installed official `godot-cpp` checkout at commit `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`, its existing release libraries, MinGW and Android NDK r28b. No SDK or package download is required. Godot's API and the public `SurfaceTool` retain mesh encoding/indexing behaviour; floating-point contraction and fast-math are disabled. Windows x86-64 and Android ARM64/x86-64 libraries are built; Android targets API 24 with 16 KiB ELF load alignment. Unsupported native platforms retain the original GDScript algorithm.

The engine is pinned by `godot-version.txt`; tests run through `scripts/dev.ps1`. Rebuild the libraries with `scripts/dev.ps1 -Action BuildTrackGeometry`. Android compilation and ELF checks do not constitute phone execution, an APK export or installation.

The linked `godot-cpp` library carries this MIT license:

Copyright (c) 2017-present Godot Engine contributors.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
