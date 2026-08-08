--[[ Gestor de alertas: lista apilable + wizard (+ tipo → buscar → opciones gráficas). ]]

local _, ns = ...

local M = {}
ns.AlertsManager = M

local MAX_RESULTS = 40
local ROW_H = 28
local COLOR_PRESETS = {
  { 1, 1, 1 },
  { 1, 0.2, 0.2 },
  { 1, 0.55, 0.1 },
  { 1, 0.9, 0.2 },
  { 0.3, 1, 0.3 },
  { 0.3, 0.7, 1 },
  { 0.7, 0.4, 1 },
  { 1, 0.4, 0.8 },
}
local ALPHA_STEPS = { 0.25, 0.5, 0.75, 1 }
local SIZE_STEPS_ICON = { 32, 40, 48, 64, 96, 128, 192 }
local SIZE_STEPS_GFX = { 32, 48, 64, 96, 128, 192, 288, 384, 576 }

local function alerts()
  return ns.Alerts
end

local function media()
  return ns.AlertsMedia
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
      local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
      if not aura then
        break
      end
      local sid = tonumber(aura.spellId)
      local n = aura.name
      if sid and sid > 0 and n and not seen[sid] then
        local nl = strlower(n)
        if qLower == "" or strfind(nl, qLower, 1, true) then
          seen[sid] = true
          out[#out + 1] = {
            spellId = sid,
            name = n .. "  [" .. unit .. "/" .. filter .. "]",
            nameLower = nl,
            icon = aura.icon or spellIcon(sid),
          }
        end
      end
    end
  end
  scan("player", "HELPFUL")
  scan("player", "HARMFUL")
  scan("target", "HELPFUL")
  scan("target", "HARMFUL")
end

