local addonName = ...
local Core = QueueSimulatorCore

QueueSimulatorAccountDB = QueueSimulatorAccountDB or MPlusApplicationTrackerAccountDB or {}
QueueSimulatorCharacterDB = QueueSimulatorCharacterDB or MPlusApplicationTrackerCharacterDB or {}
MPlusApplicationTrackerAccountDB = nil
MPlusApplicationTrackerCharacterDB = nil

local tracker = Core.new(QueueSimulatorCharacterDB, QueueSimulatorAccountDB, QueueSimulatorCharacterDB.sessionState, QueueSimulatorAccountDB.sessionState)
local active = tracker.session.active

local function fmtTime(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function makeBackdrop(target, opacity)
  target:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  target:SetBackdropColor(0.035, 0.045, 0.065, opacity or 0.94)
  target:SetBackdropBorderColor(0.35, 0.55, 0.85, 0.8)
end

local function makeButton(parent, label, width)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(label)
  return button
end

local TONE_COLORS = {
  primary = { 0.92, 0.82, 0.42 },
  active = { 0.35, 0.7, 1 },
  invited = { 1, 0.78, 0.25 },
  accepted = { 0.35, 0.9, 0.45 },
  declined = { 1, 0.38, 0.38 },
  full = { 1, 0.58, 0.22 },
  muted = { 0.72, 0.75, 0.82 },
}

local function setTone(fontString, tone)
  local color = TONE_COLORS[tone] or TONE_COLORS.muted
  fontString:SetTextColor(color[1], color[2], color[3])
end

local frame = CreateFrame("Frame", "QueueSimulatorFrame", UIParent, "BackdropTemplate")
frame:SetSize(330, 260)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
makeBackdrop(frame, 0.94)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("QUEUE SIMULATOR")
local elapsedText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
elapsedText:SetPoint("TOPRIGHT", -14, -15)
elapsedText:SetTextColor(0.72, 0.75, 0.82)

local applicationLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
applicationLabel:SetPoint("TOPLEFT", 16, -43)
applicationLabel:SetText("Applications")
local applicationValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
applicationValue:SetPoint("TOPRIGHT", -16, -38)
setTone(applicationValue, "primary")

local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(0.3, 0.5, 0.8, 0.45)
divider:SetPoint("TOPLEFT", 14, -72)
divider:SetPoint("TOPRIGHT", -14, -72)
divider:SetHeight(1)

local floatingRows = {}
for index = 1, 8 do
  local column = (index - 1) % 2
  local row = math.floor((index - 1) / 2)
  local x = 16 + column * 158
  local y = -88 - row * 28
  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", x, y)
  local value = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  value:SetPoint("TOPRIGHT", frame, "TOPLEFT", x + 140, y + 1)
  floatingRows[index] = { label = label, value = value }
end

local endButton = makeButton(frame, "End Session", 125)
endButton:SetPoint("BOTTOMLEFT", 14, 14)
local dashboardButton = makeButton(frame, "Dashboard", 125)
dashboardButton:SetPoint("BOTTOMRIGHT", -14, 14)

local dashboardFrame = CreateFrame("Frame", "QueueSimulatorDashboardFrame", UIParent, "BackdropTemplate")
dashboardFrame:SetSize(700, 520)
dashboardFrame:SetPoint("CENTER")
dashboardFrame:SetMovable(true)
dashboardFrame:EnableMouse(true)
dashboardFrame:RegisterForDrag("LeftButton")
dashboardFrame:SetScript("OnDragStart", dashboardFrame.StartMoving)
dashboardFrame:SetScript("OnDragStop", dashboardFrame.StopMovingOrSizing)
makeBackdrop(dashboardFrame, 0.98)
dashboardFrame:Hide()

local dashboardTitle = dashboardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
dashboardTitle:SetPoint("TOPLEFT", 18, -14)
dashboardTitle:SetText("QUEUE SIMULATOR DASHBOARD")

local summaryDefinitions = {
  { key = "sessions", label = "Sessions" },
  { key = "applications", label = "Applications" },
  { key = "accepted", label = "Accepted" },
  { key = "acceptanceRate", label = "Acceptance" },
  { key = "averageDuration", label = "Avg. session" },
}
local summaryCards = {}
for index, definition in ipairs(summaryDefinitions) do
  local card = CreateFrame("Frame", nil, dashboardFrame, "BackdropTemplate")
  card:SetSize(124, 58)
  card:SetPoint("TOPLEFT", 18 + (index - 1) * 133, -46)
  makeBackdrop(card, 0.55)
  card:SetBackdropBorderColor(0.2, 0.35, 0.58, 0.65)
  local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOP", 0, -8)
  label:SetText(definition.label)
  label:SetTextColor(0.68, 0.72, 0.8)
  local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  value:SetPoint("BOTTOM", 0, 8)
  setTone(value, definition.key == "accepted" and "accepted" or "primary")
  summaryCards[definition.key] = value
end

local outcomeDefinitions = {
  { key = "declined", label = "Declined", tone = "declined" },
  { key = "cancelled", label = "Withdrawn", tone = "muted" },
  { key = "declined_full", label = "Group full", tone = "full" },
  { key = "declined_delisted", label = "Delisted", tone = "muted" },
  { key = "timedout", label = "Expired", tone = "muted" },
  { key = "invited", label = "Invited", tone = "invited" },
  { key = "inviteaccepted", label = "Accepted", tone = "accepted" },
  { key = "failed", label = "Failed", tone = "muted" },
}
local lifetimeOutcomeValues = {}
for index, definition in ipairs(outcomeDefinitions) do
  local column = (index - 1) % 4
  local row = math.floor((index - 1) / 4)
  local x = 20 + column * 168
  local y = -122 - row * 25
  local label = dashboardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", x, y)
  label:SetText(definition.label)
  local value = dashboardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  value:SetPoint("TOPLEFT", x + 105, y + 1)
  setTone(value, definition.tone)
  lifetimeOutcomeValues[definition.key] = value
end

local historyTitle = dashboardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
historyTitle:SetPoint("TOPLEFT", 20, -182)
historyTitle:SetText("RECENT SESSIONS")
local historyHint = dashboardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
historyHint:SetPoint("TOPRIGHT", -34, -183)
historyHint:SetText("Click a session to show its outcome details")
historyHint:SetTextColor(0.58, 0.62, 0.7)

local statsScrollFrame = CreateFrame("ScrollFrame", nil, dashboardFrame, "UIPanelScrollFrameTemplate")
statsScrollFrame:SetPoint("TOPLEFT", 18, -205)
statsScrollFrame:SetPoint("BOTTOMRIGHT", -34, 52)
local statsScrollChild = CreateFrame("Frame", nil, statsScrollFrame)
statsScrollChild:SetSize(638, 1)
statsScrollFrame:SetScrollChild(statsScrollChild)
local expandedSessions = {}
local sessionRowFrames = {}

local refreshDashboard
local function clearSessionRows()
  for _, rowFrame in ipairs(sessionRowFrames) do rowFrame:Hide() end
end

local function acquireSessionRow(poolIndex)
  local rowFrame = sessionRowFrames[poolIndex]
  if rowFrame then return rowFrame end

  rowFrame = CreateFrame("Frame", nil, statsScrollChild, "BackdropTemplate")
  makeBackdrop(rowFrame, 0.45)
  rowFrame:SetBackdropBorderColor(0.18, 0.28, 0.45, 0.55)
  rowFrame.toggle = CreateFrame("Button", nil, rowFrame)
  rowFrame.toggle:SetPoint("TOPLEFT", 5, -4)
  rowFrame.toggle:SetPoint("TOPRIGHT", -5, -4)
  rowFrame.toggle:SetHeight(28)
  rowFrame.heading = rowFrame.toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  rowFrame.heading:SetPoint("LEFT", 7, 0)
  rowFrame.summary = rowFrame.toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rowFrame.summary:SetPoint("RIGHT", -7, 0)
  rowFrame.details = {}
  for detailIndex = 0, 9 do
    local column = detailIndex % 4
    local detailRow = math.floor(detailIndex / 4)
    local x = 14 + column * 152
    local detailY = -47 - detailRow * 26
    local label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, detailY)
    local value = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    value:SetPoint("TOPLEFT", x + 96, detailY + 1)
    rowFrame.details[detailIndex + 1] = { label = label, value = value }
  end
  sessionRowFrames[poolIndex] = rowFrame
  return rowFrame
