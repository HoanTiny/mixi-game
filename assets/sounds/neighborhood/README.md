# Neighborhood foley

Original procedural effects synthesized by `tools/gen_sounds.py` (ogg, 22.05 kHz mono).
No external recordings, voice cloning, speech or music. Sources for all sounds: `../NGUON.md`.

- fan.ogg: quạt cây loop (motor hum, three-blade air), workbench and workshop
- screw.ogg: ratchet screwdriver clicks and a small metal knock, action feedback
- dishes.ogg: porcelain bowls, chopsticks and spoons, restaurant during meals
- sweep.ogg: two strokes of a straw broom, courtyard cleaning hours
- scooter_pass.ogg: 110cc step-through passing with Doppler, existing nearby traffic positions

World emitters fade outside opening hours and have bounded audible distances.
The HUD music-note button mutes/unmutes the Master bus, including these effects.

`bath.wav`: tiếng xối nước tổng hợp, sinh bằng `tools/gen_bath_sound.py` (seed cố định), phát một lần khi tắm.