local function colorEq(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  return math.abs((a[1] or 0) - (b[1] or 0)) < 0.02
    and math.abs((a[2] or 0) - (b[2] or 0)) < 0.02
    and math.abs((a[3] or 0) - (b[3] or 0)) < 0.02
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

function M:SearchSpells(query)
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

  -- Query vacía + tipo aura: listar auras activas (fácil encontrar Mass Disintegrate, etc.).
  if query == "" then
    if self._wiz and self._wiz.kind == "aura" then
      collectAuraSpellMatches("", out, seen, MAX_RESULTS)
    end
    return out
  end

  -- spellId puro o embebido (#436335 / id 436335)
  local idOnly = query:match("^#?(%d+)$") or query:match("(%d%d%d%d%d+)")
  if idOnly and query:match("^#?%d+$") then
    push(resolveSpellEntry(tonumber(idOnly)))
    return out
  end

  local q = strlower(query)

  -- Libro de hechizos
  local idx = self:GetSpellIndex()
  for i = 1, #idx do
    local e = idx[i]
    if strfind(e.nameLower, q, 1, true) then
      push(e)
    end
  end

  -- Auras activas player/target (talentos override / Not In Spellbook)
  collectAuraSpellMatches(q, out, seen, MAX_RESULTS)

  -- API por nombre exacto/parcial
  if #out == 0 and C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(query)
    if type(info) == "table" and info.spellID then
      push({
        spellId = info.spellID,
        name = info.name or query,
        icon = info.iconID,
      })
    elseif type(info) == "number" then
      push(resolveSpellEntry(info))
    end
  end

  -- Si pegaron un id junto a texto, ofrecerlo igual
  if idOnly then
    push(resolveSpellEntry(tonumber(idOnly)))
  end

  return out
end

local function makeButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 100, h or 22)
  b:SetText(text or "")
  return b
end

function M:Ensure()
  if self._frame then
    return self._frame
  end
  local f = CreateFrame("Frame", "ChukieUi_AlertsManager", UIParent, "BackdropTemplate")
  f:SetSize(560, 560)
  f:SetPoint("CENTER")
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
    if M._suppressHideRevert then
      return
    end
    if M._wizDirty then
      M:RevertLiveChanges()
    else
      M:EndLiveSession(false)
    end
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText("Chukie UI — Alertas")
  f.title = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  -- LIST VIEW
  local list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", 16, -40)
  list:SetPoint("BOTTOMRIGHT", -16, 16)
  f.list = list

  local hint = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hint:SetPoint("TOPLEFT", 0, 0)
  hint:SetPoint("TOPRIGHT", -160, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText("Reglas del perfil activo. Usá + para agregar CD, proc o aura.")
  list.hint = hint

  local modBtn = makeButton(list, "Módulo: Off", 100, 24)
  modBtn:SetPoint("TOPRIGHT", -44, 2)
  modBtn:SetScript("OnClick", function()
    if not alerts() then
      return
    end
    alerts():SetEnabled(not alerts():IsEnabled())
    M:RefreshList()
  end)
  modBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Si está Off, las alertas solo se ven en el editor (preview).", 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  modBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  list.modBtn = modBtn

  local addBtn = makeButton(list, "+", 36, 24)
  addBtn:SetPoint("TOPRIGHT", 0, 2)
  addBtn:SetScript("OnClick", function()
    M:StartWizard()
  end)
  list.addBtn = addBtn

  local scroll = CreateFrame("ScrollFrame", "ChukieUi_AlertsManagerScroll", list, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -28)
  scroll:SetPoint("BOTTOMRIGHT", -28, 0)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(480, 10)
  scroll:SetScrollChild(content)
  list.scroll = scroll
  list.content = content
  list.rows = {}

  -- WIZARD VIEW
  local wiz = CreateFrame("Frame", nil, f)
  wiz:SetPoint("TOPLEFT", 16, -40)
  wiz:SetPoint("BOTTOMRIGHT", -16, 16)
  wiz:Hide()
  f.wizard = wiz

  wiz.stepText = wiz:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  wiz.stepText:SetPoint("TOPLEFT", 0, 0)
  wiz.stepText:SetJustifyH("LEFT")

  -- Step A: type
  wiz.typePane = CreateFrame("Frame", nil, wiz)
  wiz.typePane:SetAllPoints()
  local cdBtn = makeButton(wiz.typePane, "Cooldown (CD)", 160, 28)
  cdBtn:SetPoint("TOPLEFT", 0, -36)
  cdBtn:SetScript("OnClick", function()
    M._wiz.kind = "cooldown"
    M:ShowWizardStep("search")
  end)
  local procBtn = makeButton(wiz.typePane, "Proc (buff)", 160, 28)
  procBtn:SetPoint("LEFT", cdBtn, "RIGHT", 12, 0)
  procBtn:SetScript("OnClick", function()
    M._wiz.kind = "proc"
    M:ShowWizardStep("search")
  end)
  local auraBtn = makeButton(wiz.typePane, "Aura (buff/debuff)", 160, 28)
  auraBtn:SetPoint("TOPLEFT", cdBtn, "BOTTOMLEFT", 0, -10)
  auraBtn:SetScript("OnClick", function()
    M._wiz.kind = "aura"
    M._wiz.auraUnit = M._wiz.auraUnit or "player"
    M._wiz.auraFilter = M._wiz.auraFilter or "both"
    M._wiz.auraShow = M._wiz.auraShow or "present"
    M:ShowWizardStep("search")
  end)
  local typeHint = wiz.typePane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  typeHint:SetPoint("TOPLEFT", auraBtn, "BOTTOMLEFT", 0, -12)
  typeHint:SetJustifyH("LEFT")
  typeHint:SetText("Proc = buff en jugador. Aura = player/target, buff/debuff, presente/ausente.")
  local backList = makeButton(wiz.typePane, "Cancelar", 90, 22)
  backList:SetPoint("BOTTOMLEFT", 0, 0)
  backList:SetScript("OnClick", function()
    M:ShowList()
  end)

  -- Step B: search
  wiz.searchPane = CreateFrame("Frame", nil, wiz)
  wiz.searchPane:SetAllPoints()
  wiz.searchPane:Hide()
  local searchLabel = wiz.searchPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  searchLabel:SetPoint("TOPLEFT", 0, -30)
  searchLabel:SetText("Buscar por nombre o spellId:")
  local searchHint = wiz.searchPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchHint:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -2)
  searchHint:SetJustifyH("LEFT")
  searchHint:SetTextColor(0.75, 0.75, 0.8)
  searchHint:SetText("Tip: talentos/auras fuera del libro → pegá el spellId (ej. 436335) o dejá vacío en tipo Aura.")
  wiz.searchHint = searchHint
  local edit = CreateFrame("EditBox", "ChukieUi_AlertsSearchBox", wiz.searchPane, "InputBoxTemplate")
  edit:SetSize(280, 24)
  edit:SetPoint("TOPLEFT", searchHint, "BOTTOMLEFT", 8, -6)
  edit:SetAutoFocus(false)
  edit:SetScript("OnTextChanged", function(self)
    if M._searchTimer then
      M._searchTimer:Cancel()
      M._searchTimer = nil
    end
    local text = self:GetText()
    M._searchTimer = C_Timer.NewTimer(0.15, function()
      M._searchTimer = nil
      M:RefreshSearchResults(text)
    end)
  end)
  edit:SetScript("OnEnterPressed", function(self)
    M:RefreshSearchResults(self:GetText())
  end)
  wiz.searchEdit = edit

  local resScroll = CreateFrame("ScrollFrame", "ChukieUi_AlertsSearchScroll", wiz.searchPane, "UIPanelScrollFrameTemplate")
  resScroll:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -8, -10)
  resScroll:SetPoint("BOTTOMRIGHT", 28, 36)
  local resContent = CreateFrame("Frame", nil, resScroll)
  resContent:SetSize(460, 10)
  resScroll:SetScrollChild(resContent)
  wiz.resScroll = resScroll
  wiz.resContent = resContent
  wiz.resRows = {}

  local backType = makeButton(wiz.searchPane, "Atrás", 90, 22)
  backType:SetPoint("BOTTOMLEFT", 0, 0)
  backType:SetScript("OnClick", function()
    M:ShowWizardStep("type")
  end)

  -- Step C: options
  wiz.optsPane = CreateFrame("Frame", nil, wiz)
  wiz.optsPane:SetAllPoints()
  wiz.optsPane:Hide()
  wiz.optsTitle = wiz.optsPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  wiz.optsTitle:SetPoint("TOPLEFT", 0, -28)
  wiz.optsTitle:SetJustifyH("LEFT")

  -- Preview
  wiz.preview = CreateFrame("Frame", nil, wiz.optsPane)
  wiz.preview:SetSize(64, 64)
  wiz.preview:SetPoint("TOPRIGHT", 0, -28)
  wiz.preview.tex = wiz.preview:CreateTexture(nil, "ARTWORK")
  wiz.preview.tex:SetAllPoints()
  wiz.preview.label = wiz.preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  wiz.preview.label:SetPoint("CENTER")
  wiz.preview.label:Hide()

  wiz.optDisplay = makeButton(wiz.optsPane, "Modo: Icono", 140, 22)
  wiz.optDisplay:SetPoint("TOPLEFT", 0, -54)
  wiz.optDisplay:SetScript("OnClick", function()
    local order = { "icon", "aura", "text" }
    M._wiz.display = nextInList(order, M._wiz.display or "icon")
    if M._wiz.display == "aura" and (not M._wiz.auraPath or M._wiz.auraPath == "") and media() and media().DefaultAuraPath then
      M._wiz.auraPath = media().DefaultAuraPath()
    end
    M:SyncOptsPane()
  end)

  wiz.optSound = CreateFrame("CheckButton", nil, wiz.optsPane, "UICheckButtonTemplate")
  wiz.optSound:SetPoint("LEFT", wiz.optDisplay, "RIGHT", 12, 0)
  wiz.optSound.text = wiz.optSound:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  wiz.optSound.text:SetPoint("LEFT", wiz.optSound, "RIGHT", 2, 0)
  wiz.optSound.text:SetText("Sonido")
  wiz.optSound:SetScript("OnClick", function()
    if M._wiz then
      M._wiz.sound = wiz.optSound:GetChecked() and true or false
      M:SyncOptsPane()
    end
  end)

  wiz.optCombat = CreateFrame("CheckButton", nil, wiz.optsPane, "UICheckButtonTemplate")
  wiz.optCombat:SetPoint("LEFT", wiz.optSound.text, "RIGHT", 12, 0)
  wiz.optCombat.text = wiz.optCombat:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  wiz.optCombat.text:SetPoint("LEFT", wiz.optCombat, "RIGHT", 2, 0)
  wiz.optCombat.text:SetText("Solo combate")
  wiz.optCombat:SetScript("OnClick", function()
    if M._wiz then
      M._wiz.combatOnly = wiz.optCombat:GetChecked() and true or false
      M:ApplyLive()
    end
  end)

  wiz.optTarget = CreateFrame("CheckButton", nil, wiz.optsPane, "UICheckButtonTemplate")
  wiz.optTarget:SetPoint("LEFT", wiz.optCombat.text, "RIGHT", 12, 0)
  wiz.optTarget.text = wiz.optTarget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  wiz.optTarget.text:SetPoint("LEFT", wiz.optTarget, "RIGHT", 2, 0)
  wiz.optTarget.text:SetText("Solo target")
  wiz.optTarget:SetScript("OnClick", function()
    if M._wiz then
      M._wiz.targetOnly = wiz.optTarget:GetChecked() and true or false
      M:ApplyLive()
    end
  end)

  wiz.soundPane = CreateFrame("Frame", nil, wiz.optsPane)
  wiz.soundPane:SetPoint("TOPLEFT", wiz.optDisplay, "BOTTOMLEFT", 0, -8)
  wiz.soundPane:SetSize(520, 24)
  wiz.optSoundPick = makeButton(wiz.soundPane, "Sonido: (default)", 200, 22)
  wiz.optSoundPick:SetPoint("LEFT", 0, 0)
  wiz.optSoundPick:SetScript("OnClick", function()
    if not M._wiz then
      return
    end
    local list = (media() and media().GetSoundPaths and media().GetSoundPaths()) or (media() and media().sounds) or {}
    local paths = { "" }
    for i = 1, #list do
      paths[#paths + 1] = list[i]
    end
    M._wiz.soundPath = nextInList(paths, M._wiz.soundPath or "")
    M:SyncOptsPane()
  end)
  wiz.optSoundTest = makeButton(wiz.soundPane, "Probar", 70, 22)
  wiz.optSoundTest:SetPoint("LEFT", wiz.optSoundPick, "RIGHT", 6, 0)
  wiz.optSoundTest:SetScript("OnClick", function()
    if alerts() and alerts().PlaySoundPreview then
      alerts():PlaySoundPreview(M._wiz and M._wiz.soundPath)
    end
  end)

  -- Common: size / color / alpha / position
  wiz.optSizeMinus = makeButton(wiz.optsPane, "Tam -", 48, 22)
  wiz.optSizeMinus:SetPoint("TOPLEFT", wiz.soundPane, "BOTTOMLEFT", 0, -8)
  wiz.optSizeMinus:SetScript("OnClick", function()
    local steps = (M._wiz.display == "icon") and SIZE_STEPS_ICON or SIZE_STEPS_GFX
    local cur = M._wiz.size or 48
    local prev = steps[1]
    for i = 1, #steps do
      if steps[i] >= cur then
        break
      end
      prev = steps[i]
    end
    for i = 1, #steps do
      if steps[i] == cur and i > 1 then
        prev = steps[i - 1]
        break
      end
    end
    M._wiz.size = prev
    M:SyncOptsPane()
  end)
  wiz.optSize = makeButton(wiz.optsPane, "Tamano: 48", 100, 22)
  wiz.optSize:SetPoint("LEFT", wiz.optSizeMinus, "RIGHT", 4, 0)
  wiz.optSize:SetScript("OnClick", function()
    local steps = (M._wiz.display == "icon") and SIZE_STEPS_ICON or SIZE_STEPS_GFX
    M._wiz.size = nextInList(steps, M._wiz.size or 48)
    M:SyncOptsPane()
  end)
  wiz.optSizePlus = makeButton(wiz.optsPane, "Tam +", 48, 22)
  wiz.optSizePlus:SetPoint("LEFT", wiz.optSize, "RIGHT", 4, 0)
  wiz.optSizePlus:SetScript("OnClick", function()
    local steps = (M._wiz.display == "icon") and SIZE_STEPS_ICON or SIZE_STEPS_GFX
    local cur = M._wiz.size or 48
    local nxt = steps[#steps]
    for i = 1, #steps do
      if steps[i] == cur then
        nxt = steps[math.min(#steps, i + 1)]
        break
      elseif steps[i] > cur then
        nxt = steps[i]
        break
      end
    end
    M._wiz.size = nxt
    M:SyncOptsPane()
  end)

  wiz.optColor = makeButton(wiz.optsPane, "Color", 70, 22)
  wiz.optColor:SetPoint("LEFT", wiz.optSizePlus, "RIGHT", 8, 0)
  wiz.optColor:SetScript("OnClick", function()
    M._wiz.color = nextInList(COLOR_PRESETS, M._wiz.color or { 1, 1, 1 }, colorEq)
    M:SyncOptsPane()
  end)
  wiz.colorSwatch = wiz.optsPane:CreateTexture(nil, "ARTWORK")
  wiz.colorSwatch:SetSize(18, 18)
  wiz.colorSwatch:SetPoint("LEFT", wiz.optColor, "RIGHT", 4, 0)
  wiz.colorSwatch:SetColorTexture(1, 1, 1, 1)

  wiz.optAlpha = makeButton(wiz.optsPane, "Alpha: 1", 80, 22)
  wiz.optAlpha:SetPoint("LEFT", wiz.colorSwatch, "RIGHT", 6, 0)
  wiz.optAlpha:SetScript("OnClick", function()
    M._wiz.alpha = nextInList(ALPHA_STEPS, tonumber(M._wiz.alpha) or 1)
    M:SyncOptsPane()
  end)

  wiz.optPos = makeButton(wiz.optsPane, "Pos: 0,120", 110, 22)
  wiz.optPos:SetPoint("TOPLEFT", wiz.optSizeMinus, "BOTTOMLEFT", 0, -8)
  wiz.optPos:SetScript("OnClick", function()
    local presets = {
      { "CENTER", 0, 120 },
      { "CENTER", 0, 0 },
      { "CENTER", -120, 80 },
      { "CENTER", 120, 80 },
      { "CENTER", 0, -100 },
    }
    local cur = M._wiz.point or { "CENTER", 0, 120 }
    local nextP = presets[1]
    for i = 1, #presets do
      if presets[i][2] == (cur[2] or 0) and presets[i][3] == (cur[3] or 0) then
        nextP = presets[(i % #presets) + 1]
        break
      end
    end
    M._wiz.point = { nextP[1], nextP[2], nextP[3] }
    M:SyncOptsPane()
  end)

  local nudge = function(dx, dy)
    local p = M._wiz.point or { "CENTER", 0, 120 }
    M._wiz.point = { p[1] or "CENTER", (tonumber(p[2]) or 0) + dx, (tonumber(p[3]) or 0) + dy }
    M:SyncOptsPane()
  end
  local function tip(btn, text)
    btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(text, 1, 1, 1)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end
  wiz.nudgeL = makeButton(wiz.optsPane, "<", 28, 22)
  wiz.nudgeL:SetPoint("LEFT", wiz.optPos, "RIGHT", 4, 0)
  wiz.nudgeL:SetScript("OnClick", function()
    nudge(-10, 0)
  end)
  tip(wiz.nudgeL, "Mover izquierda (-10)")
  wiz.nudgeR = makeButton(wiz.optsPane, ">", 28, 22)
  wiz.nudgeR:SetPoint("LEFT", wiz.nudgeL, "RIGHT", 2, 0)
  wiz.nudgeR:SetScript("OnClick", function()
    nudge(10, 0)
  end)
  tip(wiz.nudgeR, "Mover derecha (+10)")
  wiz.nudgeU = makeButton(wiz.optsPane, "^", 28, 22)
  wiz.nudgeU:SetPoint("LEFT", wiz.nudgeR, "RIGHT", 2, 0)
  wiz.nudgeU:SetScript("OnClick", function()
    nudge(0, 10)
  end)
  tip(wiz.nudgeU, "Mover arriba (+10)")
  wiz.nudgeD = makeButton(wiz.optsPane, "v", 28, 22)
  wiz.nudgeD:SetPoint("LEFT", wiz.nudgeU, "RIGHT", 2, 0)
  wiz.nudgeD:SetScript("OnClick", function()
    nudge(0, -10)
  end)
  tip(wiz.nudgeD, "Mover abajo (-10)")
  wiz.nudgeHint = wiz.optsPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  wiz.nudgeHint:SetPoint("LEFT", wiz.nudgeD, "RIGHT", 8, 0)
  wiz.nudgeHint:SetText("< > ^ v = posicion")

  -- showOn for CD in all display modes
  wiz.optShowOnCommon = makeButton(wiz.optsPane, "Mostrar: Disponible", 170, 22)
  wiz.optShowOnCommon:SetPoint("TOPLEFT", wiz.optPos, "BOTTOMLEFT", 0, -8)
  wiz.optShowOnCommon:SetScript("OnClick", function()
    local order = { "available", "ready", "cooldown", "always" }
    M._wiz.showOn = nextInList(order, M._wiz.showOn or "available")
    M:SyncOptsPane()
  end)

  -- Opciones kind == "aura" (unidad / filtro / presente|ausente)
  wiz.auraKindPane = CreateFrame("Frame", nil, wiz.optsPane)
  wiz.auraKindPane:SetPoint("TOPLEFT", wiz.optPos, "BOTTOMLEFT", 0, -8)
  wiz.auraKindPane:SetSize(520, 28)
  wiz.optAuraUnit = makeButton(wiz.auraKindPane, "Unidad: Player", 120, 22)
  wiz.optAuraUnit:SetPoint("LEFT", 0, 0)
  wiz.optAuraUnit:SetScript("OnClick", function()
    if not M._wiz then
      return
    end
    M._wiz.auraUnit = nextInList({ "player", "target" }, M._wiz.auraUnit or "player")
    M:SyncOptsPane()
  end)
  tip(wiz.optAuraUnit, "Player o Target: dónde buscar el buff/debuff.")
  wiz.optAuraFilter = makeButton(wiz.auraKindPane, "Tipo: Ambos", 110, 22)
  wiz.optAuraFilter:SetPoint("LEFT", wiz.optAuraUnit, "RIGHT", 6, 0)
  wiz.optAuraFilter:SetScript("OnClick", function()
    if not M._wiz then
      return
    end
    M._wiz.auraFilter = nextInList({ "both", "HELPFUL", "HARMFUL" }, M._wiz.auraFilter or "both")
    M:SyncOptsPane()
  end)
  tip(wiz.optAuraFilter, "Buff (HELPFUL), Debuff (HARMFUL) o ambos.")
  wiz.optAuraShow = makeButton(wiz.auraKindPane, "Cuando: Presente", 130, 22)
  wiz.optAuraShow:SetPoint("LEFT", wiz.optAuraFilter, "RIGHT", 6, 0)
  wiz.optAuraShow:SetScript("OnClick", function()
    if not M._wiz then
      return
    end
    M._wiz.auraShow = nextInList({ "present", "absent", "always" }, M._wiz.auraShow or "present")
    M:SyncOptsPane()
  end)
  tip(wiz.optAuraShow, "Presente / Ausente / Siempre.")

  wiz.auraBackendHint = wiz.optsPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  wiz.auraBackendHint:SetPoint("TOPLEFT", wiz.auraKindPane, "BOTTOMLEFT", 0, -2)
  wiz.auraBackendHint:SetPoint("TOPRIGHT", wiz.optsPane, "TOPRIGHT", -8, 0)
  wiz.auraBackendHint:SetJustifyH("LEFT")
  wiz.auraBackendHint:SetText("")

  -- Filtro cargas (habilidad) / stacks (aura)
  wiz.chargePane = CreateFrame("Frame", nil, wiz.optsPane)
  wiz.chargePane:SetPoint("TOPLEFT", wiz.optShowOnCommon, "BOTTOMLEFT", 0, -8)
  wiz.chargePane:SetSize(520, 28)
  wiz.optCharge = CreateFrame("CheckButton", nil, wiz.chargePane, "UICheckButtonTemplate")
  wiz.optCharge:SetPoint("LEFT", 0, 0)
  wiz.optCharge.text = wiz.optCharge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  wiz.optCharge.text:SetPoint("LEFT", wiz.optCharge, "RIGHT", 2, 0)
  wiz.optCharge.text:SetText("Filtro cargas/stacks")
  wiz.optCharge:SetScript("OnClick", function()
    if not M._wiz then
      return
    end
    M._wiz.chargeFilter = M._wiz.chargeFilter or { enabled = false, op = "gte", value = 1 }
    M._wiz.chargeFilter.enabled = wiz.optCharge:GetChecked() and true or false
    M:ApplyLive()
  end)
  tip(wiz.optCharge, "CD: cargas del hechizo. Proc/Aura: stacks del buff/debuff. Operador + valor.")
  local CHARGE_OPS = { "gte", "gt", "eq", "lte", "lt", "ne" }
  local CHARGE_OP_LABELS = {
    eq = "==",
    ne = "!=",
    gt = ">",
    gte = ">=",
    lt = "<",
    lte = "<=",
  }
  wiz.optChargeOp = makeButton(wiz.chargePane, "Op: >=", 70, 22)
  wiz.optChargeOp:SetPoint("LEFT", wiz.optCharge.text, "RIGHT", 10, 0)
  wiz.optChargeOp:SetScript("OnClick", function()
    if not M._wiz then
      return
    end
    M._wiz.chargeFilter = M._wiz.chargeFilter or { enabled = false, op = "gte", value = 1 }
    M._wiz.chargeFilter.op = nextInList(CHARGE_OPS, M._wiz.chargeFilter.op or "gte")
    M:SyncOptsPane()
  end)
  wiz.optChargeVal = makeButton(wiz.chargePane, "Valor: 1", 80, 22)
  wiz.optChargeVal:SetPoint("LEFT", wiz.optChargeOp, "RIGHT", 4, 0)
  wiz.optChargeVal:SetScript("OnClick", function()
    if not M._wiz then
      return
    end
    M._wiz.chargeFilter = M._wiz.chargeFilter or { enabled = false, op = "gte", value = 1 }
    local vals = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    M._wiz.chargeFilter.value = nextInList(vals, tonumber(M._wiz.chargeFilter.value) or 1)
    M:SyncOptsPane()
  end)
  wiz.chargeHint = wiz.chargePane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  wiz.chargeHint:SetPoint("LEFT", wiz.optChargeVal, "RIGHT", 8, 0)
  wiz.chargeHint:SetText("ej. >= 2 cargas")

  -- Overlay FX (proc dorado de barra)
  wiz.fxPane = CreateFrame("Frame", nil, wiz.optsPane)
  wiz.fxPane:SetPoint("TOPLEFT", wiz.chargePane, "BOTTOMLEFT", 0, -8)
  wiz.fxPane:SetSize(520, 52)
  wiz.fxTitle = wiz.fxPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  wiz.fxTitle:SetPoint("TOPLEFT", 0, 0)
  wiz.fxTitle:SetText("Al proc (barra dorada):")
  wiz.fxHint = wiz.fxPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  wiz.fxHint:SetPoint("LEFT", wiz.fxTitle, "RIGHT", 8, 0)
  wiz.fxHint:SetText("Cuando la barra resalta el hechizo en dorado.")
  local function makeFxCheck(label, key, after)
    local cb = CreateFrame("CheckButton", nil, wiz.fxPane, "UICheckButtonTemplate")
    if after then
      cb:SetPoint("LEFT", after, "RIGHT", 10, 0)
    else
      cb:SetPoint("TOPLEFT", wiz.fxTitle, "BOTTOMLEFT", 0, -2)
    end
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetText(label)
    cb:SetScript("OnClick", function()
      if not M._wiz then
        return
      end
      M._wiz.overlayFx = M._wiz.overlayFx or { pulse = false, color = false, shake = false, glow = false }
      M._wiz.overlayFx[key] = cb:GetChecked() and true or false
      M:ApplyLive()
    end)
    return cb
  end
  wiz.fxPulse = makeFxCheck("Latir", "pulse", nil)
  wiz.fxColor = makeFxCheck("Color", "color", wiz.fxPulse.text)
  wiz.fxShake = makeFxCheck("Vibrar", "shake", wiz.fxColor.text)
  wiz.fxGlow = makeFxCheck("Glow", "glow", wiz.fxShake.text)
  wiz.fxTest = makeButton(wiz.fxPane, "Probar FX", 90, 22)
  wiz.fxTest:SetPoint("LEFT", wiz.fxGlow.text, "RIGHT", 12, 0)
  wiz.fxTest:SetScript("OnClick", function()
    if not M._wiz or not M._wiz.editId or not alerts() or not alerts().SimulateOverlay then
      return
    end
    M:ApplyLive()
    alerts():SimulateOverlay(M._wiz.editId, 2)
  end)

  -- Icon-only controls
  wiz.iconPane = CreateFrame("Frame", nil, wiz.optsPane)
  wiz.iconPane:SetPoint("TOPLEFT", wiz.fxPane, "BOTTOMLEFT", 0, -10)
  wiz.iconPane:SetSize(500, 80)
  wiz.optGlow = makeButton(wiz.iconPane, "Glow: Proc", 130, 22)
  wiz.optGlow:SetPoint("TOPLEFT", 0, 0)
  wiz.optGlow:SetScript("OnClick", function()
    local glows = { "Proc", "Pixel", "buttonOverlay", "none" }
    M._wiz.glowType = nextInList(glows, M._wiz.glowType or "Proc")
    M:SyncOptsPane()
  end)
  wiz.optSwipe = CreateFrame("CheckButton", nil, wiz.iconPane, "UICheckButtonTemplate")
  wiz.optSwipe:SetPoint("LEFT", wiz.optGlow, "RIGHT", 8, 0)
  wiz.optSwipe.text = wiz.optSwipe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  wiz.optSwipe.text:SetPoint("LEFT", wiz.optSwipe, "RIGHT", 2, 0)
  wiz.optSwipe.text:SetText("Swipe de cooldown")
  wiz.optSwipe:SetScript("OnClick", function()
    if M._wiz then
      M._wiz.swipe = wiz.optSwipe:GetChecked() and true or false
      M:ApplyLive()
    end
  end)

  -- Aura controls
  wiz.auraPane = CreateFrame("Frame", nil, wiz.optsPane)
  wiz.auraPane:SetPoint("TOPLEFT", wiz.fxPane, "BOTTOMLEFT", 0, -10)
  wiz.auraPane:SetSize(500, 120)
  wiz.auraPane:Hide()
  wiz.optLayout = makeButton(wiz.auraPane, "Layout: Single", 130, 22)
  wiz.optLayout:SetPoint("TOPLEFT", 0, 0)
  wiz.optLayout:SetScript("OnClick", function()
    M._wiz.auraLayout = (M._wiz.auraLayout == "pair") and "single" or "pair"
    M:SyncOptsPane()
  end)
  wiz.optGap = makeButton(wiz.auraPane, "Gap: 80", 90, 22)
  wiz.optGap:SetPoint("LEFT", wiz.optLayout, "RIGHT", 8, 0)
  wiz.optGap:SetScript("OnClick", function()
    local gaps = { 40, 60, 80, 100, 140, 200 }
    M._wiz.pairGap = nextInList(gaps, tonumber(M._wiz.pairGap) or 80)
    M:SyncOptsPane()
  end)
  wiz.optPickAura = makeButton(wiz.auraPane, "Elegir arte…", 120, 22)
  wiz.optPickAura:SetPoint("LEFT", wiz.optGap, "RIGHT", 8, 0)
  wiz.optPickAura:SetScript("OnClick", function()
    M:ShowAuraPicker()
  end)
  wiz.auraName = wiz.auraPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  wiz.auraName:SetPoint("TOPLEFT", wiz.optLayout, "BOTTOMLEFT", 0, -8)
  wiz.auraName:SetJustifyH("LEFT")
  wiz.auraName:SetWidth(480)

  -- Text controls
  wiz.textPane = CreateFrame("Frame", nil, wiz.optsPane)
  wiz.textPane:SetPoint("TOPLEFT", wiz.fxPane, "BOTTOMLEFT", 0, -10)
  wiz.textPane:SetSize(500, 80)
  wiz.textPane:Hide()
  local textLbl = wiz.textPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  textLbl:SetPoint("TOPLEFT", 0, 0)
  textLbl:SetText("Texto (vacío = nombre del hechizo):")
  wiz.textEdit = CreateFrame("EditBox", "ChukieUi_AlertsTextBox", wiz.textPane, "InputBoxTemplate")
  wiz.textEdit:SetSize(320, 24)
  wiz.textEdit:SetPoint("TOPLEFT", textLbl, "BOTTOMLEFT", 8, -6)
  wiz.textEdit:SetAutoFocus(false)
  wiz.textEdit:SetScript("OnTextChanged", function(self)
    if M._wiz then
      M._wiz.text = self:GetText() or ""
      M:UpdatePreview()
      M:ApplyLive()
    end
  end)
  wiz.optFont = makeButton(wiz.textPane, "Fuente: default", 140, 22)
  wiz.optFont:SetPoint("LEFT", wiz.textEdit, "RIGHT", 8, 0)
  wiz.optFont:SetScript("OnClick", function()
    local fonts = { "" }
    local list = (media() and media().GetFontPaths and media().GetFontPaths()) or (media() and media().fonts) or {}
    for i = 1, #list do
      fonts[#fonts + 1] = list[i]
    end
    M._wiz.fontPath = nextInList(fonts, M._wiz.fontPath or "")
    M:SyncOptsPane()
  end)

  -- Aura picker overlay
  wiz.pickerPane = CreateFrame("Frame", nil, wiz.optsPane, "BackdropTemplate")
  wiz.pickerPane:SetPoint("TOPLEFT", 0, -50)
  wiz.pickerPane:SetPoint("BOTTOMRIGHT", 0, 36)
  wiz.pickerPane:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  wiz.pickerPane:Hide()
  wiz.pickerPane:SetFrameLevel(wiz.optsPane:GetFrameLevel() + 10)
  local pickTitle = wiz.pickerPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  pickTitle:SetPoint("TOP", 0, -8)
  pickTitle:SetText("Elegir arte (local + User + SharedMedia)")
  local pickClose = makeButton(wiz.pickerPane, "Cerrar", 80, 22)
  pickClose:SetPoint("TOPRIGHT", -8, -6)
  pickClose:SetScript("OnClick", function()
    wiz.pickerPane:Hide()
  end)
  local pickScroll = CreateFrame("ScrollFrame", "ChukieUi_AlertsAuraPickScroll", wiz.pickerPane, "UIPanelScrollFrameTemplate")
  pickScroll:SetPoint("TOPLEFT", 10, -32)
  pickScroll:SetPoint("BOTTOMRIGHT", -28, 10)
  local pickContent = CreateFrame("Frame", nil, pickScroll)
  pickContent:SetSize(480, 10)
  pickScroll:SetScrollChild(pickContent)
  wiz.pickScroll = pickScroll
  wiz.pickContent = pickContent
  wiz.pickCells = {}

  local saveBtn = makeButton(wiz.optsPane, "Guardar", 100, 24)
  saveBtn:SetPoint("BOTTOMRIGHT", 0, 0)
  saveBtn:SetScript("OnClick", function()
    M:CommitWizard()
  end)
  local cancelBtn = makeButton(wiz.optsPane, "Cancelar", 90, 22)
  cancelBtn:SetPoint("BOTTOMLEFT", 0, 0)
  cancelBtn:SetScript("OnClick", function()
    wiz.pickerPane:Hide()
    M:CancelWizard()
  end)
  wiz.saveBtn = saveBtn
  wiz.cancelBtn = cancelBtn

  self._frame = f
  return f
end

function M:ShowList()
  local f = self:Ensure()
  f.wizard:Hide()
  f.list:Show()
  f.title:SetText("Chukie UI — Alertas")
  self:RefreshList()
end

function M:snapshotRule(rule)
  if type(rule) ~= "table" then
    return nil
  end
  local s = {}
  for k, v in pairs(rule) do
    if k == "point" and type(v) == "table" then
      s.point = { v[1], v[2], v[3] }
    elseif k == "color" and type(v) == "table" then
      s.color = { v[1], v[2], v[3] }
    elseif k == "overlayFx" and type(v) == "table" then
      s.overlayFx = {
        pulse = v.pulse == true,
        color = v.color == true,
        shake = v.shake == true,
        glow = v.glow == true,
      }
    elseif k == "chargeFilter" and type(v) == "table" then
      s.chargeFilter = {
        enabled = v.enabled == true,
        op = v.op or "gte",
        value = math.floor(tonumber(v.value) or 1),
      }
    elseif type(v) ~= "table" then
      s[k] = v
    end
  end
  return s
end

function M:BuildPayloadFromWiz()
  local w = self._wiz
  local wiz = self:Ensure().wizard
  if not w then
    return nil
  end
  return {
    kind = w.kind,
    spellId = w.spellId,
    enabled = true,
    showOn = w.showOn or "available",
    size = w.size or 48,
    swipe = wiz.optSwipe:GetChecked() and true or false,
    glowType = w.glowType or "Proc",
    sound = wiz.optSound:GetChecked() and true or false,
    soundPath = w.soundPath or "",
    combatOnly = wiz.optCombat:GetChecked() and true or false,
    targetOnly = wiz.optTarget:GetChecked() and true or false,
    display = w.display or "icon",
    color = w.color or { 1, 1, 1 },
    alpha = tonumber(w.alpha) or 1,
    auraPath = w.auraPath or "",
    auraLayout = w.auraLayout or "single",
    pairGap = tonumber(w.pairGap) or 80,
    text = wiz.textEdit and wiz.textEdit:GetText() or (w.text or ""),
    fontPath = w.fontPath or "",
    point = w.point or { "CENTER", 0, 120 },
    overlayFx = {
      pulse = wiz.fxPulse:GetChecked() and true or false,
      color = wiz.fxColor:GetChecked() and true or false,
      shake = wiz.fxShake:GetChecked() and true or false,
      glow = wiz.fxGlow:GetChecked() and true or false,
    },
    chargeFilter = {
      enabled = wiz.optCharge:GetChecked() and true or false,
      op = (w.chargeFilter and w.chargeFilter.op) or "gte",
      value = math.floor(tonumber(w.chargeFilter and w.chargeFilter.value) or 1),
    },
    auraUnit = w.auraUnit or "player",
    auraFilter = w.auraFilter or "both",
    auraShow = w.auraShow or "present",
  }
end

function M:ApplyLive()
  if not self._liveEditing or not self._wiz or not self._wiz.spellId or self._wiz.spellId <= 0 then
    return
  end
  local payload = self:BuildPayloadFromWiz()
  if not payload then
    return
  end
  if not self._wiz.editId then
    local rule, err = alerts():AddRule(payload)
    if not rule then
      if err then
        print("|cffff9900Chukie UI|r: " .. tostring(err))
      end
      return
    end
    self._wiz.editId = rule.id
    self._wiz.isDraft = true
  else
    alerts():UpdateRule(self._wiz.editId, payload)
  end
  alerts():SetLivePreview(self._wiz.editId, true)
  self._wizDirty = true
end

function M:EndLiveSession()
  if alerts() and alerts().ClearLivePreview then
    alerts():ClearLivePreview()
  end
  if alerts() and alerts().Refresh then
    alerts():Refresh()
  end
  self._liveEditing = false
end

function M:RevertLiveChanges()
  local w = self._wiz
  if w and w.editId and alerts() then
    if w.isDraft then
      alerts():DeleteRule(w.editId)
    elseif w.baseline then
      alerts():UpdateRule(w.editId, w.baseline)
    end
  end
  self._wizDirty = false
  self._wiz = nil
  self:EndLiveSession()
end

function M:CancelWizard()
  self:RevertLiveChanges()
  self:ShowList()
end
function M:RefreshList()
  local f = self:Ensure()
  local content = f.list.content
  local rows = f.list.rows
  for i = 1, #rows do
    rows[i]:Hide()
  end
  local modOn = alerts() and alerts():IsEnabled()
  if f.list.modBtn then
    f.list.modBtn:SetText(modOn and "Módulo: On" or "Módulo: Off")
  end
  if f.list.hint then
    if modOn then
      f.list.hint:SetText("Reglas del perfil activo. Usá + para agregar CD, proc o aura.")
    else
      f.list.hint:SetText("|cffff6666Módulo Off:|r las alertas no se muestran en combate. Activá «Módulo: On».")
    end
  end
  local rules = alerts() and alerts():GetRules() or {}
  local y = 0
  local dispLabel = { icon = "Icono", aura = "Aura", text = "Texto" }
  for i = 1, #rules do
    local rule = rules[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Button", nil, content, "BackdropTemplate")
      row:SetSize(470, ROW_H)
      row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
      })
      row:SetBackdropColor(0.1, 0.1, 0.12, 0.8)
      row:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.9)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(22, 22)
      row.icon:SetPoint("LEFT", 4, 0)
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.label:SetPoint("RIGHT", row, "RIGHT", -150, 0)
      row.label:SetJustifyH("LEFT")
      row.toggle = makeButton(row, "On", 40, 20)
      row.toggle:SetPoint("RIGHT", -96, 0)
      row.edit = makeButton(row, "Editar", 50, 20)
      row.edit:SetPoint("RIGHT", -44, 0)
      row.del = makeButton(row, "X", 28, 20)
      row.del:SetPoint("RIGHT", -4, 0)
      rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:Show()
    if rule.display == "aura" and rule.auraPath and rule.auraPath ~= "" then
      row.icon:SetTexture(rule.auraPath)
    else
      row.icon:SetTexture(spellIcon(rule.spellId) or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    local kindLabel = "CD"
    if rule.kind == "proc" then
      kindLabel = "Proc"
    elseif rule.kind == "aura" then
      kindLabel = "Aura"
    end
    local d = dispLabel[rule.display or "icon"] or "Icono"
    row.label:SetText(string.format("[%s·%s] %s (#%d)", kindLabel, d, spellName(rule.spellId), rule.spellId))
    row.toggle:SetText(rule.enabled ~= false and "On" or "Off")
    local id = rule.id
    row.toggle:SetScript("OnClick", function()
      local r = alerts():GetRuleById(id)
      if r then
        alerts():UpdateRule(id, { enabled = not (r.enabled ~= false) })
        M:RefreshList()
      end
    end)
    row.edit:SetScript("OnClick", function()
      M:EditRule(id)
    end)
    row.del:SetScript("OnClick", function()
      alerts():DeleteRule(id)
      M:RefreshList()
    end)
    y = y + ROW_H + 4
  end
  content:SetHeight(math.max(10, y))
end

function M:StartWizard(existing)
  if self._wizDirty then
    self:CancelWizard()
  end
  local point = existing and existing.point
  self._wiz = {
    editId = existing and existing.id or nil,
    isDraft = false,
    baseline = existing and self:snapshotRule(existing) or nil,
    kind = existing and existing.kind or "cooldown",
    spellId = existing and existing.spellId or 0,
    showOn = existing and existing.showOn or "available",
    size = existing and existing.size or 48,
    swipe = existing and existing.swipe ~= false,
    glowType = existing and existing.glowType or "Proc",
    sound = existing and existing.sound ~= false,
    soundPath = existing and existing.soundPath or "",
    combatOnly = existing and existing.combatOnly == true,
    targetOnly = existing and existing.targetOnly == true,
    display = existing and existing.display or "icon",
    color = existing and existing.color and { existing.color[1], existing.color[2], existing.color[3] } or { 1, 1, 1 },
    alpha = existing and existing.alpha or 1,
    auraPath = existing and existing.auraPath or "",
    auraLayout = existing and existing.auraLayout or "single",
    pairGap = existing and existing.pairGap or 80,
    text = existing and existing.text or "",
    fontPath = existing and existing.fontPath or "",
    point = point and { point[1], point[2], point[3] } or { "CENTER", 0, 120 },
    overlayFx = {
      pulse = existing and existing.overlayFx and existing.overlayFx.pulse == true,
      color = existing and existing.overlayFx and existing.overlayFx.color == true,
      shake = existing and existing.overlayFx and existing.overlayFx.shake == true,
      glow = existing and existing.overlayFx and existing.overlayFx.glow == true,
    },
    chargeFilter = {
      enabled = existing and existing.chargeFilter and existing.chargeFilter.enabled == true,
      op = existing and existing.chargeFilter and existing.chargeFilter.op or "gte",
      value = existing and existing.chargeFilter and tonumber(existing.chargeFilter.value) or 1,
    },
    auraUnit = existing and existing.auraUnit or "player",
    auraFilter = existing and existing.auraFilter or "both",
    auraShow = existing and existing.auraShow or "present",
  }
  self._wizDirty = false
  self._liveEditing = false
  local f = self:Ensure()
  f.list:Hide()
  f.wizard:Show()
  f.wizard.pickerPane:Hide()
  if existing and existing.spellId and existing.spellId > 0 then
    self:ShowWizardStep("opts")
  else
    self:ShowWizardStep("type")
  end
end

function M:EditRule(id)
  local rule = alerts():GetRuleById(id)
  if not rule then
    return
  end
  self:StartWizard(rule)
end

function M:ShowWizardStep(step)
  local f = self:Ensure()
  local wiz = f.wizard
  wiz.typePane:Hide()
  wiz.searchPane:Hide()
  wiz.optsPane:Hide()
  wiz.pickerPane:Hide()
  local kind = (self._wiz and self._wiz.kind) or "cooldown"
  if step == "type" then
    self._liveEditing = false
    wiz.stepText:SetText("Paso 1/3 — Elegi el tipo de alerta")
    wiz.typePane:Show()
    f.title:SetText("Nueva alerta")
  elseif step == "search" then
    self._liveEditing = false
    wiz.stepText:SetText(
      "Paso 2/3 — Busca el hechizo ("
        .. (kind == "proc" and "proc" or (kind == "aura" and "aura" or "CD"))
        .. ")"
    )
    wiz.searchPane:Show()
    wiz.searchEdit:SetText("")
    if wiz.searchHint then
      if kind == "aura" then
        wiz.searchHint:SetText("Vacío = auras activas (player/target). O pegá spellId (Mass Disintegrate ≈ 436335).")
      else
        wiz.searchHint:SetText("Tip: talentos/auras fuera del libro → pegá el spellId (ej. 436335).")
      end
    end
    self:RefreshSearchResults("")
    wiz.searchEdit:SetFocus()
    f.title:SetText("Buscar hechizo")
  else
    wiz.stepText:SetText("Paso 3/3 — Opciones (cambios en vivo; Guardar / Cancelar)")
    wiz.optsPane:Show()
    self._liveEditing = true
    self:SyncOptsPane()
    f.title:SetText("Opciones")
  end
end

function M:RefreshSearchResults(query)
  local wiz = self:Ensure().wizard
  local results = self:SearchSpells(query)
  local content = wiz.resContent
  local rows = wiz.resRows
  for i = 1, #rows do
    rows[i]:Hide()
  end
  local y = 0
  for i = 1, #results do
    local e = results[i]
    local row = rows[i]
    if not row then
      row = CreateFrame("Button", nil, content, "BackdropTemplate")
      row:SetSize(430, 26)
      row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
      row:SetBackdropColor(0.15, 0.15, 0.18, 0.9)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(20, 20)
      row.icon:SetPoint("LEFT", 4, 0)
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.label:SetJustifyH("LEFT")
      row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:Show()
    row.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.label:SetText(string.format("%s  (#%d)", e.name, e.spellId))
    local sid = e.spellId
    row:SetScript("OnClick", function()
      M._wiz.spellId = sid
      M:ShowWizardStep("opts")
    end)
    y = y + 28
  end
  content:SetHeight(math.max(10, y))
end

function M:UpdatePreview()
  local w = self._wiz
  local wiz = self:Ensure().wizard
  if not w then
    return
  end
  local c = w.color or { 1, 1, 1 }
  local a = tonumber(w.alpha) or 1
  wiz.preview.label:Hide()
  wiz.preview.tex:Show()
  if w.display == "aura" then
    local path = w.auraPath
    if (not path or path == "") and media() and media().DefaultAuraPath then
      path = media().DefaultAuraPath()
    end
    wiz.preview.tex:SetTexture(path or "Interface\\Icons\\INV_Misc_QuestionMark")
    wiz.preview.tex:SetVertexColor(c[1], c[2], c[3])
    wiz.preview.tex:SetAlpha(a)
  elseif w.display == "text" then
    wiz.preview.tex:Hide()
    wiz.preview.label:Show()
    local msg = w.text
    if not msg or strtrim(msg) == "" then
      msg = spellName(w.spellId)
    end
    wiz.preview.label:SetText(msg)
    wiz.preview.label:SetTextColor(c[1], c[2], c[3], a)
  else
    wiz.preview.tex:SetTexture(spellIcon(w.spellId) or "Interface\\Icons\\INV_Misc_QuestionMark")
    wiz.preview.tex:SetVertexColor(c[1], c[2], c[3])
    wiz.preview.tex:SetAlpha(a)
  end
end

function M:SyncOptsPane()
  local w = self._wiz
  if not w then
    return
  end
  local wiz = self:Ensure().wizard
  local kindTitle = "CD"
  if w.kind == "proc" then
    kindTitle = "Proc"
  elseif w.kind == "aura" then
    kindTitle = "Aura"
  end
  local name = spellName(w.spellId)
  wiz.optsTitle:SetText(string.format("%s — %s (#%d)", kindTitle, name, w.spellId or 0))

  local dispLabels = { icon = "Icono", aura = "Aura", text = "Texto" }
  wiz.optDisplay:SetText("Modo: " .. (dispLabels[w.display or "icon"] or "Icono"))
  wiz.optSound:SetChecked(w.sound ~= false)
  local soundOn = w.sound ~= false
  wiz.soundPane:SetShown(soundOn)
  if soundOn then
    wiz.optSizeMinus:SetPoint("TOPLEFT", wiz.soundPane, "BOTTOMLEFT", 0, -8)
    local sp = w.soundPath or ""
    local label = (sp ~= "" and (sp:match("([^\\]+)$") or sp)) or "(default)"
    wiz.optSoundPick:SetText("Sonido: " .. label)
  else
    wiz.optSizeMinus:SetPoint("TOPLEFT", wiz.optDisplay, "BOTTOMLEFT", 0, -8)
  end
  wiz.optCombat:SetChecked(w.combatOnly == true)
  wiz.optTarget:SetChecked(w.targetOnly == true)
  local fx = w.overlayFx or {}
  wiz.fxPulse:SetChecked(fx.pulse == true)
  wiz.fxColor:SetChecked(fx.color == true)
  wiz.fxShake:SetChecked(fx.shake == true)
  wiz.fxGlow:SetChecked(fx.glow == true)
  local cf = w.chargeFilter or {}
  wiz.optCharge:SetChecked(cf.enabled == true)
  local opLabels = { eq = "==", ne = "!=", gt = ">", gte = ">=", lt = "<", lte = "<=" }
  wiz.optChargeOp:SetText("Op: " .. (opLabels[cf.op or "gte"] or ">="))
  wiz.optChargeVal:SetText("Valor: " .. tostring(math.floor(tonumber(cf.value) or 1)))
  local chargeKind = "cargas hechizo"
  if w.kind == "proc" then
    chargeKind = "stacks aura"
  elseif w.kind == "aura" then
    chargeKind = "stacks (unidad)"
  end
  wiz.chargeHint:SetText("ej. >= 2 (" .. chargeKind .. ")")
  wiz.optSize:SetText("Tamano: " .. tostring(w.size or 48))
  local c = w.color or { 1, 1, 1 }
  wiz.colorSwatch:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
  wiz.optAlpha:SetText("Alpha: " .. tostring(w.alpha or 1))
  local p = w.point or { "CENTER", 0, 120 }
  wiz.optPos:SetText(string.format("Pos: %d,%d", tonumber(p[2]) or 0, tonumber(p[3]) or 0))

  local d = w.display or "icon"
  wiz.iconPane:SetShown(d == "icon")
  wiz.auraPane:SetShown(d == "aura")
  wiz.textPane:SetShown(d == "text")

  local isCd = w.kind == "cooldown"
  local isAura = w.kind == "aura"
  local labels = {
    available = "Disponible",
    ready = "Ready (solo CD)",
    cooldown = "En CD",
    always = "Siempre",
  }
  wiz.optShowOnCommon:SetText("Mostrar: " .. (labels[w.showOn or "available"] or "Disponible"))
  wiz.optShowOnCommon:SetShown(isCd)
  wiz.auraKindPane:SetShown(isAura)
  if isAura then
    local unitL = (w.auraUnit == "target") and "Target" or "Player"
    wiz.optAuraUnit:SetText("Unidad: " .. unitL)
    local filtL = ({ both = "Ambos", HELPFUL = "Buff", HARMFUL = "Debuff" })[w.auraFilter or "both"] or "Ambos"
    wiz.optAuraFilter:SetText("Tipo: " .. filtL)
    local showL = ({ present = "Presente", absent = "Ausente", always = "Siempre" })[w.auraShow or "present"] or "Presente"
    wiz.optAuraShow:SetText("Cuando: " .. showL)
    if wiz.auraBackendHint then
      wiz.auraBackendHint:Show()
      local hasAPI = alerts() and alerts().HasAuraContainerAPI and alerts():HasAuraContainerAPI()
      local mode = w.auraShow or "present"
      local stacks = w.chargeFilter and w.chargeFilter.enabled
      if hasAPI and mode == "present" and not stacks then
        wiz.auraBackendHint:SetText("|cff66ff66Motor: AuraContainer 12.1|r (Blizzard asigna el buff; icono o arte).")
      elseif hasAPI then
        wiz.auraBackendHint:SetText("|cffffcc66Motor: legacy|r (Ausente/Siempre/stacks no van en Container).")
      else
        wiz.auraBackendHint:SetText("|cffffcc66Motor: legacy|r (sin AuraContainer en este cliente; auras secretas no se leen).")
      end
      wiz.chargePane:SetPoint("TOPLEFT", wiz.auraBackendHint, "BOTTOMLEFT", 0, -6)
    else
      wiz.chargePane:SetPoint("TOPLEFT", wiz.auraKindPane, "BOTTOMLEFT", 0, -8)
    end
  else
    if wiz.auraBackendHint then
      wiz.auraBackendHint:Hide()
    end
    wiz.chargePane:SetPoint("TOPLEFT", wiz.optShowOnCommon, "BOTTOMLEFT", 0, -8)
  end
  wiz.fxPane:SetShown(isCd)
  local modeAnchor = isCd and wiz.fxPane or wiz.chargePane
  wiz.iconPane:SetPoint("TOPLEFT", modeAnchor, "BOTTOMLEFT", 0, -10)
  wiz.auraPane:SetPoint("TOPLEFT", modeAnchor, "BOTTOMLEFT", 0, -10)
  wiz.textPane:SetPoint("TOPLEFT", modeAnchor, "BOTTOMLEFT", 0, -10)

  if d == "icon" then
    wiz.optSwipe:SetChecked(w.swipe ~= false)
    wiz.optSwipe:SetShown(isCd)
    local glowLabels = { Proc = "Proc", Pixel = "Pixel", buttonOverlay = "Overlay", none = "Ninguno" }
    wiz.optGlow:SetText("Glow: " .. (glowLabels[w.glowType or "Proc"] or "Proc"))
  elseif d == "aura" then
    wiz.optLayout:SetText("Layout: " .. ((w.auraLayout == "pair") and "Par" or "Single"))
    wiz.optGap:SetShown(w.auraLayout == "pair")
    wiz.optGap:SetText("Gap: " .. tostring(w.pairGap or 80))
    local ap = w.auraPath or ""
    wiz.auraName:SetText("Arte: " .. (ap ~= "" and (ap:match("([^\\]+)$") or ap) or "(preset default)"))
  else
    if not wiz.textEdit:HasFocus() then
      wiz.textEdit:SetText(w.text or "")
    end
    local fp = w.fontPath or ""
    wiz.optFont:SetText("Fuente: " .. (fp ~= "" and (fp:match("([^\\]+)$") or "custom") or "default"))
  end

  self:UpdatePreview()
  self:ApplyLive()
end

function M:ShowAuraPicker()
  local wiz = self:Ensure().wizard
  wiz.pickerPane:Show()
  local catalog = (media() and media().GetAuraCatalog and media().GetAuraCatalog()) or {}
  local content = wiz.pickContent
  local cells = wiz.pickCells
  for i = 1, #cells do
    cells[i]:Hide()
  end
  local cols = 8
  local cell = 44
  local pad = 4
  for i = 1, #catalog do
    local e = catalog[i]
    local btn = cells[i]
    if not btn then
      btn = CreateFrame("Button", nil, content)
      btn:SetSize(cell, cell)
      btn.tex = btn:CreateTexture(nil, "ARTWORK")
      btn.tex:SetAllPoints()
      btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      cells[i] = btn
    end
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", col * (cell + pad), -row * (cell + pad))
    btn:Show()
    btn.tex:SetTexture(e.path)
    local path = e.path
    btn:SetScript("OnClick", function()
      M._wiz.auraPath = path
      wiz.pickerPane:Hide()
      M:SyncOptsPane()
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
  content:SetHeight(math.max(10, rows * (cell + pad)))
end

function M:CommitWizard()
  local w = self._wiz
  if not w or not w.spellId or w.spellId <= 0 then
    return
  end
  self._liveEditing = true
  self:ApplyLive()
  if not w.editId then
    print("|cffff9900Chukie UI|r: no se pudo guardar la alerta.")
    return
  end
  if alerts() and alerts().EnsureModuleEnabled then
    alerts():EnsureModuleEnabled()
  end
  w.isDraft = false
  w.baseline = nil
  self._wizDirty = false
  self._wiz = nil
  self:EndLiveSession()
  self:ShowList()
end

function M:Show()
  -- Pantalla limpia para ajustar graficos: cerrar Opciones / menu.
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
  self:ShowList()
  self._suppressHideRevert = true
  self._frame:Show()
  self._suppressHideRevert = false
  self._frame:Raise()
end

function M:Hide()
  self._suppressHideRevert = true
  if self._wizDirty then
    self:RevertLiveChanges()
  else
    self:EndLiveSession()
  end
  if self._frame then
    self._frame:Hide()
  end
  self._suppressHideRevert = false
end
function M:RefreshIfShown()
  if self._frame and self._frame:IsShown() and self._frame.list:IsShown() then
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
