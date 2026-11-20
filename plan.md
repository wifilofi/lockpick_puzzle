# Lockpick gameplay architecture plan

## Handoff

Implement this plan in a new session after the user explicitly says **go**, as specified in the local `AGENTS.override.md`. The existing [Lockpick.lua](content/Scripts/Lockpick.lua) is the starting point. Keep the first implementation in that file using local classes with instance-owned state. The standalone build lives in `build/`.

## Current game

`Round` owns the state machine and puzzle data. `LockView` owns 3D entities, animation, bulbs, and the loss flash. `Hud` owns RmlUi, card clicks, keyboard bindings, and result controls. `loadLevel(id)` supplies the fixed level and is the seam for future generation.

A round starts with an automatic strike. A selected card starts a turn, then another strike. An occupied socket triggers shock and pick drop, then loss. A successful strike sets the pin and plays recoil. After recoil, the last strike opens the door. Otherwise the round starts the next queued card or waits for input.

## 1. Extract a reusable timed state machine

- Add a local `StateMachine` with a constructor, `change(state)`, and `update(dt)`. The machine owns the active state and elapsed time. Each instance has its own runtime state.
- Move phase durations and completion handlers into state definitions. Handlers call round methods to apply puzzle rules and choose the next state. Idle states such as `ready` and `finished` have no duration.
- Have `update(dt)` return the phase that advanced and its elapsed time and progress, even if it completed and entered a new phase. Keep the existing one-phase-per-update behavior, including dropping surplus time at a transition. This preserves the end pose of the strike, the initial flash, and the order of queued turns.
- Put the timer and current phase in the machine. Keep the hand, queue, occupied sockets, attempts, rotation, and result in `Round`. Keep engine objects out of both classes. Move the machine to a shared `require` module when a second consumer needs it.

## 2. Refresh presentation on changes

- Route card clicks and the 1–3 keyboard shortcuts through the same selection method. Route restart buttons and R through the same restart method. Refresh the HUD on changes to the visible hand, attempts, status, or result.
- Keep `OnUpdate` for keyboard polling and active animation. After polling input, return early when the round is idle. During active phases, advance the machine and apply the animation frame. Update bulbs and result feedback when the corresponding state changes.
- Preserve FIFO queueing during animations, including the opening strike. Hide a selected card immediately. Keep duplicate cards independently selectable by visible slot.
- Restart at any point clears the queue and active effects, restores the starting lock and HUD, and starts a fresh opening strike. A keyboard restart currently stops further processing for that frame.
- Use the engine APIs available in the installed build. RmlUi already delivers click callbacks. The Lua input API exposes `Pressed()` polling, and the current bindings expose no general timer scheduler. Keep explicit animation ticks.

## 3. Add event-driven game flow above the round

- Add a local `GameFlow` with `playing` and `results` states. It owns the active level ID and decides what to do with round completion, restart, retry, and future next-level requests. It has no frame timer.
- Enter `results` once when `Round` finishes the door-opening or pick-drop animation. Keep loss and win as round outcomes. Present that result through the HUD.
- Route Retry back to `playing` on the same level. Preserve Restart during play and from the result screen. Both use `loadLevel(id)` and the existing round reset path.
- Add a Next Level transition when there is a second level or a generator to supply one. Use an SRI autoload for `GameFlow` if it later needs to persist across title, level-select, or gameplay scenes.

## Verification and delivery

Capture the current behavior before editing and replay the same cases after each extraction. Use plain Lua for machine and round checks and the installed SRI runtime for engine integration.

| Case | Expected outcome |
|---|---|
| Start or restart | The opening strike sets socket 1 on the fixed level. Attempts go from four to three. |
| Rapid selection | Queue `+2, +2, +1` during the opening strike. Cards disappear immediately, execute in order, and open the door. |
| Losing sequence | Play `+1, +2`. Contact with the occupied socket starts one flash, the pick drops, and results appear after the animation. |
| Restart during turn or flash | Queued moves, shock lighting, and partially animated transforms reset. The opening strike replays. |
| Slow frame | An update larger than the current phase duration completes that phase once. The next phase advances on the following update. |
| Idle and results | Keyboard shortcuts remain available. The round, mesh animations, and HUD perform no recurring work while idle. |
| Retry | Results close, `GameFlow` goes back to `playing`, and a fresh round starts. |
| Independent instances | Selecting cards or advancing one machine does not alter another machine or its input level data. |

After the runtime checks pass, refresh `build/lockpick_puzzle.exe` and its accompanying files. SRI requires the packaging output to be outside the project. Stage the build there, then copy the verified package into `build/`.

Springs, linked sockets, undo, hints, level generation, and new scenes are follow-on work. When a solver or generator needs the puzzle rules, extract a pure transition function that can run without phase timers or rendering.