end

local function createSessionRow(row, y, poolIndex)
  local expanded = expandedSessions[row.index] == true
  local height = expanded and 138 or 38
  local rowFrame = acquireSessionRow(poolIndex)
  rowFrame:ClearAllPoints()
  rowFrame:SetPoint("TOPLEFT", 0, -y)
  rowFrame:SetSize(630, height)
  rowFrame:Show()
  rowFrame.heading:SetText(string.format("%s  Session #%d", expanded and "–" or "+", row.index))
  rowFrame.summary:SetText(string.format("%d applications   %s   %d accepted", row.applications, fmtTime(row.duration), row.accepted))
  rowFrame.toggle:SetScript("OnClick", function()
    expandedSessions[row.index] = not expanded
    refreshDashboard()
  end)

  for index = 2, #row.stats do
    local stat = row.stats[index]
    local detail = rowFrame.details[index - 1]
    detail.label:SetText(stat.label)
    detail.value:SetText(stat.value)
    setTone(detail.value, stat.tone)
    detail.label:SetShown(expanded)
    detail.value:SetShown(expanded)
  end
  return height
end

local emptyHistory = statsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
emptyHistory:SetPoint("TOPLEFT", 8, -12)
emptyHistory:SetText("No completed sessions yet. Start applying to Mythic+ groups to begin tracking.")
emptyHistory:Hide()

