--[[ Control del archivo WoWCombatLog.txt.
     El estado real pertenece a LoggingCombat(); el perfil sólo guarda automatización y filtros. ]]

local ADDON_NAME, ns = ...

local CL = {}
ns.CombatLog = CL

local QUERY_CACHE_SECONDS = 1

local function db()
  if ns.Profile and ns.Profile.GetRightPanelWidgetsModel then
    return ns.Profile:GetRightPanelWidgetsModel()
  end
  return {}
end

local function notify(text)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff65d8ffChukie UI|r: " .. tostring(text))
  end
end

local function now()
  return GetTime and GetTime() or 0
end

function CL:GetState(force)
  if type(LoggingCombat) ~= "function" then
    self._available = false
    self._state = false
    return false
  end
  self._available = true
  if not force and self._state ~= nil and (now() - (self._lastQueryAt or 0)) < QUERY_CACHE_SECONDS then
    return self._state
  end
  local ok, state = pcall(LoggingCombat)
  self._lastQueryAt = now()
  if ok and type(state) == "boolean" then
    self._state = state
  end
  return self._state == true
end

function CL:RefreshWidget()
  local rw = ns.RightPanelWidgets
  if rw and rw.ApplyCombatLogVisual then
    rw:ApplyCombatLogVisual()
  end
end

function CL:SetState(wanted, source)
  wanted = wanted == true
  if type(LoggingCombat) ~= "function" then
    notify("LoggingCombat no está disponible en este cliente.")
    return false
  end
  local current = self:GetState(false)
  if current == wanted then
    self._state = current
    self:RefreshWidget()
    return true
  end
  local ok, result = pcall(LoggingCombat, wanted)
  self._lastQueryAt = now()
  if not ok or type(result) ~= "boolean" then
    notify("No se pudo cambiar Combat Log (posible límite de llamadas).")
    return false
  end
  self._state = result
  if source == "auto" and self._state then
    self._autoStarted = true
  elseif source == "manual" then
    self._autoStarted = nil
  end
  self:RefreshWidget()
  return self._state == wanted
end

function CL:Toggle()
  local wanted = not self:GetState(false)
  if self:SetState(wanted, "manual") then
    notify(wanted and "Combat Log activado." or "Combat Log desactivado.")
  end
end

local function classify(instanceType, difficultyID)
  difficultyID = tonumber(difficultyID) or 0
  if instanceType == "party" then
    if difficultyID == 8 then
      return "dungeonMythicPlus"
    elseif difficultyID == 23 then
      return "dungeonMythic"
    elseif difficultyID == 24 then
      return "timewalking"
    elseif difficultyID == 2 then
      return "dungeonHeroic"
    end
    return "dungeonNormal"
  elseif instanceType == "raid" then
    if difficultyID == 16 then
      return "raidMythic"
    elseif difficultyID == 15 or difficultyID == 5 or difficultyID == 6 then
      return "raidHeroic"
    elseif difficultyID == 17 or difficultyID == 7 or difficultyID == 151 then
      return "raidLfr"
    elseif difficultyID == 33 then
      return "timewalking"
    end
    return "raidNormal"
  elseif instanceType == "scenario" then
    return "delve"
  elseif instanceType == "arena" or instanceType == "pvp" then
    return "pvp"
  end
  return nil
end

function CL:GetCurrentContext()
  if type(GetInstanceInfo) ~= "function" then
    return nil
  end
  local name, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  local challengeMapID
  if difficultyID == 8 and C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
    local ok, value = pcall(C_ChallengeMode.GetActiveChallengeMapID)
    if ok then
      challengeMapID = tonumber(value)
    end
  end
  local contentType = classify(instanceType, difficultyID)
  if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
    local ok, inDelve = pcall(C_PartyInfo.IsDelveInProgress)
    if ok and inDelve then
      contentType = "delve"
    end
  end
  return {
    name = name,
    instanceType = instanceType,
    difficultyID = tonumber(difficultyID) or 0,
    difficultyName = difficultyName,
    instanceID = tonumber(instanceID),
    challengeMapID = challengeMapID,
    contentType = contentType,
  }
