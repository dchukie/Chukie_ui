--[[ Ranuras reserved2–4: prioridad acción extra → habilidad de zona → ítems especiales de misiones rastreadas.
     Botones seguros con nombres globales para Esc → Controles → Teclas de acción rápida (Bindings.xml). ]]

local _, ns = ...

local D = {}
ns.DynamicReservedSlots = D

D._globalNames = {
  [2] = "ChukieDynAct2",
  [3] = "ChukieDynAct3",
  [4] = "ChukieDynAct4",
}

local function widgetsDb()
  if ns.Profile and ns.Profile.GetRightPanelWidgetsModel then
    return ns.Profile:GetRightPanelWidgetsModel()
  end
  return nil
end

function D.IsFeatureEnabled()
  local db = widgetsDb()
  if not db then
    return true
  end
  return db.dynamicActionSlotsEnabled ~= false
end

local function clearSecureAttributes(btn)
  if not btn or InCombatLockdown() then
    return false
  end
  for _, k in ipairs({ "type", "spell", "item", "macro", "macrotext", "action", "unit", "target" }) do
    btn:SetAttribute(k, nil)
  end
  return true
end

local function copySecureFromBlizzard(dst, src)
  if not dst or not src or InCombatLockdown() then
    return false
  end
  clearSecureAttributes(dst)
  local t = src.GetAttribute and src:GetAttribute("type")
  if not t or t == "" then
    return false
  end
  dst:SetAttribute("type", t)
  for _, k in ipairs({ "spell", "item", "macro", "macrotext", "action", "unit", "target", "help-button", "harm-button" }) do
    local v = src.GetAttribute and src:GetAttribute(k)
    if v ~= nil then
      dst:SetAttribute(k, v)
    end
  end
  return true
end

local function applyMacroSecure(dst, text)
  if not dst or InCombatLockdown() or type(text) ~= "string" or text == "" then
    return false
  end
  clearSecureAttributes(dst)
  dst:SetAttribute("type", "macro")
  dst:SetAttribute("macrotext", text)
  return true
end

local function applySpellSecure(dst, spellId)
  if not dst or InCombatLockdown() or not spellId then
    return false
  end
  clearSecureAttributes(dst)
  dst:SetAttribute("type", "spell")
  dst:SetAttribute("spell", spellId)
  return true
end

local function applyItemSecure(dst, itemId)
  if not dst or InCombatLockdown() or not itemId then
    return false
  end
  clearSecureAttributes(dst)
  dst:SetAttribute("type", "item")
  dst:SetAttribute("item", "item:" .. tostring(itemId))
  return true
end

function D.ApplyEntryToSecure(secureBtn, entry)
  if not secureBtn or not entry then
    return false
  end
  if entry.actionType == "macro" and entry.macrotext then
    return applyMacroSecure(secureBtn, entry.macrotext)
  end
  if entry.actionType == "spell" and entry.spellId then
    return applySpellSecure(secureBtn, entry.spellId)
  end
  if entry.actionType == "item" and entry.itemId then
    return applyItemSecure(secureBtn, entry.itemId)
  end
  return false
end

function D.ApplyEntryToSecureResolved(secureBtn, entry)
  if not secureBtn or not entry then
    return false
  end
  if entry.actionType == "blizzard" and entry.blizzardCopySource then
    if copySecureFromBlizzard(secureBtn, entry.blizzardCopySource) then
      return true
    end
    if entry.source == "extra" then
      return applyMacroSecure(secureBtn, "/click ExtraActionButton1")
    end
    local nm = entry.blizzardCopySource.GetName and entry.blizzardCopySource:GetName()
    if type(nm) == "string" and nm ~= "" then
      return applyMacroSecure(secureBtn, "/click " .. nm)
    end
    return false
  end
  return D.ApplyEntryToSecure(secureBtn, entry)
end

function D.ClearSecure(secureBtn)
  if not secureBtn then
    return
  end
  clearSecureAttributes(secureBtn)
  secureBtn:Hide()
end

local function extraActionBlizzardButton()
  return _G.ExtraActionButton1
end

--- Sólo cuando el botón extra está visible y tiene tipo seguro (evita falsos positivos de HasExtraActionBar / atributos viejos).
local function extraActionLikelyActive()
  local eb = extraActionBlizzardButton()
  if not eb or not eb.IsShown or not eb:IsShown() then
    return false
  end
  if eb.IsVisible and not eb:IsVisible() then
    return false
  end
  local t = eb.GetAttribute and eb:GetAttribute("type")
  return t ~= nil and t ~= ""
end

