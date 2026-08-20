--[[ Módulo Alertas CD / procs / auras — reglas apilables por perfil. ]]

local _, ns = ...

local A = {}
ns.Alerts = A

local MAX_RULES = 32
local MAX_GROUPS = 32
local MAX_EFFECTS_PER_GROUP = 8
local SIZE_MIN, SIZE_MAX = 24, 768
local SHOW_ON_OK = { cooldown = true, ready = true, always = true, available = true }
local GLOW_OK = { Proc = true, Pixel = true, buttonOverlay = true, none = true }
local KIND_OK = { cooldown = true, proc = true, aura = true }
local DISPLAY_OK = { icon = true, aura = true, text = true }
local LAYOUT_OK = { single = true, pair = true }
local AURA_UNIT_OK = { player = true, target = true }
local AURA_FILTER_OK = { HELPFUL = true, HARMFUL = true, both = true }
local AURA_SHOW_OK = { present = true, absent = true, always = true }
local GCD_SPELL_ID = 61304
local spellName
local EFFECT_TYPE_OK = {
  icon = true,
  texture = true,
  text = true,
  sound = true,
  bar = true,
  ring = true,
  counter = true,
}
local EFFECT_STUB = { bar = true, ring = true, counter = true }
local EFFECT_VISUAL = { icon = true, texture = true, text = true }
local GROUP_RULE_TYPE_OK = {
  cooldown = true,
  aura = true,
  proc = true,
  combat = true,
  target = true,
  charges = true,
}

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
  --- Solo kind == "aura"
  auraUnit = "player",
  auraFilter = "both",
  auraShow = "present",
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
  r.auraUnit = AURA_UNIT_OK[r.auraUnit] and r.auraUnit or "player"
  r.auraFilter = AURA_FILTER_OK[r.auraFilter] and r.auraFilter or "both"
  r.auraShow = AURA_SHOW_OK[r.auraShow] and r.auraShow or "present"
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

local function allocId(db)
  db.nextId = math.floor(tonumber(db.nextId) or 1)
  if db.nextId < 1 then
    db.nextId = 1
  end
  local id = db.nextId
  db.nextId = db.nextId + 1
  return id
end

local function copyGroupRule(src)
  local typ = type(src) == "table" and src.type or nil
  if not GROUP_RULE_TYPE_OK[typ] then
    return nil
  end
  local r = {
    id = math.floor(tonumber(src.id) or 0),
    type = typ,
    enabled = src.enabled ~= false,
  }
  if typ == "cooldown" then
    r.spellId = math.floor(tonumber(src.spellId) or 0)
    r.showOn = SHOW_ON_OK[src.showOn] and src.showOn or "available"
  elseif typ == "aura" then
    r.spellId = math.floor(tonumber(src.spellId) or 0)
    r.auraUnit = AURA_UNIT_OK[src.auraUnit] and src.auraUnit or "player"
    r.auraFilter = AURA_FILTER_OK[src.auraFilter] and src.auraFilter or "both"
    r.auraShow = AURA_SHOW_OK[src.auraShow] and src.auraShow or "present"
  elseif typ == "proc" then
    r.spellId = math.floor(tonumber(src.spellId) or 0)
  elseif typ == "combat" or typ == "target" then
    r.on = src.on ~= false
  elseif typ == "charges" then
    r.spellId = math.floor(tonumber(src.spellId) or 0)
    r.op = CHARGE_OP_OK[src.op] and src.op or "gte"
    r.value = math.floor(clamp(src.value, 0, 99))
  end
  return r
end

local function copyEffect(src, index)
  local e = {
    enabled = true,
    size = 48,
    alpha = 1,
    glowType = "Proc",
    swipe = true,
    edge = false,
    inverse = false,
    auraPath = "",
    auraLayout = "single",
    pairGap = 80,
    text = "",
    fontPath = "",
    soundPath = "",
    playOn = "show",
    fill = "fill",
    texture = "",
    format = "charges",
  }
  e.color = { 1, 1, 1 }
  e.point = copyPoint(nil, index)
  if type(src) == "table" then
    for k, v in pairs(src) do
      if k == "point" then
        e.point = copyPoint(v, index)
      elseif k == "color" then
        e.color = copyColor(v)
      elseif type(v) ~= "table" then
        e[k] = v
      end
    end
  end
  e.id = math.floor(tonumber(e.id) or 0)
  e.spellId = math.floor(tonumber(e.spellId) or 0)
  e.type = EFFECT_TYPE_OK[e.type] and e.type or "icon"
  e.enabled = e.enabled ~= false
  e.size = clampSize(e.size)
  e.alpha = clamp(e.alpha, 0, 1)
  e.color = copyColor(e.color)
  e.glowType = GLOW_OK[e.glowType] and e.glowType or "Proc"
  e.swipe = e.swipe ~= false
  e.edge = e.edge == true
  e.inverse = e.inverse == true
  e.auraPath = type(e.auraPath) == "string" and e.auraPath or ""
  e.auraLayout = LAYOUT_OK[e.auraLayout] and e.auraLayout or "single"
  e.pairGap = clamp(math.floor(tonumber(e.pairGap) or 80), 20, 400)
  e.text = type(e.text) == "string" and e.text or ""
  e.fontPath = type(e.fontPath) == "string" and e.fontPath or ""
  e.soundPath = type(e.soundPath) == "string" and e.soundPath or ""
  e.playOn = e.playOn == "show" and "show" or "show"
  e.fill = (e.fill == "empty") and "empty" or "fill"
  e.texture = type(e.texture) == "string" and e.texture or ""
  e.format = type(e.format) == "string" and e.format or "charges"
  e.point = copyPoint(e.point, index)
  return e
end

local function firstVisualEffect(group)
  if not group or type(group.effects) ~= "table" then
    return nil
  end
  for i = 1, #group.effects do
    local e = group.effects[i]
    if e and EFFECT_VISUAL[e.type] then
      return e, i
    end
  end
  return nil
end

local function firstSoundEffect(group)
  if not group or type(group.effects) ~= "table" then
    return nil
  end
  for i = 1, #group.effects do
    local e = group.effects[i]
    if e and e.type == "sound" then
      return e, i
    end
  end
  return nil
end

local function findGroupRule(group, typ)
  if not group or type(group.rules) ~= "table" then
    return nil
  end
  for i = 1, #group.rules do
    local r = group.rules[i]
    if r and r.type == typ then
      return r, i
    end
  end
  return nil
end

local function countVisualEffects(group, enabledOnly)
  local n = 0
  if not group or type(group.effects) ~= "table" then
    return 0
  end
  for i = 1, #group.effects do
    local e = group.effects[i]
    if e and EFFECT_VISUAL[e.type] then
      if not enabledOnly or e.enabled ~= false then
        n = n + 1
      end
    end
  end
  return n
end

--- Proyección grupo → rule legacy (wizard / AuraContainer / watch).
local function groupToVirtualRule(group)
  local r = copyRule(nil, 1)
  if type(group) ~= "table" then
    return r
  end
  r.id = math.floor(tonumber(group.id) or 0)
  r.enabled = group.enabled ~= false
  r.overlayFx = copyOverlayFx(group.overlayFx)
  r.name = type(group.name) == "string" and group.name or ""
  r.kind = "cooldown"
  r.showOn = "available"
  r.spellId = 0
  r.combatOnly = false
  r.targetOnly = false
  r.chargeFilter = copyChargeFilter(nil)
  if type(group.rules) == "table" then
    for i = 1, #group.rules do
      local gr = group.rules[i]
      if gr then
        if (tonumber(r.spellId) or 0) <= 0 and
          (gr.type == "cooldown" or gr.type == "aura" or gr.type == "proc" or gr.type == "charges")
        then
          r.spellId = math.floor(tonumber(gr.spellId) or 0)
        end
        if gr.type == "cooldown" then
          r.kind = "cooldown"
          r.showOn = SHOW_ON_OK[gr.showOn] and gr.showOn or "available"
        elseif gr.type == "aura" then
          r.kind = "aura"
          r.auraUnit = AURA_UNIT_OK[gr.auraUnit] and gr.auraUnit or "player"
          r.auraFilter = AURA_FILTER_OK[gr.auraFilter] and gr.auraFilter or "both"
          r.auraShow = AURA_SHOW_OK[gr.auraShow] and gr.auraShow or "present"
        elseif gr.type == "proc" then
          r.kind = "proc"
        elseif gr.type == "combat" then
          r.combatOnly = gr.on ~= false
        elseif gr.type == "target" then
          r.targetOnly = gr.on ~= false
        elseif gr.type == "charges" then
          r.chargeFilter = copyChargeFilter({
            enabled = true,
            op = gr.op,
            value = gr.value,
          })
        end
      end
    end
  end
  local vis = firstVisualEffect(group)
  if vis then
    if vis.type == "texture" then
      r.display = "aura"
    elseif vis.type == "text" then
      r.display = "text"
    else
      r.display = "icon"
    end
    r.size = vis.size
    r.point = copyPoint(vis.point, 1)
    r.color = copyColor(vis.color)
    r.alpha = vis.alpha
    r.glowType = vis.glowType
    r.swipe = vis.swipe
    r.edge = vis.edge
    r.inverse = vis.inverse
    r.auraPath = vis.auraPath
    r.auraLayout = vis.auraLayout
    r.pairGap = vis.pairGap
    r.text = vis.text
    r.fontPath = vis.fontPath
  end
  local snd = firstSoundEffect(group)
  if snd then
    r.sound = snd.enabled ~= false
    r.soundPath = snd.soundPath or ""
  else
    r.sound = false
    r.soundPath = ""
  end
  return r
end

