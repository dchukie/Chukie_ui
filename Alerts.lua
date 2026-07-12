--[[ Módulo Alertas CD/procs — reglas apilables por perfil. ]]

local _, ns = ...

local A = {}
ns.Alerts = A

local MAX_RULES = 32
local SIZE_MIN, SIZE_MAX = 24, 768
local SHOW_ON_OK = { cooldown = true, ready = true, always = true, available = true }
local GLOW_OK = { Proc = true, Pixel = true, buttonOverlay = true, none = true }
local KIND_OK = { cooldown = true, proc = true }
local DISPLAY_OK = { icon = true, aura = true, text = true }
local LAYOUT_OK = { single = true, pair = true }
local GCD_SPELL_ID = 61304

local RULE_DEFAULTS = {
  enabled = true,
  showOn = "available",
  size = 48,
  swipe = true,
  edge = false,
  inverse = false,
  glowType = "Proc",
  sound = true,
  soundPath = "",
  combatOnly = false,
  targetOnly = false,
  display = "icon",
  alpha = 1,
  auraPath = "",
  auraLayout = "single",
  pairGap = 80,
  text = "",
  fontPath = "",
}

local OVERLAY_FX_DEFAULTS = {
  pulse = false,
  color = false,
  shake = false,
  glow = false,
}

local CHARGE_OP_OK = {
  eq = true,
  ne = true,
  gt = true,
  gte = true,
  lt = true,
  lte = true,
}

local CHARGE_FILTER_DEFAULTS = {
  enabled = false,
  op = "gte",
  value = 1,
}

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

local function copyPoint(p, index)
  -- Ancla fija: CENTER del arte → CENTER de pantalla.
  local x, y
  if type(p) == "table" then
    x = tonumber(p[2]) or 0
    y = tonumber(p[3]) or 0
  else
    local i = tonumber(index) or 1
    x = (i - 1) * 56
    y = 120
  end
  return { "CENTER", x, y }
end

local function copyColor(c)
  if type(c) ~= "table" then
    return { 1, 1, 1 }
  end
  return {
    clamp(c[1] or c.r, 0, 1),
    clamp(c[2] or c.g, 0, 1),
    clamp(c[3] or c.b, 0, 1),
  }
end

local function copyOverlayFx(src)
  local o = {}
  for k, v in pairs(OVERLAY_FX_DEFAULTS) do
    o[k] = v
  end
  if type(src) == "table" then
    o.pulse = src.pulse == true
    o.color = src.color == true
    o.shake = src.shake == true
    o.glow = src.glow == true
  end
  return o
end

local function copyChargeFilter(src)
  local o = {
    enabled = false,
    op = "gte",
    value = 1,
  }
  if type(src) == "table" then
    o.enabled = src.enabled == true
    o.op = CHARGE_OP_OK[src.op] and src.op or "gte"
    o.value = math.floor(clamp(src.value, 0, 99))
  end
  return o
end

local function clampSize(n)
  n = math.floor(tonumber(n) or 48)
  if n < SIZE_MIN then
    n = SIZE_MIN
  end
  if n > SIZE_MAX then
    n = SIZE_MAX
  end
  return n
end

local function copyRule(src, index)
  local r = {}
  for k, v in pairs(RULE_DEFAULTS) do
    r[k] = v
  end
  r.color = { 1, 1, 1 }
  r.overlayFx = copyOverlayFx(nil)
  r.chargeFilter = copyChargeFilter(nil)
  if type(src) == "table" then
    for k, v in pairs(src) do
      if k == "point" then
        r.point = copyPoint(v, index)
      elseif k == "color" then
        r.color = copyColor(v)
      elseif k == "overlayFx" then
        r.overlayFx = copyOverlayFx(v)
      elseif k == "chargeFilter" then
        r.chargeFilter = copyChargeFilter(v)
      elseif type(v) ~= "table" then
        r[k] = v
      end
    end
  end
  r.id = math.floor(tonumber(r.id) or 0)
  r.spellId = math.floor(tonumber(r.spellId) or 0)
  r.kind = KIND_OK[r.kind] and r.kind or "cooldown"
  r.enabled = r.enabled ~= false
  r.size = clampSize(r.size)
  r.showOn = SHOW_ON_OK[r.showOn] and r.showOn or "available"
  r.glowType = GLOW_OK[r.glowType] and r.glowType or "Proc"
  r.swipe = r.swipe ~= false
  r.edge = r.edge == true
  r.inverse = r.inverse == true
  r.sound = r.sound ~= false
  r.soundPath = type(r.soundPath) == "string" and r.soundPath or ""
  r.combatOnly = r.combatOnly == true
  r.targetOnly = r.targetOnly == true
  r.display = DISPLAY_OK[r.display] and r.display or "icon"
  r.alpha = clamp(r.alpha, 0, 1)
  r.color = copyColor(r.color)
  r.overlayFx = copyOverlayFx(r.overlayFx)
  r.chargeFilter = copyChargeFilter(r.chargeFilter)
  r.auraPath = type(r.auraPath) == "string" and r.auraPath or ""
  r.auraLayout = LAYOUT_OK[r.auraLayout] and r.auraLayout or "single"
  r.pairGap = clamp(math.floor(tonumber(r.pairGap) or 80), 20, 400)
  r.text = type(r.text) == "string" and r.text or ""
  r.fontPath = type(r.fontPath) == "string" and r.fontPath or ""
  r.point = copyPoint(r.point, index)
  return r
end

function A.DefaultRule(kind, spellId, index)
  return copyRule({
    kind = kind or "cooldown",
    spellId = spellId or 0,
    enabled = true,
  }, index)
