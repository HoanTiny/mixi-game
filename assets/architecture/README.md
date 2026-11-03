# Street architecture kit

Original geometry authored for this project in `scripts/architecture/street_kit.gd`.
The native Godot `ArrayMesh` resources contain indexed triangles, metre-scale UVs,
normals and tangents. Materials reference the existing project textures under
`assets/ph/textures`; those assets retain their original source/licence records.
No models were extracted from another game.

The nine scenes under `scenes/architecture` contain three separate groups:

- `GroundArchitecture`: open shop recess or courtyard room walls and ground detail.
- `UpperArchitecture`: upper rooms, balconies, glazing, shutters and pipework.
- `RoofArchitecture`: roof sheets, gables, cornices, parapets and gutters.
- `FrontWingWalls` (lodging only): all ground-floor walls and doors in the front
  wings. Hide this group when the player is inside the rear court so its full
  seven-metre width, residents and props remain visible at the gameplay camera angle.

Hide the upper and roof groups to expose the ground floor. Do not compress their
Y scale. Collision footprints are in the ground group's `blockers` metadata and
in the dictionary returned by the runtime builder. All coordinates are metres:
X runs along the facade, Y up, and positive Z faces the street.

The restaurant, workshop and lodging prototypes use 8, 9 and 13 metre frontages.
Six residential profiles differ in bays, shutters, balconies and roof silhouettes.
Runtime dimensions can adapt to narrower terraces without changing lot bounds.
The 13 × 8 metre lodging plan has a 3 metre entrance alley opening into a 7 metre
rear courtyard. The courtyard and shop recesses are actual empty volumes.

The weathering pass adds a continuous subtle grime gradient at the wall base,
irregular vertex-alpha damp and limewash patches, real staggered brick faces at
chipped lower piers, cement skirting and runoff marks.
Meter boxes, conduit and bracketed AC units stay with their owning cutaway group.
Patch shapes use deterministic seeds, while identical materials are shared to
avoid one draw surface per mark. Shop tiles use a muted tint; the repair workshop
and lodging courtyard use neutral `concrete_floor_02` at 0.32 tiles per metre for
large, quiet tonal variation visible at the gameplay camera distance.

Rebuild the saved scenes and compressed resources with:

```text
godot --headless --path . --script tools/build_architecture.gd
```

The generator checks mesh attributes, triangle winding, saved scene instantiation,
narrow lot boundaries and the courtyard passage. To capture the architecture
with and without its upper floors, run graphically with `-- --preview` appended;
the two preview PNGs are saved in `tests/`.
