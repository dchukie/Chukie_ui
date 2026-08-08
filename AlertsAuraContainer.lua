--[[ AuraContainer (12.1+ / Interface 120100): Blizzard asigna el aura; nosotros presentamos.
    En 12.0.7 sin API → HasAuraContainerAPI() = false y path legacy. ]]

local _, ns = ...
local A = ns.Alerts
if not A then
  return
end

local SIZE_MIN = A.SIZE_MIN or 24
local SIZE_MAX = A.SIZE_MAX or 768

local function clamp(n, lo, hi)
  n = tonumber(n) or lo
  if n < lo then
    return lo
  end
  if n > hi then
    return hi
  end
  return n
end

local _apiAvailable = nil
local _pendingCombatCreates = {}

--- Invalidar caché (p.ej. tras /reload o cambio de build).
function A:ResetAuraContainerApiCache()
  _apiAvailable = nil
end

--- true si el cliente expone AuraContainer usable (12.1+).
function A:HasAuraContainerAPI()
  if _apiAvailable ~= nil then
    return _apiAvailable
  end
  -- No crear frames en combate (12.1 error/Lua error intencional).
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  local templates = { "CustomAuraContainerTemplate", "ManagedAuraContainerTemplate", nil }
  for ti = 1, #templates do
    local ok, frame
    if templates[ti] then
      ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, templates[ti])
    else
      ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent)
    end
    if ok and frame then
      local hasGroup = type(frame.AddAuraGroup) == "function"
      local hasSlot = type(frame.AddAuraSlot) == "function"
      local hasUnit = type(frame.SetUnit) == "function"
      frame:Hide()
      pcall(frame.SetParent, frame, nil)
      if hasUnit and (hasGroup or hasSlot) then
        _apiAvailable = true
        return true
      end
    end
  end
  _apiAvailable = false
  return false
end

function A:GetAuraDisplayBackend()
  if self:HasAuraContainerAPI() then
    return "container"
  end
  return "legacy"
end

--- Reglas que pueden vivir en Container (presencia pura; Blizzard controla show/hide).
function A:CanUseAuraContainerForRule(rule)
  if not rule or rule.kind ~= "aura" then
    return false
  end
  if not self:HasAuraContainerAPI() then
    return false
  end
  if (tonumber(rule.spellId) or 0) <= 0 then
    return false
  end
  local mode = rule.auraShow or "present"
  if mode ~= "present" then
    return false
  end
  if rule.chargeFilter and rule.chargeFilter.enabled then
    return false
  end
  if self._livePreview and self._livePreview.ruleId == rule.id then
    return false
  end
  return true
end

local function filterStringForRule(rule)
  local f = rule.auraFilter or "both"
  if f == "HARMFUL" then
    return "HARMFUL|INCLUDE_NAME_PLATE_ONLY"
  end
  if f == "HELPFUL" then
    return "HELPFUL|INCLUDE_NAME_PLATE_ONLY"
  end
  return "HELPFUL|INCLUDE_NAME_PLATE_ONLY"
end