local function zoneAbilitySpellButton()
  local zf = _G.ZoneAbilityFrame
  if zf and zf.SpellButton then
    return zf.SpellButton
  end
  return _G.ZoneAbilityFrameSpellButton
end

--- Añade una entrada por cada hechizo de zona distinto hasta llenar maxSlots.
local function appendZoneAbilityEntries(out, maxSlots)
  if #out >= maxSlots then
    return
  end
  local seenSpell = {}
  for i = 1, #out do
    local e = out[i]
    if e.actionType == "spell" and e.spellId then
      seenSpell[e.spellId] = true
    end
  end
  local zf = _G.ZoneAbilityFrame
  local zoneFrameShown = zf and zf.IsShown and zf:IsShown()
  if zoneFrameShown and C_ZoneAbility and C_ZoneAbility.GetDisplayedZoneAbilities then
    local arr = C_ZoneAbility.GetDisplayedZoneAbilities()
    if type(arr) == "table" then
      for idx = 1, #arr do
        if #out >= maxSlots then
          return
        end
        local row = arr[idx]
        if type(row) == "table" then
          local sid = row.spellID or row.spellId or row.zoneAbilitySpellID or row.uiPrioritySpellID
          if type(sid) == "number" and sid > 0 and not seenSpell[sid] then
            seenSpell[sid] = true
            out[#out + 1] = { source = "zone", actionType = "spell", spellId = sid }
          end
        end
      end
    end
  end
  if #out >= maxSlots then
    return
  end
  local zb = zoneAbilitySpellButton()
  local anyZoneSpell = false
  for i = 1, #out do
    if out[i].source == "zone" and out[i].actionType == "spell" then
      anyZoneSpell = true
      break
    end
  end
  if not anyZoneSpell and zb and zb.IsShown and zb:IsShown() then
    out[#out + 1] = { source = "zone", actionType = "blizzard", blizzardCopySource = zb }
  end
end

--- Comprueba que la fuente de la entrada sigue activa (evita ranura 2 «pegada» si el marco de zona ocultó el botón tras BuildQueue).
function D.ValidateEntryContext(entry)
  if not entry or not entry.source then
    return false
  end
  if entry.source == "extra" then
    return extraActionLikelyActive()
  end
  if entry.source == "zone" then
    if entry.actionType == "spell" and type(entry.spellId) == "number" and entry.spellId > 0 then
      local zf = _G.ZoneAbilityFrame
      if not (zf and zf.IsShown and zf:IsShown()) then
        return false
      end
      if C_ZoneAbility and C_ZoneAbility.GetDisplayedZoneAbilities then
        local arr = C_ZoneAbility.GetDisplayedZoneAbilities()
        if type(arr) == "table" then
          for idx = 1, #arr do
            local row = arr[idx]
            if type(row) == "table" then
              local sid = row.spellID or row.spellId or row.zoneAbilitySpellID or row.uiPrioritySpellID
              if tonumber(sid) == tonumber(entry.spellId) then
                return true
              end
            end
          end
        end
      end
      return false
    end
    if entry.actionType == "blizzard" and entry.blizzardCopySource then
      local zb = entry.blizzardCopySource
      if not (zb and zb.IsShown and zb:IsShown()) then
        return false
      end
      local t = zb.GetAttribute and zb:GetAttribute("type")
      return t ~= nil and t ~= ""
    end
    if entry.actionType == "macro" and type(entry.macrotext) == "string" and entry.macrotext ~= "" then
      local zb = zoneAbilitySpellButton()
      return zb and zb.IsShown and zb:IsShown()
    end
    return false
  end
  if entry.source == "quest" and entry.actionType == "item" and entry.itemId then
    return (C_Item and C_Item.GetItemCount(entry.itemId) or 0) > 0
  end
  return true
end

local function appendTrackedQuestSpecialItems(out, maxTotal)
  if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not GetQuestLogSpecialItemInfo then
    return
  end
  local seen = {}
  for i = 1, #out do
    local e = out[i]
    if e.actionType == "item" and e.itemId then
      seen[e.itemId] = true
    end
  end
  local n = C_QuestLog.GetNumQuestLogEntries()
  for i = 1, n do
    if #out >= maxTotal then
      return
    end
    local info = C_QuestLog.GetInfo(i)
    if info and info.questID and C_QuestLog.IsQuestTracked and C_QuestLog.IsQuestTracked(info.questID) then
      local ok, a, b = pcall(GetQuestLogSpecialItemInfo, i)
      if ok and a ~= nil then
        local itemId = nil
        if type(b) == "number" and b > 0 then
          itemId = b
        elseif type(a) == "number" and a > 0 then
          itemId = a
        elseif type(a) == "string" then
          itemId = tonumber(string.match(a, "item:(%d+)")) or tonumber(string.match(a, "Hitem:(%d+)"))
        end
        if itemId and not seen[itemId] and (C_Item.GetItemCount(itemId) or 0) > 0 then
          seen[itemId] = true
          out[#out + 1] = {
            source = "quest",
            actionType = "item",
            itemId = itemId,
          }
        end
      end
    end
  end
end

function D.BuildQueue(maxSlots)
  maxSlots = maxSlots or 3
  local out = {}
  if not D.IsFeatureEnabled() then
    return out
  end

  if extraActionLikelyActive() and extraActionBlizzardButton() then
    out[#out + 1] = {
      source = "extra",
      actionType = "blizzard",
      blizzardCopySource = extraActionBlizzardButton(),
    }
  end

  if #out < maxSlots then
    appendZoneAbilityEntries(out, maxSlots)
  end

  if #out < maxSlots then
    appendTrackedQuestSpecialItems(out, maxSlots)
  end

  while #out > maxSlots do
    table.remove(out)
  end
  return out
end

function D.GetEntryIcon(entry)
  if not entry then
    return nil
  end
  if entry.actionType == "spell" and entry.spellId and C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(entry.spellId)
  end
  if entry.actionType == "item" and entry.itemId and C_Item and C_Item.GetItemIconByID then
    return C_Item.GetItemIconByID(entry.itemId)
  end
  if entry.blizzardCopySource then
    local tex = entry.blizzardCopySource.GetNormalTexture and entry.blizzardCopySource:GetNormalTexture()
    if tex and tex.GetTexture then
      return tex:GetTexture()
    end
  end
  if entry.source == "extra" then
    local eb = extraActionBlizzardButton()
    if eb and eb.GetNormalTexture then
      local t = eb:GetNormalTexture()
      if t and t.GetTexture then
        return t:GetTexture()
      end
    end
  end
  return nil
end

local function cooldownFromSpellOrItem(spellId, itemId)
  if spellId and C_Spell and C_Spell.GetSpellCooldown then
    local info = C_Spell.GetSpellCooldown(spellId)
    if info then
      local st = info.startTime or (info.startTimeMS and info.startTimeMS * 0.001) or 0
      local dur = info.duration or (info.durationMS and info.durationMS * 0.001) or 0
      st = tonumber(st) or 0
      dur = tonumber(dur) or 0
      return st, dur, tonumber(info.modRate) or 1
    end
  end
  if itemId and C_Item and C_Item.GetItemCooldown then
    local a, b = C_Item.GetItemCooldown(itemId)
    if type(a) == "table" then
      local st = a.startTimeSeconds or a.startTime or 0
      local dur = a.durationSeconds or a.duration or 0
      return tonumber(st) or 0, tonumber(dur) or 0, 1
    end
    if type(a) == "number" then
      return tonumber(a) or 0, tonumber(b) or 0, 1
    end
  end
  if itemId and GetItemCooldown then
    local st, dur = GetItemCooldown(itemId)
    return tonumber(st) or 0, tonumber(dur) or 0, 1
  end
  return 0, 0, 1
end

local function cooldownFromBlizzardActionButton(btn)
  if not btn then
    return 0, 0, 1
  end
  local cd = btn.cooldown
  if cd and cd.GetCooldownTimes then
    local ok, a, b, c = pcall(cd.GetCooldownTimes, cd)
    if ok and type(a) == "number" and type(b) == "number" then
      return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 1
    end
  end
  return 0, 0, 1
end

function D.GetEntryCooldownTimes(entry)
  if not entry then
    return 0, 0, 1
  end
  if entry.actionType == "spell" then
    return cooldownFromSpellOrItem(entry.spellId, nil)
  end
  if entry.actionType == "item" then
    return cooldownFromSpellOrItem(nil, entry.itemId)
  end
  if entry.source == "extra" then
    return cooldownFromBlizzardActionButton(extraActionBlizzardButton())
  end
  if entry.source == "zone" then
    local st, dur, m = cooldownFromBlizzardActionButton(zoneAbilitySpellButton())
    if dur > 0.001 then
      return st, dur, m
    end
    if entry.spellId then
      return cooldownFromSpellOrItem(entry.spellId, nil)
    end
    return st, dur, m
  end
  if entry.actionType == "macro" then
    if entry.source == "extra" then
      return cooldownFromBlizzardActionButton(extraActionBlizzardButton())
    end
    if entry.source == "zone" then
      return cooldownFromBlizzardActionButton(zoneAbilitySpellButton())
    end
  end
  return 0, 0, 1
end
