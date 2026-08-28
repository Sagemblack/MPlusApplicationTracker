local M = {}

local OUTCOMES = {
  "declined",
  "cancelled",
  "declined_full",
  "declined_delisted",
  "timedout",
  "failed",
  "invited",
  "inviteaccepted",
  "invitedeclined",
}

local function ensureTotals(store)
  store.totalApplications = store.totalApplications or 0
  if store.totalSessionTime == nil then
    store.totalSessionTime = 0
    for _, session in ipairs(store.sessionHistory or {}) do
      store.totalSessionTime = store.totalSessionTime + (session.duration or 0)
    end
  end
  for _, outcome in ipairs(OUTCOMES) do
    store[outcome] = store[outcome] or 0
  end
end

local function copyActive(source)
  local active = {}
  for applicationID, value in pairs(source or {}) do active[applicationID] = value end
  return active
end

local function restoreSession(store)
  local startedAt = store and (store.mpatSessionStartedAt or store.startedAt)
  if not startedAt then
    return { applications = 0, active = {}, ended = false }
  end
  local ended = store.mpatSessionEnded
  if ended == nil then ended = store.ended == true end
  return {
    applications = store.mpatSessionApplications or store.applications or 0,
    active = copyActive(store.mpatSessionActive or store.active),
    startedAt = startedAt,
    endedAt = store.mpatSessionEndedAt or store.endedAt,
    ended = ended,
    recorded = store.mpatSessionRecorded or store.recorded == true,
    declined = store.mpatSessionDeclined or store.declined or 0,
    cancelled = store.mpatSessionCancelled or store.cancelled or 0,
    declined_full = store.mpatSessionDeclinedFull or store.declined_full or 0,
    declined_delisted = store.mpatSessionDeclinedDelisted or store.declined_delisted or 0,
    timedout = store.mpatSessionTimedout or store.timedout or 0,
    failed = store.mpatSessionFailed or store.failed or 0,
    invited = store.mpatSessionInvited or store.invited or 0,
    inviteaccepted = store.mpatSessionInviteAccepted or store.inviteaccepted or 0,
    accepted = store.mpatSessionAccepted or store.accepted or 0,
    invitedeclined = store.mpatSessionInviteDeclined or store.invitedeclined or 0,
  }
end

local function saveSession(store, session)
  if not store then return end
  store.mpatSessionApplications = session.applications
  store.mpatSessionActive = copyActive(session.active)
  store.mpatSessionStartedAt = session.startedAt
  store.mpatSessionEndedAt = session.endedAt
  store.mpatSessionEnded = session.ended
  store.mpatSessionRecorded = session.recorded == true
  store.mpatSessionAccepted = session.accepted or 0
  for _, outcome in ipairs(OUTCOMES) do
    store["mpatSession" .. outcome] = session[outcome] or 0
  end
  -- Keep the nested form for compatibility with the previous 0.1.x builds.
  store.applications = session.applications
  store.active = copyActive(session.active)
  store.startedAt = session.startedAt
  store.endedAt = session.endedAt
  store.ended = session.ended
  store.recorded = session.recorded == true
  for _, outcome in ipairs(OUTCOMES) do store[outcome] = session[outcome] or 0 end
  store.accepted = session.accepted or 0
end

local function recordSession(self, reason)
  if self.session.recorded or not self.session.startedAt then return end
  local summary = {
    startedAt = self.session.startedAt,
    endedAt = self.session.endedAt,
    duration = self:elapsed(self.session.endedAt or self.session.startedAt),
    applications = self.session.applications,
    reason = reason or "ended",
  }
  for _, outcome in ipairs(OUTCOMES) do summary[outcome] = self.session[outcome] or 0 end
  summary.accepted = self.session.accepted or 0
  self.session.recorded = true
  self.character.sessionHistory = self.character.sessionHistory or {}
  self.account.sessionHistory = self.account.sessionHistory or {}
  self.character.totalSessionTime = self.character.totalSessionTime + summary.duration
  self.account.totalSessionTime = self.account.totalSessionTime + summary.duration
  table.insert(self.character.sessionHistory, summary)
  table.insert(self.account.sessionHistory, summary)
