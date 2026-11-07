--[[ Gestor de alertas: lista de grupos + ventana de grupo (efectos y condiciones a la vez).

  Trabaja directamente sobre el CRUD nativo del motor (Alerts.lua):
    * Grupos:  GetGroups / GetGroupById / AddGroup / UpdateGroup / DeleteGroup
    * Reglas:  GetGroupRuleById / AddGroupRule / UpdateGroupRule / DeleteGroupRule
    * Efectos: GetEffectById / AddEffect / UpdateEffect / DeleteEffect
    * Preview: SetLivePreview / ClearLivePreview
    * Módulo:  EnsureModuleEnabled / IsEnabled / SetEnabled

  Persistencia en vivo: cada cambio se guarda de inmediato con el CRUD. «Cancelar»
  borra el borrador (grupo nuevo) o restaura el snapshot profundo (grupo existente).
]]

local _, ns = ...

local M = {}
ns.AlertsManager = M

local MAX_RESULTS = 40
local MAX_AURA_SNAPSHOT = 80
local ROW_H = 26
local SIZE_MIN_FALLBACK, SIZE_MAX_FALLBACK = 24, 768

local DISPLAY_MODES = { "icon", "texture", "text" }
local DISPLAY_LABELS = { icon = "Icono", texture = "Aura", text = "Texto" }

local EFFECT_LABELS = {
  icon = "Icono",
  texture = "Textura",
  text = "Texto",
  sound = "Sonido",
  bar = "Barra",
  ring = "Reloj",
  counter = "Contador",
}

local EFFECT_ROW_ICONS = {
  icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01",
  texture = "Interface\\Icons\\INV_Enchant_EssenceEternalLarge",
  text = "Interface\\Icons\\INV_Scroll_03",
  sound = "Interface\\Icons\\INV_Misc_Bell_01",
  bar = "Interface\\Icons\\INV_Misc_EngGizmos_30",
  ring = "Interface\\Icons\\INV_Misc_PocketWatch_01",
  counter = "Interface\\Icons\\INV_Misc_Note_01",
}

local RULE_LABELS = {
  cooldown = "Cooldown",
  aura = "Aura",
  proc = "Proc",
  combat = "Combate",
  target = "Target",
  charges = "Cargas",
}

local CHARGE_OPS = { "gte", "gt", "eq", "lte", "lt", "ne" }
local CHARGE_OP_LABELS = { eq = "==", ne = "!=", gt = ">", gte = ">=", lt = "<", lte = "<=" }
local CHARGE_VALUE_MAX = 99

local SHOW_ON_ORDER = { "available", "ready", "cooldown", "always" }
local SHOW_ON_LABELS = {
  available = "Disponible",
  ready = "Listo / cargas llenas",
  cooldown = "Recargando",
  always = "Siempre",
}

-- ---------------------------------------------------------------------------
-- Helpers de motor / media
-- ---------------------------------------------------------------------------

local function alerts()
  return ns.Alerts
end

local function media()
  return ns.AlertsMedia
end

local function clampChargeValue(v)
  v = math.floor(tonumber(v) or 0)
  if v < 0 then
    return 0
  end
  if v > CHARGE_VALUE_MAX then
    return CHARGE_VALUE_MAX
  end
  return v
end

local function sizeBounds()
  local a = ns.Alerts
  local lo = (a and tonumber(a.SIZE_MIN)) or SIZE_MIN_FALLBACK
  local hi = (a and tonumber(a.SIZE_MAX)) or SIZE_MAX_FALLBACK
  return lo, hi
end

--- HSV (h en 0-360, s/v en 0-1) → RGB 0-1.
local function hsvToRgb(h, s, v)
  h = (h % 360) / 60
  local i = math.floor(h)
  local f = h - i
  local p = v * (1 - s)
  local q = v * (1 - s * f)
  local t = v * (1 - s * (1 - f))
  if i == 0 then
    return v, t, p
  elseif i == 1 then
    return q, v, p
  elseif i == 2 then
    return p, v, t
  elseif i == 3 then
    return p, q, v
  elseif i == 4 then
    return t, p, v
  end
  return v, p, q
end

--- RGB 0-1 → HSV (h 0-360, s/v 0-1).
local function rgbToHsv(r, g, b)
  local mx = math.max(r, g, b)
  local mn = math.min(r, g, b)
  local d = mx - mn
  local s = (mx == 0) and 0 or (d / mx)
  local h = 0
  if d > 0 then
    if mx == r then
      h = ((g - b) / d) % 6
    elseif mx == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end
    h = h * 60
    if h < 0 then
      h = h + 360
    end
  end
  return h, s, mx
end

--- Devuelve el valor solo si es legible: tocar un secreto en un `if`, en tonumber
--- o en una concatenación lanza error mientras el addon está tainted.
local function plain(v)
  if issecretvalue and issecretvalue(v) then
    return nil
  end
  return v
end

local function spellIcon(spellId)
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(spellId)
  end
  return nil
end

local function spellName(spellId)
  if alerts() and alerts().GetSpellDisplayName then
    return alerts():GetSpellDisplayName(spellId)
  end
  return "#" .. tostring(spellId or 0)
end

--- Resuelve un spellId aunque no esté en el libro (talentos/auras override).
local function resolveSpellEntry(spellId)
  spellId = tonumber(spellId)
  if not spellId or spellId <= 0 then
    return nil
  end
  if C_Spell and C_Spell.RequestLoadSpellData then
    pcall(C_Spell.RequestLoadSpellData, spellId)
  end
  local name, icon
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellId)
    if type(info) == "table" then
      name = info.name
      icon = info.iconID
      spellId = tonumber(info.spellID) or spellId
    elseif type(info) == "string" then
      name = info
    end
  end
  if (not name or name == "") and GetSpellInfo then
    name = GetSpellInfo(spellId)
  end
  if not name or name == "" then
    name = spellName(spellId)
  end
  if not name or name == "" then
    name = "#" .. tostring(spellId)
  end
  return {
    spellId = spellId,
    name = name,
    nameLower = strlower(name),
    icon = icon or spellIcon(spellId),
  }
end

--- Busca en auras activas (player/target). Útil para talentos «Not In Spellbook».
local function collectAuraSpellMatches(qLower, out, seen, maxN)
  maxN = maxN or MAX_RESULTS
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
    return
  end
  local function scan(unit, filter)
    if #out >= maxN then
      return
    end
    if unit ~= "player" and not UnitExists(unit) then
      return
    end
    for i = 1, 40 do
      if #out >= maxN then
        return
      end
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
      if not ok then
        -- Aura secreta: la llamada falla en ese índice, no en los siguientes.
      elseif not aura then
        break
      else
        local sid = tonumber(plain(aura.spellId))
        local n = plain(aura.name)
        if sid and sid > 0 and n and not seen[sid] then
          local nl = strlower(n)
          if qLower == "" or strfind(nl, qLower, 1, true) then
            seen[sid] = true
            out[#out + 1] = {
              spellId = sid,
              name = n .. "  [" .. unit .. "/" .. filter .. "]",
              nameLower = nl,
              icon = plain(aura.icon) or spellIcon(sid),
            }
          end
        end
      end
    end
  end
  scan("player", "HELPFUL")
  scan("player", "HARMFUL")
  scan("target", "HELPFUL")
  scan("target", "HARMFUL")
end

--- Instantánea de las auras activas en player/target: nombre, id, icono y origen.
--- Devuelve además cuántas quedaron fuera por ser secretas (Blizzard las oculta).
local function captureAuraSnapshot()
  local out = {}
  local secretSkipped = 0
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
    return out, 0
  end
  local seen = {}
  local function scan(unit, filter)
    if unit ~= "player" and not UnitExists(unit) then
      return
    end
    for i = 1, 40 do
      if #out >= MAX_AURA_SNAPSHOT then
        return
      end
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
      if not ok then
        -- Aura secreta en ese índice: seguir, el resto de la lista sí se lee.
        secretSkipped = secretSkipped + 1
      elseif not aura then
        break
      else
        local sid = tonumber(plain(aura.spellId))
        local name = plain(aura.name)
        if sid and sid > 0 and name then
          local key = tostring(sid) .. unit .. filter
          if not seen[key] then
            seen[key] = true
            out[#out + 1] = {
              spellId = sid,
              name = name,
              icon = plain(aura.icon) or spellIcon(sid),
              unit = unit,
              harmful = filter == "HARMFUL",
            }
          end
        else
          -- Existe pero su id o nombre son secretos: no se puede ofrecer para elegir.
          secretSkipped = secretSkipped + 1
        end
      end
    end
  end
  scan("player", "HELPFUL")
  scan("player", "HARMFUL")
  scan("target", "HELPFUL")
  scan("target", "HARMFUL")
  return out, secretSkipped
end

