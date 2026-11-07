--[[ Panel de auras: slots grandes en posición fija, uno por hechizo elegido.
     Cada slot es un AuraContainer del cliente (12.1): Blizzard decide cuándo se
     dibuja el icono, así que también aparecen las auras que oculta al addon.
     Consecuencia del mismo diseño: el addon no sabe cuáles están activas, por eso
     los slots no se compactan y cada aura vive siempre en su propio hueco.
     Los contenedores no se pueden crear en combate: se difiere a PLAYER_REGEN_ENABLED. ]]

local _, ns = ...

local AP = {}
ns.AuraPanel = AP

local SIZE_MIN, SIZE_MAX = 24, 256
--- Los contenedores se crean con este lado y el tamaño real se aplica por escala:
--- así mover el slider no obliga a recrear frames (imposible en combate, además).
local SLOT_BASE = 64
local SPACING_MAX = 40
local PER_LINE_MAX = 12
local MAX_AURAS = 24
local GROWTHS = { "right", "left", "down", "up" }
local GROWTH_LABELS = {
  right = "Derecha",
  left = "Izquierda",
  down = "Abajo",
  up = "Arriba",
}

local function clamp(n, lo, hi)
  n = tonumber(n)
  if not n then
    return lo
  end
  if n < lo then
    return lo
  end
  if n > hi then
    return hi
  end
  return n
end

--- Solo devuelve el valor si es legible: tocar un secreto en un `if` o en
--- tonumber lanza error mientras el addon está tainted.
local function plain(v)
  if issecretvalue and issecretvalue(v) then
    return nil
  end
  return v
end

local function spellIcon(spellId)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, spellId)
    if ok then
      return tex
    end
  end
  return nil
end

local function spellName(spellId)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
    if ok and type(info) == "table" and info.name then
      return info.name
    end
    if ok and type(info) == "string" then
      return info
    end
  end
  return "#" .. tostring(spellId or 0)
end

-- ---------------------------------------------------------------------------
-- Modelo
-- ---------------------------------------------------------------------------

function AP:DB()
  if ns.Profile and ns.Profile.GetAuraPanelModel then
    return ns.Profile:GetAuraPanelModel()
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return { auras = {} }
  end
  p.auraPanel = p.auraPanel or {}
  p.auraPanel.auras = p.auraPanel.auras or {}
  return p.auraPanel
end

function AP:IsEnabled()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or not p.enabled then
    return false
  end
  return self:DB().enabled == true
end

function AP:Size()
  return clamp(self:DB().size, SIZE_MIN, SIZE_MAX)
end

function AP:Spacing()
  return clamp(self:DB().spacing, 0, SPACING_MAX)
end

function AP:PerLine()
  return math.floor(clamp(self:DB().perLine, 1, PER_LINE_MAX))
end

function AP:Growth()
  local g = self:DB().growth
  return GROWTH_LABELS[g] and g or "right"
end

function AP:Auras()
  local db = self:DB()
  db.auras = db.auras or {}
  return db.auras
end

function AP:FindAura(spellId)
  spellId = math.floor(tonumber(spellId) or 0)
  local list = self:Auras()
  for i = 1, #list do
    if math.floor(tonumber(list[i].spellId) or 0) == spellId then
      return list[i], i
    end
  end
  return nil, nil
end