refreshDashboard = function()
  local db = QueueSimulatorAccountDB
  local summary = Core.lifetimeSummary(db)
  summaryCards.sessions:SetText(summary.sessions)
  summaryCards.applications:SetText(summary.applications)
  summaryCards.accepted:SetText(summary.accepted)
  summaryCards.acceptanceRate:SetText(string.format("%.1f%%", summary.acceptanceRate))
  summaryCards.averageDuration:SetText(fmtTime(summary.averageDuration))
  for _, definition in ipairs(outcomeDefinitions) do
    lifetimeOutcomeValues[definition.key]:SetText(db[definition.key] or 0)
  end

  clearSessionRows()
  local rows = Core.historyRows(db.sessionHistory, 50)
  emptyHistory:SetShown(#rows == 0)
  local y = 0
  for index, row in ipairs(rows) do y = y + createSessionRow(row, y, index) + 6 end
  statsScrollChild:SetHeight(math.max(statsScrollFrame:GetHeight(), y))
end

local function showDashboard()
  refreshDashboard()
  dashboardFrame:Show()
  dashboardFrame:Raise()
end

local function refresh()
  local stats = Core.sessionStats(tracker.session)
  applicationValue:SetText(stats[1].value)
  elapsedText:SetText(fmtTime(tracker:elapsed(GetTime())))
  for index = 2, #stats do
    local row = floatingRows[index - 1]
    row.label:SetText(stats[index].label)
    row.value:SetText(stats[index].value)
    setTone(row.value, stats[index].tone)
  end
  endButton:SetEnabled(tracker.session.startedAt ~= nil and not tracker.session.ended)
end

local closeDashboard = makeButton(dashboardFrame, "Close", 90)
closeDashboard:SetPoint("BOTTOMRIGHT", -14, 14)
closeDashboard:SetScript("OnClick", function() dashboardFrame:Hide() end)
local clearHistoryButton = makeButton(dashboardFrame, "Clear History", 110)
clearHistoryButton:SetPoint("BOTTOMLEFT", 14, 14)
StaticPopupDialogs.QUEUESIMULATOR_CLEAR_HISTORY = {
  text = "Clear all completed M+ session history?\nLifetime totals will not be changed.",
  button1 = "Clear History",
  button2 = "Cancel",
  OnAccept = function()
    tracker:clearHistory()
    refreshDashboard()
    print("Queue Simulator: session history cleared. Lifetime totals were kept.")
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}
clearHistoryButton:SetScript("OnClick", function()
  StaticPopup_Show("QUEUESIMULATOR_CLEAR_HISTORY")
end)
local resetLifetimeButton = makeButton(dashboardFrame, "Reset Lifetime", 115)
resetLifetimeButton:SetPoint("BOTTOM", 0, 14)
StaticPopupDialogs.QUEUESIMULATOR_RESET_LIFETIME = {
  text = "Reset all lifetime M+ tracker data?\nThis clears lifetime totals, history, and the current session.",
  button1 = "Reset Lifetime",
  button2 = "Cancel",
  OnAccept = function()
    tracker:resetLifetime()
    active = tracker.session.active
    frame:Hide()
    refresh()
    refreshDashboard()
    print("Queue Simulator: lifetime totals, history, and current session reset.")
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}
resetLifetimeButton:SetScript("OnClick", function()
  StaticPopup_Show("QUEUESIMULATOR_RESET_LIFETIME")
end)

endButton:SetScript("OnClick", function()
  if tracker:endSession(GetTime(), "manual") then
    frame:Hide()
    refresh()
    refreshDashboard()
    print("Queue Simulator: session ended and saved to history.")
  end
end)
dashboardButton:SetScript("OnClick", showDashboard)

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
  inviteaccepted = true, invitedeclined = true,
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
  local changed = false
  if type(raw[1]) == "table" then applications = raw[1] end
  for _, searchResultID in ipairs(applications) do
    if isMythicPlus(searchResultID) and not active[searchResultID] then
      local info = C_LFGList.GetApplicationInfo and C_LFGList.GetApplicationInfo(searchResultID)
      local status = info
      if type(info) == "table" then status = info.applicationStatus or info.pendingApplicationStatus end
      if status == "applied" or status == "pending" then
        changed = markApplication(searchResultID) or changed
      end
    end
  end
  refresh()
  if changed and dashboardFrame:IsShown() then refreshDashboard() end
end

local function onApplicationStatus(_, searchResultID, newStatus)
  local changed = false
  if newStatus == "applied" then
    if isMythicPlus(searchResultID) then changed = markApplication(searchResultID) end
  elseif newStatus == "invited" and active[searchResultID] then
    changed = tracker:applicationOutcome(searchResultID, newStatus, GetTime())
  elseif TERMINAL[newStatus] and active[searchResultID] then
    if tracker:applicationOutcome(searchResultID, newStatus, GetTime()) then
      changed = true
      active[searchResultID] = nil
      if tracker.session.ended then frame:Hide() end
    end
  end
  refresh()
  if changed and dashboardFrame:IsShown() then refreshDashboard() end
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

SLASH_QUEUESIMULATOR1 = "/qsim"
SlashCmdList.QUEUESIMULATOR = function(message)
  message = string.lower(message or "")
  if message == "reset" then
    tracker:resetSession()
    refresh()
    print("Queue Simulator: session reset.")
  elseif message == "end" then
    if tracker:endSession(GetTime(), "manual") then
      frame:Hide()
      refresh()
      refreshDashboard()
      print("Queue Simulator: session ended and saved to history.")
    else
      print("Queue Simulator: no active session to end.")
    end
  elseif message == "history" or message == "stats" then
    showDashboard()
  elseif message == "hide" then
    frame:Hide()
  elseif message == "show" then
    frame:Show(); refresh()
  elseif message == "" then
    showDashboard()
  elseif message == "status" then
    local stats = Core.sessionStats(tracker.session)
    print(string.format(
      "Queue Simulator: %d applications, %d active, %d invited, %d accepted, %s elapsed.",
      stats[1].value, stats[2].value, stats[3].value, stats[4].value,
      fmtTime(tracker:elapsed(GetTime()))))
  elseif message == "debug" then
    local activeCount = Core.activeCount(tracker.session.active)
    print(string.format("Queue Simulator debug: session=%d startedAt=%s ended=%s active=%d charSaved=%s accountSaved=%s visible=%s", tracker.session.applications, tostring(tracker.session.startedAt), tostring(tracker.session.ended), activeCount, tostring(QueueSimulatorCharacterDB.mpatSessionStartedAt), tostring(QueueSimulatorAccountDB.mpatSessionStartedAt), tostring(frame:IsShown())))
  else
    print("Queue Simulator: /qsim show, /qsim hide, /qsim reset, /qsim status, /qsim history, /qsim debug")
  end
end

if tracker.session.startedAt and not tracker.session.ended then
  frame:Show()
else
  frame:Hide()
end
refresh()
print("Queue Simulator loaded. Type /qsim for help.")