local function nextInList(list, cur, eqFn)
  for i = 1, #list do
    local match = eqFn and eqFn(list[i], cur) or list[i] == cur
    if match then
      return list[(i % #list) + 1]
    end
  end
  return list[1]
end

-- ---------------------------------------------------------------------------
-- Índice / búsqueda de hechizos (reutilizado en el editor de reglas)
-- ---------------------------------------------------------------------------

function M:BuildSpellIndex()
  local idx = {}
  local seen = {}
  local function add(spellId, name, icon)
    spellId = tonumber(spellId)
    if not spellId or spellId <= 0 or seen[spellId] then
      return
    end
    name = name or spellName(spellId)
    if not name or name == "" then
      return
    end
    seen[spellId] = true
    idx[#idx + 1] = {
      spellId = spellId,
      name = name,
      nameLower = strlower(name),
      icon = icon or spellIcon(spellId),
    }
  end

  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo then
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
    for i = 1, n do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
      if line and line.itemIndexOffset and line.numSpellBookItems then
        local off = line.itemIndexOffset
        local count = line.numSpellBookItems
        for s = off + 1, off + count do
          local info = C_SpellBook.GetSpellBookItemInfo and C_SpellBook.GetSpellBookItemInfo(s, bank)
          if info and info.spellID then
            add(info.spellID, info.name, info.iconID)
          elseif C_SpellBook.GetSpellBookItemName then
            local name = C_SpellBook.GetSpellBookItemName(s, bank)
            local _, _, spellID = C_SpellBook.GetSpellBookItemType and C_SpellBook.GetSpellBookItemType(s, bank)
            if spellID then
              add(spellID, name)
            end
          end
        end
      end
    end
  end

  table.sort(idx, function(a, b)
    return a.nameLower < b.nameLower
  end)
  self._spellIndex = idx
  return idx
end

function M:GetSpellIndex()
  if self._spellIndex and #self._spellIndex > 0 then
    return self._spellIndex
  end
  return self:BuildSpellIndex()
end

function M:SearchSpells(query, includeAuras)
  query = strtrim(tostring(query or ""))
  local out = {}
  local seen = {}
  local function push(entry)
    if not entry or not entry.spellId or seen[entry.spellId] or #out >= MAX_RESULTS then
      return
    end
    seen[entry.spellId] = true
    out[#out + 1] = entry
  end

  if query == "" then
    if includeAuras then
      collectAuraSpellMatches("", out, seen, MAX_RESULTS)
    end
    return out
  end

  local idOnly = query:match("^#?(%d+)$") or query:match("(%d%d%d%d%d+)")
  if idOnly and query:match("^#?%d+$") then
    push(resolveSpellEntry(tonumber(idOnly)))
    return out
  end

  local q = strlower(query)
  local idx = self:GetSpellIndex()
  for i = 1, #idx do
    local e = idx[i]
    if strfind(e.nameLower, q, 1, true) then
      push(e)
    end
  end
  collectAuraSpellMatches(q, out, seen, MAX_RESULTS)

  if #out == 0 and C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(query)
    if type(info) == "table" and info.spellID then
      push({ spellId = info.spellID, name = info.name or query, icon = info.iconID })
    elseif type(info) == "number" then
      push(resolveSpellEntry(info))
    end
  end
  if idOnly then
    push(resolveSpellEntry(tonumber(idOnly)))
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Widgets básicos
-- ---------------------------------------------------------------------------

local function makeButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 100, h or 22)
  b:SetText(text or "")
  return b
end

local function makeCheck(parent, label)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb.text:SetText(label or "")
  return cb
end

local function tip(btn, text)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

-- ---------------------------------------------------------------------------
-- Snapshot profundo (para restaurar al cancelar la edición de un grupo existente)
-- ---------------------------------------------------------------------------

local function copyPointT(p)
  if type(p) ~= "table" then
    return nil
  end
  return { p[1], p[2], p[3] }
end

local function copyColorT(c)
  if type(c) ~= "table" then
    return nil
  end
  return { c[1], c[2], c[3] }
end

local function snapshotGroup(g)
  if type(g) ~= "table" then
    return nil
  end
  local s = {
    name = g.name,
    enabled = g.enabled ~= false,
    ruleLogic = g.ruleLogic == "or" and "or" or "and",
    rules = {},
    effects = {},
  }
  if type(g.overlayFx) == "table" then
    s.overlayFx = {
      pulse = g.overlayFx.pulse == true,
      color = g.overlayFx.color == true,
      shake = g.overlayFx.shake == true,
      glow = g.overlayFx.glow == true,
    }
  end
  for i = 1, #(g.rules or {}) do
    local r = g.rules[i]
    local nr = {}
    for k, v in pairs(r) do
      if type(v) ~= "table" then
        nr[k] = v
      end
    end
    nr.id = nil
    s.rules[#s.rules + 1] = nr
  end
  for i = 1, #(g.effects or {}) do
    local e = g.effects[i]
    local ne = {}
    for k, v in pairs(e) do
      if type(v) ~= "table" then
        ne[k] = v
      end
    end
    ne.id = nil
    ne.point = copyPointT(e.point)
    ne.color = copyColorT(e.color)
    s.effects[#s.effects + 1] = ne
  end
  return s
end

--- Restaura un grupo a partir de un snapshot (los IDs internos pueden cambiar).
local function restoreSnapshot(groupId, snap)
  local a = alerts()
  if not a or not snap then
    return
  end
  a:UpdateGroup(groupId, {
    name = snap.name,
    enabled = snap.enabled,
    ruleLogic = snap.ruleLogic,
    overlayFx = snap.overlayFx,
  })
  -- Reglas: borrar todas y recrear.
  local g = a:GetGroupById(groupId)
  if g then
    for i = #g.rules, 1, -1 do
      a:DeleteGroupRule(groupId, g.rules[i].id)
    end
  end
  for i = 1, #snap.rules do
    a:AddGroupRule(groupId, snap.rules[i])
  end
  -- Efectos: actualizar en el lugar para no violar min-visual / max-efectos.
  g = a:GetGroupById(groupId)
  while g and #g.effects < #snap.effects do
    if not a:AddEffect(groupId, { type = "icon" }) then
      break
    end
    g = a:GetGroupById(groupId)
  end
  g = a:GetGroupById(groupId)
  if g then
    for i = 1, math.min(#g.effects, #snap.effects) do
      a:UpdateEffect(groupId, g.effects[i].id, snap.effects[i])
    end
  end
  g = a:GetGroupById(groupId)
  if g then
    for i = #g.effects, #snap.effects + 1, -1 do
      a:DeleteEffect(groupId, g.effects[i].id)
    end
  end
end

-- ---------------------------------------------------------------------------
-- Sesión: accesores
-- ---------------------------------------------------------------------------

local function session()
  return M._session
end

local function curGroup()
  local s = M._session
  if not s or not alerts() then
    return nil
  end
  return alerts():GetGroupById(s.groupId)
end

local function curEffect()
  local s = M._session
  if not s or not s.effectId or not alerts() then
    return nil
  end
  return alerts():GetEffectById(s.groupId, s.effectId)
end

local function curRule()
  local s = M._session
  if not s or not s.ruleId or not alerts() then
    return nil
  end
  return alerts():GetGroupRuleById(s.groupId, s.ruleId)
end

function M:MarkDirty()
  if self._session then
    self._session.dirty = true
  end
end

function M:ApplyPreview()
  local s = self._session
  if not s or not alerts() or not alerts().SetLivePreview then
    return
  end
  alerts():SetLivePreview(s.groupId, s.forceEffect and s.effectId or nil)
  -- Refresco inmediato para que la previa reaccione sin esperar al ticker.
  if alerts().UpdateAllRules then
    alerts():UpdateAllRules()
  end
end

function M:EndPreview()
  if alerts() and alerts().ClearLivePreview then
    alerts():ClearLivePreview()
  end
  if alerts() and alerts().Refresh then
    alerts():Refresh()
  end
end

-- ---------------------------------------------------------------------------
-- Construcción del marco (una sola vez)
-- ---------------------------------------------------------------------------

function M:Ensure()
  if self._frame then
    return self._frame
  end

  local f = CreateFrame("Frame", "ChukieUi_AlertsManager", UIParent, "BackdropTemplate")
  f:SetSize(640, 660)
  -- Centrado en la mitad derecha: la mitad izquierda queda libre para ver las alertas.
  f:SetPoint("CENTER", UIParent, "CENTER", ((UIParent:GetWidth() or 1024) / 4), 0)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(200)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  tinsert(UISpecialFrames, "ChukieUi_AlertsManager")
  f:SetScript("OnHide", function()
    if M._suppressHide then
      return
    end
    M:CancelSession(true)
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText("Chukie UI — Alertas")
  f.title = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  self._frame = f
  self:BuildListView(f)
  self:BuildGroupView(f)
  return f
end

-- ---------------------------------------------------------------------------
-- Vista lista de grupos
-- ---------------------------------------------------------------------------

function M:BuildListView(f)
  local list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", 16, -44)
  list:SetPoint("BOTTOMRIGHT", -16, 16)
  f.list = list

  local hint = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hint:SetPoint("TOPLEFT", 0, 0)
  hint:SetPoint("TOPRIGHT", -170, 0)
  hint:SetJustifyH("LEFT")
  list.hint = hint

  local modBtn = makeButton(list, "Módulo: Off", 110, 24)
  modBtn:SetPoint("TOPRIGHT", -46, 2)
  modBtn:SetScript("OnClick", function()
    if not alerts() then
      return
    end
    alerts():SetEnabled(not alerts():IsEnabled())
    M:RefreshList()
  end)
  tip(modBtn, "Si está Off, las alertas solo se ven en el editor (preview).")
  list.modBtn = modBtn

  local addBtn = makeButton(list, "+", 38, 24)
  addBtn:SetPoint("TOPRIGHT", 0, 2)
  addBtn:SetScript("OnClick", function()
    M:StartNewGroup()
  end)
  tip(addBtn, "Nuevo grupo de alerta")
  list.addBtn = addBtn

  local scroll = CreateFrame("ScrollFrame", "ChukieUi_AlertsManagerScroll", list, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -30)
  scroll:SetPoint("BOTTOMRIGHT", -28, 0)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(560, 10)
  scroll:SetScrollChild(content)
  list.scroll = scroll
  list.content = content
  list.rows = {}
end

function M:RefreshList()
  local f = self:Ensure()
  local content = f.list.content
  local rows = f.list.rows
  for i = 1, #rows do
    rows[i]:Hide()
  end

  local modOn = alerts() and alerts():IsEnabled()
  f.list.modBtn:SetText(modOn and "Módulo: On" or "Módulo: Off")
  if modOn then
    f.list.hint:SetText("Grupos del perfil activo. Cada grupo tiene efectos y condiciones. Usá + para agregar.")
  else
    f.list.hint:SetText("|cffff6666Módulo Off:|r las alertas no se muestran en combate. Activá «Módulo: On».")
  end

  local groups = (alerts() and alerts():GetGroups()) or {}
  local y = 0
  for i = 1, #groups do
    local g = groups[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Button", nil, content, "BackdropTemplate")
      row:SetSize(548, ROW_H)
      row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
      })
      row:SetBackdropColor(0.1, 0.1, 0.12, 0.85)
      row:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.9)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(20, 20)
      row.icon:SetPoint("LEFT", 4, 0)
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.label:SetPoint("RIGHT", row, "RIGHT", -220, 0)
      row.label:SetJustifyH("LEFT")
      row.logic = makeButton(row, "AND", 46, 20)
      row.logic:SetPoint("RIGHT", -158, 0)
      row.toggle = makeButton(row, "On", 44, 20)
      row.toggle:SetPoint("RIGHT", -108, 0)
      row.edit = makeButton(row, "Editar", 56, 20)
      row.edit:SetPoint("RIGHT", -34, 0)
      row.del = makeButton(row, "X", 26, 20)
      row.del:SetPoint("RIGHT", -4, 0)
      rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:Show()

    local sid = 0
    for ri = 1, #(g.rules or {}) do
      sid = tonumber(g.rules[ri].spellId) or 0
      if sid > 0 then
        break
      end
    end
    row.icon:SetTexture(spellIcon(sid) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local nFx = #(g.effects or {})
    local nRules = #(g.rules or {})
    local gname = (g.name and g.name ~= "" and g.name) or ("Alerta #" .. tostring(g.id))
    row.label:SetText(string.format(
      "%s  · %d efecto%s · %d %s",
      gname,
      nFx,
      nFx == 1 and "" or "s",
      nRules,
      nRules == 1 and "condición" or "condiciones"
    ))
    row.logic:SetText(g.ruleLogic == "or" and "OR" or "AND")
    row.toggle:SetText(g.enabled ~= false and "On" or "Off")

    local id = g.id
    row.logic:SetScript("OnClick", function()
      local gg = alerts():GetGroupById(id)
      if gg then
        alerts():UpdateGroup(id, { ruleLogic = gg.ruleLogic == "or" and "and" or "or" })
        M:RefreshList()
      end
    end)
    row.toggle:SetScript("OnClick", function()
      local gg = alerts():GetGroupById(id)
      if gg then
        alerts():UpdateGroup(id, { enabled = not (gg.enabled ~= false) })
        M:RefreshList()
      end
    end)
    row.edit:SetScript("OnClick", function()
      M:StartEditGroup(id)
    end)
    row.del:SetScript("OnClick", function()
      alerts():DeleteGroup(id)
      M:RefreshList()
    end)
    y = y + ROW_H + 4
  end

  if #groups == 0 then
    if not f.list.empty then
      f.list.empty = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      f.list.empty:SetPoint("TOPLEFT", 4, -10)
      f.list.empty:SetJustifyH("LEFT")
      f.list.empty:SetText("Sin grupos todavía: usá «+» para crear el primero.")
    end
    f.list.empty:Show()
  elseif f.list.empty then
    f.list.empty:Hide()
  end
  content:SetHeight(math.max(10, y))
end

-- ---------------------------------------------------------------------------
-- Ventana de grupo: cabecera + listas (efectos / condiciones) + editor
-- ---------------------------------------------------------------------------

function M:BuildGroupView(f)
  local gp = CreateFrame("Frame", nil, f)
  gp:SetPoint("TOPLEFT", 16, -44)
  gp:SetPoint("BOTTOMRIGHT", -16, 16)
  gp:Hide()
  f.groupView = gp

  local nameLabel = gp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  nameLabel:SetPoint("TOPLEFT", 0, -4)
  nameLabel:SetText("Nombre:")
  local nameEdit = CreateFrame("EditBox", nil, gp, "InputBoxTemplate")
  nameEdit:SetSize(210, 22)
  nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
  nameEdit:SetAutoFocus(false)
  nameEdit:SetMaxLetters(48)
  nameEdit:SetScript("OnTextChanged", function(self)
    if self._syncing or not M._session or not alerts() then
      return
    end
    alerts():UpdateGroup(M._session.groupId, { name = self:GetText() or "" })
    M:MarkDirty()
  end)
  nameEdit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  nameEdit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  gp.nameEdit = nameEdit

  local enabled = makeCheck(gp, "Activo")
  enabled:SetPoint("LEFT", nameEdit, "RIGHT", 12, 0)
  enabled:SetScript("OnClick", function(self)
    if not M._session or not alerts() then
      return
    end
    alerts():UpdateGroup(M._session.groupId, { enabled = self:GetChecked() and true or false })
    M:MarkDirty()
    M:ApplyPreview()
  end)
  gp.enabledCheck = enabled

  local logic = makeButton(gp, "Logica: AND", 116, 22)
  logic:SetPoint("TOPRIGHT", 0, -4)
  logic:SetScript("OnClick", function()
    local g = curGroup()
    if g then
      alerts():UpdateGroup(M._session.groupId, { ruleLogic = g.ruleLogic == "or" and "and" or "or" })
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end
  end)
  tip(logic, "AND: se muestra si se cumplen todas las condiciones. OR: con una basta.")
  gp.logicBtn = logic

  local sep = gp:CreateTexture(nil, "ARTWORK")
  sep:SetPoint("TOPLEFT", 0, -32)
  sep:SetPoint("TOPRIGHT", 0, -32)
  sep:SetHeight(1)
  sep:SetColorTexture(0.4, 0.4, 0.45, 0.7)

  local left = CreateFrame("Frame", nil, gp)
  left:SetPoint("TOPLEFT", 0, -40)
  left:SetPoint("BOTTOMLEFT", 0, 34)
  left:SetWidth(214)
  gp.left = left

  local right = CreateFrame("Frame", nil, gp)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 14, 0)
  right:SetPoint("BOTTOMRIGHT", gp, "BOTTOMRIGHT", 0, 34)
  gp.right = right

  self:BuildEffectPanel(gp)
  self:BuildRulePanel(gp)
  self:BuildEffectEditor(gp)
  self:BuildRuleEditor(gp)

  local forceGroup = makeButton(gp, "Forzar grupo", 108, 22)
  forceGroup:SetPoint("BOTTOMLEFT", 0, 0)
  forceGroup:SetScript("OnClick", function()
    if M._session then
      M._session.forceEffect = false
      M:ApplyPreview()
    end
  end)
  tip(forceGroup, "Muestra el grupo completo ignorando las condiciones.")

  local forceEffect = makeButton(gp, "Forzar efecto", 108, 22)
  forceEffect:SetPoint("LEFT", forceGroup, "RIGHT", 6, 0)
  forceEffect:SetScript("OnClick", function()
    if M._session and M._session.effectId then
      M._session.forceEffect = true
      M:ApplyPreview()
    else
      print("|cffff9900Chukie UI|r: elegi un efecto en la lista.")
    end
  end)
  tip(forceEffect, "Muestra solo el efecto seleccionado.")

  local cancelBtn = makeButton(gp, "Cancelar", 100, 24)
  cancelBtn:SetPoint("BOTTOMRIGHT", -124, 0)
  cancelBtn:SetScript("OnClick", function()
    M:CancelSession(false)
  end)
  local saveBtn = makeButton(gp, "Guardar", 118, 24)
  saveBtn:SetPoint("BOTTOMRIGHT", 0, 0)
  saveBtn:SetScript("OnClick", function()
    M:SaveSession()
  end)
end

--- Selección única compartida por las dos listas: define qué se edita a la derecha.
function M:Select(kind, id)
  local s = self._session
  if not s then
    return
  end
  s.selKind = kind
  if kind == "effect" then
    s.effectId = id
  else
    s.ruleId = id
  end
  self:SyncGroupView()
  self:ApplyPreview()
end

function M:SyncHeader()
  local gp = self._frame.groupView
  local g = curGroup()
  gp.nameEdit._syncing = true
  gp.nameEdit:SetText((g and g.name) or "")
  gp.nameEdit:SetCursorPosition(0)
  gp.nameEdit._syncing = false
  gp.enabledCheck:SetChecked(g and g.enabled ~= false)
  gp.logicBtn:SetText("Logica: " .. ((g and g.ruleLogic == "or") and "OR" or "AND"))
end

-- ---------------------------------------------------------------------------
-- Efectos: lista (izquierda) + editor (derecha)
-- ---------------------------------------------------------------------------

function M:BuildEffectPanel(gp)
  local left = gp.left

  local title = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetText("Efectos (qué se ve)")

  local W, H, GAP = 68, 20, 5
  local function addBtn(label, col, row, enabledBtn)
    local b = makeButton(left, label, W, H)
    b:SetPoint("TOPLEFT", col * (W + GAP), -18 - row * (H + 4))
    if not enabledBtn then
      b:Disable()
      b:SetAlpha(0.45)
      tip(b, "Todavía no implementado.")
    end
    return b
  end

  local addIcon = addBtn("+ Icono", 0, 0, true)
  local addTex = addBtn("+ Textura", 1, 0, true)
  local addText = addBtn("+ Texto", 2, 0, true)
  local addSound = addBtn("+ Sonido", 0, 1, true)
  addBtn("+ Barra", 1, 1, false)
  addBtn("+ Reloj", 2, 1, false)
  addBtn("+ Contador", 0, 2, false)

  local function addEffect(typ)
    if not M._session or not alerts() then
      return
    end
    local g = curGroup()
    local n = g and #(g.effects or {}) or 0
    local e, err = alerts():AddEffect(M._session.groupId, {
      type = typ,
      enabled = true,
      point = { "CENTER", 0, 120 + n * 8 },
      size = 48,
    })
    if not e then
      if err then
        print("|cffff9900Chukie UI|r: " .. tostring(err))
      end
      return
    end
    M:MarkDirty()
    M:Select("effect", e.id)
  end
  addIcon:SetScript("OnClick", function()
    addEffect("icon")
  end)
  addTex:SetScript("OnClick", function()
    addEffect("texture")
  end)
  addText:SetScript("OnClick", function()
    addEffect("text")
  end)
  addSound:SetScript("OnClick", function()
    addEffect("sound")
  end)

  local listBox = CreateFrame("Frame", nil, left, "BackdropTemplate")
  listBox:SetPoint("TOPLEFT", 0, -92)
  listBox:SetSize(214, 160)
  listBox:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  listBox:SetBackdropColor(0, 0, 0, 0.35)
  listBox:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.9)
  gp.effectListBox = listBox
  gp.effectRows = {}
end

function M:BuildEffectEditor(gp)
  local right = gp.right

  local preview = CreateFrame("Frame", nil, right)
  preview:SetSize(56, 56)
  preview:SetPoint("TOPRIGHT", 0, 0)
  preview.tex = preview:CreateTexture(nil, "ARTWORK")
  preview.tex:SetAllPoints()
  preview.label = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  preview.label:SetPoint("CENTER")
  preview.label:Hide()
  gp.preview = preview

  local ed = CreateFrame("Frame", nil, right)
  ed:SetAllPoints()
  ed:Hide()
  gp.effectEditor = ed

  ed.title = ed:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ed.title:SetPoint("TOPLEFT", 0, 0)
  ed.title:SetPoint("TOPRIGHT", -64, 0)
  ed.title:SetJustifyH("LEFT")

  ed.enabledCheck = makeCheck(ed, "Efecto activo")
  ed.enabledCheck:SetPoint("TOPLEFT", 0, -22)
  ed.enabledCheck:SetScript("OnClick", function(self)
    local e = curEffect()
    if e then
      alerts():UpdateEffect(M._session.groupId, e.id, { enabled = self:GetChecked() and true or false })
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end
  end)

  ed.modeBtn = makeButton(ed, "Modo: Icono", 120, 22)
  ed.modeBtn:SetPoint("LEFT", ed.enabledCheck.text, "RIGHT", 12, 0)
  ed.modeBtn:SetScript("OnClick", function()
    local e = curEffect()
    if not e or e.type == "sound" then
      return
    end
    local nextType = nextInList(DISPLAY_MODES, e.type)
    alerts():UpdateEffect(M._session.groupId, e.id, { type = nextType })
    M:MarkDirty()
    M:SyncGroupView()
    M:ApplyPreview()
  end)

  ed.sizeLabel = ed:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ed.sizeLabel:SetPoint("TOPLEFT", 0, -54)
  ed.sizeLabel:SetWidth(90)
  ed.sizeLabel:SetJustifyH("LEFT")
  ed.sizeLabel:SetText("Tamano: 48")
  local sizeLo, sizeHi = sizeBounds()
  ed.sizeSlider = CreateFrame("Slider", "ChukieUi_AlertsSizeSlider", ed, "OptionsSliderTemplate")
  ed.sizeSlider:SetOrientation("HORIZONTAL")
  ed.sizeSlider:SetWidth(180)
  ed.sizeSlider:SetHeight(16)
  ed.sizeSlider:SetPoint("LEFT", ed.sizeLabel, "RIGHT", 6, 0)
  ed.sizeSlider:SetMinMaxValues(sizeLo, sizeHi)
  ed.sizeSlider:SetValueStep(1)
  ed.sizeSlider:SetObeyStepOnDrag(true)
  do
    local nm = ed.sizeSlider:GetName()
    local lo = ed.sizeSlider.Low or _G[nm .. "Low"]
    local hi = ed.sizeSlider.High or _G[nm .. "High"]
    local tx = ed.sizeSlider.Text or _G[nm .. "Text"]
    if lo then
      lo:SetText(tostring(sizeLo))
    end
    if hi then
      hi:SetText(tostring(sizeHi))
    end
    if tx then
      tx:SetText("")
    end
  end
  ed.sizeSlider:SetScript("OnValueChanged", function(self, value)
    if self._syncing then
      return
    end
    local e = curEffect()
    if not e then
      return
    end
    local sz = math.floor((tonumber(value) or 48) + 0.5)
    ed.sizeLabel:SetText("Tamano: " .. tostring(sz))
    alerts():UpdateEffect(M._session.groupId, e.id, { size = sz })
    M:MarkDirty()
    M:UpdateEffectPreview()
    M:ApplyPreview()
  end)

  -- Posición
  ed.posBtn = makeButton(ed, "Pos: 0,120", 110, 22)
  ed.posBtn:SetPoint("TOPLEFT", 0, -84)
  ed.posBtn:SetScript("OnClick", function()
    local e = curEffect()
    if not e then
      return
    end
    local presets = {
      { "CENTER", 0, 120 },
      { "CENTER", 0, 0 },
      { "CENTER", -120, 80 },
      { "CENTER", 120, 80 },
      { "CENTER", 0, -100 },
    }
    local p2 = e.point or { "CENTER", 0, 120 }
    local nextP = presets[1]
    for i = 1, #presets do
      if presets[i][2] == (tonumber(p2[2]) or 0) and presets[i][3] == (tonumber(p2[3]) or 0) then
        nextP = presets[(i % #presets) + 1]
        break
      end
    end
    alerts():UpdateEffect(M._session.groupId, e.id, { point = { nextP[1], nextP[2], nextP[3] } })
    M:MarkDirty()
    M:SyncGroupView()
    M:ApplyPreview()
  end)
  local function nudge(dx, dy)
    local e = curEffect()
    if not e then
      return
    end
    local p2 = e.point or { "CENTER", 0, 120 }
    alerts():UpdateEffect(M._session.groupId, e.id, {
      point = { p2[1] or "CENTER", (tonumber(p2[2]) or 0) + dx, (tonumber(p2[3]) or 0) + dy },
    })
    M:MarkDirty()
    M:SyncGroupView()
    M:ApplyPreview()
  end
  ed.nudgeL = makeButton(ed, "<", 26, 22)
  ed.nudgeL:SetPoint("LEFT", ed.posBtn, "RIGHT", 6, 0)
  ed.nudgeL:SetScript("OnClick", function()
    nudge(-10, 0)
  end)
  ed.nudgeR = makeButton(ed, ">", 26, 22)
  ed.nudgeR:SetPoint("LEFT", ed.nudgeL, "RIGHT", 2, 0)
  ed.nudgeR:SetScript("OnClick", function()
    nudge(10, 0)
  end)
  ed.nudgeU = makeButton(ed, "^", 26, 22)
  ed.nudgeU:SetPoint("LEFT", ed.nudgeR, "RIGHT", 2, 0)
  ed.nudgeU:SetScript("OnClick", function()
    nudge(0, 10)
  end)
  ed.nudgeD = makeButton(ed, "v", 26, 22)
  ed.nudgeD:SetPoint("LEFT", ed.nudgeU, "RIGHT", 2, 0)
  ed.nudgeD:SetScript("OnClick", function()
    nudge(0, -10)
  end)

  -- Color + Alpha (barras verticales)
  self:BuildColorBars(ed)

  -- Sub-paneles por tipo
  self:BuildEffectIconPane(ed)
  self:BuildEffectTexturePane(ed)
  self:BuildEffectTextPane(ed)
  self:BuildEffectSoundPane(ed)
end

function M:BuildColorBars(ed)
  local pane = CreateFrame("Frame", nil, ed)
  pane:SetPoint("TOPLEFT", 0, -114)
  pane:SetSize(220, 120)
  ed.colorPane = pane
  local BAR_H = 96
  local BAR_W = 18

  local function makeBarBackdrop(bar)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetColorTexture(0, 0, 0, 0.9)
    return bg
  end
  local function makeBarThumb(bar)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 1)
    thumb:SetSize(BAR_W + 8, 3)
    thumb:SetPoint("CENTER", bar, "TOP", 0, 0)
    return thumb
  end
  local function barFraction(bar)
    local scale = bar:GetEffectiveScale()
    if not scale or scale == 0 then
      return 0
    end
    local _, cy = GetCursorPosition()
    cy = cy / scale
    local top, bottom = bar:GetTop(), bar:GetBottom()
    if not top or not bottom or top <= bottom then
      return 0
    end
    local fr = (cy - bottom) / (top - bottom)
    if fr < 0 then
      fr = 0
    elseif fr > 1 then
      fr = 1
    end
    return fr
  end
  local function attachBarDrag(bar, onFraction)
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function(self)
      self._dragging = true
      onFraction(barFraction(self))
    end)
    bar:SetScript("OnMouseUp", function(self)
      self._dragging = false
    end)
    bar:SetScript("OnUpdate", function(self)
      if self._dragging then
        onFraction(barFraction(self))
      end
    end)
  end
  local function setThumbFraction(thumb, bar, fr)
    fr = tonumber(fr) or 0
    if fr < 0 then
      fr = 0
    elseif fr > 1 then
      fr = 1
    end
    thumb:SetPoint("CENTER", bar, "BOTTOM", 0, fr * BAR_H)
  end

  local hueLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hueLabel:SetPoint("TOPLEFT", 4, 0)
  hueLabel:SetText("Color")
  local hueBar = CreateFrame("Frame", nil, pane)
  hueBar:SetSize(BAR_W, BAR_H)
  hueBar:SetPoint("TOPLEFT", hueLabel, "BOTTOMLEFT", 2, -4)
  makeBarBackdrop(hueBar)
  do
    local stops = {
      { 1, 0, 0 },
      { 1, 1, 0 },
      { 0, 1, 0 },
      { 0, 1, 1 },
      { 0, 0, 1 },
      { 1, 0, 1 },
      { 1, 0, 0 },
    }
    local seg = BAR_H / 6
    for i = 1, 6 do
      local t = hueBar:CreateTexture(nil, "ARTWORK")
      t:SetPoint("TOPLEFT", 0, -(i - 1) * seg)
      t:SetPoint("TOPRIGHT", 0, -(i - 1) * seg)
      t:SetHeight(seg)
      local top = stops[i]
      local bot = stops[i + 1]
      t:SetColorTexture(1, 1, 1, 1)
      t:SetGradient("VERTICAL", CreateColor(bot[1], bot[2], bot[3], 1), CreateColor(top[1], top[2], top[3], 1))
    end
  end
  local hueThumb = makeBarThumb(hueBar)
  attachBarDrag(hueBar, function(fr)
    local e = curEffect()
    if not e then
      return
    end
    local hue = (1 - fr) * 360
    local r, g, b = hsvToRgb(hue, 1, 1)
    alerts():UpdateEffect(M._session.groupId, e.id, { color = { r, g, b } })
    M:MarkDirty()
    M:SyncColorControls()
    M:UpdateEffectPreview()
    M:ApplyPreview()
  end)

  local alphaLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  alphaLabel:SetPoint("TOPLEFT", hueBar, "TOPRIGHT", 24, 4)
  alphaLabel:SetText("Alpha")
  local alphaBar = CreateFrame("Frame", nil, pane)
  alphaBar:SetSize(BAR_W, BAR_H)
  alphaBar:SetPoint("TOPLEFT", alphaLabel, "BOTTOMLEFT", 2, -4)
  local alphaChecker = alphaBar:CreateTexture(nil, "BACKGROUND")
  alphaChecker:SetPoint("TOPLEFT", -1, 1)
  alphaChecker:SetPoint("BOTTOMRIGHT", 1, -1)
  alphaChecker:SetColorTexture(0.5, 0.5, 0.5, 1)
  local alphaFill = alphaBar:CreateTexture(nil, "ARTWORK")
  alphaFill:SetAllPoints()
  alphaFill:SetColorTexture(1, 1, 1, 1)
  alphaFill:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
  local alphaThumb = makeBarThumb(alphaBar)
  attachBarDrag(alphaBar, function(fr)
    local e = curEffect()
    if not e then
      return
    end
    alerts():UpdateEffect(M._session.groupId, e.id, { alpha = fr })
    M:MarkDirty()
    M:SyncColorControls()
    M:UpdateEffectPreview()
    M:ApplyPreview()
  end)

  local swatch = pane:CreateTexture(nil, "OVERLAY")
  swatch:SetSize(28, 28)
  swatch:SetPoint("TOPLEFT", alphaBar, "TOPRIGHT", 16, -BAR_H + 28)
  swatch:SetColorTexture(1, 1, 1, 1)

  ed.hueBar = hueBar
  ed.hueThumb = hueThumb
  ed.alphaBar = alphaBar
  ed.alphaThumb = alphaThumb
  ed.alphaFill = alphaFill
  ed.colorSwatch = swatch
  ed._setThumbFraction = setThumbFraction
end

function M:SyncColorControls()
  local ed = self._frame.groupView.effectEditor
  local e = curEffect()
  if not ed.colorSwatch then
    return
  end
  local c = (e and e.color) or { 1, 1, 1 }
  local r, g, b = c[1] or 1, c[2] or 1, c[3] or 1
  local a = tonumber(e and e.alpha) or 1
  if a < 0 then
    a = 0
  elseif a > 1 then
    a = 1
  end
  if ed._setThumbFraction then
    local h, s = rgbToHsv(r, g, b)
    local hueFrac = (s <= 0) and 1 or (1 - (h / 360))
    ed._setThumbFraction(ed.hueThumb, ed.hueBar, hueFrac)
    ed._setThumbFraction(ed.alphaThumb, ed.alphaBar, a)
  end
  if ed.alphaFill then
    ed.alphaFill:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
  end
  ed.colorSwatch:SetColorTexture(r, g, b, a)
end

function M:BuildEffectIconPane(ed)
  local pane = CreateFrame("Frame", nil, ed)
  pane:SetPoint("TOPLEFT", ed.colorPane, "BOTTOMLEFT", 0, -8)
  pane:SetPoint("RIGHT", ed, "RIGHT", 0, 0)
  pane:SetHeight(90)
  ed.iconPane = pane

  local lbl = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", 0, 0)
  lbl:SetText("Icono (spellId opcional):")
  local edit = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
  edit:SetSize(90, 22)
  edit:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
  edit:SetAutoFocus(false)
  edit:SetNumeric(true)
  edit:SetMaxLetters(9)
  edit:SetScript("OnTextChanged", function(self)
    if self._syncing then
      return
    end
    local e = curEffect()
    if not e then
      return
    end
    alerts():UpdateEffect(M._session.groupId, e.id, { spellId = tonumber(self:GetText()) or 0 })
    M:MarkDirty()
    M:UpdateEffectPreview()
    M:ApplyPreview()
  end)
  edit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  edit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  pane.spellEdit = edit
  pane.spellName = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pane.spellName:SetPoint("LEFT", edit, "RIGHT", 8, 0)
  pane.spellName:SetJustifyH("LEFT")
  pane.spellName:SetTextColor(0.75, 0.75, 0.8)

  local glow = makeButton(pane, "Glow: Proc", 130, 22)
  glow:SetPoint("TOPLEFT", 0, -30)
  glow:SetScript("OnClick", function()
    local e = curEffect()
    if not e then
      return
    end
    local order = { "Proc", "Pixel", "buttonOverlay", "none" }
    alerts():UpdateEffect(M._session.groupId, e.id, { glowType = nextInList(order, e.glowType or "Proc") })
    M:MarkDirty()
    M:SyncGroupView()
    M:ApplyPreview()
  end)
  pane.glowBtn = glow

  local swipe = makeCheck(pane, "Swipe de cooldown")
  swipe:SetPoint("LEFT", glow, "RIGHT", 10, 0)
  swipe:SetScript("OnClick", function(self)
    local e = curEffect()
    if e then
      alerts():UpdateEffect(M._session.groupId, e.id, { swipe = self:GetChecked() and true or false })
      M:MarkDirty()
      M:ApplyPreview()
    end
  end)
  pane.swipeCheck = swipe

  local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hint:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", 0, -6)
  hint:SetJustifyH("LEFT")
  hint:SetTextColor(0.7, 0.7, 0.75)
  hint:SetText("Sin spellId propio, el icono usa el hechizo de la primera condición del grupo.")
end

function M:BuildEffectTexturePane(ed)
  local pane = CreateFrame("Frame", nil, ed)
  pane:SetPoint("TOPLEFT", ed.colorPane, "BOTTOMLEFT", 0, -8)
  pane:SetPoint("RIGHT", ed, "RIGHT", 0, 0)
  pane:SetHeight(90)
  pane:Hide()
  ed.texPane = pane

  local pick = makeButton(pane, "Elegir arte…", 120, 22)
  pick:SetPoint("TOPLEFT", 0, 0)
  pick:SetScript("OnClick", function()
    M:ShowAuraPicker()
  end)
  local layout = makeButton(pane, "Layout: Single", 130, 22)
  layout:SetPoint("LEFT", pick, "RIGHT", 8, 0)
  layout:SetScript("OnClick", function()
    local e = curEffect()
    if not e then
      return
    end
    local nl = (e.auraLayout == "pair") and "single" or "pair"
    alerts():UpdateEffect(M._session.groupId, e.id, { auraLayout = nl })
    M:MarkDirty()
    M:SyncGroupView()
    M:ApplyPreview()
  end)
  local gap = makeButton(pane, "Gap: 80", 90, 22)
  gap:SetPoint("LEFT", layout, "RIGHT", 8, 0)
  gap:SetScript("OnClick", function()
    local e = curEffect()
    if not e then
      return
    end
    local gaps = { 40, 60, 80, 100, 140, 200 }
    alerts():UpdateEffect(M._session.groupId, e.id, { pairGap = nextInList(gaps, tonumber(e.pairGap) or 80) })
    M:MarkDirty()
    M:SyncGroupView()
    M:ApplyPreview()
  end)
  pane.layoutBtn = layout
  pane.gapBtn = gap
  pane.artName = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pane.artName:SetPoint("TOPLEFT", pick, "BOTTOMLEFT", 0, -8)
  pane.artName:SetJustifyH("LEFT")
  pane.artName:SetWidth(360)
end

function M:BuildEffectTextPane(ed)
  local pane = CreateFrame("Frame", nil, ed)
  pane:SetPoint("TOPLEFT", ed.colorPane, "BOTTOMLEFT", 0, -8)
  pane:SetPoint("RIGHT", ed, "RIGHT", 0, 0)
  pane:SetHeight(90)
  pane:Hide()
  ed.textPane = pane

  local lbl = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", 0, 0)
  lbl:SetText("Texto (vacío = nombre del hechizo):")
  local edit = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
  edit:SetSize(280, 24)
  edit:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 8, -6)
  edit:SetAutoFocus(false)
  edit:SetScript("OnTextChanged", function(self)
    if self._syncing then
      return
    end
    local e = curEffect()
    if e then
      alerts():UpdateEffect(M._session.groupId, e.id, { text = self:GetText() or "" })
      M:MarkDirty()
      M:UpdateEffectPreview()
      M:ApplyPreview()
    end
  end)
  edit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  edit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  pane.textEdit = edit

  local font = makeButton(pane, "Fuente: default", 150, 22)
  font:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -8, -8)
  font:SetScript("OnClick", function()
    local e = curEffect()
    if not e then
      return
    end
    local fonts = { "" }
    local listSrc = (media() and media().GetFontPaths and media().GetFontPaths()) or {}
    for i = 1, #listSrc do
      fonts[#fonts + 1] = listSrc[i]
    end
    alerts():UpdateEffect(M._session.groupId, e.id, { fontPath = nextInList(fonts, e.fontPath or "") })
    M:MarkDirty()
    M:SyncGroupView()
    M:ApplyPreview()
  end)
  pane.fontBtn = font
end

function M:BuildEffectSoundPane(ed)
  local pane = CreateFrame("Frame", nil, ed)
  pane:SetPoint("TOPLEFT", ed.colorPane, "BOTTOMLEFT", 0, -8)
  pane:SetPoint("RIGHT", ed, "RIGHT", 0, 0)
  pane:SetHeight(90)
  pane:Hide()
  ed.soundPane = pane

  local pick = makeButton(pane, "Sonido: (default)", 220, 22)
  pick:SetPoint("TOPLEFT", 0, 0)
  pick:SetScript("OnClick", function()
    local e = curEffect()
    if not e then
      return
    end
    local listSrc = (media() and media().GetSoundPaths and media().GetSoundPaths()) or {}
    local paths = { "" }
    for i = 1, #listSrc do
      paths[#paths + 1] = listSrc[i]
    end
    alerts():UpdateEffect(M._session.groupId, e.id, { soundPath = nextInList(paths, e.soundPath or "") })
    M:MarkDirty()
    M:SyncGroupView()
  end)
  pane.pickBtn = pick
  local test = makeButton(pane, "Probar", 70, 22)
  test:SetPoint("LEFT", pick, "RIGHT", 6, 0)
  test:SetScript("OnClick", function()
    local e = curEffect()
    if alerts() and alerts().PlaySoundPreview then
      alerts():PlaySoundPreview(e and e.soundPath)
    end
  end)

  local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hint:SetPoint("TOPLEFT", pick, "BOTTOMLEFT", 0, -8)
  hint:SetJustifyH("LEFT")
  hint:SetTextColor(0.7, 0.7, 0.75)
  hint:SetText("El sonido se reproduce cuando el grupo pasa a mostrarse.")
end

function M:UpdateEffectPreview()
  local p = self._frame.groupView
  local e = curEffect()
  local prev = p.preview
  prev.tex:Show()
  prev.label:Hide()
  if not e then
    prev.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    prev.tex:SetVertexColor(1, 1, 1)
    prev.tex:SetAlpha(1)
    return
  end
  local c = e.color or { 1, 1, 1 }
  local a = tonumber(e.alpha) or 1
  if e.type == "sound" then
    prev.tex:SetTexture("Interface\\Common\\VoiceChat-Speaker")
    prev.tex:SetVertexColor(1, 1, 1)
    prev.tex:SetAlpha(1)
  elseif e.type == "texture" then
    local path = e.auraPath
    if (not path or path == "") and media() and media().DefaultAuraPath then
      path = media().DefaultAuraPath()
    end
    prev.tex:SetTexture(path or "Interface\\Icons\\INV_Misc_QuestionMark")
    prev.tex:SetVertexColor(c[1], c[2], c[3])
    prev.tex:SetAlpha(a)
  elseif e.type == "text" then
    prev.tex:Hide()
    prev.label:Show()
    local msg = e.text
    if not msg or strtrim(msg) == "" then
      local g = curGroup()
      local sid = 0
      for i = 1, #(g and g.rules or {}) do
        sid = tonumber(g.rules[i].spellId) or 0
        if sid > 0 then
          break
        end
      end
      msg = spellName(sid)
    end
    prev.label:SetText(msg)
    prev.label:SetTextColor(c[1], c[2], c[3], a)
  else
    local sid = tonumber(e.spellId) or 0
    if sid <= 0 then
      local g = curGroup()
      for i = 1, #(g and g.rules or {}) do
        sid = tonumber(g.rules[i].spellId) or 0
        if sid > 0 then
          break
        end
      end
    end
    prev.tex:SetTexture(spellIcon(sid) or "Interface\\Icons\\INV_Misc_QuestionMark")
    prev.tex:SetVertexColor(c[1], c[2], c[3])
    prev.tex:SetAlpha(a)
  end
end

function M:RefreshEffectList()
  local p = self._frame.groupView
  local rows = p.effectRows
  for i = 1, #rows do
    rows[i]:Hide()
    rows[i].effectId = nil
  end
  local g = curGroup()
  if not g then
    return
  end
  for i = 1, #g.effects do
    local e = g.effects[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Button", nil, p.effectListBox, "BackdropTemplate")
      row:SetSize(200, 22)
      row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(16, 16)
      row.icon:SetPoint("LEFT", 3, 0)
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
      row.label:SetPoint("RIGHT", -22, 0)
      row.label:SetJustifyH("LEFT")
      row.del = makeButton(row, "X", 18, 18)
      row.del:SetPoint("RIGHT", -2, 0)
      rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 24)
    row:Show()
    row.effectId = e.id
    row.icon:SetTexture(EFFECT_ROW_ICONS[e.type] or "Interface\\Icons\\INV_Misc_QuestionMark")
    local lab = EFFECT_LABELS[e.type] or e.type
    local on = (e.enabled ~= false) and "" or " (off)"
    row.label:SetText(lab .. on)
    local eid = e.id
    row:SetScript("OnClick", function()
      M:Select("effect", eid)
    end)
    row.del:SetScript("OnClick", function()
      local ok, err = alerts():DeleteEffect(M._session.groupId, eid)
      if not ok then
        if err then
          print("|cffff9900Chukie UI|r: " .. tostring(err))
        end
        return
      end
      if M._session.effectId == eid then
        M._session.effectId = nil
      end
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end)
  end
end

function M:SyncEffectEditor()
  local p = self._frame.groupView
  local ed = p.effectEditor
  local e = curEffect()
  if not e then
    ed:Hide()
    self:UpdateEffectPreview()
    return
  end
  ed:Show()

  ed.title:SetText(string.format("Efecto: %s", EFFECT_LABELS[e.type] or e.type))
  ed.enabledCheck:SetChecked(e.enabled ~= false)

  local isSound = e.type == "sound"
  local isVisual = not isSound
  ed.modeBtn:SetShown(isVisual)
  if isVisual then
    ed.modeBtn:SetText("Modo: " .. (DISPLAY_LABELS[e.type] or "Icono"))
  end

  -- Tamaño / posición / color solo para visuales
  ed.sizeLabel:SetShown(isVisual)
  ed.sizeSlider:SetShown(isVisual)
  ed.posBtn:SetShown(isVisual)
  ed.nudgeL:SetShown(isVisual)
  ed.nudgeR:SetShown(isVisual)
  ed.nudgeU:SetShown(isVisual)
  ed.nudgeD:SetShown(isVisual)
  ed.colorPane:SetShown(isVisual)

  if isVisual then
    local sz = tonumber(e.size) or 48
    local lo, hi = sizeBounds()
    if sz < lo then
      sz = lo
    elseif sz > hi then
      sz = hi
    end
    ed.sizeSlider._syncing = true
    ed.sizeSlider:SetValue(sz)
    ed.sizeSlider._syncing = false
    ed.sizeLabel:SetText("Tamano: " .. tostring(math.floor(sz + 0.5)))
    local pt = e.point or { "CENTER", 0, 120 }
    ed.posBtn:SetText(string.format("Pos: %d,%d", tonumber(pt[2]) or 0, tonumber(pt[3]) or 0))
    self:SyncColorControls()
  end

  ed.iconPane:SetShown(e.type == "icon")
  ed.texPane:SetShown(e.type == "texture")
  ed.textPane:SetShown(e.type == "text")
  ed.soundPane:SetShown(isSound)

  if e.type == "icon" then
    local box = ed.iconPane.spellEdit
    if not box:HasFocus() then
      box._syncing = true
      box:SetText((tonumber(e.spellId) or 0) > 0 and tostring(e.spellId) or "")
      box._syncing = false
    end
    local sid = tonumber(e.spellId) or 0
    ed.iconPane.spellName:SetText(sid > 0 and spellName(sid) or "")
    local glowLabels = { Proc = "Proc", Pixel = "Pixel", buttonOverlay = "Overlay", none = "Ninguno" }
    ed.iconPane.glowBtn:SetText("Glow: " .. (glowLabels[e.glowType or "Proc"] or "Proc"))
    ed.iconPane.swipeCheck:SetChecked(e.swipe ~= false)
  elseif e.type == "texture" then
    ed.texPane.layoutBtn:SetText("Layout: " .. ((e.auraLayout == "pair") and "Par" or "Single"))
    ed.texPane.gapBtn:SetShown(e.auraLayout == "pair")
    ed.texPane.gapBtn:SetText("Gap: " .. tostring(e.pairGap or 80))
    local ap = e.auraPath or ""
    ed.texPane.artName:SetText("Arte: " .. (ap ~= "" and (ap:match("([^\\]+)$") or ap) or "(preset default)"))
  elseif e.type == "text" then
    local box = ed.textPane.textEdit
    if not box:HasFocus() then
      box._syncing = true
      box:SetText(e.text or "")
      box._syncing = false
    end
    local fp = e.fontPath or ""
    ed.textPane.fontBtn:SetText("Fuente: " .. (fp ~= "" and (fp:match("([^\\]+)$") or "custom") or "default"))
  elseif isSound then
    local sp = e.soundPath or ""
    local label = (sp ~= "" and (sp:match("([^\\]+)$") or sp)) or "(default)"
    ed.soundPane.pickBtn:SetText("Sonido: " .. label)
  end

  self:UpdateEffectPreview()
end

function M:ShowAuraPicker()
  local f = self:Ensure()
  if not f.picker then
    local pk = CreateFrame("Frame", nil, f, "BackdropTemplate")
    pk:SetPoint("TOPLEFT", 40, -60)
    pk:SetPoint("BOTTOMRIGHT", -40, 60)
    pk:SetFrameStrata("FULLSCREEN_DIALOG")
    pk:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    pk:Hide()
    local t = pk:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOP", 0, -10)
    t:SetText("Elegir arte (local + User + SharedMedia)")
    local cl = makeButton(pk, "Cerrar", 80, 22)
    cl:SetPoint("TOPRIGHT", -8, -8)
    cl:SetScript("OnClick", function()
      pk:Hide()
    end)
    local sc = CreateFrame("ScrollFrame", "ChukieUi_AlertsAuraPickScroll", pk, "UIPanelScrollFrameTemplate")
    sc:SetPoint("TOPLEFT", 12, -36)
    sc:SetPoint("BOTTOMRIGHT", -30, 12)
    local ct = CreateFrame("Frame", nil, sc)
    ct:SetSize(480, 10)
    sc:SetScrollChild(ct)
    pk.content = ct
    pk.cells = {}
    f.picker = pk
  end
  local pk = f.picker
  pk:Show()
  pk:Raise()
  local catalog = (media() and media().GetAuraCatalog and media().GetAuraCatalog()) or {}
  local cells = pk.cells
  for i = 1, #cells do
    cells[i]:Hide()
  end
  local cols, cell, pad = 9, 44, 4
  for i = 1, #catalog do
    local e = catalog[i]
    local btn = cells[i]
    if not btn then
      btn = CreateFrame("Button", nil, pk.content)
      btn:SetSize(cell, cell)
      btn.tex = btn:CreateTexture(nil, "ARTWORK")
      btn.tex:SetAllPoints()
      btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      cells[i] = btn
    end
    local col = (i - 1) % cols
    local rw = math.floor((i - 1) / cols)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", col * (cell + pad), -rw * (cell + pad))
    btn:Show()
    btn.tex:SetTexture(e.path)
    local path = e.path
    btn:SetScript("OnClick", function()
      local eff = curEffect()
      if eff then
        alerts():UpdateEffect(M._session.groupId, eff.id, { auraPath = path })
        M:MarkDirty()
        M:SyncGroupView()
        M:ApplyPreview()
      end
      pk:Hide()
    end)
    btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(e.label or "", 1, 1, 1)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end
  local rows = math.ceil(#catalog / cols)
  pk.content:SetHeight(math.max(10, rows * (cell + pad)))
end

-- ---------------------------------------------------------------------------
-- Condiciones: lista (izquierda) + editor (derecha)
-- ---------------------------------------------------------------------------

function M:BuildRulePanel(gp)
  local left = gp.left

  local title = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, -264)
  title:SetText("Condiciones (cuándo se ve)")

  local W, H, GAP = 68, 20, 5
  local function addBtn(label, col, row)
    local b = makeButton(left, label, W, H)
    b:SetPoint("TOPLEFT", col * (W + GAP), -282 - row * (H + 4))
    return b
  end
  local addCd = addBtn("+ CD", 0, 0)
  local addAura = addBtn("+ Aura", 1, 0)
  local addProc = addBtn("+ Proc", 2, 0)
  local addCombat = addBtn("+ Combate", 0, 1)
  local addTarget = addBtn("+ Target", 1, 1)
  local addCharges = addBtn("+ Cargas", 2, 1)

  local function addRule(typ)
    if not M._session or not alerts() then
      return
    end
    local partial = { type = typ, enabled = true }
    if typ == "combat" or typ == "target" then
      partial.on = true
    elseif typ == "charges" then
      partial.op = "gte"
      partial.value = 1
    elseif typ == "aura" then
      partial.auraUnit = "player"
      partial.auraFilter = "both"
      partial.auraShow = "present"
    elseif typ == "cooldown" then
      partial.showOn = "available"
    end
    local r, err = alerts():AddGroupRule(M._session.groupId, partial)
    if not r then
      if err then
        print("|cffff9900Chukie UI|r: " .. tostring(err))
      end
      return
    end
    M:MarkDirty()
    M:Select("rule", r.id)
  end
  addCd:SetScript("OnClick", function()
    addRule("cooldown")
  end)
  addAura:SetScript("OnClick", function()
    addRule("aura")
  end)
  addProc:SetScript("OnClick", function()
    addRule("proc")
  end)
  addCombat:SetScript("OnClick", function()
    addRule("combat")
  end)
  addTarget:SetScript("OnClick", function()
    addRule("target")
  end)
  addCharges:SetScript("OnClick", function()
    addRule("charges")
  end)

  local scroll = CreateFrame("ScrollFrame", "ChukieUi_AlertsRulesScroll", left, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -332)
  scroll:SetPoint("BOTTOMLEFT", 0, 0)
  scroll:SetWidth(196)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(176, 10)
  scroll:SetScrollChild(content)
  gp.ruleScroll = scroll
  gp.ruleContent = content
  gp.ruleRows = {}
end

function M:BuildRuleEditor(gp)
  local ed = CreateFrame("Frame", nil, gp.right)
  ed:SetAllPoints()
  ed:Hide()
  gp.ruleEditor = ed

  ed.title = ed:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ed.title:SetPoint("TOPLEFT", 0, 0)
  ed.title:SetJustifyH("LEFT")

  ed.enabledCheck = makeCheck(ed, "Condición activa")
  ed.enabledCheck:SetPoint("TOPLEFT", 0, -22)
  ed.enabledCheck:SetScript("OnClick", function(self)
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { enabled = self:GetChecked() and true or false })
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end
  end)

  -- Hechizo: numérico + búsqueda por nombre
  ed.spellLabel = ed:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ed.spellLabel:SetPoint("TOPLEFT", 0, -52)
  ed.spellLabel:SetText("spellId:")
  ed.spellEdit = CreateFrame("EditBox", nil, ed, "InputBoxTemplate")
  ed.spellEdit:SetSize(90, 22)
  ed.spellEdit:SetPoint("LEFT", ed.spellLabel, "RIGHT", 8, 0)
  ed.spellEdit:SetAutoFocus(false)
  ed.spellEdit:SetNumeric(true)
  ed.spellEdit:SetMaxLetters(9)
  ed.spellEdit:SetScript("OnTextChanged", function(self)
    if self._syncing then
      return
    end
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { spellId = tonumber(self:GetText()) or 0 })
      M:MarkDirty()
      M:UpdateRuleSpellName()
      M:ApplyPreview()
    end
  end)
  ed.spellEdit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  ed.spellEdit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  ed.spellName = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ed.spellName:SetPoint("LEFT", ed.spellEdit, "RIGHT", 8, 0)
  ed.spellName:SetJustifyH("LEFT")
  ed.spellName:SetTextColor(0.8, 0.8, 0.85)

  ed.searchLabel = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ed.searchLabel:SetPoint("TOPLEFT", ed.spellLabel, "BOTTOMLEFT", 0, -12)
  ed.searchLabel:SetText("Buscar hechizo:")
  ed.searchEdit = CreateFrame("EditBox", nil, ed, "InputBoxTemplate")
  ed.searchEdit:SetSize(160, 22)
  ed.searchEdit:SetPoint("LEFT", ed.searchLabel, "RIGHT", 8, 0)
  ed.searchEdit:SetAutoFocus(false)
  ed.searchEdit:SetScript("OnEnterPressed", function(self)
    M:RunRuleSearch(self:GetText())
  end)
  ed.searchEdit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  ed.searchBtn = makeButton(ed, "Buscar", 66, 22)
  ed.searchBtn:SetPoint("LEFT", ed.searchEdit, "RIGHT", 6, 0)
  ed.searchBtn:SetScript("OnClick", function()
    M:RunRuleSearch(ed.searchEdit:GetText())
  end)

  -- Resultados de búsqueda (debajo de las filas condicionales para no solaparlas)
  ed.resultBox = CreateFrame("Frame", nil, ed)
  ed.resultBox:SetPoint("TOPLEFT", ed.searchLabel, "BOTTOMLEFT", 0, -44)
  ed.resultBox:SetSize(320, 160)
  ed.resultRows = {}

  -- Fila showOn (CD)
  ed.showOnBtn = makeButton(ed, "Mostrar: Disponible", 200, 22)
  ed.showOnBtn:SetPoint("TOPLEFT", ed.searchLabel, "BOTTOMLEFT", 0, -12)
  ed.showOnBtn:SetScript("OnClick", function()
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { showOn = nextInList(SHOW_ON_ORDER, r.showOn or "available") })
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end
  end)

  -- Filas aura (unit/filter/show)
  ed.auraUnitBtn = makeButton(ed, "Unidad: Player", 104, 22)
  ed.auraUnitBtn:SetPoint("TOPLEFT", ed.searchLabel, "BOTTOMLEFT", 0, -12)
  ed.auraUnitBtn:SetScript("OnClick", function()
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { auraUnit = nextInList({ "player", "target" }, r.auraUnit or "player") })
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end
  end)
  ed.auraFilterBtn = makeButton(ed, "Tipo: Ambos", 104, 22)
  ed.auraFilterBtn:SetPoint("LEFT", ed.auraUnitBtn, "RIGHT", 6, 0)
  ed.auraFilterBtn:SetScript("OnClick", function()
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { auraFilter = nextInList({ "both", "HELPFUL", "HARMFUL" }, r.auraFilter or "both") })
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end
  end)
  ed.auraShowBtn = makeButton(ed, "Cuando: Presente", 128, 22)
  ed.auraShowBtn:SetPoint("LEFT", ed.auraFilterBtn, "RIGHT", 6, 0)
  ed.auraShowBtn:SetScript("OnClick", function()
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { auraShow = nextInList({ "present", "absent", "always" }, r.auraShow or "present") })
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end
  end)

  -- Fila cargas (op + valor)
  ed.chargeOpBtn = makeButton(ed, "Op: >=", 70, 22)
  ed.chargeOpBtn:SetPoint("TOPLEFT", ed.searchLabel, "BOTTOMLEFT", 0, -12)
  ed.chargeOpBtn:SetScript("OnClick", function()
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { op = nextInList(CHARGE_OPS, r.op or "gte") })
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end
  end)
  ed.chargeValLabel = ed:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ed.chargeValLabel:SetPoint("LEFT", ed.chargeOpBtn, "RIGHT", 10, 0)
  ed.chargeValLabel:SetText("Valor:")
  ed.chargeValEdit = CreateFrame("EditBox", nil, ed, "InputBoxTemplate")
  ed.chargeValEdit:SetSize(44, 22)
  ed.chargeValEdit:SetPoint("LEFT", ed.chargeValLabel, "RIGHT", 8, 0)
  ed.chargeValEdit:SetAutoFocus(false)
  ed.chargeValEdit:SetNumeric(true)
  ed.chargeValEdit:SetMaxLetters(2)
  ed.chargeValEdit:SetJustifyH("CENTER")
  ed.chargeValEdit:SetScript("OnTextChanged", function(self)
    if self._syncing then
      return
    end
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { value = clampChargeValue(self:GetText()) })
      M:MarkDirty()
      M:ApplyPreview()
    end
  end)
  ed.chargeValEdit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  ed.chargeValEdit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  -- Fila on (combat/target)
  ed.onCheck = makeCheck(ed, "Activo (on = verdadero)")
  ed.onCheck:SetPoint("TOPLEFT", ed.searchLabel, "BOTTOMLEFT", 0, -12)
  ed.onCheck:SetScript("OnClick", function(self)
    local r = curRule()
    if r then
      alerts():UpdateGroupRule(M._session.groupId, r.id, { on = self:GetChecked() and true or false })
      M:MarkDirty()
      M:ApplyPreview()
    end
  end)

  -- Instantánea de auras activas: se toma al abrir el grupo y se refresca a pedido.
  ed.auraListLabel = ed:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ed.auraListLabel:SetPoint("TOPLEFT", 0, -302)
  ed.auraListLabel:SetJustifyH("LEFT")
  ed.auraListLabel:SetText("Auras activas (instantánea):")

  ed.auraRefreshBtn = makeButton(ed, "Refrescar", 84, 20)
  ed.auraRefreshBtn:SetPoint("TOPRIGHT", 0, -300)
  ed.auraRefreshBtn:SetScript("OnClick", function()
    M:RefreshAuraSnapshot()
    M:RefreshAuraList()
  end)
  tip(ed.auraRefreshBtn, "Vuelve a leer los buffs/debuffs de player y target en este instante.")

  ed.auraScroll = CreateFrame("ScrollFrame", "ChukieUi_AlertsAuraSnapScroll", ed, "UIPanelScrollFrameTemplate")
  ed.auraScroll:SetPoint("TOPLEFT", 0, -324)
  ed.auraScroll:SetPoint("BOTTOMRIGHT", -26, 30)
  ed.auraContent = CreateFrame("Frame", nil, ed.auraScroll)
  ed.auraContent:SetSize(330, 10)
  ed.auraScroll:SetScrollChild(ed.auraContent)
  ed.auraRows = {}

  ed.help = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ed.help:SetPoint("BOTTOMLEFT", 0, 0)
  ed.help:SetPoint("BOTTOMRIGHT", 0, 0)
  ed.help:SetJustifyH("LEFT")
  ed.help:SetTextColor(0.7, 0.7, 0.75)