end

local function migrateLegacy(db)
  if type(db.rules) ~= "table" then
    db.rules = {}
  end
  if #db.rules > 0 then
    return
  end
  local nextId = math.floor(tonumber(db.nextId) or 1)
  local function pushLegacy(kind, cfg)
    if type(cfg) ~= "table" then
      return
    end
    local sid = math.floor(tonumber(cfg.spellId) or 0)
    if sid <= 0 then
      return
    end
    local rule = copyRule(cfg, #db.rules + 1)
    rule.kind = kind
    rule.spellId = sid
    rule.id = nextId
    nextId = nextId + 1
    db.rules[#db.rules + 1] = rule
  end
  pushLegacy("cooldown", db.cd)
  pushLegacy("proc", db.proc)
  db.nextId = nextId
end

function A:NormalizeRule(rule, index)
  return copyRule(rule, index)
end

local TICK_INTERVAL_MIN, TICK_INTERVAL_MAX = 0.05, 0.50
local TICK_INTERVAL_DEFAULT = 0.15
local TICK_INTERVAL_PRESETS = { 0.05, 0.10, 0.15, 0.20, 0.25, 0.50 }

local function normalizeTickInterval(v)
  v = tonumber(v) or TICK_INTERVAL_DEFAULT
  if v < TICK_INTERVAL_MIN then
    v = TICK_INTERVAL_MIN
  end
  if v > TICK_INTERVAL_MAX then
    v = TICK_INTERVAL_MAX
  end
  local best, bestD = TICK_INTERVAL_PRESETS[3], 99
  for i = 1, #TICK_INTERVAL_PRESETS do
    local p = TICK_INTERVAL_PRESETS[i]
    local d = math.abs(p - v)
    if d < bestD then
      best, bestD = p, d
    end
  end
  return best
end

function A:GetTickIntervalPresets()
  return TICK_INTERVAL_PRESETS
end

function A:GetTickInterval()
  return normalizeTickInterval(self:DB().tickInterval)
end

function A:EnsureSchema(db)
  db = db or {}
  db.enabled = db.enabled == true
  db.rules = db.rules or {}
  db.nextId = math.floor(tonumber(db.nextId) or 1)
  if db.nextId < 1 then
    db.nextId = 1
  end
  db.tickInterval = normalizeTickInterval(db.tickInterval)
  migrateLegacy(db)
  local out = {}
  local maxId = db.nextId - 1
  for i = 1, math.min(#db.rules, MAX_RULES) do
    local r = copyRule(db.rules[i], i)
    if r.id <= 0 then
      r.id = db.nextId
      db.nextId = db.nextId + 1
    end
    if r.id > maxId then
      maxId = r.id
    end
    if r.spellId > 0 and KIND_OK[r.kind] then
      out[#out + 1] = r
    end
  end
  db.rules = out
  db.nextId = math.max(db.nextId, maxId + 1)
  return db
end

function A:DB()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return self:EnsureSchema({ enabled = false, nextId = 1, rules = {} })
  end
  p.alerts = self:EnsureSchema(p.alerts or {})
  return p.alerts
end

function A:IsEnabled()
  return self:DB().enabled == true
end

function A:GetRules()
  return self:DB().rules
end

function A:GetRuleById(id)
  id = tonumber(id)
  if not id then
    return nil
  end
  local rules = self:GetRules()
  for i = 1, #rules do
    if rules[i].id == id then
      return rules[i], i
    end
  end
  return nil
end

function A:AddRule(partial)
  local db = self:DB()
  if #db.rules >= MAX_RULES then
    return nil, "Máximo " .. MAX_RULES .. " alertas por perfil."
  end
  local rule = copyRule(partial, #db.rules + 1)
  if rule.spellId <= 0 then
    return nil, "Falta spellId."
  end
  if not KIND_OK[rule.kind] then
    return nil, "Tipo inválido."
  end
  rule.id = db.nextId
  db.nextId = db.nextId + 1
  db.rules[#db.rules + 1] = rule
  self:Refresh()
  return rule
end

function A:UpdateRule(id, partial)
  local rule, idx = self:GetRuleById(id)
  if not rule then
    return nil, "Regla no encontrada."
  end
  local merged = copyRule(rule, idx)
  if type(partial) == "table" then
    for k, v in pairs(partial) do
      if k == "point" then
        merged.point = copyPoint(v, idx)
      elseif k == "color" then
        merged.color = copyColor(v)
      elseif k == "overlayFx" then
        merged.overlayFx = copyOverlayFx(v)
      elseif k == "chargeFilter" then
        merged.chargeFilter = copyChargeFilter(v)
      elseif k ~= "id" then
        merged[k] = v
      end
    end
  end
  merged = copyRule(merged, idx)
  merged.id = rule.id
  if merged.spellId <= 0 then
    return nil, "Falta spellId."
  end
  self:DB().rules[idx] = merged
  self:Refresh()
  return merged
end

function A:DeleteRule(id)
  local _, idx = self:GetRuleById(id)
  if not idx then
    return false
  end
  local db = self:DB()
  table.remove(db.rules, idx)
  self:Refresh()
  return true
end

function A:GetMediaCounts()
  if ns.AlertsMedia and ns.AlertsMedia.Counts then
    return ns.AlertsMedia.Counts()
  end
  return {
    textures = 0,
    shapes = 0,
    rings = 0,
    borders = 0,
    statusbars = 0,
    fonts = 0,
    sounds = 0,
    powerAuras = 0,
    powerAurasSounds = 0,
  }
end

function A:GetLibCustomGlow()
  if not LibStub then
    return nil
  end
  return LibStub("LibCustomGlow-1.0", true)
end

function A:ResolveAuraPath(rule)
  local p = rule and rule.auraPath
  if type(p) == "string" and p ~= "" then
    return p
  end
  if ns.AlertsMedia and ns.AlertsMedia.DefaultAuraPath then
    return ns.AlertsMedia.DefaultAuraPath()
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function spellTexture(spellId)
  if not spellId or spellId <= 0 then
    return nil
  end
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(spellId)
  end
  if GetSpellTexture then
    return GetSpellTexture(spellId)
  end
  return nil
end

local function spellName(spellId)
  if C_Spell and C_Spell.GetSpellName then
    return C_Spell.GetSpellName(spellId)
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellId)
    return info and info.name or nil
  end
  return nil
end

function A:GetSpellDisplayName(spellId)
  return spellName(spellId) or ("#" .. tostring(spellId or 0))
end

local function isSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

local function getSpellCooldown(spellId)
  if C_Spell and C_Spell.GetSpellCooldown then
    local info = C_Spell.GetSpellCooldown(spellId)
    if type(info) == "table" then
      local start = info.startTime
      local duration = info.duration
      local modRate = info.modRate
      local onGcd = info.isOnGCD
      -- Retail 12+: start/duration pueden ser secretos; no decidir con ellos.
      if isSecret(start) or isSecret(duration) or isSecret(modRate) then
        return 0, 0, info.isEnabled ~= false, 1, onGcd == true, true
      end
      return tonumber(start) or 0, tonumber(duration) or 0, info.isEnabled ~= false, tonumber(modRate) or 1, onGcd == true, false
    end
  end
  if GetSpellCooldown then
    local start, duration, enable, modRate = GetSpellCooldown(spellId)
    if isSecret(start) or isSecret(duration) or isSecret(modRate) then
      return 0, 0, enable ~= 0, 1, false, true
    end
    return tonumber(start) or 0, tonumber(duration) or 0, enable ~= 0, tonumber(modRate) or 1, false, false
  end
  return 0, 0, true, 1, false, false
end

--- CD propio (no GCD): duration significativa y distinta del GCD actual.
--- 6º retorno: secret=true si Blizzard ocultó los tiempos (no usar para available/ready/cooldown).
local function isOnRealCooldown(spellId)
  local start, duration, enabled, modRate, flaggedGcd, secret = getSpellCooldown(spellId)
  if secret then
    return false, start, duration, enabled, modRate, true
  end
  if not enabled or not duration or duration <= 0 or not start or start <= 0 then
    return false, start, duration, enabled, modRate, false
  end
  if flaggedGcd then
    return false, start, duration, enabled, modRate, false
  end
  local _, gcdDur, _, _, _, gcdSecret = getSpellCooldown(GCD_SPELL_ID)
  if gcdSecret then
    gcdDur = 0
  else
    gcdDur = tonumber(gcdDur) or 0
  end
  -- GCD típico ~1–1.5s; si duration ≈ gcd o <= 1.5, tratar como GCD.
  if gcdDur > 0 and duration <= (gcdDur + 0.05) then
    return false, start, duration, enabled, modRate, false
  end
  if duration <= 1.5 then
    return false, start, duration, enabled, modRate, false
  end
  return true, start, duration, enabled, modRate, false
end

local function isSpellUsableNow(spellId)
  if C_Spell and C_Spell.IsSpellUsable then
    local ok = C_Spell.IsSpellUsable(spellId)
    return ok and true or false
  end
  if IsUsableSpell then
    local ok = IsUsableSpell(spellId)
    return ok and true or false
  end
  return true
end

local function isSpellInRangeOk(spellId)
  if C_Spell and C_Spell.IsSpellInRange then
    local inRange = C_Spell.IsSpellInRange(spellId)
    -- nil = N/A (sin target / no aplica) → ok
    if inRange == false then
      return false
    end
    return true
  end
  if IsSpellInRange then
    local r = IsSpellInRange(spellId, "target")
    if r == 0 then
      return false
    end
  end
  return true
end

--- Disponible: usable + rango OK + no en CD real (GCD no cuenta).
--- Si el CD es secreto, no asumir disponible.
local function isSpellAvailable(spellId)
  if not isSpellUsableNow(spellId) then
    return false
  end
  if not isSpellInRangeOk(spellId) then
    return false
  end
  local onReal, _, _, _, _, secret = isOnRealCooldown(spellId)
  if secret then
    return false
  end
  return not onReal
end

local function safeSetCooldown(cd, start, duration, modRate)
  if not cd then
    return false
  end
  if isSecret(start) or isSecret(duration) or isSecret(modRate) then
    pcall(function()
      cd:Clear()
    end)
    return false
  end
  start = tonumber(start) or 0
  duration = tonumber(duration) or 0
  modRate = tonumber(modRate) or 1
  local ok = pcall(cd.SetCooldown, cd, start, duration, modRate)
  if not ok then
    pcall(function()
      cd:Clear()
    end)
  end
  return ok
end

local function playerHasAura(spellId)
  if not spellId or spellId <= 0 then
    return false
  end
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    return C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
  end
  if AuraUtil and AuraUtil.FindAuraBySpellID then
    return AuraUtil.FindAuraBySpellID(spellId, "player", "HELPFUL") ~= nil
      or AuraUtil.FindAuraBySpellID(spellId, "player", "HARMFUL") ~= nil
  end
  return false
end

--- Stacks del aura en el jugador (0 si no está).
local function getAuraStacks(spellId)
  spellId = tonumber(spellId) or 0
  if spellId <= 0 then
    return 0
  end
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
    if not aura then
      return 0
    end
    local apps = aura.applications
    if isSecret(apps) then
      return nil
    end
    apps = tonumber(apps)
    if not apps or apps < 1 then
      return 1
    end
    return apps
  end
  if AuraUtil and AuraUtil.FindAuraBySpellID then
    local name, _, count = AuraUtil.FindAuraBySpellID(spellId, "player", "HELPFUL")
    if not name then
      name, _, count = AuraUtil.FindAuraBySpellID(spellId, "player", "HARMFUL")
    end
    if not name then
      return 0
    end
    count = tonumber(count)
    if not count or count < 1 then
      return 1
    end
    return count
  end
  return playerHasAura(spellId) and 1 or 0
end

--- Cargas actuales del hechizo. Sin sistema de cargas: 1 si no en CD real, 0 si en CD.
--- nil = desconocido (valor secreto).
local function getSpellChargeCount(spellId)
  spellId = tonumber(spellId) or 0
  if spellId <= 0 then
    return 0
  end
  if C_Spell and C_Spell.GetSpellCharges then
    local info = C_Spell.GetSpellCharges(spellId)
    if type(info) == "table" then
      local cur = info.currentCharges
      if isSecret(cur) then
        return nil
      end
      return math.floor(tonumber(cur) or 0)
    end
  end
  if GetSpellCharges then
    local cur = GetSpellCharges(spellId)
    if cur ~= nil then
      if isSecret(cur) then
        return nil
      end
      return math.floor(tonumber(cur) or 0)
    end
  end
  local onCd, _, _, _, _, secret = isOnRealCooldown(spellId)
  if secret then
    return nil
  end
  return onCd and 0 or 1
end

local function compareNumber(n, op, value)
  n = tonumber(n)
  value = tonumber(value) or 0
  if n == nil then
    return false
  end
  if op == "eq" then
    return n == value
  elseif op == "ne" then
    return n ~= value
  elseif op == "gt" then
    return n > value
  elseif op == "gte" then
    return n >= value
  elseif op == "lt" then
    return n < value
  elseif op == "lte" then
    return n <= value
  end
  return false
end

--- Filtro opcional de cargas (CD) o stacks (proc). AND con el resto de condiciones.
local function passesChargeFilter(rule)
  local f = rule and rule.chargeFilter
  if type(f) ~= "table" or not f.enabled then
    return true
  end
  local n
  if rule.kind == "proc" then
    n = getAuraStacks(rule.spellId)
  else
    n = getSpellChargeCount(rule.spellId)
  end
  if n == nil then
    return false
  end
  return compareNumber(n, f.op or "gte", f.value or 1)
end

local function defaultSoundPath()
  if ns.AlertsMedia and ns.AlertsMedia.sounds and #ns.AlertsMedia.sounds > 0 then
    local prefer = { "RobotBlip.ogg", "AirHorn.ogg", "ErrorBeep.ogg" }
    local byName = {}
    for i = 1, #ns.AlertsMedia.sounds do
      local p = ns.AlertsMedia.sounds[i]
      local name = p:match("([^\\]+)$")
      if name then
        byName[name] = p
      end
    end
    for i = 1, #prefer do
      if byName[prefer[i]] then
        return byName[prefer[i]]
      end
    end
    return ns.AlertsMedia.sounds[1]
  end
  return nil
end

local function resolveSoundPath(soundPath)
  if type(soundPath) == "string" and soundPath ~= "" then
    if ns.AlertsMedia and ns.AlertsMedia.GetSoundPaths then
      local list = ns.AlertsMedia.GetSoundPaths()
      for i = 1, #list do
        if list[i] == soundPath then
          return soundPath
        end
      end
    elseif ns.AlertsMedia and ns.AlertsMedia.IsKnownMediaPath and ns.AlertsMedia.IsKnownMediaPath(soundPath) then
      return soundPath
    else
      -- path explícito aún usable aunque no esté en catálogo
      return soundPath
    end
  end
  return defaultSoundPath()
end

local function playAlertSound(enabled, soundPath)
  if not enabled then
    return
  end
  local path = resolveSoundPath(soundPath)
  if path and PlaySoundFile then
    pcall(PlaySoundFile, path, "Master")
  end
end

function A:PlaySoundPreview(soundPath)
  playAlertSound(true, soundPath)
end

local function stopOverlayGlow(frame)
  if not frame or not frame._overlayGlowOn then
    return
  end
  local lib = A:GetLibCustomGlow()
  if lib and lib.ProcGlow_Stop then
    lib.ProcGlow_Stop(frame, "overlay")
  end
  frame._overlayGlowOn = false
end

local function startOverlayGlow(frame)
  if not frame then
    return
  end
  if frame._overlayGlowOn then
    return
  end
  local lib = A:GetLibCustomGlow()
  if lib and lib.ProcGlow_Start then
    lib.ProcGlow_Start(frame, { key = "overlay", startAnim = true, duration = 1 })
    frame._overlayGlowOn = true
  end
end

local function isSpellOverlayed(spellId, ruleId)
  spellId = tonumber(spellId) or 0
  if A._simOverlay and (A._simOverlay.untilTime or 0) > GetTime() then
    if ruleId and A._simOverlay.ruleId == ruleId then
      return true
    end
    if spellId > 0 and A._simOverlay.spellId == spellId then
      return true
    end
  end
  if spellId <= 0 then
    return false
  end
  if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
    return C_SpellActivationOverlay.IsSpellOverlayed(spellId) and true or false
  end
  if IsSpellOverlayed then
    return IsSpellOverlayed(spellId) and true or false
  end
  return false
end

local function hasAnyOverlayFx(fx)
  return type(fx) == "table" and (fx.pulse or fx.color or fx.shake or fx.glow)
end

local function restoreOverlayVisuals(frame, rule)
  if not frame then
    return
  end
  frame:SetScale(1)
  frame:SetAlpha(1)
  applyPoint(frame, rule and rule.point)
  stopOverlayGlow(frame)
  -- restore base colors after color FX
  local c = (rule and rule.color) or { 1, 1, 1 }
  local a = clamp(rule and rule.alpha or 1, 0, 1)
  if frame.icon then
    frame.icon:SetVertexColor(c[1], c[2], c[3])
  end
  if frame.iconLayer then
    frame.iconLayer:SetAlpha(a)
  end
  if frame.auraLayer then
    if frame.auraLayer.left then
      frame.auraLayer.left:SetVertexColor(c[1], c[2], c[3])
      frame.auraLayer.left:SetAlpha(a)
    end
    if frame.auraLayer.right then
      frame.auraLayer.right:SetVertexColor(c[1], c[2], c[3])
      frame.auraLayer.right:SetAlpha(a)
    end
  end
  if frame.textLayer and frame.textLayer.label then
    frame.textLayer.label:SetTextColor(c[1], c[2], c[3], a)
  end
end

local function applyOverlayFx(frame, rule, show)
  if not frame then
    return
  end
  local fx = rule and rule.overlayFx
  local want = show and hasAnyOverlayFx(fx) and isSpellOverlayed(rule.spellId, rule.id)
  if not want then
    if frame._overlayFxActive then
      frame._overlayFxActive = false
      frame:SetScript("OnUpdate", nil)
      restoreOverlayVisuals(frame, rule)
    end
    return
  end
  frame._overlayFxActive = true
  frame._overlayFx = fx
  frame._overlayRule = rule
  frame._fxT = frame._fxT or 0
  if fx.glow then
    startOverlayGlow(frame)
  else
    stopOverlayGlow(frame)
  end
  if not (fx.pulse or fx.color or fx.shake) then
    frame:SetScript("OnUpdate", nil)
    return
  end
  frame:SetScript("OnUpdate", function(self, elapsed)
    if not self._overlayFxActive or not self._overlayFx then
      return
    end
    local fxx = self._overlayFx
    local rr = self._overlayRule
    self._fxT = (self._fxT or 0) + elapsed
    local t = self._fxT
    local wave = (math.sin(t * 6) + 1) * 0.5 -- 0..1
    if fxx.pulse then
      self:SetScale(1 + 0.12 * wave)
      self:SetAlpha(0.75 + 0.25 * wave)
    else
      self:SetScale(1)
      self:SetAlpha(1)
    end
    local base = (rr and rr.color) or { 1, 1, 1 }
    local ba = clamp(rr and rr.alpha or 1, 0, 1)
    if fxx.color then
      local gr, gg, gb = 1, 0.85, 0.2
      local r = base[1] + (gr - base[1]) * wave
      local g = base[2] + (gg - base[2]) * wave
      local b = base[3] + (gb - base[3]) * wave
      if self.icon then
        self.icon:SetVertexColor(r, g, b)
      end
      if self.auraLayer then
        if self.auraLayer.left then
          self.auraLayer.left:SetVertexColor(r, g, b)
        end
        if self.auraLayer.right then
          self.auraLayer.right:SetVertexColor(r, g, b)
        end
      end
      if self.textLayer and self.textLayer.label then
        self.textLayer.label:SetTextColor(r, g, b, ba)
      end
    end
    if fxx.shake then
      local px = (rr and rr.point and rr.point[2]) or 0
      local py = (rr and rr.point and rr.point[3]) or 0
      local amp = 2 + 2 * wave
      local ox = (math.random() * 2 - 1) * amp
      local oy = (math.random() * 2 - 1) * amp
      self:ClearAllPoints()
      self:SetPoint("CENTER", UIParent, "CENTER", px + ox, py + oy)
    else
      applyPoint(self, rr and rr.point)
    end
  end)
end

local function hasValidTarget(spellId)
  if not UnitExists("target") or UnitIsDead("target") then
    return false
  end
  if C_Spell and C_Spell.IsSpellInRange then
    local inRange = C_Spell.IsSpellInRange(spellId)
    if inRange == false then
      return false
    end
  end
  return true
end

local function stopGlow(frame)
  if not frame then
    return
  end
  local lib = A:GetLibCustomGlow()
  if not lib then
    return
  end
  local key = frame._chukieGlowKey or "chukie"
  if frame._chukieGlowKind == "Proc" and lib.ProcGlow_Stop then
    lib.ProcGlow_Stop(frame, key)
  elseif frame._chukieGlowKind == "Pixel" and lib.PixelGlow_Stop then
    lib.PixelGlow_Stop(frame, key)
  elseif frame._chukieGlowKind == "buttonOverlay" and lib.ButtonGlow_Stop then
    lib.ButtonGlow_Stop(frame)
  end
  frame._chukieGlowKind = nil
  frame._chukieGlowOn = false
end

local function startGlow(frame, glowType, glowKey)
  if not frame or not glowType or glowType == "none" then
    stopGlow(frame)
    return
  end
  local lib = A:GetLibCustomGlow()
  if not lib then
    return
  end
  glowKey = glowKey or "chukie"
  if frame._chukieGlowOn and frame._chukieGlowKind == glowType and frame._chukieGlowKey == glowKey then
    return
  end
  stopGlow(frame)
  frame._chukieGlowKey = glowKey
  if glowType == "Proc" and lib.ProcGlow_Start then
    lib.ProcGlow_Start(frame, { key = glowKey, startAnim = true, duration = 1 })
  elseif glowType == "Pixel" and lib.PixelGlow_Start then
    lib.PixelGlow_Start(frame, nil, 8, 0.25, nil, 2, 0, 0, true, glowKey)
  elseif glowType == "buttonOverlay" and lib.ButtonGlow_Start then
    lib.ButtonGlow_Start(frame)
  else
    return
  end
  frame._chukieGlowKind = glowType
  frame._chukieGlowOn = true
end

function A:EnsureHost()
  if self._host then
    return self._host
  end
  local host = CreateFrame("Frame", "ChukieUi_AlertsHost", UIParent)
  host:SetFrameStrata("HIGH")
  host:SetFrameLevel(100)
  host:SetAllPoints(UIParent)
  host:EnableMouse(false)
  self._host = host
  return host
end

function A:EnsureRuleFrame(ruleId)
  self._frames = self._frames or {}
  local f = self._frames[ruleId]
  if f then
    return f
  end
  local host = self:EnsureHost()
  f = CreateFrame("Frame", "ChukieUi_AlertRule" .. tostring(ruleId), host)
  f:SetSize(48, 48)
  f:Hide()
  f:EnableMouse(false)

  -- Icon layer
  local iconLayer = CreateFrame("Frame", nil, f)
  iconLayer:SetAllPoints()
  local icon = iconLayer:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  iconLayer.icon = icon
  local cd = CreateFrame("Cooldown", f:GetName() .. "Cooldown", iconLayer, "CooldownFrameTemplate")
  cd:SetAllPoints()
  if cd.SetDrawEdge then
    cd:SetDrawEdge(false)
  end
  if cd.SetHideCountdownNumbers then
    cd:SetHideCountdownNumbers(true)
  end
  iconLayer.cooldown = cd
  f.iconLayer = iconLayer
  f.icon = icon
  f.cooldown = cd

  -- Aura layer (single or pair)
  local auraLayer = CreateFrame("Frame", nil, f)
  auraLayer:SetAllPoints()
  auraLayer:Hide()
  local aL = auraLayer:CreateTexture(nil, "ARTWORK")
  aL:SetSize(48, 48)
  aL:SetPoint("CENTER", auraLayer, "CENTER", 0, 0)
  local aR = auraLayer:CreateTexture(nil, "ARTWORK")
  aR:SetSize(48, 48)
  aR:SetPoint("CENTER", auraLayer, "CENTER", 0, 0)
  aR:Hide()
  auraLayer.left = aL
  auraLayer.right = aR
  f.auraLayer = auraLayer

  -- Text layer
  local textLayer = CreateFrame("Frame", nil, f)
  textLayer:SetAllPoints()
  textLayer:Hide()
  local fs = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  fs:SetPoint("CENTER")
  fs:SetJustifyH("CENTER")
  textLayer.label = fs
  f.textLayer = textLayer

  f._wasShown = false
  f._ruleId = ruleId
  self._frames[ruleId] = f
  return f
end

local function applyPoint(frame, pointCfg)
  frame:ClearAllPoints()
  local x = tonumber(pointCfg and pointCfg[2]) or 0
  local y = tonumber(pointCfg and pointCfg[3]) or 0
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function hideAllLayers(frame)
  if frame.iconLayer then
    frame.iconLayer:Hide()
  end
  if frame.auraLayer then
    frame.auraLayer:Hide()
    if frame.auraLayer.right then
      frame.auraLayer.right:Hide()
    end
  end
  if frame.textLayer then
    frame.textLayer:Hide()
  end
  stopGlow(frame)
  if frame.cooldown then
    frame.cooldown:Clear()
    frame.cooldown:Hide()
  end
  frame._cdStart = nil
  frame._cdDur = nil
  frame._displayMode = nil
end

local function hideLayersExcept(frame, keep)
  if keep ~= "icon" and frame.iconLayer then
    frame.iconLayer:Hide()
  end
  if keep ~= "aura" and frame.auraLayer then
    frame.auraLayer:Hide()
    if frame.auraLayer.right then
      frame.auraLayer.right:Hide()
    end
  end
  if keep ~= "text" and frame.textLayer then
    frame.textLayer:Hide()
  end
  if keep ~= "icon" then
    stopGlow(frame)
    if frame.cooldown then
      frame.cooldown:Clear()
      frame.cooldown:Hide()
    end
    frame._cdStart = nil
    frame._cdDur = nil
  end
end

local function applyIconMode(frame, rule, show, onCd, start, duration, modRate, glowKey, playSoundIfNew)
  local size = tonumber(rule.size) or 48
  frame:SetSize(size, size)
  applyPoint(frame, rule.point)
  if not show then
    hideAllLayers(frame)
    frame:Hide()
    frame._wasShown = false
    return
  end
  hideLayersExcept(frame, "icon")
  frame:Show()
  frame.iconLayer:Show()
  frame._displayMode = "icon"
  local tex = spellTexture(rule.spellId)
  frame.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
  local c = rule.color or { 1, 1, 1 }
  frame.icon:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
  frame.iconLayer:SetAlpha(clamp(rule.alpha, 0, 1))
  if playSoundIfNew and not frame._wasShown then
    playAlertSound(rule.sound ~= false, rule.soundPath)
  end
  startGlow(frame, rule.glowType, glowKey)
  if rule.kind ~= "proc" and frame.cooldown then
    if rule.swipe ~= false then
      frame.cooldown:Show()
      if frame.cooldown.SetDrawSwipe then
        frame.cooldown:SetDrawSwipe(true)
      end
      if frame.cooldown.SetDrawEdge then
        frame.cooldown:SetDrawEdge(rule.edge == true)
      end
      if frame.cooldown.SetReverse then
        frame.cooldown:SetReverse(rule.inverse == true)
      end
      if onCd then
        -- Solo SetCooldown si cambió (como ActionBar; evita reiniciar el swipe).
        if frame._cdStart ~= start or frame._cdDur ~= duration then
          frame._cdStart = start
          frame._cdDur = duration
          safeSetCooldown(frame.cooldown, start, duration, modRate or 1)
        end
      else
        if frame._cdStart ~= nil then
          frame.cooldown:Clear()
          frame._cdStart = nil
          frame._cdDur = nil
        end
      end
    else
      frame.cooldown:Hide()
      frame._cdStart = nil
      frame._cdDur = nil
    end
  end
  frame._wasShown = true
end

local function applyAuraMode(frame, rule, show, playSoundIfNew)
  local size = tonumber(rule.size) or 48
  local gap = tonumber(rule.pairGap) or 80
  local pair = rule.auraLayout == "pair"
  local hostW = pair and (size * 2 + gap) or size
  frame:SetSize(hostW, size)
  applyPoint(frame, rule.point)
  if not show then
    hideAllLayers(frame)
    frame:Hide()
    frame._wasShown = false
    return
  end
  hideLayersExcept(frame, "aura")
  frame:Show()
  frame._displayMode = "aura"
  local layer = frame.auraLayer
  layer:Show()
  local path = A:ResolveAuraPath(rule)
  local c = rule.color or { 1, 1, 1 }
  local a = clamp(rule.alpha, 0, 1)
  local L, R = layer.left, layer.right
  L:SetTexture(path)
  L:SetSize(size, size)
  L:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
  L:SetAlpha(a)
  L:ClearAllPoints()
  if pair then
    L:SetPoint("CENTER", layer, "CENTER", -gap / 2, 0)
    L:SetTexCoord(0, 1, 0, 1)
    R:SetTexture(path)
    R:SetSize(size, size)
    R:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
    R:SetAlpha(a)
    R:ClearAllPoints()
    R:SetPoint("CENTER", layer, "CENTER", gap / 2, 0)
    R:SetTexCoord(1, 0, 0, 1) -- mirror
    R:Show()
  else
    L:SetPoint("CENTER", layer, "CENTER", 0, 0)
    L:SetTexCoord(0, 1, 0, 1)
    R:Hide()
  end
  if playSoundIfNew and not frame._wasShown then
    playAlertSound(rule.sound ~= false, rule.soundPath)
  end
  frame._wasShown = true
end

local function applyTextMode(frame, rule, show, playSoundIfNew)
  local size = tonumber(rule.size) or 48
  frame:SetSize(math.max(120, size * 4), size + 8)
  applyPoint(frame, rule.point)
  if not show then
    hideAllLayers(frame)
    frame:Hide()
    frame._wasShown = false
    return
  end
  hideLayersExcept(frame, "text")
  frame:Show()
  frame._displayMode = "text"
  local layer = frame.textLayer
  layer:Show()
  local label = layer.label
  local msg = rule.text
  if type(msg) ~= "string" or strtrim(msg) == "" then
    msg = A:GetSpellDisplayName(rule.spellId)
  end
  local fontPath = rule.fontPath
  local fontSize = math.max(12, math.min(64, size))
  if type(fontPath) == "string" and fontPath ~= "" then
    label:SetFont(fontPath, fontSize, "OUTLINE")
  else
    label:SetFontObject(GameFontHighlightLarge)
    local f, _, flags = label:GetFont()
    if f then
      label:SetFont(f, fontSize, flags or "OUTLINE")
    end
  end
  label:SetText(msg)
  local c = rule.color or { 1, 1, 1 }
  label:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1, clamp(rule.alpha, 0, 1))
  if playSoundIfNew and not frame._wasShown then
    playAlertSound(rule.sound ~= false, rule.soundPath)
  end
  frame._wasShown = true
end

local function shouldShowRule(rule)
  local preview = A._livePreview and A._livePreview.ruleId == rule.id and A._livePreview.forceShow
  if not preview then
    if not A:IsEnabled() or rule.enabled == false or (tonumber(rule.spellId) or 0) <= 0 then
      return false, false, 0, 0, 1
    end
    if rule.combatOnly and not UnitAffectingCombat("player") then
      return false, false, 0, 0, 1
    end
    if rule.targetOnly and not hasValidTarget(rule.spellId) then
      return false, false, 0, 0, 1
    end
  elseif (tonumber(rule.spellId) or 0) <= 0 then
    return false, false, 0, 0, 1
  end
  if rule.kind == "proc" then
    if preview then
      return true, false, 0, 0, 1
    end
    local show
    if rule.chargeFilter and rule.chargeFilter.enabled then
      show = passesChargeFilter(rule)
    else
      show = playerHasAura(rule.spellId)
    end
    return show, false, 0, 0, 1
  end
  local onCd, start, duration, enabled, modRate, secret = isOnRealCooldown(rule.spellId)
  if preview then
    return true, onCd, start or 0, duration or 0, modRate or 1
  end
  local showOn = rule.showOn or "available"
  -- CD secreto: no decidir available/ready/cooldown; always sí (sin swipe usable).
  if secret and showOn ~= "always" then
    return false, false, 0, 0, 1
  end
  local show
  if showOn == "always" then
    show = true
  elseif showOn == "cooldown" then
    show = onCd
  elseif showOn == "available" then
    show = isSpellAvailable(rule.spellId)
  else
    show = not onCd
  end
  if show and not passesChargeFilter(rule) then
    show = false
  end
  return show, onCd, start or 0, duration or 0, modRate or 1
end

function A:SetLivePreview(ruleId, on)
  if on and ruleId then
    self._livePreview = { ruleId = ruleId, forceShow = true }
  else
    self._livePreview = nil
  end
end

function A:ClearLivePreview()
  self._livePreview = nil
  self._simOverlay = nil
end

function A:SimulateOverlay(ruleId, seconds)
  seconds = tonumber(seconds) or 2
  local rule = self:GetRuleById(ruleId)
  self._simOverlay = {
    ruleId = ruleId,
    spellId = rule and rule.spellId or 0,
    untilTime = GetTime() + seconds,
  }
  self:UpdateAllRules()
  C_Timer.After(seconds + 0.05, function()
    if A._simOverlay and A._simOverlay.ruleId == ruleId then
      A._simOverlay = nil
      A:UpdateAllRules()
    end
  end)
end

function A:UpdateRuleFrame(rule, index)
  if not rule or not rule.id then
    return
  end
  local f = self:EnsureRuleFrame(rule.id)
  local glowKey = "r" .. tostring(rule.id)
  local show, onCd, start, duration, modRate = shouldShowRule(rule)
  local silent = self._livePreview and self._livePreview.ruleId == rule.id
  local display = rule.display or "icon"
  if display == "aura" then
    applyAuraMode(f, rule, show, not silent)
  elseif display == "text" then
    applyTextMode(f, rule, show, not silent)
  else
    applyIconMode(f, rule, show, onCd, start, duration, modRate, glowKey, not silent)
  end
  applyOverlayFx(f, rule, show)
end

local function hideFrame(frame)
  if not frame then
    return
  end
  if frame._overlayFxActive then
    frame._overlayFxActive = false
    frame:SetScript("OnUpdate", nil)
  end
  stopOverlayGlow(frame)
  hideAllLayers(frame)
  frame:Hide()
  frame._wasShown = false
end

function A:UpdateAllRules()
  local db = self:DB()
  local enabled = self:IsEnabled()
  local previewId = self._livePreview and self._livePreview.ruleId
  local seen = {}
  for i = 1, #db.rules do
    local rule = db.rules[i]
    seen[rule.id] = true
    if enabled or rule.id == previewId then
      self:UpdateRuleFrame(rule, i)
    else
      local f = self._frames and self._frames[rule.id]
      hideFrame(f)
    end
  end
  if self._frames then
    for id, f in pairs(self._frames) do
      if not seen[id] then
        hideFrame(f)
      end
    end
  end
end

function A:EnsureEvents()
  if self._ev then
    return
  end
  local ev = CreateFrame("Frame")
  self._ev = ev
  -- Mismos triggers que ActionBar (+ CD/usabilidad) para respuesta cercana a la barra.
  ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
  ev:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
  ev:RegisterEvent("ACTIONBAR_UPDATE_STATE")
  ev:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
  ev:RegisterEvent("SPELL_UPDATE_CHARGES")
  ev:RegisterEvent("SPELLS_CHANGED")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PLAYER_TARGET_CHANGED")
  ev:RegisterEvent("PLAYER_REGEN_DISABLED")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  pcall(function()
    ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
  end)
  pcall(function()
    ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
  end)
  pcall(function()
    ev:RegisterEvent("SPELL_UPDATE_USABLE")
  end)
  ev:RegisterUnitEvent("UNIT_AURA", "player")
  ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
  pcall(function()
    ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
  end)
  local function kickUpdate()
    if not A:IsEnabled() and not (A._livePreview and A._livePreview.ruleId) then
      return
    end
    -- Inmediato: sin C_Timer.After (eso retrasaba vs ActionBar).
    A:UpdateAllRules()
  end
  ev:SetScript("OnEvent", kickUpdate)

  self:RestartTicker()
end

--- Poll en segundo plano (fin de CD / rango). Intervalo por perfil: alerts.tickInterval.
function A:RestartTicker()
  if self._ticker then
    self._ticker:Cancel()
    self._ticker = nil
  end
  local interval = self:GetTickInterval()
  self._tickerInterval = interval
  self._ticker = C_Timer.NewTicker(interval, function()
    if not A:IsEnabled() and not (A._livePreview and A._livePreview.ruleId) then
      return
    end
    A:UpdateAllRules()
  end)
end

function A:HideAll()
  if not self._frames then
    return
  end
  for _, f in pairs(self._frames) do
    hideFrame(f)
  end
end

function A:Refresh()
  self:EnsureSchema(self:DB())
  self:EnsureEvents()
  self:RestartTicker()
  if not self:IsEnabled() and not (self._livePreview and self._livePreview.ruleId) then
    self:HideAll()
    return
  end
  self:EnsureHost()
  self:UpdateAllRules()
end

function A:OnProfileChanged()
  self:Refresh()
  if ns.AlertsManager and ns.AlertsManager.RefreshIfShown then
    ns.AlertsManager:RefreshIfShown()
  end
end

A.MAX_RULES = MAX_RULES
A.SIZE_MIN = SIZE_MIN
A.SIZE_MAX = SIZE_MAX