function AP:AddAura(spellId)
  spellId = math.floor(tonumber(spellId) or 0)
  if spellId <= 0 then
    return false, "id inválido"
  end
  if self:FindAura(spellId) then
    return false, "ya está en el panel"
  end
  local list = self:Auras()
  if #list >= MAX_AURAS then
    return false, "el panel ya tiene " .. MAX_AURAS .. " auras"
  end
  list[#list + 1] = { spellId = spellId, enabled = true }
  self:Refresh()
  return true
end

function AP:RemoveAura(spellId)
  local _, idx = self:FindAura(spellId)
  if not idx then
    return false
  end
  table.remove(self:Auras(), idx)
  self:Refresh()
  return true
end

function AP:MoveAura(spellId, delta)
  local _, idx = self:FindAura(spellId)
  if not idx then
    return false
  end
  local list = self:Auras()
  local target = idx + (tonumber(delta) or 0)
  if target < 1 or target > #list then
    return false
  end
  local item = table.remove(list, idx)
  table.insert(list, target, item)
  self:Refresh()
  return true
end

-- ---------------------------------------------------------------------------
-- Host y slots
-- ---------------------------------------------------------------------------

local function panelExtent(self, count)
  local size, spacing, perLine = self:Size(), self:Spacing(), self:PerLine()
  local growth = self:Growth()
  local n = math.max(count, 1)
  local main = math.min(n, perLine)
  local cross = math.ceil(n / perLine)
  local mainPx = main * size + (main - 1) * spacing
  local crossPx = cross * size + (cross - 1) * spacing
  if growth == "down" or growth == "up" then
    return crossPx, mainPx
  end
  return mainPx, crossPx
end

--- Posición del slot i (1..n) respecto al centro del host.
local function slotOffset(self, i, count)
  local size, spacing, perLine = self:Size(), self:Spacing(), self:PerLine()
  local growth = self:Growth()
  local step = size + spacing
  local mainIdx = (i - 1) % perLine
  local crossIdx = math.floor((i - 1) / perLine)
  local w, h = panelExtent(self, count)
  local x, y
  if growth == "down" or growth == "up" then
    y = growth == "down" and -mainIdx * step or mainIdx * step
    x = crossIdx * step
    x = x - (w - size) / 2
    y = y + (growth == "down" and (h - size) / 2 or -(h - size) / 2)
  else
    x = growth == "right" and mainIdx * step or -mainIdx * step
    y = -crossIdx * step
    x = x + (growth == "right" and -(w - size) / 2 or (w - size) / 2)
    y = y + (h - size) / 2
  end
  return x, y
end

function AP:EnsureHost()
  if self._host then
    return self._host
  end
  local host = CreateFrame("Frame", "ChukieUi_AuraPanel", UIParent)
  host:SetFrameStrata("MEDIUM")
  host:SetClampedToScreen(true)
  host:SetMovable(true)
  host:EnableMouse(false)
  host:RegisterForDrag("LeftButton")
  host.bg = host:CreateTexture(nil, "BACKGROUND")
  host.bg:SetAllPoints(host)
  host.bg:SetColorTexture(0, 0.7, 1, 0.12)
  host.bg:Hide()
  host.hint = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  host.hint:SetPoint("BOTTOM", host, "TOP", 0, 4)
  host.hint:SetText("Panel de auras: arrastrá para mover")
  host.hint:Hide()
  host:SetScript("OnDragStart", function(f)
    if InCombatLockdown and InCombatLockdown() then
      return
    end
    f:StartMoving()
  end)
  host:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local cx, cy = f:GetCenter()
    local px, py = UIParent:GetCenter()
    if cx and px then
      local db = AP:DB()
      db.point = { "CENTER", math.floor(cx - px + 0.5), math.floor(cy - py + 0.5) }
    end
    AP:Layout()
  end)
  self._host = host
  return host
end

function AP:ReleaseSlots()
  if not self._slots then
    return
  end
  for key, slot in pairs(self._slots) do
    if slot.container then
      slot.container:Hide()
      pcall(function()
        slot.container:SetParent(nil)
      end)
    end
    if slot.ghost then
      slot.ghost:Hide()
      pcall(function()
        slot.ghost:SetParent(nil)
      end)
    end
    self._slots[key] = nil
  end
end

--- Marca de posición: el addon no sabe si el aura está activa, así que sin esta
--- guía el hueco vacío sería invisible al configurar.
local function createGhost(host, spellId)
  local ghost = CreateFrame("Frame", nil, host)
  ghost:EnableMouse(false)
  ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
  ghost.icon:SetAllPoints(ghost)
  ghost.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  ghost.icon:SetTexture(spellIcon(spellId))
  ghost.icon:SetDesaturated(true)
  ghost.icon:SetAlpha(0.35)
  ghost.border = ghost:CreateTexture(nil, "OVERLAY")
  ghost.border:SetAllPoints(ghost)
  ghost.border:SetColorTexture(1, 1, 1, 0.08)
  return ghost