end

--- Relee las auras de player/target y guarda la instantánea de la sesión.
function M:RefreshAuraSnapshot()
  local snap, hidden = captureAuraSnapshot()
  self._auraSnapshot = snap
  self._auraHidden = hidden or 0
  return snap
end

function M:RefreshAuraList()
  local ed = self._frame.groupView.ruleEditor
  local rows = ed.auraRows
  for i = 1, #rows do
    rows[i]:Hide()
  end
  local snap = self._auraSnapshot or self:RefreshAuraSnapshot()
  local y = 0
  for i = 1, #snap do
    local a = snap[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Button", nil, ed.auraContent, "BackdropTemplate")
      row:SetSize(330, 20)
      row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
      row:SetBackdropColor(0.12, 0.12, 0.15, 0.9)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(16, 16)
      row.icon:SetPoint("LEFT", 3, 0)
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
      row.label:SetPoint("RIGHT", -3, 0)
      row.label:SetJustifyH("LEFT")
      row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:Show()
    row.icon:SetTexture(a.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.label:SetText(string.format("%s  (#%d)  |cff9999aa%s%s|r", a.name, a.spellId, a.unit, a.harmful and " · debuff" or " · buff"))
    local entry = a
    row:SetScript("OnClick", function()
      local r = curRule()
      if not r then
        return
      end
      local partial = { spellId = entry.spellId }
      -- Elegir un debuff del objetivo implica unidad y tipo: se ajustan solos.
      if r.type == "aura" then
        partial.auraUnit = entry.unit
        partial.auraFilter = entry.harmful and "HARMFUL" or "HELPFUL"
      end
      alerts():UpdateGroupRule(M._session.groupId, r.id, partial)
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end)
    y = y + 21
  end
  ed.auraContent:SetHeight(math.max(10, y))
  local hidden = tonumber(self._auraHidden) or 0
  local txt = (#snap == 0) and "Auras activas: ninguna legible" or string.format("Auras activas: %d", #snap)
  if hidden > 0 then
    txt = txt .. string.format(" |cffff8888(+%d secretas)|r", hidden)
  end
  ed.auraListLabel:SetText(txt)
end

function M:RunRuleSearch(query)
  local ed = self._frame.groupView.ruleEditor
  local r = curRule()
  local includeAuras = r and r.type == "aura"
  local results = self:SearchSpells(query, includeAuras)
  local rows = ed.resultRows
  for i = 1, #rows do
    rows[i]:Hide()
  end
  local maxShow = math.min(#results, 7)
  for i = 1, maxShow do
    local e = results[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Button", nil, ed.resultBox, "BackdropTemplate")
      row:SetSize(320, 20)
      row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
      row:SetBackdropColor(0.15, 0.15, 0.18, 0.9)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(16, 16)
      row.icon:SetPoint("LEFT", 3, 0)
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
      row.label:SetPoint("RIGHT", -3, 0)
      row.label:SetJustifyH("LEFT")
      row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -(i - 1) * 21)
    row:Show()
    row.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.label:SetText(string.format("%s  (#%d)", e.name, e.spellId))
    local sid = e.spellId
    row:SetScript("OnClick", function()
      local rr = curRule()
      if rr then
        alerts():UpdateGroupRule(M._session.groupId, rr.id, { spellId = sid })
        M:MarkDirty()
        M:SyncGroupView()
        M:ApplyPreview()
      end
      for j = 1, #ed.resultRows do
        ed.resultRows[j]:Hide()
      end
    end)
  end
  if maxShow == 0 then
    print("|cffff9900Chukie UI|r: sin resultados. Probá con el spellId numérico.")
  end
end

function M:UpdateRuleSpellName()
  local ed = self._frame.groupView.ruleEditor
  local r = curRule()
  local sid = r and tonumber(r.spellId) or 0
  ed.spellName:SetText(sid > 0 and spellName(sid) or "")
end

function M:RefreshRuleList()
  local p = self._frame.groupView
  local rows = p.ruleRows
  for i = 1, #rows do
    rows[i]:Hide()
    rows[i].ruleId = nil
  end
  local g = curGroup()
  if not g then
    p.ruleContent:SetHeight(10)
    return
  end
  local y = 0
  for i = 1, #g.rules do
    local r = g.rules[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Button", nil, p.ruleContent, "BackdropTemplate")
      row:SetSize(176, 22)
      row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.label:SetPoint("LEFT", 4, 0)
      row.label:SetPoint("RIGHT", -22, 0)
      row.label:SetJustifyH("LEFT")
      row.del = makeButton(row, "X", 18, 18)
      row.del:SetPoint("RIGHT", -2, 0)
      rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:Show()
    row.ruleId = r.id
    local lab = RULE_LABELS[r.type] or r.type
    local extra = ""
    if r.type == "cooldown" or r.type == "aura" or r.type == "proc" or r.type == "charges" then
      local sid = tonumber(r.spellId) or 0
      extra = sid > 0 and ("  " .. spellName(sid)) or "  (sin hechizo)"
    end
    local on = (r.enabled ~= false) and "" or " (off)"
    row.label:SetText(lab .. extra .. on)
    local rid = r.id
    row:SetScript("OnClick", function()
      M:Select("rule", rid)
    end)
    row.del:SetScript("OnClick", function()
      alerts():DeleteGroupRule(M._session.groupId, rid)
      if M._session.ruleId == rid then
        M._session.ruleId = nil
      end
      M:MarkDirty()
      M:SyncGroupView()
      M:ApplyPreview()
    end)
    y = y + 24
  end
  p.ruleContent:SetHeight(math.max(10, y))
end

function M:SyncRuleEditor()
  local p = self._frame.groupView
  local ed = p.ruleEditor
  local r = curRule()

  -- Ocultar todas las filas condicionales
  ed.spellLabel:Hide()
  ed.spellEdit:Hide()
  ed.spellName:Hide()
  ed.searchLabel:Hide()
  ed.searchEdit:Hide()
  ed.searchBtn:Hide()
  ed.showOnBtn:Hide()
  ed.auraUnitBtn:Hide()
  ed.auraFilterBtn:Hide()
  ed.auraShowBtn:Hide()
  ed.chargeOpBtn:Hide()
  ed.chargeValLabel:Hide()
  ed.chargeValEdit:Hide()
  ed.onCheck:Hide()
  ed.auraListLabel:Hide()
  ed.auraRefreshBtn:Hide()
  ed.auraScroll:Hide()
  for j = 1, #ed.resultRows do
    ed.resultRows[j]:Hide()
  end

  if not r then
    ed.title:SetText("Elegí o agregá una condición")
    ed.enabledCheck:Hide()
    ed.help:SetText("Sin condiciones el grupo se guarda, pero el motor lo deja oculto.")
    return
  end
  ed.enabledCheck:Show()
  ed.enabledCheck:SetChecked(r.enabled ~= false)
  ed.title:SetText("Condición: " .. (RULE_LABELS[r.type] or r.type))

  local hasSpell = r.type == "cooldown" or r.type == "aura" or r.type == "proc" or r.type == "charges"
  if hasSpell then
    ed.spellLabel:Show()
    ed.spellEdit:Show()
    ed.spellName:Show()
    ed.searchLabel:Show()
    ed.searchEdit:Show()
    ed.searchBtn:Show()
    local box = ed.spellEdit
    if not box:HasFocus() then
      box._syncing = true
      box:SetText((tonumber(r.spellId) or 0) > 0 and tostring(r.spellId) or "")
      box._syncing = false
    end
    self:UpdateRuleSpellName()
  end

  if r.type == "cooldown" then
    ed.showOnBtn:Show()
    ed.showOnBtn:SetText("Mostrar: " .. (SHOW_ON_LABELS[r.showOn or "available"] or "Disponible"))
    ed.help:SetText("CD: cuándo mostrar según el estado del cooldown del hechizo.")
  elseif r.type == "aura" then
    ed.auraUnitBtn:Show()
    ed.auraFilterBtn:Show()
    ed.auraShowBtn:Show()
    ed.auraUnitBtn:SetText("Unidad: " .. ((r.auraUnit == "target") and "Target" or "Player"))
    ed.auraFilterBtn:SetText("Tipo: " .. (({ both = "Ambos", HELPFUL = "Buff", HARMFUL = "Debuff" })[r.auraFilter or "both"] or "Ambos"))
    ed.auraShowBtn:SetText("Cuando: " .. (({ present = "Presente", absent = "Ausente", always = "Siempre" })[r.auraShow or "present"] or "Presente"))
    local secretAura = alerts().IsSpellAuraSecret and alerts():IsSpellAuraSecret(r.spellId)
    local delegable = alerts().GroupUsesAuraContainer and alerts():GroupUsesAuraContainer(curGroup())
    if delegable then
      ed.help:SetText("|cff66ff66Lo dibuja el cliente:|r con una sola condición Aura «Presente» y un solo efecto de icono/textura, el juego decide cuándo se ve, así que funciona con auras ocultas. Tamaño y posición los manda el efecto.")
    elseif secretAura and (r.auraShow or "present") == "absent" then
      ed.help:SetText("|cffff6666Blizzard oculta este aura:|r no se puede afirmar que falte, así que la condición «Ausente» nunca se cumple. Usá la condición Cooldown en su lugar.")
    elseif secretAura then
      ed.help:SetText("|cffffcc66Aura oculta por Blizzard:|r solo se detecta si el cliente la expone; «Presente» puede fallar.")
    else
      ed.help:SetText("Aura: buff/debuff en player o target; presente / ausente / siempre.")
    end
  elseif r.type == "proc" then
    ed.help:SetText("Proc: se cumple mientras el jugador tenga el buff indicado.")
  elseif r.type == "charges" then
    ed.chargeOpBtn:Show()
    ed.chargeValLabel:Show()
    ed.chargeValEdit:Show()
    ed.chargeOpBtn:SetText("Op: " .. (CHARGE_OP_LABELS[r.op or "gte"] or ">="))
    if not ed.chargeValEdit:HasFocus() then
      ed.chargeValEdit._syncing = true
      ed.chargeValEdit:SetText(tostring(clampChargeValue(r.value)))
      ed.chargeValEdit._syncing = false
    end
    ed.help:SetText("Cargas: compara las cargas del hechizo con el valor (operador + valor).")
  elseif r.type == "combat" then
    ed.onCheck:Show()
    ed.onCheck:SetChecked(r.on ~= false)
    ed.onCheck.text:SetText("En combate (on)")
    ed.help:SetText("Combate: marca on para exigir estar en combate; sin marcar, exige NO estar en combate.")
  elseif r.type == "target" then
    ed.onCheck:Show()
    ed.onCheck:SetChecked(r.on ~= false)
    ed.onCheck.text:SetText("Con target (on)")
    ed.help:SetText("Target: marca on para exigir target vivo; sin marcar, exige NO tener target.")
  end

  -- Solo aura y proc leen auras: para el resto el id que hace falta es del hechizo.
  if r.type == "aura" or r.type == "proc" then
    ed.auraListLabel:Show()
    ed.auraRefreshBtn:Show()
    ed.auraScroll:Show()
    self:RefreshAuraList()
  end
end

-- ---------------------------------------------------------------------------
-- Vista de grupo (listas + editor contextual)
-- ---------------------------------------------------------------------------

function M:SyncGroupView()
  local f = self:Ensure()
  local s = self._session
  if not s then
    return
  end
  local gp = f.groupView
  local g = curGroup()
  f.title:SetText(s.isDraft and "Nuevo grupo" or "Editar grupo")

  self:SyncHeader()
  self:RefreshEffectList()
  self:RefreshRuleList()

  -- La selección determina qué editor se ve a la derecha.
  if s.effectId and not curEffect() then
    s.effectId = nil
  end
  if s.ruleId and not curRule() then
    s.ruleId = nil
  end
  if not s.effectId and g and g.effects[1] then
    s.effectId = g.effects[1].id
  end
  if not s.ruleId and g and g.rules[1] then
    s.ruleId = g.rules[1].id
  end
  if s.selKind ~= "rule" then
    s.selKind = "effect"
  end
  if s.selKind == "rule" and not s.ruleId then
    s.selKind = "effect"
  end
  if s.selKind == "effect" and not s.effectId and s.ruleId then
    s.selKind = "rule"
  end

  if s.selKind == "rule" then
    s.forceEffect = false
    gp.effectEditor:Hide()
    gp.preview:Hide()
    gp.ruleEditor:Show()
    self:SyncRuleEditor()
  else
    gp.ruleEditor:Hide()
    gp.preview:Show()
    self:SyncEffectEditor()
  end
  self:HighlightSelection()
end

--- Resalta la fila activa: solo una de las dos listas puede tener foco a la vez.
function M:HighlightSelection()
  local gp = self._frame.groupView
  local s = self._session
  if not s then
    return
  end
  local function paint(row, active)
    if active then
      row:SetBackdropColor(0.25, 0.35, 0.5, 0.95)
    else
      row:SetBackdropColor(0.12, 0.12, 0.15, 0.9)
    end
  end
  local rows = gp.effectRows or {}
  for i = 1, #rows do
    paint(rows[i], s.selKind == "effect" and rows[i].effectId and rows[i].effectId == s.effectId)
  end
  rows = gp.ruleRows or {}
  for i = 1, #rows do
    paint(rows[i], s.selKind == "rule" and rows[i].ruleId and rows[i].ruleId == s.ruleId)
  end
end

-- ---------------------------------------------------------------------------
-- Inicio de sesiones (nuevo / editar)
-- ---------------------------------------------------------------------------

function M:StartNewGroup()
  if not alerts() then
    return
  end
  if self._session then
    self:CancelSession(true)
  end
  local moduleWas = alerts():IsEnabled()
  local g = alerts():AddGroup({ name = "", enabled = true, ruleLogic = "and" })
  if not g then
    print("|cffff9900Chukie UI|r: no se pudo crear el grupo.")
    return
  end
  self._session = {
    groupId = g.id,
    isDraft = true,
    dirty = true,
    moduleWasEnabled = moduleWas,
    effectId = g.effects[1] and g.effects[1].id or nil,
    ruleId = nil,
    selKind = "effect",
    forceEffect = false,
  }
  local f = self:Ensure()
  f.list:Hide()
  self:RefreshAuraSnapshot()
  f.groupView:Show()
  self:SyncGroupView()
  self:ApplyPreview()
end

function M:StartEditGroup(id)
  if not alerts() then
    return
  end
  if self._session then
    self:CancelSession(true)
  end
  local g = alerts():GetGroupById(id)
  if not g then
    return
  end
  self._session = {
    groupId = id,
    isDraft = false,
    dirty = false,
    snapshot = snapshotGroup(g),
    effectId = g.effects[1] and g.effects[1].id or nil,
    ruleId = g.rules[1] and g.rules[1].id or nil,
    selKind = "effect",
    forceEffect = false,
  }
  local f = self:Ensure()
  f.list:Hide()
  self:RefreshAuraSnapshot()
  f.groupView:Show()
  self:SyncGroupView()
  self:ApplyPreview()
end

-- ---------------------------------------------------------------------------
-- Guardar / Cancelar
-- ---------------------------------------------------------------------------

function M:SaveSession()
  local s = self._session
  if not s then
    self:ShowList()
    return
  end
  if alerts() and alerts().EnsureModuleEnabled then
    alerts():EnsureModuleEnabled()
  end
  self._session = nil
  self:EndPreview()
  self:ShowList()
end

--- fromHide=true cuando lo dispara OnHide (X / ESC / Hide del panel).
function M:CancelSession(fromHide)
  local s = self._session
  if not s then
    if fromHide then
      self:EndPreview()
    end
    return
  end
  if alerts() then
    if s.isDraft then
      alerts():DeleteGroup(s.groupId)
      if s.moduleWasEnabled == false and alerts().SetEnabled then
        alerts():SetEnabled(false)
      end
    elseif s.dirty and s.snapshot then
      restoreSnapshot(s.groupId, s.snapshot)
    end
  end
  self._session = nil
  self:EndPreview()
  if not fromHide then
    self:ShowList()
  end
end

-- ---------------------------------------------------------------------------
-- Vistas / API pública
-- ---------------------------------------------------------------------------

function M:ShowList()
  local f = self:Ensure()
  if CloseDropDownMenus then
    CloseDropDownMenus()
  end
  f.groupView:Hide()
  if f.picker then
    f.picker:Hide()
  end
  f.list:Show()
  f.title:SetText("Chukie UI — Alertas (grupos)")
  self:RefreshList()
end

function M:Show()
  -- Pantalla limpia para ajustar gráficos: cerrar Opciones / menú.
  if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
    if HideUIPanel then
      HideUIPanel(SettingsPanel)
    else
      SettingsPanel:Hide()
    end
  end
  if GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown() then
    if HideUIPanel then
      HideUIPanel(GameMenuFrame)
    else
      GameMenuFrame:Hide()
    end
  end
  self:Ensure()
  self:BuildSpellIndex()
  self._suppressHide = true
  self._frame:Show()
  self._suppressHide = false
  if self._session then
    self._frame.list:Hide()
    self._frame.groupView:Show()
    self:SyncGroupView()
    self:ApplyPreview()
  else
    self:ShowList()
  end
  self._frame:Raise()
end

function M:Hide()
  self._suppressHide = true
  self:CancelSession(true)
  if self._frame then
    self._frame:Hide()
  end
  self._suppressHide = false
end

function M:Toggle()
  if self._frame and self._frame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function M:RefreshIfShown()
  if self._frame and self._frame:IsShown() and self._frame.list and self._frame.list:IsShown() then
    self:RefreshList()
  end
end

SLASH_CHUKIEAURA1 = "/chukie-aura"
SLASH_CHUKIEAURA2 = "/chukieaura"
SlashCmdList["CHUKIEAURA"] = function()
  if ns.AlertsManager and ns.AlertsManager.Show then
    ns.AlertsManager:Show()
  else
    print("|cffff9900Chukie UI|r: gestor de alertas no disponible.")
  end
end