local function copyGroup(src, db)
  local g = {
    enabled = true,
    name = "",
    ruleLogic = "and",
    rules = {},
    effects = {},
  }
  g.overlayFx = copyOverlayFx(nil)
  if type(src) == "table" then
    g.id = math.floor(tonumber(src.id) or 0)
    g.enabled = src.enabled ~= false
    g.name = type(src.name) == "string" and src.name or ""
    g.ruleLogic = src.ruleLogic == "or" and "or" or "and"
    g.overlayFx = copyOverlayFx(src.overlayFx)
    if type(src.rules) == "table" then
      local legacySpellId = 0
      for i = 1, #src.rules do
        local old = src.rules[i]
        if type(old) == "table" and old.type == "spell" then
          legacySpellId = math.floor(tonumber(old.spellId) or 0)
          break
        end
      end
      for i = 1, #src.rules do
        local nr = copyGroupRule(src.rules[i])
        if nr and #g.rules < MAX_RULES then
          if (nr.type == "cooldown" or nr.type == "aura" or nr.type == "proc" or nr.type == "charges") and
            (tonumber(nr.spellId) or 0) <= 0
          then
            nr.spellId = legacySpellId
          end
          if db and nr.id <= 0 then
            nr.id = allocId(db)
          end
          g.rules[#g.rules + 1] = nr
        end
      end
      -- Rescate del esquema intermedio: si solo quedó la antigua regla
      -- compartida "spell", convertirla en una condición CD válida.
      if #g.rules == 0 and legacySpellId > 0 then
        local nr = copyGroupRule({
          type = "cooldown",
          spellId = legacySpellId,
          showOn = "available",
        })
        if db then
          nr.id = allocId(db)
        end
        g.rules[1] = nr
      end
    end
    if type(src.effects) == "table" then
      for i = 1, math.min(#src.effects, MAX_EFFECTS_PER_GROUP) do
        local ne = copyEffect(src.effects[i], i)
        if db and ne.id <= 0 then
          ne.id = allocId(db)
        end
        g.effects[#g.effects + 1] = ne
      end
    end
  end
  if db and (not g.id or g.id <= 0) then
    g.id = allocId(db)
  end
  if g.name == "" then
    local sid = 0
    for i = 1, #g.rules do
      sid = tonumber(g.rules[i].spellId) or 0
      if sid > 0 then
        break
      end
    end
    if sid > 0 then
      g.name = spellName(sid) or ("Alerta #" .. tostring(g.id))
    else
      g.name = "Alerta #" .. tostring(g.id or 0)
    end
  end
  return g
end

local function makeGroupFromLegacyRule(db, rule)
  rule = copyRule(rule, 1)
  local g = {
    id = (rule.id > 0) and rule.id or allocId(db),
    enabled = rule.enabled ~= false,
    name = "",
    ruleLogic = "and",
    overlayFx = copyOverlayFx(rule.overlayFx),
    rules = {},
    effects = {},
  }
  if rule.kind == "aura" then
    g.rules[#g.rules + 1] = copyGroupRule({
      type = "aura",
      spellId = rule.spellId,
      auraUnit = rule.auraUnit,
      auraFilter = rule.auraFilter,
      auraShow = rule.auraShow,
    })
  elseif rule.kind == "proc" then
    g.rules[#g.rules + 1] = copyGroupRule({ type = "proc", spellId = rule.spellId })
  else
    g.rules[#g.rules + 1] = copyGroupRule({
      type = "cooldown",
      spellId = rule.spellId,
      showOn = rule.showOn,
    })
  end
  if rule.combatOnly then
    g.rules[#g.rules + 1] = copyGroupRule({ type = "combat", on = true })
  end
  if rule.targetOnly then
    g.rules[#g.rules + 1] = copyGroupRule({ type = "target", on = true })
  end
  if rule.chargeFilter and rule.chargeFilter.enabled then
    g.rules[#g.rules + 1] = copyGroupRule({
      type = "charges",
      spellId = rule.spellId,
      op = rule.chargeFilter.op,
      value = rule.chargeFilter.value,
    })
  end
  local etype = "icon"
  if rule.display == "aura" then
    etype = "texture"
  elseif rule.display == "text" then
    etype = "text"
  end
  local vis = copyEffect({
    type = etype,
    enabled = true,
    point = rule.point,
    size = rule.size,
    color = rule.color,
    alpha = rule.alpha,
    glowType = rule.glowType,
    swipe = rule.swipe,
    edge = rule.edge,
    inverse = rule.inverse,
    auraPath = rule.auraPath,
    auraLayout = rule.auraLayout,
    pairGap = rule.pairGap,
    text = rule.text,
    fontPath = rule.fontPath,
  }, 1)
  vis.id = allocId(db)
  g.effects[#g.effects + 1] = vis
  if rule.sound ~= false then
    local snd = copyEffect({
      type = "sound",
      enabled = true,
      soundPath = rule.soundPath,
      playOn = "show",
    }, 2)
    snd.id = allocId(db)
    g.effects[#g.effects + 1] = snd
  end
  if type(rule.name) == "string" and rule.name ~= "" then
    g.name = rule.name
  elseif rule.spellId and rule.spellId > 0 and spellName then
    g.name = spellName(rule.spellId) or ("Alerta #" .. tostring(g.id))
  else
    g.name = "Alerta #" .. tostring(g.id)
  end
  return copyGroup(g, db)
end

local function applyVirtualToGroup(group, vr, db, effectId)
  if not group or type(vr) ~= "table" then
    return group
  end
  if vr.enabled ~= nil then
    group.enabled = vr.enabled ~= false
  end
  if type(vr.name) == "string" then
    if vr.name ~= "" then
      group.name = vr.name
    else
      -- Nombre vacío = volver al automático por hechizo.
      local sid = math.floor(tonumber(vr.spellId) or 0)
      group.name = (sid > 0 and spellName and spellName(sid)) or ("Alerta #" .. tostring(group.id or 0))
    end
  end
  if vr.overlayFx then
    group.overlayFx = copyOverlayFx(vr.overlayFx)
  end
  local spellId = math.floor(tonumber(vr.spellId) or 0)
  local kind = KIND_OK[vr.kind] and vr.kind or "cooldown"
  -- Quitar kind rules previas y reponer la actual.
  local kept = {}
  for i = 1, #group.rules do
    local gr = group.rules[i]
    if gr and gr.type ~= "cooldown" and gr.type ~= "aura" and gr.type ~= "proc" then
      kept[#kept + 1] = gr
    end
  end
  group.rules = kept
  if kind == "aura" then
    group.rules[#group.rules + 1] = copyGroupRule({
      type = "aura",
      spellId = spellId,
      auraUnit = vr.auraUnit,
      auraFilter = vr.auraFilter,
      auraShow = vr.auraShow,
    })
  elseif kind == "proc" then
    group.rules[#group.rules + 1] = copyGroupRule({ type = "proc", spellId = spellId })
  else
    group.rules[#group.rules + 1] = copyGroupRule({
      type = "cooldown",
      spellId = spellId,
      showOn = vr.showOn,
    })
  end
  -- combat / target / charges: quitar y reponer según payload
  local kept2 = {}
  for i = 1, #group.rules do
    local gr = group.rules[i]
    if gr and gr.type ~= "combat" and gr.type ~= "target" and gr.type ~= "charges" then
      kept2[#kept2 + 1] = gr
    end
  end
  group.rules = kept2
  if vr.combatOnly then
    group.rules[#group.rules + 1] = copyGroupRule({ type = "combat", on = true })
  end
  if vr.targetOnly then
    group.rules[#group.rules + 1] = copyGroupRule({ type = "target", on = true })
  end
  if vr.chargeFilter and vr.chargeFilter.enabled then
    group.rules[#group.rules + 1] = copyGroupRule({
      type = "charges",
      spellId = spellId,
      op = vr.chargeFilter.op,
      value = vr.chargeFilter.value,
    })
  end
  local targetEffect
  if effectId then
    for i = 1, #group.effects do
      if group.effects[i].id == effectId then
        targetEffect = group.effects[i]
        break
      end
    end
  end
  if not targetEffect or not EFFECT_VISUAL[targetEffect.type] then
    targetEffect = firstVisualEffect(group)
  end
  if targetEffect and EFFECT_VISUAL[targetEffect.type] then
    if vr.display == "aura" then
      targetEffect.type = "texture"
    elseif vr.display == "text" then
      targetEffect.type = "text"
    elseif vr.display == "icon" then
      targetEffect.type = "icon"
    end
    if vr.size then
      targetEffect.size = clampSize(vr.size)
    end
    if vr.point then
      targetEffect.point = copyPoint(vr.point, 1)
    end
    if vr.color then
      targetEffect.color = copyColor(vr.color)
    end
    if vr.alpha ~= nil then
      targetEffect.alpha = clamp(vr.alpha, 0, 1)
    end
    if vr.glowType then
      targetEffect.glowType = GLOW_OK[vr.glowType] and vr.glowType or targetEffect.glowType
    end
    if vr.swipe ~= nil then
      targetEffect.swipe = vr.swipe ~= false
    end
    if vr.edge ~= nil then
      targetEffect.edge = vr.edge == true
    end
    if vr.inverse ~= nil then
      targetEffect.inverse = vr.inverse == true
    end
    if vr.auraPath ~= nil then
      targetEffect.auraPath = type(vr.auraPath) == "string" and vr.auraPath or ""
    end
    if vr.auraLayout then
      targetEffect.auraLayout = LAYOUT_OK[vr.auraLayout] and vr.auraLayout or targetEffect.auraLayout
    end
    if vr.pairGap then
      targetEffect.pairGap = clamp(math.floor(tonumber(vr.pairGap) or 80), 20, 400)
    end
    if vr.text ~= nil then
      targetEffect.text = type(vr.text) == "string" and vr.text or ""
    end
    if vr.fontPath ~= nil then
      targetEffect.fontPath = type(vr.fontPath) == "string" and vr.fontPath or ""
    end
  end
  if vr.sound ~= nil then
    local snd = firstSoundEffect(group)
    if vr.sound then
      if not snd then
        snd = copyEffect({ type = "sound", enabled = true, soundPath = vr.soundPath or "" }, #group.effects + 1)
        snd.id = allocId(db)
        group.effects[#group.effects + 1] = snd
      else
        snd.enabled = true
        if vr.soundPath ~= nil then
          snd.soundPath = type(vr.soundPath) == "string" and vr.soundPath or ""
        end
      end
    elseif snd then
      snd.enabled = false
      if vr.soundPath ~= nil then
        snd.soundPath = type(vr.soundPath) == "string" and vr.soundPath or ""
      end
    end
  end
  if (not group.name or group.name == "" or group.name:match("^Alerta #")) and spellId > 0 and spellName then
    group.name = spellName(spellId) or group.name
  end
  return copyGroup(group, db)
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

--- Normalizar en cada lectura recreaba las tablas de grupos/efectos/reglas, así que
--- cualquier referencia que sostuviera el editor quedaba huérfana y sus escrituras
--- se perdían. Se normaliza una sola vez por tabla de perfil (clave débil).
local schemaReady = setmetatable({}, { __mode = "k" })

function A:EnsureSchema(db)
  db = db or {}
  if schemaReady[db] then
    return db
  end
  db.enabled = db.enabled == true
  db.rules = db.rules or {}
  db.groups = db.groups or {}
  db.nextId = math.floor(tonumber(db.nextId) or 1)
  if db.nextId < 1 then
    db.nextId = 1
  end
  -- Evitar colisiones al asignar IDs a reglas/efectos de esquemas anteriores.
  local knownMax = db.nextId - 1
  for i = 1, #db.groups do
    local oldGroup = db.groups[i]
    if type(oldGroup) == "table" then
      knownMax = math.max(knownMax, math.floor(tonumber(oldGroup.id) or 0))
      for ri = 1, #(oldGroup.rules or {}) do
        local oldRule = oldGroup.rules[ri]
        if type(oldRule) == "table" then
          knownMax = math.max(knownMax, math.floor(tonumber(oldRule.id) or 0))
        end
      end
      for ei = 1, #(oldGroup.effects or {}) do
        local oldEffect = oldGroup.effects[ei]
        if type(oldEffect) == "table" then
          knownMax = math.max(knownMax, math.floor(tonumber(oldEffect.id) or 0))
        end
      end
    end
  end
  for i = 1, #db.rules do
    local oldRule = db.rules[i]
    if type(oldRule) == "table" then
      knownMax = math.max(knownMax, math.floor(tonumber(oldRule.id) or 0))
    end
  end
  db.nextId = math.max(db.nextId, knownMax + 1)
  db.tickInterval = normalizeTickInterval(db.tickInterval)
  migrateLegacy(db)
  local maxId = db.nextId - 1
  if #db.groups == 0 and type(db.rules) == "table" then
    for i = 1, math.min(#db.rules, MAX_GROUPS) do
      local r = copyRule(db.rules[i], i)
      if r.id > 0 then
        maxId = math.max(maxId, r.id)
      end
      db.groups[#db.groups + 1] = makeGroupFromLegacyRule(db, r)
    end
  end
  local out = {}
  for i = 1, math.min(#db.groups, MAX_GROUPS) do
    local g = copyGroup(db.groups[i], db)
    if g.id > maxId then
      maxId = g.id
    end
    for ei = 1, #g.effects do
      if g.effects[ei].id > maxId then
        maxId = g.effects[ei].id
      end
    end
    for ri = 1, #g.rules do
      if g.rules[ri].id > maxId then
        maxId = g.rules[ri].id
      end
    end
    out[#out + 1] = g
  end
  db.groups = out
  db.nextId = math.max(db.nextId, maxId + 1)
  -- Fuente de verdad: groups. rules[] queda vacío (GetRules sintetiza).
  db.rules = {}
  schemaReady[db] = true
  return db
end

function A:DB()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return self:EnsureSchema({ enabled = false, nextId = 1, rules = {}, groups = {} })
  end
  p.alerts = self:EnsureSchema(p.alerts or {})
  return p.alerts
end

function A:IsEnabled()
  return self:DB().enabled == true
end

--- Activa el módulo (necesario para que las reglas se evalúen fuera del preview del wizard).
function A:SetEnabled(on)
  local db = self:DB()
  local want = on == true
  if db.enabled == want then
    return false
  end
  db.enabled = want
  self:Refresh()
  return true
end

--- Si hay reglas guardadas, asegurar que el módulo esté ON (el wizard hace forceShow y engaña).
function A:EnsureModuleEnabled(silent)
  if self:IsEnabled() then
    return false
  end
  self:SetEnabled(true)
  if not silent then
    print("|cff00ff00Chukie UI|r: módulo Alertas activado (hace falta para verlas fuera del editor).")
  end
  return true
end

function A:GetGroups()
  return self:DB().groups
end

function A:GetGroupById(id)
  id = tonumber(id)
  if not id then
    return nil
  end
  local groups = self:GetGroups()
  for i = 1, #groups do
    if groups[i].id == id then
      return groups[i], i
    end
  end
  return nil
end

function A:AddGroup(partial)
  local db = self:DB()
  if #db.groups >= MAX_GROUPS then
    return nil, "Máximo " .. MAX_GROUPS .. " alertas por perfil."
  end
  local g = copyGroup(type(partial) == "table" and partial or {}, db)
  -- En altas nuevas no se aceptan IDs externos: todo sale del mismo allocId.
  g.id = allocId(db)
  for i = 1, #g.rules do
    g.rules[i].id = allocId(db)
  end
  for i = 1, #g.effects do
    g.effects[i].id = allocId(db)
  end
  if type(partial) ~= "table" or type(partial.name) ~= "string" or partial.name == "" then
    local sid = 0
    for i = 1, #g.rules do
      sid = tonumber(g.rules[i].spellId) or 0
      if sid > 0 then
        break
      end
    end
    g.name = (sid > 0 and spellName(sid)) or ("Alerta #" .. tostring(g.id))
  end
  local hasIcon = false
  for i = 1, #g.effects do
    if g.effects[i].type == "icon" then
      hasIcon = true
      break
    end
  end
  if not hasIcon then
    if #g.effects >= MAX_EFFECTS_PER_GROUP then
      table.remove(g.effects, #g.effects)
    end
    local icon = copyEffect({ type = "icon" }, 1)
    icon.id = allocId(db)
    table.insert(g.effects, 1, icon)
  end
  db.groups[#db.groups + 1] = g
  db.enabled = true
  self:Refresh()
  return g
end

local function updateGroupRecord(self, id, partial)
  local group, idx = self:GetGroupById(id)
  if not group then
    return nil, "Grupo no encontrado."
  end
  if type(partial) == "table" then
    if partial.name ~= nil then
      group.name = type(partial.name) == "string" and partial.name or group.name
    end
    if partial.enabled ~= nil then
      group.enabled = partial.enabled ~= false
    end
    if partial.ruleLogic ~= nil then
      group.ruleLogic = partial.ruleLogic == "or" and "or" or "and"
    end
    if partial.overlayFx ~= nil then
      group.overlayFx = copyOverlayFx(partial.overlayFx)
    end
  end
  local db = self:DB()
  db.groups[idx] = copyGroup(group, db)
  self:Refresh()
  return db.groups[idx]
end

function A:DeleteGroup(id)
  local _, idx = self:GetGroupById(id)
  if not idx then
    return false
  end
  local db = self:DB()
  table.remove(db.groups, idx)
  if self.ReleaseAuraContainer then
    self:ReleaseAuraContainer(id)
  end
  self:Refresh()
  return true
end

function A:GetGroupRuleById(groupId, ruleId)
  local group = self:GetGroupById(groupId)
  ruleId = tonumber(ruleId)
  if not group or not ruleId then
    return nil
  end
  for i = 1, #group.rules do
    if group.rules[i].id == ruleId then
      return group.rules[i], i, group
    end
  end
  return nil
end

function A:AddGroupRule(groupId, partial)
  local group, idx = self:GetGroupById(groupId)
  if not group then
    return nil, "Grupo no encontrado."
  end
  if #group.rules >= MAX_RULES then
    return nil, "Máximo " .. MAX_RULES .. " reglas por grupo."
  end
  local rule = copyGroupRule(partial)
  if not rule then
    return nil, "Tipo de regla inválido."
  end
  local db = self:DB()
  rule.id = allocId(db)
  group.rules[#group.rules + 1] = rule
  db.groups[idx] = copyGroup(group, db)
  self:Refresh()
  return db.groups[idx].rules[#db.groups[idx].rules]
end

function A:UpdateGroupRule(groupId, ruleId, partial)
  local rule, ridx, group = self:GetGroupRuleById(groupId, ruleId)
  if not rule then
    return nil, "Regla de grupo no encontrada."
  end
  local merged = {}
  for k, v in pairs(rule) do
    merged[k] = v
  end
  if type(partial) == "table" then
    for k, v in pairs(partial) do
      if k ~= "id" then
        merged[k] = v
      end
    end
  end
  local normalized = copyGroupRule(merged)
  if not normalized then
    return nil, "Tipo de regla inválido."
  end
  normalized.id = rule.id
  group.rules[ridx] = normalized
  local db = self:DB()
  local _, gidx = self:GetGroupById(groupId)
  db.groups[gidx] = copyGroup(group, db)
  self:Refresh()
  return db.groups[gidx].rules[ridx]
end

function A:DeleteGroupRule(groupId, ruleId)
  local _, ridx, group = self:GetGroupRuleById(groupId, ruleId)
  if not group then
    return false
  end
  local _, gidx = self:GetGroupById(groupId)
  table.remove(group.rules, ridx)
  local db = self:DB()
  db.groups[gidx] = copyGroup(group, db)
  self:Refresh()
  return true
end

function A:GetEffectById(groupId, effectId)
  local group = self:GetGroupById(groupId)
  effectId = tonumber(effectId)
  if not group or not effectId then
    return nil
  end
  for i = 1, #group.effects do
    if group.effects[i].id == effectId then
      return group.effects[i], i, group
    end
  end
  return nil
end

--- Proyección legacy: un "rule" por grupo (efecto visual primario + reglas).
function A:GetRules()
  local groups = self:GetGroups()
  local out = {}
  for i = 1, #groups do
    out[i] = groupToVirtualRule(groups[i])
  end
  return out
end

function A:GetRuleById(id)
  local group, idx = self:GetGroupById(id)
  if not group then
    return nil
  end
  return groupToVirtualRule(group), idx
end

local function ensureModuleOn(self, db)
  if not db.enabled then
    db.enabled = true
    if not self._autoEnableWarned then
      self._autoEnableWarned = true
      print("|cff00ff00Chukie UI|r: módulo Alertas activado automáticamente.")
    end
  end
end

function A:AddRule(partial)
  local db = self:DB()
  if #db.groups >= MAX_GROUPS then
    return nil, "Máximo " .. MAX_GROUPS .. " alertas por perfil."
  end
  local rule = copyRule(partial, #db.groups + 1)
  if rule.spellId <= 0 then
    return nil, "Falta spellId."
  end
  if not KIND_OK[rule.kind] then
    return nil, "Tipo inválido."
  end
  local group = makeGroupFromLegacyRule(db, rule)
  db.groups[#db.groups + 1] = group
  ensureModuleOn(self, db)
  self:Refresh()
  return groupToVirtualRule(group)
end

function A:UpdateRule(id, partial)
  local group, idx = self:GetGroupById(id)
  if not group then
    return nil, "Regla no encontrada."
  end
  if #(group.rules or {}) > 1 then
    return nil, "Este grupo usa reglas nativas; editá cada condición con UpdateGroupRule."
  end
  local merged = groupToVirtualRule(group)
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
      elseif k ~= "id" and k ~= "_effectId" then
        merged[k] = v
      end
    end
  end
  merged = copyRule(merged, idx)
  merged.id = group.id
  if merged.spellId <= 0 then
    return nil, "Falta spellId."
  end
  local effectId = type(partial) == "table" and tonumber(partial._effectId) or nil
  local db = self:DB()
  db.groups[idx] = applyVirtualToGroup(group, merged, db, effectId)
  self:Refresh()
  return groupToVirtualRule(db.groups[idx])
end

function A:DeleteRule(id)
  local _, idx = self:GetGroupById(id)
  if not idx then
    return false
  end
  local db = self:DB()
  table.remove(db.groups, idx)
  if self.ReleaseAuraContainer then
    self:ReleaseAuraContainer(id)
  end
  self:Refresh()
  return true
end

function A:AddEffect(groupId, partial)
  local group, idx = self:GetGroupById(groupId)
  if not group then
    return nil, "Grupo no encontrado."
  end
  if #group.effects >= MAX_EFFECTS_PER_GROUP then
    return nil, "Máximo " .. MAX_EFFECTS_PER_GROUP .. " efectos por grupo."
  end
  local db = self:DB()
  local e = copyEffect(partial, #group.effects + 1)
  e.id = allocId(db)
  if EFFECT_STUB[e.type] then
    e.enabled = false
  end
  group.effects[#group.effects + 1] = e
  db.groups[idx] = copyGroup(group, db)
  self:Refresh()
  return e
end

function A:UpdateEffect(groupId, effectId, partial)
  local e, eidx, group = self:GetEffectById(groupId, effectId)
  if not e or not group then
    return nil, "Efecto no encontrado."
  end
  local _, gidx = self:GetGroupById(groupId)
  if type(partial) == "table" then
    for k, v in pairs(partial) do
      if k == "point" then
        e.point = copyPoint(v, eidx)
      elseif k == "color" then
        e.color = copyColor(v)
      elseif k ~= "id" then
        e[k] = v
      end
    end
  end
  group.effects[eidx] = copyEffect(e, eidx)
  local db = self:DB()
  db.groups[gidx] = copyGroup(group, db)
  self:Refresh()
  return db.groups[gidx].effects[eidx]
end

function A:DeleteEffect(groupId, effectId)
  local e, eidx, group = self:GetEffectById(groupId, effectId)
  if not e or not group then
    return false
  end
  if EFFECT_VISUAL[e.type] and countVisualEffects(group, false) <= 1 then
    return false, "Hace falta al menos un efecto visual."
  end
  local _, gidx = self:GetGroupById(groupId)
  table.remove(group.effects, eidx)
  local db = self:DB()
  db.groups[gidx] = copyGroup(group, db)
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

spellName = function(spellId)
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

--- Test booleano seguro: los payloads de UNIT_AURA traen campos secretos en 12.x y
--- evaluarlos directo en un `if` lanza error ("boolean test on a secret value").
local function truthy(v)
  if v == nil or isSecret(v) then
    return false
  end
  return v and true or false
end

--- Devuelve el valor solo si es legible. Hay que filtrar antes de cualquier `if v`,
--- `tonumber(v)` o comparación, porque tocar un secreto en esas posiciones da error.
local function plain(v)
  if isSecret(v) then
    return nil
  end
  return v
end

local function spellAuraIsSecretNow(spellId)
  if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
    local ok, secret = pcall(C_Secrets.ShouldSpellAuraBeSecret, spellId)
    return ok and secret == true
  end
  return false
end

local function spellIdMatches(sid, want)
  if sid == nil or want == nil then
    return false
  end
  if isSecret(sid) then
    return false
  end
  return tonumber(sid) == tonumber(want)
end

--- Watch por auraInstanceID (NeverSecret): identifica el buff listando auras
--- cuando spellId o icon son legibles; luego sigue la instancia aunque el spellId se oculte.
--- unit -> spellId -> { [auraInstanceID] = true }
A._auraWatch = A._auraWatch or {}

local function wantSpellIcon(spellId)
  spellId = tonumber(spellId) or 0
  if spellId <= 0 then
    return nil
  end
  local tex = spellTexture(spellId)
  if tex and not isSecret(tex) then
    return tonumber(tex) or tex
  end
  return nil
end

local function auraMatchesWanted(aura, spellId, wantTex)
  if not aura then
    return false
  end
  if spellIdMatches(aura.spellId, spellId) then
    return true
  end
  -- Fallback 12.0: si el icono del buff no es secreto, comparar FileID del hechizo.
  local icon = aura.icon
  if wantTex ~= nil and icon ~= nil and not isSecret(icon) then
    local ic = tonumber(icon) or icon
    if ic == wantTex then
      return true
    end
  end
  return false
end

local function watchRemember(unit, spellId, instanceId)
  instanceId = tonumber(plain(instanceId))
  spellId = tonumber(spellId) or 0
  if not unit or not instanceId or spellId <= 0 then
    return
  end
  A._auraWatch[unit] = A._auraWatch[unit] or {}
  A._auraWatch[unit][spellId] = A._auraWatch[unit][spellId] or {}
  A._auraWatch[unit][spellId][instanceId] = true
end

local function watchForgetInstance(unit, instanceId)
  instanceId = tonumber(plain(instanceId))
  if not unit or not instanceId or not A._auraWatch[unit] then
    return
  end
  for spellId, set in pairs(A._auraWatch[unit]) do
    if set[instanceId] then
      set[instanceId] = nil
    end
  end
end

local function watchClearUnitSpell(unit, spellId)
  if A._auraWatch[unit] then
    A._auraWatch[unit][spellId] = nil
  end
end

local function watchHas(unit, spellId)
  spellId = tonumber(spellId) or 0
  local set = A._auraWatch[unit] and A._auraWatch[unit][spellId]
  if not set then
    return false
  end
  local any = false
  for iid in pairs(set) do
    any = true
    if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, iid)
      if not ok or not aura then
        set[iid] = nil
      else
        return true
      end
    else
      return true
    end
  end
  return false
end

local AURA_SCAN_FILTERS = {
  "HELPFUL",
  "HARMFUL",
  "HELPFUL|INCLUDE_NAME_PLATE_ONLY",
  "HARMFUL|INCLUDE_NAME_PLATE_ONLY",
  "HELPFUL|PLAYER",
  "HARMFUL|PLAYER",
  "HELPFUL|RAID_IN_COMBAT",
  "HELPFUL|PLAYER|RAID_IN_COMBAT",
}

local function watchedSpellIds()
  local out, seen = {}, {}
  local groups = A.GetGroups and A:GetGroups() or {}
  for gi = 1, #groups do
    local rules = groups[gi].rules or {}
    for ri = 1, #rules do
      local r = rules[ri]
      if r and r.enabled ~= false and (r.type == "aura" or r.type == "proc") then
        local sid = tonumber(r.spellId) or 0
        if sid > 0 and not seen[sid] then
          seen[sid] = true
          out[#out + 1] = sid
        end
      end
    end
  end
  return out
end

--- Reconstruye el watch listando auras del unit (API de listado de Blizzard).
function A:RebuildAuraWatch(unit)
  unit = unit or "player"
  if unit ~= "player" and not UnitExists(unit) then
    A._auraWatch[unit] = nil
    return
  end
  local spells = watchedSpellIds()
  for i = 1, #spells do
    watchClearUnitSpell(unit, spells[i])
  end
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex or #spells == 0 then
    return
  end
  local want = {}
  for i = 1, #spells do
    want[spells[i]] = wantSpellIcon(spells[i])
  end
  for li = 1, #AURA_SCAN_FILTERS do
    local filt = AURA_SCAN_FILTERS[li]
    for idx = 1, 40 do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, idx, filt)
      if not ok then
        -- Un aura secreta hace fallar la llamada: seguir con el resto de la lista.
      elseif not aura then
        break
      else
        local iid = plain(aura.auraInstanceID)
        if iid then
          for si = 1, #spells do
            local sid = spells[si]
            if auraMatchesWanted(aura, sid, want[sid]) then
              watchRemember(unit, sid, iid)
            end
          end
        end
      end
    end
  end
end

function A:IngestUnitAura(unit, updateInfo)
  if not unit or unit == "" then
    return
  end
  -- isFullUpdate puede venir secreto: si no se puede leer, se relista todo.
  if type(updateInfo) ~= "table" or isSecret(updateInfo.isFullUpdate) or truthy(updateInfo.isFullUpdate) then
    self:RebuildAuraWatch(unit)
    return
  end
  local spells = watchedSpellIds()
  if #spells == 0 then
    return
  end
  local want = {}
  for i = 1, #spells do
    want[spells[i]] = wantSpellIcon(spells[i])
  end
  if truthy(updateInfo.addedAuras) then
    for i = 1, #updateInfo.addedAuras do
      local aura = updateInfo.addedAuras[i]
      local iid = aura and plain(aura.auraInstanceID)
      if iid then
        for si = 1, #spells do
          local sid = spells[si]
          if auraMatchesWanted(aura, sid, want[sid]) then
            watchRemember(unit, sid, iid)
          end
        end
      end
    end
  end
  if truthy(updateInfo.updatedAuraInstanceIDs) then
    for i = 1, #updateInfo.updatedAuraInstanceIDs do
      local iid = plain(updateInfo.updatedAuraInstanceIDs[i])
      if iid and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, iid)
        if ok and aura then
          for si = 1, #spells do
            local sid = spells[si]
            if auraMatchesWanted(aura, sid, want[sid]) then
              watchRemember(unit, sid, iid)
            end
          end
        end
      end
    end
  end
  if truthy(updateInfo.removedAuraInstanceIDs) then
    for i = 1, #updateInfo.removedAuraInstanceIDs do
      local iid = plain(updateInfo.removedAuraInstanceIDs[i])
      if iid then
        watchForgetInstance(unit, iid)
      end
    end
  end
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

--- Booleano de la API: nil si no existe o si viene como valor secreto.
local function readBool(v)
  if v == nil or isSecret(v) then
    return nil
  end
  return v == true
end

--- Heurística antigua por tiempos (clientes sin isActive). nil = tiempos ocultos.
local function legacyOnRealCooldown(spellId)
  local start, duration, enabled, _, flaggedGcd, secret = getSpellCooldown(spellId)
  if secret then
    return nil
  end
  if not enabled or duration <= 0 or start <= 0 then
    return false
  end
  if flaggedGcd then
    return false
  end
  local _, gcdDur, _, _, _, gcdSecret = getSpellCooldown(GCD_SPELL_ID)
  gcdDur = (not gcdSecret) and (tonumber(gcdDur) or 0) or 0
  -- GCD típico ~1–1.5s; si duration ≈ gcd o <= 1.5, tratar como GCD.
  if gcdDur > 0 and duration <= (gcdDur + 0.05) then
    return false
  end
  if duration <= 1.5 then
    return false
  end
  return true
end

--- Estado de CD/cargas leyendo solo campos NeverSecret (isEnabled, isActive, isOnGCD,
--- maxCharges). Nunca toca startTime/duration, así que funciona igual en combate.
--- Campos: cdActive, onGcd, hasCharges, maxCharges, chargeActive, empty, count.
--- count es nil cuando no se puede deducir (más de 2 cargas y recarga en curso).
local function getSpellCdState(spellId)
  spellId = tonumber(spellId) or 0
  local st = {
    cdActive = false,
    onGcd = false,
    hasCharges = false,
    maxCharges = nil,
    chargeActive = false,
    empty = false,
    count = nil,
  }
  if spellId <= 0 then
    return st
  end

  local cdActiveRaw
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellId)
    if ok and type(info) == "table" then
      local active = readBool(info.isActive)
      st.onGcd = readBool(info.isOnGCD) == true
      if active ~= nil then
        cdActiveRaw = active and readBool(info.isEnabled) ~= false
      end
    end
  end
  if cdActiveRaw == nil then
    local legacy = legacyOnRealCooldown(spellId)
    if legacy ~= nil then
      cdActiveRaw = legacy
      st.onGcd = false
    end
  end
  st.cdActive = cdActiveRaw == true and not st.onGcd

  if C_Spell and C_Spell.GetSpellCharges then
    local ok, info = pcall(C_Spell.GetSpellCharges, spellId)
    if ok and type(info) == "table" and not isSecret(info.maxCharges) then
      local maxCharges = tonumber(info.maxCharges)
      if maxCharges and maxCharges > 1 then
        st.hasCharges = true
        st.maxCharges = math.floor(maxCharges)
        local current
        if not isSecret(info.currentCharges) then
          current = tonumber(info.currentCharges)
        end
        local active = readBool(info.isActive)
        if active == nil and current then
          active = current < st.maxCharges
        end
        st.chargeActive = active == true
        -- Sin cargas: además de la recarga, el CD normal del hechizo está activo.
        st.empty = st.chargeActive and st.cdActive
        if current then
          st.count = math.floor(current)
          st.empty = st.count <= 0
        elseif not st.chargeActive then
          st.count = st.maxCharges
        elseif st.empty then
          st.count = 0
        elseif st.maxCharges == 2 then
          st.count = 1
        end
      end
    end
  end

  if not st.hasCharges then
    st.empty = st.cdActive
    st.count = st.cdActive and 0 or 1
  end

  return st
end

local function isSpellUsableNow(spellId)
  if C_Spell and C_Spell.IsSpellUsable then
    local ok, usable = pcall(C_Spell.IsSpellUsable, spellId)
    if not ok or isSecret(usable) then
      return true
    end
    return usable and true or false
  end
  if IsUsableSpell then
    local ok, usable = pcall(IsUsableSpell, spellId)
    if not ok or isSecret(usable) then
      return true
    end
    return usable and true or false
  end
  return true
end

local function isSpellInRangeOk(spellId)
  if C_Spell and C_Spell.IsSpellInRange then
    local ok, inRange = pcall(C_Spell.IsSpellInRange, spellId)
    -- nil = N/A (sin target / no aplica) → ok
    if ok and not isSecret(inRange) and inRange == false then
      return false
    end
    return true
  end
  if IsSpellInRange then
    local ok, r = pcall(IsSpellInRange, spellId, "target")
    if ok and not isSecret(r) and r == 0 then
      return false
    end
  end
  return true
end

--- Disponible: usable + rango OK + al menos una carga (o sin CD real).
local function isSpellAvailable(spellId, st)
  if not isSpellUsableNow(spellId) then
    return false
  end
  if not isSpellInRangeOk(spellId) then
    return false
  end
  st = st or getSpellCdState(spellId)
  return not st.empty
end

local function clearCooldown(cd)
  if cd then
    pcall(function()
      cd:Clear()
    end)
  end
end

--- Swipe del CD. En 12.x los duration objects son la única vía admitida para
--- configurar un Cooldown con datos secretos: el widget los resuelve internamente
--- sin exponer tiempos, así que el swipe también anima en combate.
--- Con cargas se dibuja la recarga de la próxima (con 0 cargas equivale al CD completo).
local function applySpellCooldownVisual(cd, spellId, hasCharges)
  if not cd then
    return
  end
  spellId = tonumber(spellId) or 0
  if spellId <= 0 then
    clearCooldown(cd)
    return
  end
  if cd.SetCooldownFromDurationObject and C_Spell then
    local getter = hasCharges and C_Spell.GetSpellChargeDuration or C_Spell.GetSpellCooldownDuration
    if getter then
      local ok, dur
      if hasCharges then
        ok, dur = pcall(getter, spellId)
      else
        ok, dur = pcall(getter, spellId, true)
      end
      if ok and dur and pcall(cd.SetCooldownFromDurationObject, cd, dur) then
        return
      end
      clearCooldown(cd)
      return
    end
  end
  local start, duration, enabled, modRate, _, secret = getSpellCooldown(spellId)
  if secret or not enabled or duration <= 0 or start <= 0 then
    clearCooldown(cd)
    return
  end
  if not pcall(cd.SetCooldown, cd, start, duration, modRate or 1) then
    clearCooldown(cd)
  end
end

--- ¿La unidad tiene el aura? filter = HELPFUL | HARMFUL | both.
local function unitHasAura(unit, spellId, filter)
  spellId = tonumber(spellId) or 0
  if spellId <= 0 or not unit or unit == "" then
    return false
  end
  if unit ~= "player" and not UnitExists(unit) then
    return false
  end
  filter = filter or "both"

  local function auraMatchesFilter(aura)
    if not aura then
      return false
    end
    -- isHarmful/isHelpful son NeverSecret en 12.x
    if filter == "both" then
      return true
    end
    if filter == "HELPFUL" then
      if aura.isHelpful == true then
        return true
      end
      return aura.isHarmful ~= true
    end
    if filter == "HARMFUL" then
      if aura.isHarmful == true then
        return true
      end
      return aura.isHelpful ~= true
    end
    return true
  end

  -- 1) Lookup directo por spellId (nil != ausente si el aura es secreta en combate).
  if unit == "player" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
    if ok and aura and auraMatchesFilter(aura) then
      return true
    end
  end
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
    local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellID, unit, spellId)
    if ok and data and auraMatchesFilter(data) then
      return true
    end
  end
  -- GetUnitAuraBySpellID (12.x)
  if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
    local ok, data = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellId)
    if ok and data and auraMatchesFilter(data) then
      return true
    end
  end

  -- 2) Por nombre (mismo RequiresNonSecretAura, pero a veces responde cuando el id no).
  local name = spellName(spellId)
  if name and name ~= "" and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    local nameFilters
    if filter == "HELPFUL" then
      nameFilters = { "HELPFUL", "HELPFUL|INCLUDE_NAME_PLATE_ONLY" }
    elseif filter == "HARMFUL" then
      nameFilters = { "HARMFUL", "HARMFUL|INCLUDE_NAME_PLATE_ONLY" }
    else
      nameFilters = {
        "HELPFUL",
        "HARMFUL",
        "HELPFUL|INCLUDE_NAME_PLATE_ONLY",
        "HARMFUL|INCLUDE_NAME_PLATE_ONLY",
      }
    end
    for i = 1, #nameFilters do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, nameFilters[i])
      if ok and aura and auraMatchesFilter(aura) then
        return true
      end
    end
  end

  -- 3) Barrido por índice + match spellId o icon FileID (si no son secretos).
  local wantTex = wantSpellIcon(spellId)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local lists
    if filter == "HELPFUL" then
      lists = {
        "HELPFUL",
        "HELPFUL|INCLUDE_NAME_PLATE_ONLY",
        "HELPFUL|PLAYER",
        "HELPFUL|RAID_IN_COMBAT",
        "HELPFUL|PLAYER|RAID_IN_COMBAT",
      }
    elseif filter == "HARMFUL" then
      lists = { "HARMFUL", "HARMFUL|INCLUDE_NAME_PLATE_ONLY", "HARMFUL|PLAYER" }
    else
      lists = AURA_SCAN_FILTERS
    end
    for li = 1, #lists do
      for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, lists[li])
        if not ok then
          -- Aura secreta en ese índice: no cortar, puede haber más adelante.
        elseif not aura then
          break
        elseif auraMatchesFilter(aura) and auraMatchesWanted(aura, spellId, wantTex) then
          watchRemember(unit, spellId, aura.auraInstanceID)
          return true
        end
      end
    end
  end

  if AuraUtil and AuraUtil.FindAuraBySpellID then
    if filter == "HELPFUL" then
      if AuraUtil.FindAuraBySpellID(spellId, unit, "HELPFUL") ~= nil then
        return true
      end
    elseif filter == "HARMFUL" then
      if AuraUtil.FindAuraBySpellID(spellId, unit, "HARMFUL") ~= nil then
        return true
      end
    elseif AuraUtil.FindAuraBySpellID(spellId, unit, "HELPFUL") ~= nil
      or AuraUtil.FindAuraBySpellID(spellId, unit, "HARMFUL") ~= nil
    then
      return true
    end
  end

  -- 4) Instancia ya identificada (spellId/icon legibles en un update anterior).
  if watchHas(unit, spellId) then
    return true
  end
  return false
end

--- ¿Se puede confiar en un "no lo tiene"? Con auras secretas todas las vías de
--- lectura fallan igual que si el buff no estuviera, así que la ausencia no se
--- puede afirmar y las condiciones que dependen de ella no deben dispararse.
local function auraAbsenceIsReliable(unit, spellId)
  spellId = tonumber(spellId) or 0
  if spellId <= 0 then
    return true
  end
  -- En builds sin la API de secretos no hay forma de distinguir: se mantiene el
  -- comportamiento clásico y la ausencia se toma como válida.
  return not spellAuraIsSecretNow(spellId)
end

--- ¿El cliente oculta el aura de este hechizo ahora? Lo usa el editor para avisar
--- que una condición basada en la ausencia del aura no se puede evaluar.
function A:IsSpellAuraSecret(spellId)
  return spellAuraIsSecretNow(spellId)
end

--- Diagnóstico en juego: /chukieui cdcheck [spellId]
--- Muestra qué se puede saber del CD/cargas sin leer valores secretos.
function A:DebugCdCheck(spellId)
  spellId = tonumber(spellId) or 0
  if spellId <= 0 then
    print("|cffff9900Chukie UI|r: uso — /chukieui cdcheck 410089")
    return
  end
  local st = getSpellCdState(spellId)
  local exact = "no"
  if C_Spell and C_Spell.GetSpellCharges then
    local ok, info = pcall(C_Spell.GetSpellCharges, spellId)
    if ok and type(info) == "table" and not isSecret(info.currentCharges) then
      exact = "sí"
    end
  end
  print(string.format(
    "|cff00ff00Chukie UI|r cdcheck #%d (%s) | combate=%s | cargas=%s max=%s | recargando=%s | CD=%s (gcd=%s) | sinCargas=%s | conteo=%s (exacto=%s)",
    spellId,
    tostring(spellName(spellId) or "?"),
    tostring(UnitAffectingCombat("player") and true or false),
    tostring(st.hasCharges),
    tostring(st.maxCharges),
    tostring(st.chargeActive),
    tostring(st.cdActive),
    tostring(st.onGcd),
    tostring(st.empty),
    tostring(st.count),
    exact
  ))
end

--- Diagnóstico en juego: /chukieui auracheck [spellId]
function A:DebugAuraCheck(spellId, unit)
  spellId = tonumber(spellId) or 0
  unit = unit or "player"
  self:RebuildAuraWatch(unit)
  local name = spellName(spellId) or "?"
  local secret = spellAuraIsSecretNow(spellId)
  local has = unitHasAura(unit, spellId, "both")
  local secrecy = "?"
  if C_Secrets and C_Secrets.GetSpellAuraSecrecy then
    local ok, s = pcall(C_Secrets.GetSpellAuraSecrecy, spellId)
    if ok then
      secrecy = tostring(s)
    end
  end
  local direct = "nil"
  if unit == "player" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
    direct = (ok and aura) and "table" or "nil"
  end
  local wantTex = wantSpellIcon(spellId)
  local listed, iconHit, sidHit, iconSecretN, sidSecretN = 0, 0, 0, 0, 0
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL|INCLUDE_NAME_PLATE_ONLY")
      if not ok then
        -- La llamada falla en las auras secretas: contarlas y seguir.
        sidSecretN = sidSecretN + 1
      elseif not aura then
        break
      else
        listed = listed + 1
        if isSecret(aura.spellId) then
          sidSecretN = sidSecretN + 1
        elseif spellIdMatches(aura.spellId, spellId) then
          sidHit = sidHit + 1
        end
        if isSecret(aura.icon) then
          iconSecretN = iconSecretN + 1
        elseif wantTex and (tonumber(aura.icon) or aura.icon) == wantTex then
          iconHit = iconHit + 1
        end
      end
    end
  end
  local tracked = watchHas(unit, spellId)
  print(string.format(
    "|cff00ff00Chukie UI|r auracheck #%d (%s) unit=%s | módulo=%s | has=%s | secretNow=%s | secrecy=%s | GetPlayerAura=%s | combate=%s",
    spellId,
    name,
    unit,
    tostring(self:IsEnabled()),
    tostring(has),
    tostring(secret),
    secrecy,
    direct,
    tostring(UnitAffectingCombat("player"))
  ))
  print(string.format(
    "|cff00ff00Chukie UI|r   listado nameplate: %d | spellIdHit=%d spellIdSecret=%d | iconHit=%d iconSecret=%d | trackedInstance=%s | wantIcon=%s",
    listed,
    sidHit,
    sidSecretN,
    iconHit,
    iconSecretN,
    tostring(tracked),
    tostring(wantTex)
  ))
  if secret and not has then
    local hasAC = self.HasAuraContainerAPI and self:HasAuraContainerAPI()
    if hasAC then
      print("|cffff9900Chukie UI|r   Aura secreta: el listado legacy no la identifica. Usá regla kind=aura «Presente» (motor AuraContainer).")
    else
      print("|cffff9900Chukie UI|r   Aura secreta sin AuraContainer en este cliente. Actualizá a 12.1 (Interface 120100) o el motor Container no está disponible.")
    end
  end
  local backend = self.GetAuraDisplayBackend and self:GetAuraDisplayBackend() or "legacy"
  print(string.format(
    "|cff00ff00Chukie UI|r   displayBackend=%s | auraContainerAPI=%s",
    backend,
    tostring(self.HasAuraContainerAPI and self:HasAuraContainerAPI() or false)
  ))
  return has
end

local function playerHasAura(spellId)
  return unitHasAura("player", spellId, "both")
end

--- Stacks del aura en la unidad (0 si no está; nil si secreto).
local function getUnitAuraStacks(unit, spellId, filter)
  spellId = tonumber(spellId) or 0
  if spellId <= 0 then
    return 0
  end
  unit = unit or "player"
  filter = filter or "both"

  local function appsFromAura(aura)
    if not aura then
      return nil
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

  local function matchesFilter(aura)
    if not aura then
      return false
    end
    if filter == "HELPFUL" and aura.isHarmful == true then
      return false
    end
    if filter == "HARMFUL" and aura.isHarmful ~= true then
      return false
    end
    return true
  end

  -- No cortar en nil: Mass Disintegrate y similares a veces fallan en GetPlayerAuraBySpellID.
  if unit == "player" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
    if ok and aura and matchesFilter(aura) then
      local n = appsFromAura(aura)
      return n == nil and nil or n
    end
  end
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellID, unit, spellId)
    if ok and aura and matchesFilter(aura) then
      local n = appsFromAura(aura)
      return n == nil and nil or n
    end
  end
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local lists
    if filter == "HELPFUL" then
      lists = { "HELPFUL", "HELPFUL|INCLUDE_NAME_PLATE_ONLY", "HELPFUL|PLAYER" }
    elseif filter == "HARMFUL" then
      lists = { "HARMFUL", "HARMFUL|INCLUDE_NAME_PLATE_ONLY", "HARMFUL|PLAYER" }
    else
      lists = {
        "HELPFUL",
        "HARMFUL",
        "HELPFUL|INCLUDE_NAME_PLATE_ONLY",
        "HARMFUL|INCLUDE_NAME_PLATE_ONLY",
        "HELPFUL|PLAYER",
        "HARMFUL|PLAYER",
      }
    end
    for li = 1, #lists do
      for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, lists[li])
        if not ok then
          -- Aura secreta en ese índice: seguir con el resto de la lista.
        elseif not aura then
          break
        else
          local sid = plain(aura.spellId)
          if sid and tonumber(sid) == spellId then
            local n = appsFromAura(aura)
            return n == nil and nil or n
          end
        end
      end
    end
  end
  if AuraUtil and AuraUtil.FindAuraBySpellID then
    local function try(filt)
      local name, _, count = AuraUtil.FindAuraBySpellID(spellId, unit, filt)
      if not name then
        return false, 0
      end
      if isSecret(count) then
        return true, nil
      end
      count = tonumber(count)
      if not count or count < 1 then
        return true, 1
      end
      return true, count
    end
    if filter == "HELPFUL" or filter == "HARMFUL" then
      local found, n = try(filter)
      if found then
        return n
      end
    else
      local found, n = try("HELPFUL")
      if found then
        return n
      end
      found, n = try("HARMFUL")
      if found then
        return n
      end
    end
  end
  return 0
end

--- Stacks del aura en el jugador (0 si no está).
local function getAuraStacks(spellId)
  return getUnitAuraStacks("player", spellId, "both")
end

--- Cargas actuales del hechizo. Sin sistema de cargas: 1 si no en CD real, 0 si en CD.
--- nil = no deducible (en combate, con más de 2 cargas y recarga en curso).
local function getSpellChargeCount(spellId)
  spellId = tonumber(spellId) or 0
  if spellId <= 0 then
    return 0
  end
  return getSpellCdState(spellId).count
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

--- Filtro opcional de cargas (CD) o stacks (proc/aura). AND con el resto de condiciones.
--- En cooldowns, si el conteo no es deducible se ignora el filtro en vez de ocultar
--- la alerta (Blizzard oculta el número exacto de cargas en combate).
local function passesChargeFilter(rule, st)
  local f = rule and rule.chargeFilter
  if type(f) ~= "table" or not f.enabled then
    return true
  end
  local n
  if rule.kind == "proc" then
    n = getAuraStacks(rule.spellId)
  elseif rule.kind == "aura" then
    local unit = rule.auraUnit == "target" and "target" or "player"
    n = getUnitAuraStacks(unit, rule.spellId, rule.auraFilter or "both")
  else
    if st then
      n = st.count
    else
      n = getSpellChargeCount(rule.spellId)
    end
    if n == nil then
      return true
    end
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
  -- Overlay dorado de barra: solo CD (no proc/aura).
  if rule and (rule.kind == "proc" or rule.kind == "aura") then
    if frame._overlayFxActive then
      frame._overlayFxActive = false
      frame:SetScript("OnUpdate", nil)
      restoreOverlayVisuals(frame, rule)
    end
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
    self._host:Show()
    return self._host
  end
  local host = CreateFrame("Frame", "ChukieUi_AlertsHost", UIParent)
  host:SetFrameStrata("HIGH")
  host:SetFrameLevel(100)
  host:SetAllPoints(UIParent)
  host:EnableMouse(false)
  host:Show()
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
  local chargeText = iconLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  chargeText:SetPoint("BOTTOMRIGHT", iconLayer, "BOTTOMRIGHT", -3, 2)
  chargeText:SetJustifyH("RIGHT")
  chargeText:SetTextColor(1, 1, 1, 1)
  chargeText:SetShadowColor(0, 0, 0, 1)
  chargeText:SetShadowOffset(1, -1)
  chargeText:Hide()
  iconLayer.chargeText = chargeText
  f.iconLayer = iconLayer
  f.icon = icon
  f.cooldown = cd
  f.chargeText = chargeText

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
    if frame.chargeText then
      frame.chargeText:Hide()
    end
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
  frame._displayMode = nil
end

local function hideLayersExcept(frame, keep)
  if keep ~= "icon" and frame.iconLayer then
    frame.iconLayer:Hide()
    if frame.chargeText then
      frame.chargeText:Hide()
    end
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
  end
end

local function applyIconMode(frame, rule, show, st, glowKey, playSoundIfNew)
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
  if frame.chargeText then
    -- En combate el número exacto solo se puede deducir hasta 2 cargas.
    local n = st and st.hasCharges and st.count or nil
    if rule.kind == "cooldown" and n ~= nil then
      frame.chargeText:SetText(tostring(n))
      frame.chargeText:Show()
    else
      frame.chargeText:Hide()
    end
  end
  if playSoundIfNew and not frame._wasShown then
    playAlertSound(rule.sound ~= false, rule.soundPath)
  end
  startGlow(frame, rule.glowType, glowKey)
  if rule.kind ~= "proc" and rule.kind ~= "aura" and frame.cooldown then
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
      applySpellCooldownVisual(frame.cooldown, rule.spellId, st and st.hasCharges)
    else
      frame.cooldown:Hide()
      clearCooldown(frame.cooldown)
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

--- Devuelve show y, en reglas de cooldown, el estado no secreto de CD/cargas.
local function shouldShowRule(rule)
  local pv = A._livePreview
  local preview = pv and pv.forceShow and (pv.groupId == rule.id or pv.ruleId == rule.id)
  if not preview then
    if not A:IsEnabled() or rule.enabled == false or (tonumber(rule.spellId) or 0) <= 0 then
      return false
    end
    if rule.combatOnly and not UnitAffectingCombat("player") then
      return false
    end
    if rule.targetOnly and not hasValidTarget(rule.spellId) then
      return false
    end
  elseif (tonumber(rule.spellId) or 0) <= 0 then
    return false
  end
  if rule.kind == "proc" then
    if preview then
      return true
    end
    if rule.chargeFilter and rule.chargeFilter.enabled then
      return passesChargeFilter(rule)
    end
    return playerHasAura(rule.spellId)
  end
  if rule.kind == "aura" then
    if preview then
      return true
    end
    local unit = rule.auraUnit == "target" and "target" or "player"
    if unit == "target" and not UnitExists("target") then
      return false
    end
    local has = unitHasAura(unit, rule.spellId, rule.auraFilter or "both")
    local mode = rule.auraShow or "present"
    local show
    if mode == "always" then
      show = true
    elseif mode == "absent" then
      show = not has
    else
      show = has
    end
    if show and not passesChargeFilter(rule) then
      show = false
    end
    return show
  end
  local st = getSpellCdState(rule.spellId)
  if preview then
    return true, st
  end
  local showOn = rule.showOn or "available"
  local show
  if showOn == "always" then
    show = true
  elseif showOn == "cooldown" then
    -- Con cargas, «en CD» significa que alguna carga está recargando.
    if st.hasCharges then
      show = st.chargeActive
    else
      show = st.cdActive
    end
  elseif showOn == "ready" then
    -- Con cargas, «lista» significa cargas al máximo.
    if st.hasCharges then
      show = not st.chargeActive
    else
      show = not st.cdActive
    end
  else
    show = isSpellAvailable(rule.spellId, st)
  end
  if show and not passesChargeFilter(rule, st) then
    show = false
  end
  return show, st
end

local function basicTargetExists()
  return UnitExists("target") and not UnitIsDead("target")
end

local function evaluateGroupRule(rule)
  if not rule or rule.enabled == false then
    return nil
  end
  local typ = rule.type
  if typ == "combat" then
    local active = UnitAffectingCombat("player") and true or false
    return active == (rule.on ~= false)
  elseif typ == "target" then
    return basicTargetExists() == (rule.on ~= false)
  end

  local spellId = math.floor(tonumber(rule.spellId) or 0)
  if spellId <= 0 then
    return false
  end
  local st = getSpellCdState(spellId)
  st.spellId = spellId

  if typ == "proc" then
    return playerHasAura(spellId), st
  elseif typ == "aura" then
    local unit = rule.auraUnit == "target" and "target" or "player"
    local has = unitHasAura(unit, spellId, rule.auraFilter or "both")
    local mode = rule.auraShow or "present"
    if mode == "always" then
      return true, st
    elseif mode == "absent" then
      -- "No lo veo" no es "no lo tiene": con un aura secreta no se afirma ausencia.
      if not has and not auraAbsenceIsReliable(unit, spellId) then
        return false, st
      end
      return not has, st
    end
    return has, st
  elseif typ == "charges" then
    -- Un valor secreto no debe convertirse en true, especialmente con OR.
    -- nil hace que esta condición sea neutral; si es la única, el grupo queda oculto.
    if st.count == nil then
      return nil, st
    end
    return compareNumber(st.count, rule.op or "gte", rule.value or 1), st
  elseif typ == "cooldown" then
    local mode = rule.showOn or "available"
    if mode == "always" then
      return true, st
    elseif mode == "cooldown" then
      if st.hasCharges then
        return st.chargeActive, st
      end
      return st.cdActive, st
    elseif mode == "ready" then
      if st.hasCharges then
        return not st.chargeActive, st
      end
      return not st.cdActive, st
    end
    return isSpellAvailable(spellId, st), st
  end
  return false, st
end

--- Evalúa exclusivamente las reglas nativas del grupo.
--- Retorna show y un estado de hechizo no secreto útil para la presentación.
function A:EvaluateGroupRules(group)
  if type(group) ~= "table" or type(group.rules) ~= "table" then
    return false, nil
  end
  local useOr = group.ruleLogic == "or"
  local evaluated = 0
  local firstState
  local anyTrue = false
  for i = 1, #group.rules do
    local ok, st = evaluateGroupRule(group.rules[i])
    if ok ~= nil then
      evaluated = evaluated + 1
      if st and not firstState then
        firstState = st
      end
      if ok then
        anyTrue = true
      elseif not useOr then
        return false, firstState
      end
    end
  end
  if evaluated == 0 then
    return false, firstState
  end
  if useOr then
    return anyTrue, firstState
  end
  return true, firstState
end

function A:SetLivePreview(groupId, effectId)
  if not groupId then
    self._livePreview = nil
    return
  end
  if effectId == false then
    self._livePreview = nil
    return
  end
  local eid
  if type(effectId) == "number" then
    eid = effectId
  end
  self._livePreview = {
    groupId = groupId,
    ruleId = groupId,
    effectId = eid,
    forceShow = true,
  }
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

--- Traduce el grupo al formato que espera el AuraContainer, o nil si no se puede
--- delegar. Solo encaja "mostrar este aura mientras esté puesta": Blizzard decide
--- el show/hide (por eso funciona con auras secretas) y nosotros solo presentamos,
--- así que cualquier condición extra, el sonido o varios efectos lo descartan.
local function containerRuleForGroup(group)
  if type(group) ~= "table" then
    return nil
  end
  local auraRule
  local rules = group.rules or {}
  for i = 1, #rules do
    local r = rules[i]
    if r and r.enabled ~= false then
      if r.type ~= "aura" or auraRule then
        return nil
      end
      auraRule = r
    end
  end
  if not auraRule or (auraRule.auraShow or "present") ~= "present" then
    return nil
  end
  if (math.floor(tonumber(auraRule.spellId) or 0)) <= 0 then
    return nil
  end
  local effect
  local effects = group.effects or {}
  for i = 1, #effects do
    local e = effects[i]
    if e and e.enabled ~= false then
      if e.type == "sound" then
        return nil
      end
      if EFFECT_VISUAL[e.type] then
        if effect then
          return nil
        end
        effect = e
      end
    end
  end
  if not effect or effect.type == "text" then
    return nil
  end
  return {
    id = group.id,
    kind = "aura",
    enabled = group.enabled ~= false,
    spellId = math.floor(tonumber(auraRule.spellId) or 0),
    auraShow = "present",
    auraUnit = auraRule.auraUnit == "target" and "target" or "player",
    auraFilter = auraRule.auraFilter or "both",
    display = effect.type == "texture" and "aura" or "icon",
    size = effect.size,
    point = effect.point,
    color = effect.color,
    alpha = effect.alpha,
    auraPath = effect.auraPath,
    auraLayout = effect.auraLayout,
    pairGap = effect.pairGap,
  }
end

--- Para la UI: si el grupo encaja en la ruta que dibuja el cliente y si esa ruta
--- está disponible en este cliente (en combate no se puede comprobar).
function A:GroupUsesAuraContainer(group)
  if not containerRuleForGroup(group) then
    return false, false
  end
  return true, (self.HasAuraContainerAPI and self:HasAuraContainerAPI()) or false
end

--- Diagnóstico en juego: /chukieui auracontainer
--- Dice qué grupos puede dibujar el cliente y cuáles tienen contenedor vivo.
function A:DebugAuraContainers()
  print(string.format(
    "|cff00ff00Chukie UI|r auracontainer | backend=%s | api=%s | combate=%s",
    tostring(self.GetAuraDisplayBackend and self:GetAuraDisplayBackend() or "?"),
    tostring(self.HasAuraContainerAPI and self:HasAuraContainerAPI() or false),
    tostring(UnitAffectingCombat("player") and true or false)
  ))
  local groups = self:GetGroups() or {}
  if #groups == 0 then
    print("|cff00ff00Chukie UI|r   sin grupos en el perfil.")
    return
  end
  for i = 1, #groups do
    local g = groups[i]
    local cRule = containerRuleForGroup(g)
    local live = self._auraContainers and self._auraContainers[g.id]
    local extra = ""
    if cRule then
      extra = string.format(
        " | aura #%d en %s, %s de %s px",
        cRule.spellId,
        cRule.auraUnit,
        cRule.display == "aura" and "textura" or "icono",
        tostring(math.floor(tonumber(cRule.size) or 48))
      )
    end
    print(string.format(
      "|cff00ff00Chukie UI|r   #%d %s | delegable=%s | contenedor=%s%s",
      g.id,
      (g.name and g.name ~= "" and g.name) or "?",
      cRule and "sí" or "no",
      live and "sí" or "no",
      extra
    ))
  end
end

local function firstGroupSpellId(group)
  for i = 1, #(group.rules or {}) do
    local sid = math.floor(tonumber(group.rules[i].spellId) or 0)
    if sid > 0 then
      return sid
    end
  end
  return 0
end

local function viewForEffect(group, effect)
  local vr = groupToVirtualRule(group)
  vr.spellId = math.floor(tonumber(effect.spellId) or 0)
  if vr.spellId <= 0 then
    vr.spellId = firstGroupSpellId(group)
  end
  for i = 1, #(group.rules or {}) do
    local gr = group.rules[i]
    if gr and tonumber(gr.spellId) == vr.spellId then
      if gr.type == "aura" or gr.type == "proc" or gr.type == "cooldown" then
        vr.kind = gr.type
      elseif gr.type == "charges" then
        vr.kind = "cooldown"
      end
      break
    end
  end
  if effect.type == "texture" then
    vr.display = "aura"
  elseif effect.type == "text" then
    vr.display = "text"
  else
    vr.display = "icon"
  end
  vr.size = effect.size
  vr.point = copyPoint(effect.point, 1)
  vr.color = copyColor(effect.color)
  vr.alpha = effect.alpha
  vr.glowType = effect.glowType
  vr.swipe = effect.swipe
  vr.edge = effect.edge
  vr.inverse = effect.inverse
  vr.auraPath = effect.auraPath
  vr.auraLayout = effect.auraLayout
  vr.pairGap = effect.pairGap
  vr.text = effect.text
  vr.fontPath = effect.fontPath
  vr.sound = false
  return vr
end

local function hideGroupEffects(group)
  if not group or type(group.effects) ~= "table" then
    return
  end
  for i = 1, #group.effects do
    local e = group.effects[i]
    local f = A._frames and A._frames[e.id]
    if f then
      hideFrame(f)
    end
  end
  if A._groupShown then
    A._groupShown[group.id] = nil
  end
end

local function renderEffect(group, effect, show, st, silent)
  if EFFECT_STUB[effect.type] or effect.type == "sound" then
    return
  end
  local view = viewForEffect(group, effect)
  if (not st or st.spellId ~= view.spellId) and view.spellId > 0 then
    st = getSpellCdState(view.spellId)
    st.spellId = view.spellId
  end
  local f = A:EnsureRuleFrame(effect.id)
  local glowKey = "g" .. tostring(group.id) .. "e" .. tostring(effect.id)
  if not show then
    hideFrame(f)
    return
  end
  if view.display == "aura" then
    applyAuraMode(f, view, true, false)
  elseif view.display == "text" then
    applyTextMode(f, view, true, false)
  else
    applyIconMode(f, view, true, st, glowKey, false)
  end
  applyOverlayFx(f, view, true)
end

function A:UpdateRuleFrame(rule, index)
  if not rule or not rule.id then
    return
  end
  local group = self:GetGroupById(rule.id)
  if group then
    self:UpdateGroup(group)
    return
  end
  if self.SyncAuraContainerRule and self:SyncAuraContainerRule(rule) then
    local f = self._frames and self._frames[rule.id]
    if f then
      hideFrame(f)
    end
    return
  end
  local f = self:EnsureRuleFrame(rule.id)
  local glowKey = "r" .. tostring(rule.id)
  local show, st = shouldShowRule(rule)
  local silent = self._livePreview and self._livePreview.forceShow and self._livePreview.ruleId == rule.id
  local display = rule.display or "icon"
  if display == "aura" then
    applyAuraMode(f, rule, show, not silent)
  elseif display == "text" then
    applyTextMode(f, rule, show, not silent)
  else
    applyIconMode(f, rule, show, st, glowKey, not silent)
  end
  applyOverlayFx(f, rule, show)
end

function A:UpdateGroup(group, partial)
  -- API pública CRUD y ruta interna de render comparten nombre por compatibilidad.
  if type(group) ~= "table" then
    return updateGroupRecord(self, group, partial)
  end
  if not group then
    return
  end
  local pv = self._livePreview
  local forcing = pv and pv.forceShow and pv.groupId == group.id
  local enabled = self:IsEnabled()
  if not forcing and (not enabled or group.enabled == false) then
    hideGroupEffects(group)
    if self.ReleaseAuraContainer then
      self:ReleaseAuraContainer(group.id)
    end
    return
  end
  -- Delegación al cliente: hay que resolverla antes de evaluar, porque el sentido
  -- de esta ruta es justamente que el aura puede ser ilegible para el addon.
  if not forcing then
    local cRule = containerRuleForGroup(group)
    if cRule and self.SyncAuraContainerRule and self:SyncAuraContainerRule(cRule) then
      hideGroupEffects(group)
      self._groupShown = self._groupShown or {}
      self._groupShown[group.id] = nil
      return
    end
  end
  if self.ReleaseAuraContainer then
    self:ReleaseAuraContainer(group.id)
  end

  local show, st = self:EvaluateGroupRules(group)
  if forcing then
    show = true
    local previewSpellId = firstGroupSpellId(group)
    if not st and previewSpellId > 0 then
      st = getSpellCdState(previewSpellId)
      st.spellId = previewSpellId
    end
    st = st or { hasCharges = false, count = 1, cdActive = false }
    if st.count == nil then
      st.count = 1
    end
  end
  if not show then
    hideGroupEffects(group)
    if self.ReleaseAuraContainer then
      self:ReleaseAuraContainer(group.id)
    end
    return
  end
  local filterId = forcing and pv.effectId or nil
  local anyShown = false
  for i = 1, #group.effects do
    local e = group.effects[i]
    local want = true
    if filterId then
      want = e.id == filterId
    elseif e.enabled == false then
      want = false
    end
    if not want or e.type == "sound" or EFFECT_STUB[e.type] then
      local f = self._frames and self._frames[e.id]
      if f then
        hideFrame(f)
      end
    else
      renderEffect(group, e, true, st, forcing)
      if EFFECT_VISUAL[e.type] then
        anyShown = true
      end
    end
  end
  self._groupShown = self._groupShown or {}
  if anyShown and not forcing then
    local snd = firstSoundEffect(group)
    if snd and snd.enabled ~= false and not self._groupShown[group.id] then
      playAlertSound(true, snd.soundPath)
    end
    self._groupShown[group.id] = true
  elseif not anyShown then
    self._groupShown[group.id] = nil
  end
end

function A:UpdateAllRules()
  local db = self:DB()
  local enabled = self:IsEnabled()
  local pv = self._livePreview
  local previewId = pv and pv.forceShow and (pv.groupId or pv.ruleId)
  local seenEffects = {}
  local seenGroups = {}
  local groups = db.groups or {}
  for i = 1, #groups do
    local group = groups[i]
    seenGroups[group.id] = true
    for ei = 1, #group.effects do
      seenEffects[group.effects[ei].id] = true
    end
    if enabled or group.id == previewId then
      self:UpdateGroup(group)
    else
      hideGroupEffects(group)
      if self.ReleaseAuraContainer then
        self:ReleaseAuraContainer(group.id)
      end
    end
  end
  if self._frames then
    for id, f in pairs(self._frames) do
      if not seenEffects[id] then
        hideFrame(f)
      end
    end
  end
  if self.ReleaseStaleAuraContainers then
    self:ReleaseStaleAuraContainers(seenGroups)
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
  -- Varios units en una sola llamada (dos RegisterUnitEvent se pisan).
  ev:RegisterUnitEvent("UNIT_AURA", "player", "target")
  ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
  pcall(function()
    ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
  end)
  local function kickUpdate()
    if not A:IsEnabled() and not (A._livePreview and A._livePreview.forceShow) then
      return
    end
    A:UpdateAllRules()
  end
  ev:SetScript("OnEvent", function(_, event, unit, updateInfo)
    if event == "UNIT_AURA" and A.IngestUnitAura then
      A:IngestUnitAura(unit, updateInfo)
    end
    if event == "PLAYER_ENTERING_WORLD" and A.RebuildAuraWatch then
      A:RebuildAuraWatch("player")
    end
    kickUpdate()
  end)

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
    if not A:IsEnabled() and not (A._livePreview and A._livePreview.forceShow) then
      return
    end
    A:UpdateAllRules()
  end)
end

function A:HideAll()
  if self.HideAllAuraContainers then
    self:HideAllAuraContainers()
  end
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
  if not self:IsEnabled() and not (self._livePreview and self._livePreview.forceShow) then
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
A.MAX_GROUPS = MAX_GROUPS
A.SIZE_MIN = SIZE_MIN
A.SIZE_MAX = SIZE_MAX
A.EFFECT_STUB = EFFECT_STUB
A.EFFECT_VISUAL = EFFECT_VISUAL
