# Neighborhood 1.9

Five visual/life-simulation updates built on the existing day 1–3 repair story:

1. Authored fan assemblies, contoured kettle with separate lid, meter, screwdriver
   and replaceable components. Higgsfield-generated enamel/wood/plaster/felt
   albedos are recorded in `assets/higgsfield/provenance.json`. Case opening is a
   saved step; existing partial repairs migrate as already open. Testing closes
   the cover, runs the fan and preserves the actual story payout rules.
2. Six ambient resident styles with distinct body/head combinations, clothing
   tones, height/build, greying hair and cap. Six named NPC styles also receive
   cloth treatment. An keeps his existing face/rig/wardrobe with warmer skin.
3. Procedural bone overlays for eating, sweeping and repair, attached props,
   existing talk/walk/sit clips, An's meal pose, and customer handover vignettes.
   Distant/off-hours ambient rigs stop animating; handovers never grant rewards.
4. Workshop tool wall and parts shelves; restaurant serving trays/menu/stacked
   dishes; lodging beds, bedding and study corners. Furnishings stay in blocked
   room bays, central paths remain clear, and the existing cutaway reveals them.
5. Five original synthesized foley clips with localized, scheduled emitters and
   action feedback. Master mute/unmute is available from the HUD note button.

This release uses authored procedural geometry and the existing character assets,
not a new photogrammetry cast. Hand motions are bone overlays, not motion capture;
An's source rig does not have individually articulated fingers. Sound effects are
synthesized, not live Hanoi recordings. The Windows download is unchanged.

Validation: GPU `neighborhood_finish`, `workshop_visual`, `day23_visual`; story
regressions `day23`, `neighborhood_story`, `opening_slice`; clean Web export and
browser boot before publishing. Use `?neighborhood-demo&v=1.9` for a fresh no-save
preview, or the normal URL to continue a saved game.
