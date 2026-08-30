# Queue Simulator

![Queue Simulator](assets/queue-simulator-thumbnail.png)

Queue Simulator is a World of Warcraft Retail addon that tracks Mythic+ Premade Group Finder applications and the painful wait behind them.

## Features

- Counts Mythic+ applications per tracking session.
- Session timer begins with the first application.
- Session ends when an invitation is accepted.
- Tracks declined, player-cancelled, group-full, delisted, timed-out, failed, invited, invite-declined, and accepted outcomes separately.
- Stores character and account lifetime totals in SavedVariables.
- Provides a compact, movable live tracker designed to sit beside Group Finder.
- Displays live outcomes in aligned, color-assisted rows rather than a text block.
- Includes a larger dashboard with lifetime totals, acceptance rate, average session duration, and expandable recent sessions.
- Slash commands:
  - `/qsim` opens the dashboard
  - `/qsim status`
  - `/qsim show`
  - `/qsim hide`
  - `/qsim end`
  - `/qsim reset`
  - `/qsim history`

## Outcome clarification

Queue Simulator records the underlying application statuses reported by WoW and keeps **Declined** and **Delisted** as separate, non-overlapping outcomes. Blizzard's Premade Group Finder displays the word **Declined** for both an application actually declined by the group leader and a listing that was delisted. As a result, an entry shown as **Declined** in Blizzard's queue may correctly increase Queue Simulator's **Delisted** counter instead of its **Declined** counter.

## Testing

```bash
lua tests/run.lua
luac -p QueueSimulator/Core.lua
luac -p QueueSimulator/Addon.lua
```

The final compatibility check is live testing in the current WoW Retail client, especially application status events and Mythic+ activity filtering.
