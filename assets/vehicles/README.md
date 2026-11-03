# Street vehicle geometry

Authored in this project; no model, texture, logo or geometry was extracted from
the reference game. Source: `scripts/vehicles/vehicle_kit.gd`, using the existing
`Props3D` mesh primitives. Units are metres, +Z faces forward and Y=0 is the ground.

Rebuild saved native resources and validate them with:

```text
godot --headless --path . -s res://tools/build_vehicles.gd
```

| Resource | Triangles | Vehicle surfaces |
| --- | ---: | ---: |
| scooter.res | 8,324 | 1 |
| underbone.res | 8,436 | 1 |
| compact_car.res | 14,390 | 1 |

The runtime uses the same cached geometry builder. The saved resources can also be
opened in Godot without importing a third-party model format. Paint accepts each
vehicle's existing colour; metal, plastic, rubber, leather and glass use separate
roughness/specular response in one batched surface. Glass is opaque for traffic
batching. Small tread grooves, open cast-wheel spokes, fork tubes, engine casing,
exhaust, saddle seams, controls, mirrors and indicators are modelled. The car has
open wheel arches, separate window planes/pillars, door seams, handles and lamps.

API remains compatible:

- `Props3D.motorbike(kind, detail := true)` selects the authored model or old low LOD.
- `Props3D.car(detail := true)` exposes the same choice. Dense parked groups should
  explicitly use `false` unless they have their own near/far switching.
- `Props3D.rider_real(kind, driver, passenger, helmet, detail := false)` retains the
  baked riders and adds the same model choice; the detailed rider library is used
  when available, with a fallback to the original poses.

Moving vehicles now rotate the existing tyre/rim/rotor vertices and normals in the
shared shader. `UV2` stores wheel radius (= hub Y) and hub Z; zero tags the body,
forks and fixed brake calipers. This adds no geometry, surfaces or per-wheel draws.
Player movement uses `Props3D.moving_instance(mesh, paint)` with a private material
and `Props3D.set_vehicle_distance(instance, travelled_metres)`. Ordinary
`Props3D.instance` and parked batches remain stationary. Near traffic's custom RGB
retains paint while alpha carries one normalized wheel turn, advanced by route
distance/radius independently of route wrap and near/far slot changes.

Only moving vehicles enable head/taillamp emission from the existing global night
factor. Parked lenses stay off. These lenses do not add dynamic lights; the player
can have its own short-range road light managed by the world. Window planes use a
consistent dark blue-grey tint and less glossy response.

Verify actual rendered rotation, fixed body, a complete revolution, stopped
wheels, isolated materials and night lenses with `tests/vehicle_motion.gd` on the
Compatibility renderer. `tests/traffic_realism.gd` also checks phase/paint/pose
through near/far compaction and route changes.

These are compact authored meshes, not photogrammetry. They do not add steerable
front wheels, suspension or vehicle interiors. Rider movement and traffic LOD are
handled separately by `traffic.gd` and the rider bake tool.
