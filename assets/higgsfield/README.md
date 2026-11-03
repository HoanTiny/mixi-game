# Higgsfield material set — 2026-10-28

Four original 1024 × 1024 PNG albedo textures generated through the connected
Higgsfield account using `gpt_image_2_5`. Job IDs and prompts are recorded in
`provenance.json`. Quoted generation cost: 0.25 credits each: 0.75 for the first
material batch and 0.25 for the appliance enamel used in the workshop update.

| Asset | Runtime use |
| --- | --- |
| `repair_wood.png` | Repair bench tabletop, local triplanar projection |
| `hanoi_plaster.png` | Authored street facade wall material, metre UVs and four paint tints |
| `billiards_felt.png` | 3D billiards cloth, repeated mipmapped fibre detail |
| `appliance_enamel.png` | Fan casing/base and removable service cover |

These are generated colour maps, not photogrammetry or a complete PBR map set.
Keep engine lighting, roughness and specular separate; do not reuse unrelated
normal or displacement maps. Originals are preserved. Godot imports use VRAM
compression and mipmaps. No character UVs or rig were modified.

Verified with `tests/visual_redesign.gd` on the 1.8 source snapshot plus this
material change: billiards aiming/resizing, fan component drag and screw targets,
character preview and narrow viewport. GPU result: PASS, zero failures.
Screenshots are in `build/design-source/build/design-preview/`.
Concurrent survival-system edits were excluded from this isolated verification.

The subsequent workshop update was verified against the current working source:
`workshop_visual`, `day23_visual`, `day23`, `neighborhood_story`, and
`opening_slice` all passed. `build/workshop-preview/` contains actual GPU renders.
The fan geometry, meter and screwdriver are authored meshes in `repair_models.gd`;
Higgsfield supplied the enamel texture, not those meshes or An's animation.
