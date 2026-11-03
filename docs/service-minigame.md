# Service mini-game contract

`BaseMiniGame` in `scripts/minigames/base_minigame.gd` is a Control with
`cfg`, `kind`, `last`, `title`, and `finished(result: Dictionary)`. Existing
mini-games inherit through the compatible `views/minigame_view.gd` path.

Lifecycle: `intro → play → end → submitted`. Subclasses provide rules,
setup/begin, per-frame play, input, result and summary. `end()` seals the
result; `submit()` emits it only once. Cancelling the introduction returns
an empty result. Cancelling a running shift ends with current performance
and still consumes the full in-game shift when submitted.

The HUD gets a session token from `GameLogic.start_minigame(action_id)` and
passes it through `cfg.session`. The base attaches this token and
`completed: true` to the result. GameLogic checks action, day, time, zone,
completion and one-time token consumption before changing state.
Cancelled introductions call `cancel_minigame(token)`.

`bia_service` takes a four-hour shift at `ben_can` in the `ta_hien` zone,
once daily, between 16:00 and midnight. It is a 30-second QTE: clear twelve
cups, with one attempt per two-second arrival. Space/Enter and the visible
touch/click button share hit-window logic. Missed arrivals count as faults;
large frame deltas cannot skip them without penalty.

The model derives grades and rewards from bounded score; input-supplied
`ratio`, `bonus` and automatic-repeat results cannot bypass it. Current
chapter-one wages after existing 10k rounding are Perfect 140k, Good 110k,
Fail 30k, before any poor-condition multiplier. Fatigue increases by
12/16/22 and hygiene falls by 8/14/22, plus normal time decay. Grade
thresholds and pay ratios live in `data/systems/minigames.json`.

`tests/service_minigame.gd` covers timer completion, missed cups, spam
prevention, keyboard/touch play, single completion, session cancellation
and replay, result tampering, three reward grades, and differing survival
costs. Add `--service-preview` with a rendering-capable runner to save
intro/play screenshots under `build/service-preview`.
