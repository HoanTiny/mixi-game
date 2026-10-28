# Close traffic riders

27 derived meshes from the project's existing Microsoft Rocketbox models (MIT;
see `../NGUON.md` and the original license). They reuse `../crowd/atlas.png`;
no additional downloaded character assets or new image imports.

- Nine existing crowd identities, each with a scooter driver, step-through
  motorcycle driver, and passenger pose.
- Native `.res` meshes, roughly 3,500–4,300 body triangles plus helmet geometry.
- Driver hips match `Props3D.SEAT_H` / `RIDER_Z`; hands reach the grip, ankles
  match the footboard/pegs. The trunk leans from the waist and the neck keeps
  the gaze forward. Passenger feet use the rear pegs.
- Separate photographed body and vertex-coloured helmet surfaces keep the
  existing traffic material convention and per-group helmet colour.

Rebuild using `tools/bake_traffic_riders.gd` with the real Compatibility renderer.
The dummy headless renderer cannot read back baked skeleton geometry. The baker
freezes animation **before** applying inverse kinematics, waits for the rendered
pose, and verifies the final wrist/ankle positions before saving.

Traffic uses these meshes within 20 m of the player and retains them until 24 m
to avoid repeated changes near the boundary. Beyond that it uses the existing
low-detail crowd meshes. Riders remain baked static poses; this does not add
independent rider gestures or rotating wheels.
