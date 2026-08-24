local Core = dofile("MPlusApplicationTracker/Core.lua")

local function assertEqual(actual, expected, label)
  if actual ~= expected then
    error((label or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function assertTrue(value, label)
  if not value then error(label or "expected true") end
end

local function newTracker()
  local character = {}
  local account = {}
  return Core.new(character, account), character, account
end

local tracker, character, account = newTracker()
assertEqual(tracker:sessionTotal(), 0, "empty session total")
assertEqual(tracker:elapsed(100), 0, "empty elapsed")

tracker:applicationApplied(100, "key-1")
assertEqual(tracker:sessionTotal(), 1, "first application")
assertEqual(tracker:elapsed(160), 60, "session timer")
assertEqual(character.totalApplications, 1, "character lifetime applications")
assertEqual(account.totalApplications, 1, "account lifetime applications")

tracker:applicationApplied(200, "key-2")
assertEqual(tracker:sessionTotal(), 2, "second application")
tracker:applicationOutcome("key-1", "declined")
tracker:applicationOutcome("key-2", "declined_full")
assertEqual(tracker.session.declined, 1, "declined count")
assertEqual(tracker.session.declined_full, 1, "full count")
assertEqual(tracker:sessionTotal(), 2, "terminal outcomes remain in total")

tracker:applicationApplied(300, "key-3")
tracker:applicationOutcome("key-3", "cancelled")
assertEqual(tracker.session.cancelled, 1, "cancelled count")
assertEqual(tracker:sessionTotal(), 3, "cancelled included")

tracker:applicationApplied(350, "pending-key")
local restored = Core.new(character, account)
assertEqual(restored:sessionTotal(), 4, "session survives reload")
assertEqual(restored.session.active["pending-key"], true, "active application survives reload")
assertEqual(restored:elapsed(400), 300, "restored timer")
tracker = restored

tracker:applicationOutcome("pending-key", "declined", 450)
tracker:applicationApplied(500, "key-4")
tracker:applicationOutcome("key-4", "inviteaccepted", 700)
assertTrue(tracker.session.ended, "accepted invite ends session")
assertEqual(tracker.session.accepted, 1, "accepted count")
assertEqual(tracker:elapsed(999), 600, "timer stops at acceptance")
assertEqual(#character.sessionHistory, 1, "accepted session history")
assertEqual(character.sessionHistory[1].accepted, 1, "accepted session history outcome")

tracker:resetSession()
assertEqual(tracker:sessionTotal(), 0, "reset session")
assertEqual(character.totalApplications, 5, "reset does not erase lifetime")
assertEqual(account.totalApplications, 5, "reset does not erase account lifetime")

tracker:applicationApplied(1000, "key-5")
assertEqual(tracker:sessionTotal(), 1, "new session starts after accepted invite")
assertEqual(tracker:elapsed(1010), 10, "new session timer")
tracker:endSession(1100, "manual")
assertTrue(tracker.session.ended, "manual end")
assertEqual(#character.sessionHistory, 2, "manual session history")
assertEqual(character.sessionHistory[2].reason, "manual", "manual history reason")
assertEqual(tracker:elapsed(9999), 100, "manual timer stops")
tracker:clearHistory()
assertEqual(#character.sessionHistory, 0, "character history clears")
assertEqual(#account.sessionHistory, 0, "account history clears")
assertEqual(character.totalApplications, 6, "clearing history keeps lifetime")
tracker:resetLifetime()
assertEqual(character.totalApplications, 0, "lifetime reset character")
assertEqual(account.totalApplications, 0, "lifetime reset account")
assertEqual(tracker:sessionTotal(), 0, "lifetime reset session")

print("all core tests passed")