end

--- Recoloca host y slots sin recrear contenedores.
function AP:Layout()
  local host = self._host
  if not host then
    return
  end
  local db = self:DB()
  local order = self._order or {}
  local w, h = panelExtent(self, #order)
  host:SetSize(w, h)
  host:ClearAllPoints()
  local p = type(db.point) == "table" and db.point or { "CENTER", 0, -180 }
  host:SetPoint("CENTER", UIParent, "CENTER", tonumber(p[2]) or 0, tonumber(p[3]) or -180)
  local size = self:Size()
  for i = 1, #order do
    local slot = self._slots and self._slots[order[i]]
    if slot then
      local x, y = slotOffset(self, i, #order)
      if slot.container then
        slot.container:ClearAllPoints()
        slot.container:SetSize(SLOT_BASE, SLOT_BASE)
        slot.container:SetScale(size / SLOT_BASE)
        -- El offset del punto no se ve afectado por la escala del propio frame.
        slot.container:SetPoint("CENTER", host, "CENTER", x / (size / SLOT_BASE), y / (size / SLOT_BASE))
      end
      if slot.ghost then
        slot.ghost:ClearAllPoints()
        slot.ghost:SetSize(size, size)
        slot.ghost:SetPoint("CENTER", host, "CENTER", x, y)
      end
    end
  end
end

function AP:Refresh()
  local host = self._host
  if not self:IsEnabled() then
    self:ReleaseSlots()
    self._order = {}
    if host then
      host:Hide()
    end
    return
  end
  host = self:EnsureHost()
  local db = self:DB()
  local unlocked = db.unlocked == true
  local alerts = ns.Alerts
  local hasApi = alerts and alerts.CreateSingleAuraContainer and alerts:HasAuraContainerAPI()

  self._slots = self._slots or {}
  local order, seen = {}, {}
  local list = self:Auras()
  local unit = db.unit == "target" and "target" or "player"
  local filter = db.filter == "HARMFUL" and "HARMFUL" or "HELPFUL"
  local pending = false
  local rejected = 0

  for i = 1, #list do
    local entry = list[i]
    local spellId = math.floor(tonumber(entry.spellId) or 0)
    if spellId > 0 and entry.enabled ~= false then
      local slotUnit = entry.unit == "target" and "target" or (entry.unit == "player" and "player" or unit)
      local slotFilter = entry.filter == "HARMFUL" and "HARMFUL" or (entry.filter == "HELPFUL" and "HELPFUL" or filter)
      local key = spellId
      local sig = table.concat({ tostring(spellId), slotUnit, slotFilter }, "|")
      local slot = self._slots[key]
      if slot and slot.sig ~= sig then
        if slot.container then
          slot.container:Hide()
          pcall(function()
            slot.container:SetParent(nil)
          end)
        end
        slot.container = nil
        slot.sig = nil
      end
      slot = slot or {}
      self._slots[key] = slot
      if not slot.container and hasApi then
        self._slotSerial = (self._slotSerial or 0) + 1
        local c = alerts:CreateSingleAuraContainer(
          "ChukieUi_AuraPanelSlot" .. spellId .. "_" .. self._slotSerial,
          host,
          slotUnit,
          slotFilter .. "|INCLUDE_NAME_PLATE_ONLY",
          spellId,
          { size = SLOT_BASE, display = "icon", alpha = 1, color = { 1, 1, 1 } }
        )
        if c then
          slot.container = c
          slot.sig = sig
        elseif InCombatLockdown and InCombatLockdown() then
          pending = true
        else
          -- El cliente expone la API pero rechazó el slot por hechizo: hay que avisarlo.
          rejected = rejected + 1
        end
      end
      if not slot.ghost then
        slot.ghost = createGhost(host, spellId)
      end
      if unlocked then
        slot.ghost:Show()
      else
        slot.ghost:Hide()
      end
      if slot.container then
        slot.container:Show()
      end
      order[#order + 1] = key
      seen[key] = true
    end
  end

  for key, slot in pairs(self._slots) do
    if not seen[key] then
      if slot.container then
        slot.container:Hide()
        pcall(function()
          slot.container:SetParent(nil)
        end)
      end
      if slot.ghost then
        slot.ghost:Hide()
        pcall(function()
          slot.ghost:SetParent(nil)
        end)
      end
      self._slots[key] = nil
    end
  end

  self._order = order
  self._pending = pending
  self._rejected = rejected
  host:EnableMouse(unlocked)
  if unlocked then
    host.bg:Show()
    host.hint:Show()
  else
    host.bg:Hide()
    host.hint:Hide()
  end
  self:Layout()
  if #order > 0 or unlocked then
    host:Show()
  else
    host:Hide()
  end
  if self._configFrame and self._configFrame:IsShown() then
    self:SyncConfig()
  end
end

function AP:SetUnlocked(on)
  self:DB().unlocked = on and true or false
  self:Refresh()
end

-- ---------------------------------------------------------------------------
-- Instantánea de auras activas (para elegir sin buscar el id a mano)
-- ---------------------------------------------------------------------------

local function captureAuras()
  local out, hidden = {}, 0
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
    return out, hidden
  end
  local seen = {}
  local function scan(unit, filter)
    if unit ~= "player" and not UnitExists(unit) then
      return
    end
    for i = 1, 40 do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
      if not ok then
        -- Aura secreta en ese índice: el resto de la lista sí se lee.
        hidden = hidden + 1
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
          hidden = hidden + 1
        end
      end
    end
  end
  scan("player", "HELPFUL")
  scan("player", "HARMFUL")
  scan("target", "HELPFUL")
  scan("target", "HARMFUL")
  return out, hidden
end

function AP:RefreshSnapshot()
  self._snapshot, self._snapshotHidden = captureAuras()
  return self._snapshot
end

-- ---------------------------------------------------------------------------
-- Ventana de configuración
-- ---------------------------------------------------------------------------

local function makeButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 100, h or 22)
  b:SetText(text or "")
  return b
end

local function makeSlider(parent, key, label, lo, hi, step)
  local s = CreateFrame("Slider", "ChukieUi_AuraPanel" .. key, parent, "OptionsSliderTemplate")
  s:SetWidth(180)
  s:SetMinMaxValues(lo, hi)
  s:SetValueStep(step or 1)
  s:SetObeyStepOnDrag(true)
  local name = s:GetName()
  _G[name .. "Low"]:SetText(tostring(lo))
  _G[name .. "High"]:SetText(tostring(hi))
  s.labelText = _G[name .. "Text"]
  s.labelBase = label
  return s
end

function AP:EnsureConfig()
  if self._configFrame then
    return self._configFrame
  end
  local f = CreateFrame("Frame", "ChukieUi_AuraPanelConfig", UIParent, "BackdropTemplate")
  f:SetSize(520, 520)
  -- Centrada en la mitad derecha, igual que el editor de alertas.
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
  tinsert(UISpecialFrames, "ChukieUi_AuraPanelConfig")
  f:SetScript("OnHide", function()
    if AP:DB().unlocked then
      AP:SetUnlocked(false)
    end
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("Chukie UI — Panel de auras")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", 16, -40)
  body:SetPoint("BOTTOMRIGHT", -16, 14)
  f.body = body

  f.enabledCheck = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
  f.enabledCheck:SetPoint("TOPLEFT", 0, 0)
  f.enabledCheck.text = f.enabledCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.enabledCheck.text:SetPoint("LEFT", f.enabledCheck, "RIGHT", 2, 0)
  f.enabledCheck.text:SetText("Panel activo")
  f.enabledCheck:SetScript("OnClick", function(cb)
    AP:DB().enabled = cb:GetChecked() and true or false
    AP:Refresh()
  end)

  f.moveBtn = makeButton(body, "Mover", 90, 22)
  f.moveBtn:SetPoint("TOPRIGHT", 0, -2)
  f.moveBtn:SetScript("OnClick", function()
    AP:SetUnlocked(AP:DB().unlocked ~= true)
  end)

  -- Geometría: recolocar basta, y así arrastrar el slider no recrea contenedores.
  local function onGeometryChanged(slider, key, value, suffix)
    AP:DB()[key] = value
    slider.labelText:SetText(slider.labelBase .. ": " .. tostring(value) .. (suffix or ""))
    AP:Layout()
  end

  f.sizeSlider = makeSlider(body, "Size", "Tamaño", SIZE_MIN, SIZE_MAX, 2)
  f.sizeSlider:SetPoint("TOPLEFT", 8, -46)
  f.sizeSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onGeometryChanged(s, "size", math.floor(v + 0.5), " px")
  end)

  f.spacingSlider = makeSlider(body, "Spacing", "Separación", 0, SPACING_MAX, 1)
  f.spacingSlider:SetPoint("TOPLEFT", 8, -96)
  f.spacingSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onGeometryChanged(s, "spacing", math.floor(v + 0.5), " px")
  end)

  f.perLineSlider = makeSlider(body, "PerLine", "Por línea", 1, PER_LINE_MAX, 1)
  f.perLineSlider:SetPoint("TOPLEFT", 260, -46)
  f.perLineSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onGeometryChanged(s, "perLine", math.floor(v + 0.5), "")
  end)

  f.growthBtn = makeButton(body, "Crece: Derecha", 130, 22)
  f.growthBtn:SetPoint("TOPLEFT", 264, -104)
  f.growthBtn:SetScript("OnClick", function()
    local cur = AP:Growth()
    local nextIdx = 1
    for i = 1, #GROWTHS do
      if GROWTHS[i] == cur then
        nextIdx = (i % #GROWTHS) + 1
        break
      end
    end
    AP:DB().growth = GROWTHS[nextIdx]
    AP:Layout()
    AP:SyncConfig()
  end)

  f.unitBtn = makeButton(body, "Unidad: Player", 130, 22)
  f.unitBtn:SetPoint("TOPLEFT", 264, -130)
  f.unitBtn:SetScript("OnClick", function()
    local db = AP:DB()
    db.unit = db.unit == "target" and "player" or "target"
    AP:Refresh()
  end)

  f.filterBtn = makeButton(body, "Tipo: Buff", 130, 22)
  f.filterBtn:SetPoint("TOPLEFT", 264, -156)
  f.filterBtn:SetScript("OnClick", function()
    local db = AP:DB()
    db.filter = db.filter == "HARMFUL" and "HELPFUL" or "HARMFUL"
    AP:Refresh()
  end)

  f.addLabel = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.addLabel:SetPoint("TOPLEFT", 0, -148)
  f.addLabel:SetText("Agregar por id:")

  f.addEdit = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
  f.addEdit:SetSize(80, 20)
  f.addEdit:SetPoint("TOPLEFT", 90, -144)
  f.addEdit:SetAutoFocus(false)
  f.addEdit:SetNumeric(true)

  f.addBtn = makeButton(body, "Agregar", 70, 20)
  f.addBtn:SetPoint("LEFT", f.addEdit, "RIGHT", 8, 0)
  f.addBtn:SetScript("OnClick", function()
    local ok, err = AP:AddAura(f.addEdit:GetText())
    if ok then
      f.addEdit:SetText("")
    elseif err then
      print("|cffff9900Chukie UI|r panel de auras: " .. err)
    end
  end)
  f.addEdit:SetScript("OnEnterPressed", function()
    f.addBtn:Click()
  end)

  f.listLabel = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.listLabel:SetPoint("TOPLEFT", 0, -180)
  f.listLabel:SetText("Auras del panel")

  f.listScroll = CreateFrame("ScrollFrame", "ChukieUi_AuraPanelListScroll", body, "UIPanelScrollFrameTemplate")
  f.listScroll:SetPoint("TOPLEFT", 0, -200)
  f.listScroll:SetSize(230, 200)
  f.listContent = CreateFrame("Frame", nil, f.listScroll)
  f.listContent:SetSize(230, 10)
  f.listScroll:SetScrollChild(f.listContent)
  f.listRows = {}

  f.snapLabel = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.snapLabel:SetPoint("TOPLEFT", 264, -180)
  f.snapLabel:SetText("Auras activas (instantánea)")

  f.snapRefresh = makeButton(body, "Refrescar", 80, 20)
  f.snapRefresh:SetPoint("TOPLEFT", 264, -406)
  f.snapRefresh:SetScript("OnClick", function()
    AP:RefreshSnapshot()
    AP:SyncConfig()
  end)

  f.snapScroll = CreateFrame("ScrollFrame", "ChukieUi_AuraPanelSnapScroll", body, "UIPanelScrollFrameTemplate")
  f.snapScroll:SetPoint("TOPLEFT", 264, -200)
  f.snapScroll:SetSize(200, 200)
  f.snapContent = CreateFrame("Frame", nil, f.snapScroll)
  f.snapContent:SetSize(200, 10)
  f.snapScroll:SetScrollChild(f.snapContent)
  f.snapRows = {}

  f.help = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.help:SetPoint("BOTTOMLEFT", 0, 0)
  f.help:SetPoint("BOTTOMRIGHT", 0, 0)
  f.help:SetJustifyH("LEFT")
  f.help:SetTextColor(0.7, 0.7, 0.75)

  self._configFrame = f
  return f
end

function AP:SyncList()
  local f = self._configFrame
  local list = self:Auras()
  local rows = f.listRows
  for i = 1, #rows do
    rows[i]:Hide()
  end
  for i = 1, #list do
    local entry = list[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Frame", nil, f.listContent)
      row:SetSize(210, 26)
      row.bg = row:CreateTexture(nil, "BACKGROUND")
      row.bg:SetAllPoints(row)
      row.bg:SetColorTexture(1, 1, 1, 0.05)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(20, 20)
      row.icon:SetPoint("LEFT", 3, 0)
      row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
      row.text:SetWidth(105)
      row.text:SetJustifyH("LEFT")
      row.up = makeButton(row, "^", 20, 18)
      row.up:SetPoint("RIGHT", -46, 0)
      row.down = makeButton(row, "v", 20, 18)
      row.down:SetPoint("RIGHT", -24, 0)
      row.del = makeButton(row, "X", 20, 18)
      row.del:SetPoint("RIGHT", -2, 0)
      rows[i] = row
    end
    row:SetPoint("TOPLEFT", 0, -(i - 1) * 28)
    row.icon:SetTexture(spellIcon(entry.spellId))
    row.text:SetText(string.format("%s |cff888888#%d|r", spellName(entry.spellId), math.floor(tonumber(entry.spellId) or 0)))
    local sid = entry.spellId
    row.up:SetScript("OnClick", function()
      AP:MoveAura(sid, -1)
    end)
    row.down:SetScript("OnClick", function()
      AP:MoveAura(sid, 1)
    end)
    row.del:SetScript("OnClick", function()
      AP:RemoveAura(sid)
    end)
    row:Show()
  end
  f.listContent:SetHeight(math.max(#list * 28, 10))
end

function AP:SyncSnapshot()
  local f = self._configFrame
  local snap = self._snapshot or self:RefreshSnapshot()
  local rows = f.snapRows
  for i = 1, #rows do
    rows[i]:Hide()
  end
  for i = 1, #snap do
    local a = snap[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Button", nil, f.snapContent)
      row:SetSize(180, 24)
      row.bg = row:CreateTexture(nil, "BACKGROUND")
      row.bg:SetAllPoints(row)
      row.bg:SetColorTexture(1, 1, 1, 0.05)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(18, 18)
      row.icon:SetPoint("LEFT", 3, 0)
      row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
      row.text:SetWidth(150)
      row.text:SetJustifyH("LEFT")
      rows[i] = row
    end
    row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
    row.icon:SetTexture(a.icon)
    row.text:SetText(string.format(
      "%s |cff888888#%d %s/%s|r",
      a.name,
      a.spellId,
      a.unit,
      a.harmful and "debuff" or "buff"
    ))
    local sid, unit, harmful = a.spellId, a.unit, a.harmful
    row:SetScript("OnClick", function()
      local ok, err = AP:AddAura(sid)
      if ok then
        local entry = AP:FindAura(sid)
        if entry then
          entry.unit = unit
          entry.filter = harmful and "HARMFUL" or "HELPFUL"
          AP:Refresh()
        end
      elseif err then
        print("|cffff9900Chukie UI|r panel de auras: " .. err)
      end
    end)
    row:Show()
  end
  f.snapContent:SetHeight(math.max(#snap * 26, 10))
end

function AP:SyncConfig()
  local f = self:EnsureConfig()
  local db = self:DB()
  f.enabledCheck:SetChecked(db.enabled == true)
  f.moveBtn:SetText(db.unlocked == true and "Fijar" or "Mover")

  local function setSlider(s, value, suffix)
    s._syncing = true
    s:SetValue(value)
    s._syncing = false
    s.labelText:SetText(s.labelBase .. ": " .. tostring(value) .. (suffix or ""))
  end
  setSlider(f.sizeSlider, self:Size(), " px")
  setSlider(f.spacingSlider, self:Spacing(), " px")
  setSlider(f.perLineSlider, self:PerLine(), "")

  f.growthBtn:SetText("Crece: " .. (GROWTH_LABELS[self:Growth()] or "Derecha"))
  f.unitBtn:SetText("Unidad: " .. (db.unit == "target" and "Target" or "Player"))
  f.filterBtn:SetText("Tipo: " .. (db.filter == "HARMFUL" and "Debuff" or "Buff"))

  self:SyncList()
  self:SyncSnapshot()

  local alerts = ns.Alerts
  local hasApi = alerts and alerts.HasAuraContainerAPI and alerts:HasAuraContainerAPI()
  local hidden = self._snapshotHidden or 0
  if not hasApi then
    if InCombatLockdown and InCombatLockdown() then
      f.help:SetText("|cffffcc66En combate no se pueden crear los slots|r: los que falten aparecen al salir de combate.")
    else
      f.help:SetText("|cffff6666Este cliente no expone AuraContainer|r: el panel no puede dibujar auras.")
    end
  elseif (self._rejected or 0) > 0 then
    f.help:SetText("|cffffcc66El cliente aceptó la API pero rechazó " .. self._rejected .. " slot(s)|r: revisá el id, o probá con la unidad y el tipo correctos (buff/debuff).")
  else
    local extra = hidden > 0 and (" " .. hidden .. " auras activas no se pueden listar (Blizzard las oculta), pero igual se dibujan si las agregás por id.") or ""
    f.help:SetText("Cada aura ocupa siempre su hueco: el juego decide cuándo se ve, así que el addon no puede compactar la fila." .. extra)
  end
end

function AP:ShowConfig()
  local f = self:EnsureConfig()
  self:RefreshSnapshot()
  self:SyncConfig()
  f:Show()
end

function AP:ToggleConfig()
  local f = self:EnsureConfig()
  if f:IsShown() then
    f:Hide()
  else
    self:ShowConfig()
  end
end

-- ---------------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------------

do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      -- El perfil puede no estar listo si otro módulo falla antes: no romper el login.
      pcall(AP.Refresh, AP)
      return
    end
    -- Fuera de combate ya se pueden crear los contenedores que quedaron pendientes.
    if AP._pending then
      AP:Refresh()
    end
  end)
end