local function applyPointTo(frame, pointCfg)
  frame:ClearAllPoints()
  local x = tonumber(pointCfg and pointCfg[2]) or 0
  local y = tonumber(pointCfg and pointCfg[3]) or 0
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function styleAuraButton(auraButton, rule)
  if not auraButton or not rule then
    return
  end
  -- initializeFrame corre ANTES de que el botón quede forbidden en secreto (12.1).
  local size = clamp(rule.size, SIZE_MIN, SIZE_MAX)
  local display = rule.display or "icon"
  local c = rule.color or { 1, 1, 1 }
  local a = clamp(rule.alpha, 0, 1)
  pcall(auraButton.SetSize, auraButton, size, size)
  pcall(auraButton.EnableMouse, auraButton, false)

  if display == "aura" then
    local path = A:ResolveAuraPath(rule)
    local pair = rule.auraLayout == "pair"
    local gap = tonumber(rule.pairGap) or 80
    if pair then
      pcall(auraButton.SetSize, auraButton, size * 2 + gap, size)
    end
    local L = auraButton._chukieArtL
    if not L then
      L = auraButton:CreateTexture(nil, "ARTWORK")
      auraButton._chukieArtL = L
    end
    L:SetTexture(path)
    L:SetSize(size, size)
    L:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
    L:SetAlpha(a)
    L:ClearAllPoints()
    if pair then
      L:SetPoint("CENTER", auraButton, "CENTER", -gap / 2, 0)
      L:SetTexCoord(0, 1, 0, 1)
      local R = auraButton._chukieArtR
      if not R then
        R = auraButton:CreateTexture(nil, "ARTWORK")
        auraButton._chukieArtR = R
      end
      R:SetTexture(path)
      R:SetSize(size, size)
      R:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
      R:SetAlpha(a)
      R:ClearAllPoints()
      R:SetPoint("CENTER", auraButton, "CENTER", gap / 2, 0)
      R:SetTexCoord(1, 0, 0, 1)
      R:Show()
    else
      L:SetPoint("CENTER", auraButton, "CENTER", 0, 0)
      L:SetTexCoord(0, 1, 0, 1)
      if auraButton._chukieArtR then
        auraButton._chukieArtR:Hide()
      end
    end
    L:Show()
  else
    if auraButton._chukieArtL then
      auraButton._chukieArtL:Hide()
    end
    if auraButton._chukieArtR then
      auraButton._chukieArtR:Hide()
    end
    local icon = auraButton._chukieIcon
    if not icon then
      icon = auraButton:CreateTexture(nil, "ARTWORK")
      icon:SetAllPoints(auraButton)
      icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      auraButton._chukieIcon = icon
    end
    icon:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
    icon:SetAlpha(a)
    icon:Show()
    if auraButton.SetIcon then
      pcall(auraButton.SetIcon, auraButton, icon)
    end
  end
end

--- Formas documentadas en PTR 12.1 (includeSpellIDs primero).
local function buildCandidateFilters(spellId)
  return {
    { includeSpellIDs = { [spellId] = true } },
    { spellID = { include = { [spellId] = true } } },
    { spellIDs = { [spellId] = true } },
    { spellID = { include = { spellId } } },
  }
end

local function tryAttachGroup(container, groupKey, filter, spellId, initFn)
  local candidates = buildCandidateFilters(spellId)
  if type(container.AddAuraSlot) == "function" then
    for i = 1, #candidates do
      local ok = pcall(function()
        container:AddAuraSlot(groupKey, filter, {
          initializeFrame = initFn,
          candidateFilters = candidates[i],
        })
      end)
      if ok then
        return true, "AddAuraSlot"
      end
    end
  end
  if type(container.AddAuraGroup) == "function" then
    for i = 1, #candidates do
      local ok = pcall(function()
        container:AddAuraGroup(groupKey, filter, {
          maxFrameCount = 1,
          initializeFrame = initFn,
          candidateFilters = candidates[i],
        })
      end)
      if ok then
        return true, "AddAuraGroup"
      end
    end
  end
  return false, nil
end

local function createContainerFrame(name, parent)
  local templates = { "CustomAuraContainerTemplate", "ManagedAuraContainerTemplate", nil }
  for ti = 1, #templates do
    local ok, container
    if templates[ti] then
      ok, container = pcall(CreateFrame, "AuraContainer", name, parent, templates[ti])
    else
      ok, container = pcall(CreateFrame, "AuraContainer", name, parent)
    end
    if ok and container then
      return container
    end
  end
  return nil
end

function A:ReleaseAuraContainer(ruleId)
  self._auraContainers = self._auraContainers or {}
  local entry = self._auraContainers[ruleId]
  if not entry then
    return
  end
  if entry.container then
    entry.container:Hide()
    pcall(function()
      entry.container:SetParent(nil)
    end)
  end
  self._auraContainers[ruleId] = nil
  _pendingCombatCreates[ruleId] = nil
end