end

function M.new(characterTotals, accountTotals, sessionStore, fallbackSessionStore)
  ensureTotals(characterTotals)
  ensureTotals(accountTotals)
  sessionStore = sessionStore or characterTotals.sessionState
  fallbackSessionStore = fallbackSessionStore or accountTotals.sessionState
  if (not sessionStore or not sessionStore.startedAt) and fallbackSessionStore and fallbackSessionStore.startedAt then
    sessionStore = fallbackSessionStore
    characterTotals.sessionState = sessionStore
  end
  sessionStore = sessionStore or {}
  characterTotals.sessionState = sessionStore
  accountTotals.sessionState = fallbackSessionStore or accountTotals.sessionState or {}
  local self = {
    character = characterTotals,
    account = accountTotals,
    sessionStore = sessionStore,
    mirrorSessionStore = accountTotals.sessionState,
    session = restoreSession(sessionStore),
  }
  return setmetatable(self, { __index = M })
end

function M:applicationApplied(now, applicationID)
  if self.session.ended then self:resetSession() end
  if not self.session.startedAt then self.session.startedAt = now end
  if self.session.active[applicationID] then return false end
  self.session.active[applicationID] = true
  self.session.applications = self.session.applications + 1
  self.character.totalApplications = self.character.totalApplications + 1
  self.account.totalApplications = self.account.totalApplications + 1
  saveSession(self.sessionStore, self.session)
  if self.mirrorSessionStore ~= self.sessionStore then saveSession(self.mirrorSessionStore, self.session) end
  return true
end

function M:endSession(now, reason)
  if not self.session.startedAt or self.session.ended then return false end
  self.session.ended = true
  self.session.endedAt = now or self.session.startedAt
  recordSession(self, reason or "manual")
  for applicationID in pairs(self.session.active) do self.session.active[applicationID] = nil end
  saveSession(self.sessionStore, self.session)
  if self.mirrorSessionStore ~= self.sessionStore then saveSession(self.mirrorSessionStore, self.session) end
  return true
end

function M:applicationOutcome(applicationID, outcome, now)
  if not self.session.active[applicationID] then return false end
  if outcome ~= "invited" then self.session.active[applicationID] = nil end
  self.session[outcome] = (self.session[outcome] or 0) + 1
  self.character[outcome] = self.character[outcome] + 1
  self.account[outcome] = self.account[outcome] + 1
  if outcome == "inviteaccepted" then
    self.session.accepted = (self.session.accepted or 0) + 1
    self:endSession(now, "accepted")
  end
  saveSession(self.sessionStore, self.session)
  if self.mirrorSessionStore ~= self.sessionStore then saveSession(self.mirrorSessionStore, self.session) end
  return true
end

function M:sessionTotal()
  return self.session.applications
end

function M:elapsed(now)
  if not self.session.startedAt then return 0 end
  local finish = self.session.endedAt or now
  return math.max(0, finish - self.session.startedAt)
end

function M:clearHistory()
  self.character.sessionHistory = {}
  self.account.sessionHistory = {}
end

function M:resetLifetime()
  local function clearTotals(store)
    store.totalApplications = 0
    store.totalSessionTime = 0
    for _, outcome in ipairs(OUTCOMES) do store[outcome] = 0 end
    store.sessionHistory = {}
  end
  clearTotals(self.character)
  clearTotals(self.account)
  self:resetSession()
end

function M:resetSession()
  self.session = { applications = 0, active = {}, ended = false }
  saveSession(self.sessionStore, self.session)
  if self.mirrorSessionStore ~= self.sessionStore then saveSession(self.mirrorSessionStore, self.session) end
end

function M.outcomes()
  local copy = {}
  for i, outcome in ipairs(OUTCOMES) do copy[i] = outcome end
  return copy
end

_G.QueueSimulatorCore = M
return M
