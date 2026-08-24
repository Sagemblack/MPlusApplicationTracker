local addonName = ...
local Core = MPlusApplicationTrackerCore

MPlusApplicationTrackerAccountDB = MPlusApplicationTrackerAccountDB or {}
MPlusApplicationTrackerCharacterDB = MPlusApplicationTrackerCharacterDB or {}

local tracker = Core.new(MPlusApplicationTrackerCharacterDB, MPlusApplicationTrackerAccountDB, MPlusApplicationTrackerCharacterDB.sessionState, MPlusApplicationTrackerAccountDB.sessionState)
local active = tracker.session.active
local frame = CreateFrame("Frame", "MPlusApplicationTrackerFrame", UIParent, "BackdropTemplate")
frame:SetSize(300, 285)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
frame:SetBackdropColor(0.04, 0.04, 0.04, 0.92)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("PUBLIC KEY PAIN")

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("TOPLEFT", 12, -38)
text:SetJustifyH("LEFT")
text:SetSpacing(3)

local function fmtTime(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function refresh()
  local s = tracker.session
  local elapsed = tracker:elapsed(GetTime())
  local activeCount = 0
  for _ in pairs(s.active) do activeCount = activeCount + 1 end
  text:SetText(string.format(
    "Applications: %d\nTime: %s\n\nDeclined: %d\nWithdrawn: %d\nGroup full: %d\nDelisted: %d\nExpired: %d\nInvited: %d\nAccepted: %d\nActive: %d",
    s.applications, fmtTime(elapsed), s.declined or 0, s.cancelled or 0,
    s.declined_full or 0, s.declined_delisted or 0, s.timedout or 0,
    s.invited or 0, s.accepted or 0, activeCount))
  if endButton then endButton:SetEnabled(s.startedAt ~= nil and not s.ended) end
end

local function refreshStats()
  local db = MPlusApplicationTrackerAccountDB
  local lines = {
    "ACCOUNT LIFETIME TOTALS",
    string.format("Applications: %d", db.totalApplications or 0),
    string.format("Declined: %d    Withdrawn: %d", db.declined or 0, db.cancelled or 0),
    string.format("Group full: %d    Delisted: %d", db.declined_full or 0, db.declined_delisted or 0),
    string.format("Expired: %d    Failed: %d", db.timedout or 0, db.failed or 0),
    string.format("Invited: %d    Accepted: %d", db.invited or 0, db.inviteaccepted or 0),
    "",
    "COMPLETED SESSION HISTORY",
  }
  local history = db.sessionHistory or {}
  if #history == 0 then
    table.insert(lines, "No completed sessions yet.")
  else
    local first = math.max(1, #history - 9)
    for index = #history, first, -1 do
      local session = history[index]
      table.insert(lines, string.format(
        "#%d  %s  %d applications  %s",
        index, session.reason == "accepted" and "Accepted" or "Ended",
        session.applications or 0, fmtTime(session.duration or 0)))
      table.insert(lines, string.format(
        "    Declined %d | Withdrawn %d | Full %d | Accepted %d",
        session.declined or 0, session.cancelled or 0,
        session.declined_full or 0, session.accepted or 0))
    end
  end
  statsText:SetText(table.concat(lines, "\n"))
end

local function makeButton(parent, label, width)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(label)
  return button
end

local statsFrame = CreateFrame("Frame", "MPlusApplicationTrackerStatsFrame", UIParent, "BackdropTemplate")
statsFrame:SetSize(420, 360)
statsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
statsFrame:SetMovable(true)
statsFrame:EnableMouse(true)
statsFrame:RegisterForDrag("LeftButton")
statsFrame:SetScript("OnDragStart", statsFrame.StartMoving)
statsFrame:SetScript("OnDragStop", statsFrame.StopMovingOrSizing)
statsFrame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
statsFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
local statsTitle = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
statsTitle:SetPoint("TOP", 0, -12)
statsTitle:SetText("M+ APPLICATION STATISTICS")
statsText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statsText:SetPoint("TOPLEFT", 16, -42)
statsText:SetJustifyH("LEFT")
statsText:SetSpacing(3)
local closeStats = makeButton(statsFrame, "Close", 90)
closeStats:SetPoint("BOTTOMRIGHT", -12, 12)
closeStats:SetScript("OnClick", function() statsFrame:Hide() end)
local clearHistoryButton = makeButton(statsFrame, "Clear History", 110)
clearHistoryButton:SetPoint("BOTTOMLEFT", 12, 12)
StaticPopupDialogs.MPLUSAPPLICATIONTRACKER_CLEAR_HISTORY = {
  text = "Clear all completed M+ session history?\nLifetime totals will not be changed.",
  button1 = "Clear History",
  button2 = "Cancel",
  OnAccept = function()
    tracker:clearHistory()
    refreshStats()
    print("M+ Application Tracker: session history cleared. Lifetime totals were kept.")
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}
clearHistoryButton:SetScript("OnClick", function()
  StaticPopup_Show("MPLUSAPPLICATIONTRACKER_CLEAR_HISTORY")
end)
local resetLifetimeButton = makeButton(statsFrame, "Reset Lifetime", 115)
resetLifetimeButton:SetPoint("BOTTOM", 0, 12)
StaticPopupDialogs.MPLUSAPPLICATIONTRACKER_RESET_LIFETIME = {
  text = "Reset all lifetime M+ tracker data?\nThis clears lifetime totals, history, and the current session.",
  button1 = "Reset Lifetime",
  button2 = "Cancel",
  OnAccept = function()
    tracker:resetLifetime()
    active = tracker.session.active
    frame:Hide()
    refresh()
    refreshStats()
    print("M+ Application Tracker: lifetime totals, history, and current session reset.")
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}
resetLifetimeButton:SetScript("OnClick", function()
  StaticPopup_Show("MPLUSAPPLICATIONTRACKER_RESET_LIFETIME")
end)
statsFrame:Hide()

endButton = makeButton(frame, "End Session", 125)
endButton:SetPoint("BOTTOMLEFT", 12, 12)
endButton:SetScript("OnClick", function()
  if tracker:endSession(GetTime(), "manual") then
    frame:Hide()
    refresh()
    refreshStats()
    print("M+ Application Tracker: session ended and saved to history.")
  end
end)
local historyButton = makeButton(frame, "Session History", 140)
historyButton:SetPoint("BOTTOMRIGHT", -12, 12)
historyButton:SetScript("OnClick", function()
  refreshStats()
  statsFrame:Show()
end)

local function isMythicPlus(searchResultID)
  if not C_LFGList or not C_LFGList.GetSearchResultInfo then return false end
  local info = C_LFGList.GetSearchResultInfo(searchResultID)
  if not info then return false end
  local activityID = info.activityID
  if not activityID and info.activityIDs then activityID = info.activityIDs[1] end
  if not activityID or not C_LFGList.GetActivityInfoTable then return false end
  local activity = C_LFGList.GetActivityInfoTable(activityID)
  return activity and activity.isMythicPlusActivity == true
end

local TERMINAL = {
  declined = true, cancelled = true, declined_full = true,
  declined_delisted = true, timedout = true, failed = true,
  invited = true, inviteaccepted = true, invitedeclined = true,
}

local function markApplication(searchResultID)
  if tracker:applicationApplied(GetTime(), searchResultID) then
    active = tracker.session.active
    active[searchResultID] = true
    frame:Show()
    return true
  end
  return false
end

local function syncPendingApplications()
  if not C_LFGList or not C_LFGList.GetApplications then return end
  local raw = { C_LFGList.GetApplications() }
  local applications = raw
  if type(raw[1]) == "table" then applications = raw[1] end
  for _, searchResultID in ipairs(applications) do
    if isMythicPlus(searchResultID) and not active[searchResultID] then
      local info = C_LFGList.GetApplicationInfo and C_LFGList.GetApplicationInfo(searchResultID)
      local status = info
      if type(info) == "table" then status = info.applicationStatus or info.pendingApplicationStatus end
      if status == "applied" or status == "pending" then markApplication(searchResultID) end
    end
  end
  refresh()
end

local function onApplicationStatus(_, searchResultID, newStatus)
  if newStatus == "applied" then
    if isMythicPlus(searchResultID) then markApplication(searchResultID) end
  elseif TERMINAL[newStatus] and active[searchResultID] then
    if tracker:applicationOutcome(searchResultID, newStatus, GetTime()) then
      active[searchResultID] = nil
      if tracker.session.ended then frame:Hide(); refreshStats() end
    end
  end
  refresh()
end

frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(1, syncPendingApplications)
  else
    onApplicationStatus(event, ...)
  end
end)
frame:SetScript("OnUpdate", function(_, elapsed)
  frame._refreshTimer = (frame._refreshTimer or 0) + elapsed
  if frame._refreshTimer >= 1 then
    frame._refreshTimer = 0
    syncPendingApplications()
  end
end)

SLASH_MPLUSAPPLICATIONTRACKER1 = "/mpat"
SLASH_MPLUSAPPLICATIONTRACKER2 = "/mpattracker"
SLASH_MPLUSAPPLICATIONTRACKER3 = "/mplus"
SlashCmdList.MPLUSAPPLICATIONTRACKER = function(message)
  message = string.lower(message or "")
  if message == "reset" then
    tracker:resetSession()
    refresh()
    print("M+ Application Tracker: session reset.")
  elseif message == "end" then
    if tracker:endSession(GetTime(), "manual") then
      frame:Hide()
      refresh()
      refreshStats()
      print("M+ Application Tracker: session ended and saved to history.")
    else
      print("M+ Application Tracker: no active session to end.")
    end
  elseif message == "history" or message == "stats" then
    refreshStats()
    statsFrame:Show()
  elseif message == "hide" then
    frame:Hide()
  elseif message == "show" then
    frame:Show(); refresh()
  elseif message == "status" or message == "" then
    refresh(); print(text:GetText())
  elseif message == "debug" then
    local activeCount = 0
    for _ in pairs(tracker.session.active) do activeCount = activeCount + 1 end
    print(string.format("M+ debug: session=%d startedAt=%s ended=%s active=%d charSaved=%s accountSaved=%s visible=%s", tracker.session.applications, tostring(tracker.session.startedAt), tostring(tracker.session.ended), activeCount, tostring(MPlusApplicationTrackerCharacterDB.mpatSessionStartedAt), tostring(MPlusApplicationTrackerAccountDB.mpatSessionStartedAt), tostring(frame:IsShown())))
  else
    print("M+ Application Tracker: /mplus show, /mplus hide, /mplus reset, /mplus status, /mplus debug")
  end
end

if tracker.session.startedAt and not tracker.session.ended then
  frame:Show()
else
  frame:Hide()
end
refresh()
print("M+ Application Tracker loaded. Type /mplus for help.")
