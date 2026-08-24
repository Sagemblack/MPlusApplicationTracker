# M+ Application Tracker

World of Warcraft Retail addon that tracks Mythic+ Premade Group Finder applications.

## Current MVP

- Counts Mythic+ applications per tracking session.
- Session timer begins with the first application.
- Session ends when an invitation is accepted.
- Tracks declined, player-cancelled, group-full, delisted, timed-out, failed, invited, invite-declined, and accepted outcomes separately.
- Stores character and account lifetime totals in SavedVariables.
- Provides a movable compact counter.
- Slash commands:
  - `/mplus status`
  - `/mplus show`
  - `/mplus hide`
  - `/mplus reset`

## Testing

```bash
lua tests/run.lua
luac -p MPlusApplicationTracker/Core.lua
luac -p MPlusApplicationTracker/Addon.lua
```

The final compatibility check is live testing in the current WoW Retail client, especially application status events and Mythic+ activity filtering.