end

local function hasSpecificSelections(selections)
  if type(selections) ~= "table" then
    return false
  end
  for _, selected in pairs(selections) do
    if selected == true then
      return true
    end
  end
  return false
end

function CL:ContextMatches(ctx)
  if not ctx or not ctx.contentType then
    return false
  end
  local d = db()
  local types = type(d.combatLogTypes) == "table" and d.combatLogTypes or {}
  if types[ctx.contentType] ~= true then
    return false
  end
  local selected = d.combatLogInstances
  if not hasSpecificSelections(selected) then
    return true
  end
  if ctx.instanceID and selected["instance:" .. ctx.instanceID] == true then
    return true
  end
  if ctx.challengeMapID and selected["challenge:" .. ctx.challengeMapID] == true then
    return true
  end
  return false
end

function CL:ApplyAdvancedSetting()
  local d = db()
  if d.combatLogAdvanced ~= nil and GetCVar and SetCVar and GetCVar("advancedCombatLogging") ~= nil then
    pcall(SetCVar, "advancedCombatLogging", d.combatLogAdvanced == true and "1" or "0")
  end
end

function CL:EvaluateAuto()
  local d = db()
  local active = self:GetState(false)
  local profile = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if profile and profile.enabled == false then
    if self._autoStarted and active and d.combatLogStopOnExit ~= false then
      self:SetState(false, "auto")
    end
    self._autoStarted = nil
    return
  end
  self:ApplyAdvancedSetting()
  local shouldLog = self:ContextMatches(self:GetCurrentContext())
  if shouldLog then
    if not active and self:SetState(true, "auto") then
      notify("Combat Log autoactivado para esta instancia.")
    end
  elseif self._autoStarted and d.combatLogStopOnExit ~= false then
    if active and self:SetState(false, "auto") then
      notify("Combat Log automático detenido.")
    end
    self._autoStarted = nil
  end
  self:RefreshWidget()
end

function CL:AddCurrentInstance()
  local ctx = self:GetCurrentContext()
  if not ctx or not ctx.contentType or (not ctx.instanceID and not ctx.challengeMapID) then
    return false, "No estás dentro de una instancia identificable."
  end
  local d = db()
  d.combatLogInstances = type(d.combatLogInstances) == "table" and d.combatLogInstances or {}
  local key
  if ctx.contentType == "dungeonMythicPlus" and ctx.challengeMapID then
    key = "challenge:" .. ctx.challengeMapID
  else
    key = "instance:" .. ctx.instanceID
  end
  d.combatLogInstances[key] = true
  d.combatLogInstanceNames = type(d.combatLogInstanceNames) == "table" and d.combatLogInstanceNames or {}
  d.combatLogInstanceNames[key] = ctx.name or key
  return true, ctx.name or key
end

function CL:RefreshConfig()
  self:EvaluateAuto()
  if ns.RightPanelWidgets and ns.RightPanelWidgets.Refresh then
    ns.RightPanelWidgets:Refresh()
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pcall(events.RegisterEvent, events, "CHALLENGE_MODE_START")
pcall(events.RegisterEvent, events, "CHALLENGE_MODE_COMPLETED")
pcall(events.RegisterEvent, events, "ACTIVE_DELVE_DATA_UPDATE")
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 ~= ADDON_NAME then
    return
  end
  if event == "ADDON_LOADED" then
    CL:GetState(true)
    local profile = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
    if not profile or profile.enabled ~= false then
      CL:ApplyAdvancedSetting()
    end
    return
  end
  C_Timer.After(1, function()
    CL:EvaluateAuto()
  end)
end)

--- Sincroniza cambios hechos con /combatlog u otro addon sin consumir el límite de la API.
CL._syncTicker = C_Timer.NewTicker(5, function()
  local before = CL._state
  local current = CL:GetState(true)
  if before ~= current then
    CL._autoStarted = nil
    CL:RefreshWidget()
  end
end)