function A:EnsureAuraContainerForRule(rule)
  if not self:CanUseAuraContainerForRule(rule) then
    return nil
  end
  self._auraContainers = self._auraContainers or {}
  local id = rule.id
  local entry = self._auraContainers[id]
  local unit = rule.auraUnit == "target" and "target" or "player"
  local filter = filterStringForRule(rule)
  local spellId = tonumber(rule.spellId) or 0
  local sig = table.concat({
    tostring(spellId),
    unit,
    filter,
    tostring(rule.display or "icon"),
    tostring(rule.auraPath or ""),
    tostring(rule.auraLayout or "single"),
    tostring(rule.size or 48),
    tostring(rule.alpha or 1),
    tostring((rule.color and rule.color[1]) or 1),
    tostring((rule.color and rule.color[2]) or 1),
    tostring((rule.color and rule.color[3]) or 1),
  }, "|")

  if entry and entry.sig == sig and entry.container then
    return entry
  end

  if entry then
    self:ReleaseAuraContainer(id)
  end

  -- 12.1: crear AuraContainer en combate genera error.
  if InCombatLockdown and InCombatLockdown() then
    _pendingCombatCreates[id] = true
    return nil
  end

  local host = self:EnsureHost()
  local container = createContainerFrame("ChukieUi_AuraContainer" .. id, host)
  if not container then
    return nil
  end

  local size = clamp(rule.size, SIZE_MIN, SIZE_MAX)
  container:SetSize(size, size)
  applyPointTo(container, rule.point)
  pcall(container.EnableMouse, container, false)
  pcall(container.SetUnit, container, unit)

  local initFn = function(auraButton)
    styleAuraButton(auraButton, rule)
  end

  local attached = tryAttachGroup(container, "rule" .. id, filter, spellId, initFn)
  if not attached then
    container:Hide()
    pcall(function()
      container:SetParent(nil)
    end)
    return nil
  end

  entry = {
    container = container,
    sig = sig,
    ruleId = id,
    spellId = spellId,
  }
  self._auraContainers[id] = entry
  _pendingCombatCreates[id] = nil
  return entry
end

--- Sync visual/posicion. true = esta regla la maneja Container.
function A:SyncAuraContainerRule(rule)
  if not self:CanUseAuraContainerForRule(rule) then
    if rule and rule.id then
      self:ReleaseAuraContainer(rule.id)
    end
    return false
  end
  local entry = self:EnsureAuraContainerForRule(rule)
  if not entry or not entry.container then
    -- Pendiente de combate: aún “reclama” la regla para no caer al legacy (que no ve secretos).
    if rule and rule.id and _pendingCombatCreates[rule.id] then
      return true
    end
    return false
  end
  local c = entry.container
  applyPointTo(c, rule.point)
  local size = clamp(rule.size, SIZE_MIN, SIZE_MAX)
  local pair = rule.display == "aura" and rule.auraLayout == "pair"
  local gap = tonumber(rule.pairGap) or 80
  if pair then
    c:SetSize(size * 2 + gap, size)
  else
    c:SetSize(size, size)
  end

  local showHost = self:IsEnabled() and rule.enabled ~= false
  if showHost and rule.combatOnly and not UnitAffectingCombat("player") then
    showHost = false
  end
  if showHost and rule.targetOnly then
    if rule.auraUnit == "target" and not UnitExists("target") then
      showHost = false
    end
  end
  if showHost then
    c:Show()
  else
    c:Hide()
  end
  return true
end

function A:FlushPendingAuraContainers()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  local any = false
  for id in pairs(_pendingCombatCreates) do
    any = true
    break
  end
  if not any then
    return
  end
  self:ResetAuraContainerApiCache()
  if self.Refresh then
    self:Refresh()
  end
end

function A:HideAllAuraContainers()
  if not self._auraContainers then
    return
  end
  for _, entry in pairs(self._auraContainers) do
    if entry.container then
      entry.container:Hide()
    end
  end
end

function A:ReleaseStaleAuraContainers(seenIds)
  if not self._auraContainers then
    return
  end
  for id in pairs(self._auraContainers) do
    if not seenIds[id] then
      self:ReleaseAuraContainer(id)
    end
  end
end

-- Flush tras combate (crear containers diferidos).
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      A:ResetAuraContainerApiCache()
    end
    A:FlushPendingAuraContainers()
  end)
end
