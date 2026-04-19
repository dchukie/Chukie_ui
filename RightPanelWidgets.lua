--[[ Widgets del panel azul izquierdo (proxy propios):
     - Grilla 2x4 para sistema (LFG, tracking, mail, dificultad + reservas).
     - Boton ancho de fecha/hora en la parte inferior.
     - Todo anclado al slot left del arbol RightPanel/PanelCore y escalado con panelScalePercent. ]]

local _, ns = ...

local RW = {}
ns.RightPanelWidgets = RW

local WIDGET_IDS = {
  "tracking",
  "lfg",
  "mail",
  "difficulty",
  "reserved1",
  "reserved2",
  "reserved3",
  "reserved4",
}

local function getGridSlotBottomUpRightFirst(index, cols, rows)
  local total = cols * rows
  local i = math.max(1, math.min(tonumber(index) or 1, total)) - 1
  local colOrder = math.floor(i / rows) -- 0..(cols-1)
  local rowOrder = i % rows -- 0..(rows-1)
  local col = (cols - 1) - colOrder -- right -> left
  local row = (rows - 1) - rowOrder -- bottom -> top
  return col, row
end

local ICONS = {
  datetime = "Interface\\Icons\\INV_Misc_PocketWatch_01",
  lfg_off = "Interface\\LFGFrame\\LFG-Eye",
  lfg_on = "Interface\\LFGFrame\\LFG-Eye",
  -- 132328 = icono de rastreo "patitas" (Ability_Tracking).
  tracking = 132328,
  mail_off = "Interface\\Icons\\INV_Letter_15",
  mail_on = "Interface\\Icons\\INV_Letter_17",
  difficulty = "Interface\\Icons\\Achievement_ChallengeMode_Bronze",
  reserved = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
  teleport = "Interface\\Icons\\INV_Misc_Rune_01",
}

local LOCAL_DIFFICULTY_VISUALS = {
  -- Recursos propios del addon (sin dependencia de atlas externos):
  -- 1 = Normal (azul), 2 = Heroico/Hard (amarillo), 23 = Mitico/Nightmare (rojo).
  [1] = { texture = "Interface\\AddOns\\Chukie_Ui\\Media\\ChukieUi_Difficulty_Normal.png" },
  [2] = { texture = "Interface\\AddOns\\Chukie_Ui\\Media\\ChukieUi_Difficulty_Heroic.png" },
  [23] = { texture = "Interface\\AddOns\\Chukie_Ui\\Media\\ChukieUi_Difficulty_Mythic.png" },
  -- Timewalking: fallback visual cercano a Normal.
  [24] = { texture = "Interface\\AddOns\\Chukie_Ui\\Media\\ChukieUi_Difficulty_Normal.png" },
}

local LFG_EYE_SYNC_DELAY = 0.05
local lfgIdleVisualFallback = nil

local DATE_FONT_FACES = {
  [0] = STANDARD_TEXT_FONT,
  [1] = "Fonts\\FRIZQT__.TTF",
  [2] = "Fonts\\ARIALN.TTF",
  [3] = "Fonts\\MORPHEUS.TTF",
  [4] = "Fonts\\SKURRI.TTF",
}

local function clamp(n, a, b)
  n = tonumber(n) or 0
  if n < a then
    return a
  end
  if n > b then
    return b
  end
  return n
end

local function getPanelScalePct()
  if ns.RightPanel and ns.RightPanel.DB then
    local db = ns.RightPanel:DB()
    local pct = tonumber(db and db.panelScalePercent)
    if pct then
      return clamp(math.floor(pct + 0.5), 60, 220)
    end
  end
  return 100
end

function RW:DB()
  if ns.Profile and ns.Profile.GetRightPanelWidgetsModel then
    return ns.Profile:GetRightPanelWidgetsModel()
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  p.widgets = p.widgets or {}
  p.widgets.rightPanelWidgets = p.widgets.rightPanelWidgets or {}
  return p.widgets.rightPanelWidgets
end

local function formatNowText()
  if type(date) == "function" then
    local ok, s = pcall(date, "%H:%M  %d/%m")
    if ok and type(s) == "string" and s ~= "" then
      return s
    end
  end
  if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
    local t = C_DateAndTime.GetCurrentCalendarTime()
    if t and t.hour and t.minute and t.monthDay and t.month then
      return string.format("%02d:%02d  %02d/%02d", t.hour, t.minute, t.monthDay, t.month)
    end
  end
  return "--:--"
end

local function hasQueueActive()
  if QueueStatusButton and QueueStatusButton.IsShown and QueueStatusButton:IsShown() then
    return true
  end
  if not GetLFGMode then
    return false
  end
  local cats = {}
  local function addCat(v)
    if type(v) == "number" then
      cats[#cats + 1] = v
    end
  end
  addCat(_G.LE_LFG_CATEGORY_LFD)
  addCat(_G.LE_LFG_CATEGORY_RF)
  addCat(_G.LE_LFG_CATEGORY_SCENARIO)
  addCat(_G.LE_LFG_CATEGORY_PVP)
  addCat(_G.LE_LFG_CATEGORY_FLEXRAID)
  addCat(_G.LE_LFG_CATEGORY_WORLDPVP)
  if #cats == 0 then
    cats = { 1, 2, 3, 4 }
  end
  for i = 1, #cats do
    local ok, mode = pcall(GetLFGMode, cats[i])
    if ok and mode and mode ~= "none" and mode ~= "abandonedInDungeon" then
      return true
    end
  end
  return false
end

local function stopLfgEyeAnimation(btn)
  if btn and btn._lfgTicker then
    btn._lfgTicker:Cancel()
    btn._lfgTicker = nil
  end
end

local function applyVisualToIcon(icon, visual)
  if not icon or not visual then
    return
  end
  if visual.atlas and icon.SetAtlas then
    icon:SetAtlas(visual.atlas, true)
  elseif visual.texture then
    icon:SetTexture(visual.texture)
  end
  if visual.texCoord and icon.SetTexCoord then
    icon:SetTexCoord(visual.texCoord[1], visual.texCoord[2], visual.texCoord[3], visual.texCoord[4])
  elseif icon.SetTexCoord then
    icon:SetTexCoord(0, 1, 0, 1)
  end
end

local function getQueueStatusEyeVisual()
  local eye = QueueStatusButton and QueueStatusButton.Eye
  local tex = eye and eye.texture
  if not tex then
    return nil
  end
  local out = {}
  if tex.GetAtlas then
    local atlas = tex:GetAtlas()
    if type(atlas) == "string" and atlas ~= "" then
      out.atlas = atlas
    end
  end
  if tex.GetTexture then
    local texture = tex:GetTexture()
    if texture then
      out.texture = texture
    end
  end
  if tex.GetTexCoord then
    local l, r, t, b = tex:GetTexCoord()
    if l and r and t and b then
      out.texCoord = { l, r, t, b }
    end
  end
  if out.atlas or out.texture then
    return out
  end
  return nil
end

local function applyLfgEyeVisual(btn, inQueue)
  if not btn or not btn.icon then
    return
  end
  local function syncFromQueueEye()
    local visual = getQueueStatusEyeVisual()
    if visual then
      applyVisualToIcon(btn.icon, visual)
      return true, visual
    end
    return false, nil
  end

  if inQueue then
    local ok = syncFromQueueEye()
    if not btn._lfgTicker then
      btn._lfgTicker = C_Timer.NewTicker(LFG_EYE_SYNC_DELAY, function()
        if not btn or not btn.icon then
          return
        end
        syncFromQueueEye()
      end)
    end
    if not ok and lfgIdleVisualFallback then
      -- Fallback visual valido: usar "ojo abierto" si no hay fuente directa.
      applyVisualToIcon(btn.icon, lfgIdleVisualFallback)
    end
  else
    stopLfgEyeAnimation(btn)
    local ok, visual = syncFromQueueEye()
    if ok and visual then
      lfgIdleVisualFallback = visual
    elseif lfgIdleVisualFallback then
      -- Opcion valida acordada: mantener ojo abierto estatico si no aparece el cerrado.
      applyVisualToIcon(btn.icon, lfgIdleVisualFallback)
    else
      btn.icon:SetTexture(ICONS.lfg_off)
      btn.icon:SetTexCoord(0, 1, 0, 1)
    end
  end
end

local function hasTrackingContext()
  if MinimapCluster and MinimapCluster.TrackingFrame then
    return true
  end
  local n = 0
  if C_Minimap and C_Minimap.GetNumTrackingTypes then
    local ok = pcall(function()
      n = tonumber(C_Minimap.GetNumTrackingTypes()) or 0
    end)
    if ok and n > 0 then
      return true
    end
  end
  if type(GetNumTrackingTypes) == "function" then
    local ok = pcall(function()
      n = tonumber(GetNumTrackingTypes()) or 0
    end)
    if ok and n > 0 then
      return true
    end
  end
  return MiniMapTrackingButton ~= nil or MiniMapTracking ~= nil or MiniMapTrackingDropDown ~= nil
end

local function hasDifficultyContext()
  -- Este widget representa configuracion disponible, no "solo en instancia".
  return type(GetDungeonDifficultyID) == "function"
    or type(SetDungeonDifficultyID) == "function"
    or type(GetRaidDifficultyID) == "function"
    or type(SetRaidDifficultyID) == "function"
end

local function getDungeonDifficultyVisual()
  if type(GetDungeonDifficultyID) == "function" then
    local ok, id = pcall(GetDungeonDifficultyID)
    if ok and id then
      local v = LOCAL_DIFFICULTY_VISUALS[id]
      if v then
        return v
      end
    end
  end
  return { texture = ICONS.difficulty }
end

local function getMailSummaryText()
  local hasMail = HasNewMail and HasNewMail()
  local s1, s2, s3 = nil, nil, nil
  if GetLatestThreeSenders then
    s1, s2, s3 = GetLatestThreeSenders()
  end
  local lines = {}
  if hasMail then
    lines[#lines + 1] = "Tienes correo pendiente."
  else
    lines[#lines + 1] = "No hay correo pendiente."
  end
  if s1 then
    lines[#lines + 1] = "Remitentes recientes:"
    lines[#lines + 1] = "- " .. tostring(s1)
    if s2 then
      lines[#lines + 1] = "- " .. tostring(s2)
    end
    if s3 then
      lines[#lines + 1] = "- " .. tostring(s3)
    end
  end
  return table.concat(lines, "\n")
end

local function showMailSummaryPopup()
  local key = "CHUKIEUI_MAIL_SUMMARY"
  if not StaticPopupDialogs[key] then
    StaticPopupDialogs[key] = {
      text = "%s",
      button1 = "Cerrar",
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end
  StaticPopup_Show(key, getMailSummaryText())
end

local function openCalendarUi()
  local function isOpen()
    return CalendarFrame and CalendarFrame.IsShown and CalendarFrame:IsShown()
  end
  local function tryCall(fn, ...)
    if type(fn) ~= "function" then
      return false
    end
    local ok = pcall(fn, ...)
    return ok == true
  end

  if isOpen() then
    return
  end

  if not CalendarFrame and UIParentLoadAddOn then
    tryCall(UIParentLoadAddOn, "Blizzard_Calendar")
  end
  if not TimeManagerClockButton and UIParentLoadAddOn then
    tryCall(UIParentLoadAddOn, "Blizzard_TimeManager")
  end

  if isOpen() then
    return
  end

  if Calendar_Toggle then
    tryCall(Calendar_Toggle)
    if isOpen() then
      return
    end
  end
  if CalendarFrame and ShowUIPanel then
    tryCall(ShowUIPanel, CalendarFrame)
    if isOpen() then
      return
    end
  end
  if C_Calendar and C_Calendar.OpenCalendar then
    tryCall(C_Calendar.OpenCalendar)
    if isOpen() then
      return
    end
  end
  if ToggleCalendar then
    tryCall(ToggleCalendar)
    if isOpen() then
      return
    end
  end
  if TimeManagerClockButton then
    if TimeManagerClockButton.Click then
      tryCall(TimeManagerClockButton.Click, TimeManagerClockButton, "LeftButton")
      if isOpen() then
        return
      end
    end
    local onClick = TimeManagerClockButton:GetScript("OnClick")
    if onClick then
      tryCall(onClick, TimeManagerClockButton, "LeftButton")
      if isOpen() then
        return
      end
    end
  end
  if GameTimeFrame then
    if GameTimeFrame.Click then
      tryCall(GameTimeFrame.Click, GameTimeFrame, "LeftButton")
      if isOpen() then
        return
      end
    end
    local onClick = GameTimeFrame:GetScript("OnClick")
    if onClick then
      tryCall(onClick, GameTimeFrame, "LeftButton")
    end
  end
  if not isOpen() and print then
    print("|cffff9900Chukie UI|r: no se pudo abrir el calendario en este estado.")
  end
end

local function openGroupFinderUi()
  if ToggleLFDParentFrame then
    ToggleLFDParentFrame()
    return
  end
  if PVEFrame_ToggleFrame then
    pcall(PVEFrame_ToggleFrame, "GroupFinderFrame")
    return
  end
  if PVEFrame and PVEFrame_ShowFrame then
    pcall(PVEFrame_ShowFrame, "GroupFinderFrame", "LFDParentFrame")
  end
end

local trackingModal = nil
local trackingInfoCache = {}

local function getTrackingCount()
  if C_Minimap and C_Minimap.GetNumTrackingTypes then
    local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
    if ok and tonumber(n) then
      return tonumber(n) or 0
    end
  end
  if type(GetNumTrackingTypes) == "function" then
    local ok, n = pcall(GetNumTrackingTypes)
    if ok and tonumber(n) then
      return tonumber(n) or 0
    end
  end
  return 0
end

local function getTrackingInfoCompat(i)
  trackingInfoCache[i] = nil
  if C_Minimap and C_Minimap.GetTrackingInfo then
    local ok, a, b, c, d, e = pcall(C_Minimap.GetTrackingInfo, i)
    if ok then
      if type(a) == "table" then
        local info = a
        trackingInfoCache[i] = info
        local name = info.name or info.label or info.displayName
        local texture = info.texture or info.icon or info.atlas
        local activeRaw = info.active
        if activeRaw == nil then
          activeRaw = info.isActive
        end
        if activeRaw == nil then
          activeRaw = info.enabled
        end
        if activeRaw == nil then
          activeRaw = info.checked
        end
        local active = activeRaw == true or activeRaw == 1 or activeRaw == "1"
        local category = info.category
        local nested = info.nested
        return name, texture, active, category, nested
      end
      local name, texture, active, category, nested = a, b, c, d, e
      local activeNorm = active == true or active == 1 or active == "1"
      return name, texture, activeNorm, category, nested
    end
  end
  if type(GetTrackingInfo) == "function" then
    local ok, name, texture, active, category, nested = pcall(GetTrackingInfo, i)
    if ok then
      local activeNorm = active == true or active == 1 or active == "1"
      return name, texture, activeNorm, category, nested
    end
  end
  return nil, nil, false, nil, nil
end

local function isTrackingActive(i)
  local _, _, active = getTrackingInfoCompat(i)
  return active == true
end

local function setTrackingCompat(i, enabled)
  local desired = enabled == true
  local before = isTrackingActive(i)
  if before == desired then
    return true
  end

  -- C_Minimap.SetTracking funciona con indice de la lista (1..N).
  -- No usar spellID/trackingID aqui.
  local candidateIds = { i }

  local function callAndCheck(fn, label, a, b)
    local ok = pcall(fn, a, b)
    local after = isTrackingActive(i)
    if not ok and label then
      -- no-op: conservamos label para futuras trazas locales si hacen falta
    end
    if ok and after == desired then
      return true
    end
    return false
  end

  if C_Minimap and C_Minimap.SetTracking then
    for _, id in ipairs(candidateIds) do
      if callAndCheck(C_Minimap.SetTracking, "C_Minimap.SetTracking(bool)", id, desired) then
        return true
      end
    end
  end
  if type(SetTracking) == "function" then
    for _, id in ipairs(candidateIds) do
      if callAndCheck(SetTracking, "SetTracking(1/nil)", id, desired and 1 or nil) then
        return true
      end
      if callAndCheck(SetTracking, "SetTracking(bool)", id, desired) then
        return true
      end
    end
  end

  local final = isTrackingActive(i) == desired
  return final
end

local function getTrackingIndices()
  local indices = {}
  local count = getTrackingCount()
  if count > 0 then
    for i = 1, count do
      indices[#indices + 1] = i
    end
    return indices
  end
  -- Fallback: algunos clientes reportan 0 en GetNumTrackingTypes pero sí responden GetTrackingInfo.
  for i = 1, 80 do
    local name = getTrackingInfoCompat(i)
    if type(name) == "string" and name ~= "" then
      indices[#indices + 1] = i
    end
  end
  return indices
end

local function clearAllTrackingCompat()
  local indices = getTrackingIndices()
  if #indices == 0 then
    return false
  end
  local changed = false
  for _, i in ipairs(indices) do
    local _, _, isActive = getTrackingInfoCompat(i)
    if isActive then
      changed = setTrackingCompat(i, false) or changed
    end
  end
  return changed
end

local function ensureTrackingModal()
  if trackingModal and trackingModal.GetName then
    return trackingModal
  end

  local f = CreateFrame("Frame", "ChukieUi_TrackingModal", UIParent, "BackdropTemplate")
  f:SetSize(420, 440)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(200)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:Hide()
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", f, "TOP", 0, -14)
  title:SetText("Chukie UI - Rastreo")
  f.title = title

  local dragHandle = CreateFrame("Frame", nil, f)
  dragHandle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -8)
  dragHandle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -38, -8)
  dragHandle:SetHeight(28)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle:SetScript("OnDragStart", function()
    f:StartMoving()
  end)
  dragHandle:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
  end)

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
  subtitle:SetText("Ventana propia para configurar opciones de tracking.")
  f.subtitle = subtitle

  local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
  panel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -54)
  panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 58)
  panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  panel:SetBackdropColor(0, 0, 0, 0.35)

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 6)
  f.scroll = scroll

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)
  f.content = content
  f.rows = {}

  local help = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  help:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 42)
  help:SetText("Click en una fila: activa/desactiva ese rastreo.\nClick derecho: desactivar todos.")
  help:SetJustifyH("LEFT")
  f.help = help

  local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  refreshBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 12)
  refreshBtn:SetSize(90, 22)
  refreshBtn:SetText("Actualizar")

  local closeBtnBottom = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  closeBtnBottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 12)
  closeBtnBottom:SetSize(90, 22)
  closeBtnBottom:SetText("Cerrar")
  closeBtnBottom:SetScript("OnClick", function()
    f:Hide()
  end)

  f.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  f.emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
  f.emptyText:SetText("No hay opciones de rastreo disponibles.")
  f.emptyText:Hide()

  function f:RefreshList()
    local shown = 0
    local rowHeight = 28
    local indices = getTrackingIndices()
    for _, i in ipairs(indices) do
      local name, texture, active = getTrackingInfoCompat(i)
      if type(name) == "string" and name ~= "" then
        shown = shown + 1
        local row = self.rows[shown]
        if not row then
          row = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
          row:SetHeight(rowHeight - 2)
          row:RegisterForClicks("AnyUp")
          row:EnableMouse(true)
          -- Normaliza tamano/posicion del check para evitar escalado raro del template.
          local nt = row:GetNormalTexture()
          if nt then
            nt:ClearAllPoints()
            nt:SetPoint("LEFT", row, "LEFT", 2, 0)
            nt:SetSize(16, 16)
          end
          local ct = row:GetCheckedTexture()
          if ct then
            ct:ClearAllPoints()
            ct:SetPoint("LEFT", row, "LEFT", 2, 0)
            ct:SetSize(16, 16)
          end
          local ht = row:GetHighlightTexture()
          if ht then
            ht:ClearAllPoints()
            ht:SetPoint("LEFT", row, "LEFT", 2, 0)
            ht:SetSize(16, 16)
          end
          row.bg = CreateFrame("Frame", nil, row, "BackdropTemplate")
          row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
          row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
          row:RegisterForClicks("AnyUp")
          row.bg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true,
            tileSize = 8,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
          })
          row.icon = row:CreateTexture(nil, "ARTWORK")
          row.icon:SetPoint("LEFT", row, "LEFT", 24, 0)
          row.icon:SetSize(18, 18)
          row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
          row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
          row.label:SetJustifyH("LEFT")
          row:SetScript("OnMouseUp", function(btn, mouseButton)
            if mouseButton == "RightButton" then
              clearAllTrackingCompat()
            else
              local _, _, wasActive = getTrackingInfoCompat(btn._trackingIndex)
              if wasActive then
                setTrackingCompat(btn._trackingIndex, false)
              else
                setTrackingCompat(btn._trackingIndex, true)
              end
            end
            if ns.RightPanelWidgets and ns.RightPanelWidgets.Refresh then
              ns.RightPanelWidgets:Refresh()
            end
            if trackingModal and trackingModal.RefreshList then
              trackingModal:RefreshList()
            end
          end)
          self.rows[shown] = row
        end

        row._trackingIndex = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 6, -((shown - 1) * rowHeight) - 6)
        row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -6, -((shown - 1) * rowHeight) - 6)
        row.icon:SetTexture(texture or ICONS.tracking)
        row.label:SetText(name)
        row.label:SetWidth(220)
        row.label:SetWordWrap(false)
        if active then
          row:SetChecked(true)
          row.bg:SetBackdropColor(0.08, 0.11, 0.08, 0.55)
          row.bg:SetBackdropBorderColor(0.20, 0.60, 0.30, 0.95)
        else
          row:SetChecked(false)
          row.bg:SetBackdropColor(0.06, 0.06, 0.06, 0.55)
          row.bg:SetBackdropBorderColor(0.22, 0.22, 0.22, 0.9)
        end
        row:Show()
      end
    end

    for i = shown + 1, #self.rows do
      self.rows[i]:Hide()
    end

    self.emptyText:SetShown(shown == 0)
    local contentW = (self.scroll:GetWidth() or 320) - 8
    self.content:SetWidth(math.max(280, contentW))
    self.content:SetHeight(math.max(40, shown * rowHeight + 12))
  end

  refreshBtn:SetScript("OnClick", function()
    f:RefreshList()
  end)

  trackingModal = f
  if UISpecialFrames then
    table.insert(UISpecialFrames, "ChukieUi_TrackingModal")
  end
  return trackingModal
end

local function openTrackingUi()
  local modal = ensureTrackingModal()
  modal:RefreshList()
  modal:Show()
end

local difficultyModal = nil

local function getDifficultyName(id, fallback)
  if type(GetDifficultyInfo) == "function" then
    local ok, name = pcall(GetDifficultyInfo, id)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return fallback or ("ID " .. tostring(id))
end

local function buildDifficultyOptions(ids, fallbackPrefix)
  local out = {}
  for _, id in ipairs(ids) do
    local label = getDifficultyName(id, (fallbackPrefix or "Dificultad") .. " " .. tostring(id))
    out[#out + 1] = { id = id, label = label }
  end
  return out
end

local DUNGEON_DIFFICULTY_OPTIONS = buildDifficultyOptions({ 1, 2, 23 }, "Dungeon")
local RAID_DIFFICULTY_OPTIONS = buildDifficultyOptions({ 14, 15, 16, 17 }, "Raid")
local LEGACY_RAID_DIFFICULTY_OPTIONS = buildDifficultyOptions({ 3, 4, 5, 6 }, "Legacy Raid")

local function buildLootSpecOptions()
  local out = {
    { id = 0, label = "Especializacion actual" },
  }
  if type(GetNumSpecializations) ~= "function" or type(GetSpecializationInfo) ~= "function" then
    return out
  end
  local num = tonumber(GetNumSpecializations()) or 0
  for i = 1, num do
    local specID, name = GetSpecializationInfo(i)
    if tonumber(specID) and type(name) == "string" and name ~= "" then
      out[#out + 1] = { id = specID, label = name }
    end
  end
  return out
end

local function applyDifficultySelection(kind, id)
  if not id then
    return false
  end
  if kind == "dungeon" and type(SetDungeonDifficultyID) == "function" then
    local ok = pcall(SetDungeonDifficultyID, id)
    return ok == true
  end
  if kind == "raid" and type(SetRaidDifficultyID) == "function" then
    local ok = pcall(SetRaidDifficultyID, id)
    return ok == true
  end
  if kind == "legacyRaid" and type(SetLegacyRaidDifficultyID) == "function" then
    local ok = pcall(SetLegacyRaidDifficultyID, id)
    return ok == true
  end
  if kind == "lootSpec" and type(SetLootSpecialization) == "function" then
    local ok = pcall(SetLootSpecialization, id)
    return ok == true
  end
  return false
end

local function getCurrentDifficultyValue(kind)
  if kind == "dungeon" and type(GetDungeonDifficultyID) == "function" then
    local ok, v = pcall(GetDungeonDifficultyID)
    if ok then
      return v
    end
  end
  if kind == "raid" and type(GetRaidDifficultyID) == "function" then
    local ok, v = pcall(GetRaidDifficultyID)
    if ok then
      return v
    end
  end
  if kind == "legacyRaid" and type(GetLegacyRaidDifficultyID) == "function" then
    local ok, v = pcall(GetLegacyRaidDifficultyID)
    if ok then
      return v
    end
  end
  if kind == "lootSpec" and type(GetLootSpecialization) == "function" then
    local ok, v = pcall(GetLootSpecialization)
    if ok then
      return v
    end
  end
  return nil
end

local function ensureDifficultyModal()
  if difficultyModal and difficultyModal.GetName then
    return difficultyModal
  end

  local f = CreateFrame("Frame", "ChukieUi_DifficultyModal", UIParent, "BackdropTemplate")
  f:SetSize(420, 370)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(210)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:Hide()
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", f, "TOP", 0, -14)
  title:SetText("Chukie UI - Dificultad")
  f.title = title

  local dragHandle = CreateFrame("Frame", nil, f)
  dragHandle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -8)
  dragHandle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -38, -8)
  dragHandle:SetHeight(28)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle:SetScript("OnDragStart", function()
    f:StartMoving()
  end)
  dragHandle:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
  end)

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
  subtitle:SetText("Selecciona la dificultad por tipo de contenido.")
  f.subtitle = subtitle

  local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  local status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 44)
  status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 44)
  status:SetJustifyH("LEFT")
  status:SetText("Puedes cambiar dificultad fuera de contenido bloqueado.")
  f.status = status
  f._refreshTimer = nil

  local function scheduleRefresh(delaySec)
    if f._refreshTimer then
      f._refreshTimer:Cancel()
      f._refreshTimer = nil
    end
    f._refreshTimer = C_Timer.NewTimer(delaySec or 0, function()
      f._refreshTimer = nil
      if f and f.Refresh and f:IsShown() then
        f:Refresh()
      end
    end)
  end

  local function createDropdownRow(y, labelText, key, optionsSource)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 22, y)
    label:SetText(labelText)

    local dd = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -14, -2)
    UIDropDownMenu_SetWidth(dd, 240)

    local function getOptions()
      if type(optionsSource) == "function" then
        return optionsSource()
      end
      return optionsSource
    end

    local function refreshText()
      local current = getCurrentDifficultyValue(key)
      local txt = "No disponible"
      for _, opt in ipairs(getOptions()) do
        if opt.id == current then
          txt = opt.label
          break
        end
      end
      UIDropDownMenu_SetText(dd, txt)
    end

    UIDropDownMenu_Initialize(dd, function(_, level)
      if level ~= 1 then
        return
      end
      local current = getCurrentDifficultyValue(key)
      for _, opt in ipairs(getOptions()) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.label
        info.checked = (opt.id == current)
        info.func = function()
          local ok = applyDifficultySelection(key, opt.id)
          if ok then
            f.status:SetText("Aplicado: " .. labelText .. " -> " .. opt.label)
          else
            f.status:SetText("No se pudo aplicar " .. labelText .. ".")
          end
          scheduleRefresh(1.0)
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)

    return {
      dropdown = dd,
      refresh = refreshText,
    }
  end

  f.rows = {
    createDropdownRow(-62, "Dungeon", "dungeon", DUNGEON_DIFFICULTY_OPTIONS),
    createDropdownRow(-126, "Raid", "raid", RAID_DIFFICULTY_OPTIONS),
    createDropdownRow(-190, "Legacy Raid", "legacyRaid", LEGACY_RAID_DIFFICULTY_OPTIONS),
    createDropdownRow(-254, "Loot Spec", "lootSpec", buildLootSpecOptions),
  }

  local closeBtnBottom = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  closeBtnBottom:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
  closeBtnBottom:SetSize(90, 22)
  closeBtnBottom:SetText("Cerrar")
  closeBtnBottom:SetScript("OnClick", function()
    f:Hide()
  end)

  function f:Refresh()
    for _, row in ipairs(self.rows) do
      row.refresh()
    end
    self.status:SetText("Selecciona y aplica la dificultad deseada.")
  end

  f:SetScript("OnHide", function(self)
    if self._refreshTimer then
      self._refreshTimer:Cancel()
      self._refreshTimer = nil
    end
  end)

  difficultyModal = f
  if UISpecialFrames then
    table.insert(UISpecialFrames, "ChukieUi_DifficultyModal")
  end
  return difficultyModal
end

local function openDifficultyUi()
  local modal = ensureDifficultyModal()
  modal:Refresh()
  C_Timer.After(1.0, function()
    if modal and modal:IsShown() and modal.Refresh then
      modal:Refresh()
    end
  end)
  modal:Show()
end

function RW:GetMasqueGroup()
  local db = self:DB()
  if db.useMasque == false then
    return nil
  end
  local stub = _G.LibStub
  if not stub then
    return nil
  end
  local msq = stub("Masque", true)
  if not msq or type(msq.Group) ~= "function" then
    return nil
  end
  if not self._masqueGroup then
    self._masqueGroup = msq:Group("Chukie UI", "RightPanelWidgets")
  end
  return self._masqueGroup
end

function RW:StripMasqueButtons()
  local grp = self._masqueGroup
  if not grp or not self._buttons then
    return
  end
  for _, b in pairs(self._buttons) do
    if b ~= self._buttons.datetime then
      grp:RemoveButton(b)
    end
  end
end

local function masqueRegions(btn)
  return {
    Icon = btn.icon,
    Normal = false,
    Disabled = false,
    Pushed = false,
    Flash = false,
    Checked = false,
    Border = false,
    IconBorder = false,
    DebuffBorder = false,
    EnchantBorder = false,
    Highlight = false,
  }
end

function RW:ApplyMasque()
  local grp = self:GetMasqueGroup()
  if not grp or not self._buttons then
    self:StripMasqueButtons()
    return
  end
  for _, b in pairs(self._buttons) do
    if b ~= self._buttons.datetime then
      grp:RemoveButton(b)
    end
  end
  for _, b in pairs(self._buttons) do
    if b ~= self._buttons.datetime and b and b.icon and b:IsShown() and grp.AddButton then
      grp:AddButton(b, masqueRegions(b), "Legacy")
    end
  end
  if grp.ReSkin then
    grp:ReSkin()
  end
end

local function ensurePulse(button)
  if button._pulse then
    return button._pulse
  end
  local ag = button:CreateAnimationGroup()
  ag:SetLooping("REPEAT")
  local a1 = ag:CreateAnimation("Alpha")
  a1:SetOrder(1)
  a1:SetDuration(0.55)
  a1:SetFromAlpha(1.0)
  a1:SetToAlpha(0.35)
  a1:SetSmoothing("IN_OUT")
  local a2 = ag:CreateAnimation("Alpha")
  a2:SetOrder(2)
  a2:SetDuration(0.55)
  a2:SetFromAlpha(0.35)
  a2:SetToAlpha(1.0)
  a2:SetSmoothing("IN_OUT")
  button._pulse = ag
  return ag
end

local function applyIconState(btn, state)
  if not btn or not btn.icon then
    return
  end
  local icon = btn.icon
  if state.atlas and icon.SetAtlas then
    icon:SetAtlas(state.atlas, true)
  elseif state.texture then
    icon:SetTexture(state.texture)
  end
  if state.texCoord and icon.SetTexCoord then
    icon:SetTexCoord(state.texCoord[1], state.texCoord[2], state.texCoord[3], state.texCoord[4])
  elseif icon.SetTexCoord then
    icon:SetTexCoord(0, 1, 0, 1)
  end
  if state.desat ~= nil and icon.SetDesaturated then
    icon:SetDesaturated(state.desat)
  end
  if state.r then
    icon:SetVertexColor(state.r, state.g or state.r, state.b or state.r, state.a or 1)
  else
    icon:SetVertexColor(1, 1, 1, 1)
  end
  if btn._slash then
    btn._slash:SetShown(state.slashed == true)
  end
  if state.pulse then
    ensurePulse(icon):Play()
  elseif icon._pulse then
    icon._pulse:Stop()
    icon:SetAlpha(1)
  end
end

local function makeButton(parent, name)
  local b = CreateFrame("Button", name, parent, "BackdropTemplate")
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(20)
  if b.SetNormalTexture then
    b:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then
      nt:SetAlpha(0)
    end
  end
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local ht = b.GetHighlightTexture and b:GetHighlightTexture()
  if ht and ht.SetBlendMode then
    ht:SetBlendMode("ADD")
  end
  if b.SetPushedTexture then
    b:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
    local pt = b.GetPushedTexture and b:GetPushedTexture()
    if pt then
      pt:SetAlpha(0)
    end
  end
  b:RegisterForClicks("AnyUp")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.03, 0.03, 0.03, 0.55)
  b.bg = bg
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  b.icon = icon
  local slash = b:CreateTexture(nil, "OVERLAY")
  slash:SetTexture("Interface\\Buttons\\WHITE8X8")
  slash:SetVertexColor(0.9, 0.15, 0.15, 0.9)
  slash:SetPoint("CENTER", b, "CENTER", 0, 0)
  slash:SetSize(24, 3)
  slash:SetRotation(0.65)
  slash:Hide()
  b._slash = slash
  return b
end

--- Teletransporte (reserved1): catálogo en TeleportCatalog.lua; clic izq = secure default, der = grilla.

local function spellKnown(spellId)
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    return C_SpellBook.IsSpellKnown(spellId) == true
  end
  return IsSpellKnown and IsSpellKnown(spellId) or false
end

local function checkQuestCompletion(quest)
  if not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
    return true
  end
  if type(quest) == "table" then
    for i = 1, #quest do
      if C_QuestLog.IsQuestFlaggedCompleted(quest[i]) then
        return true
      end
    end
    return false
  end
  return C_QuestLog.IsQuestFlaggedCompleted(quest)
end

local function isTeleportEntryValid(entry)
  if not entry or not entry.type or not entry.id then
    return false
  end
  if entry.type == "spell" then
    return spellKnown(entry.id)
  end
  if entry.type == "toy" then
    if not PlayerHasToy(entry.id) then
      return false
    end
    if entry.quest and not checkQuestCompletion(entry.quest) then
      return false
    end
    return true
  end
  if entry.type == "item" then
    return (C_Item.GetItemCount(entry.id) or 0) > 0
  end
  return false
end

local function isTeleportGridAllowed(db, entry)
  if not entry or not entry.key then
    return true
  end
  local t = db.teleportGridVisibility
  if not t then
    return true
  end
  return t[entry.key] ~= false
end

local function teleportCatalogList()
  if ns.TeleportCatalog and ns.TeleportCatalog.GetList then
    return ns.TeleportCatalog.GetList()
  end
  return {}
end

local function getTeleportPreferredKey(db)
  if not db then
    return nil
  end
  local list = teleportCatalogList()
  local idx = tonumber(db.teleportDefaultIndex)
  if idx and idx >= 1 and idx <= #list then
    return list[idx].key
  end
  local k = db.teleportDefaultKey
  if type(k) == "string" and k ~= "" then
    return k
  end
  return nil
end

local function dedupeTeleportEntries(entries, preferredKey)
  local byKey = {}
  for i = 1, #entries do
    local e = entries[i]
    local dk = e.dedupeKey
    if type(dk) == "string" and dk ~= "" then
      byKey[dk] = byKey[dk] or {}
      table.insert(byKey[dk], i)
    end
  end
  local skip = {}
  for _, idxs in pairs(byKey) do
    if #idxs > 1 then
      local keepIdx = idxs[1]
      for j = 1, #idxs do
        local ei = entries[idxs[j]]
        if preferredKey and ei.key == preferredKey then
          keepIdx = idxs[j]
          break
        end
      end
      for j = 1, #idxs do
        if idxs[j] ~= keepIdx then
          skip[idxs[j]] = true
        end
      end
    end
  end
  local out = {}
  for i = 1, #entries do
    if not skip[i] then
      out[#out + 1] = entries[i]
    end
  end
  return out
end

local function buildTeleportValidList()
  local list = teleportCatalogList()
  local valid = {}
  for i = 1, #list do
    if isTeleportEntryValid(list[i]) then
      valid[#valid + 1] = list[i]
    end
  end
  return valid
end

local function clearTeleportSecureAttributes(btn)
  if not btn or InCombatLockdown() then
    return false
  end
  btn:SetAttribute("type", nil)
  btn:SetAttribute("spell", nil)
  btn:SetAttribute("item", nil)
  btn:SetAttribute("toy", nil)
  return true
end

local function applyTeleportSecureAttributes(btn, entry)
  if not btn or not entry then
    return
  end
  if InCombatLockdown() then
    RW._teleportRegenPending = true
    return
  end
  clearTeleportSecureAttributes(btn)
  local t = entry.type
  btn:SetAttribute("type", t)
  if t == "item" then
    btn:SetAttribute("item", "item:" .. tostring(entry.id))
  elseif t == "toy" then
    btn:SetAttribute("toy", entry.id)
  elseif t == "spell" then
    btn:SetAttribute("spell", entry.id)
  end
end

local function teleportDefaultIconTexture(entry)
  if not entry then
    return ICONS.teleport
  end
  if entry.type == "spell" and C_Spell and C_Spell.GetSpellTexture then
    local tex = C_Spell.GetSpellTexture(entry.id)
    if tex then
      return tex
    end
  end
  if (entry.type == "item" or entry.type == "toy") and C_Item and C_Item.GetItemIconByID then
    local tex = C_Item.GetItemIconByID(entry.id)
    if tex then
      return tex
    end
  end
  return ICONS.teleport
end

--- start, duration en segundos de reloj de juego (GetTime); modRate para SetCooldown.
local function getTeleportEntryCooldownTimes(entry)
  if not entry then
    return 0, 0, 1
  end
  if entry.type == "spell" and C_Spell and C_Spell.GetSpellCooldown then
    local info = C_Spell.GetSpellCooldown(entry.id)
    if info then
      local st = info.startTime
      local dur = info.duration
      if st == nil and info.startTimeMS then
        st = info.startTimeMS * 0.001
      end
      if dur == nil and info.durationMS then
        dur = info.durationMS * 0.001
      end
      st = tonumber(st) or 0
      dur = tonumber(dur) or 0
      return st, dur, tonumber(info.modRate) or 1
    end
  end
  if (entry.type == "item" or entry.type == "toy") and C_Item and C_Item.GetItemCooldown then
    local a, b, c = C_Item.GetItemCooldown(entry.id)
    if type(a) == "table" then
      local st = a.startTimeSeconds or a.startTime or 0
      local dur = a.durationSeconds or a.duration or 0
      return tonumber(st) or 0, tonumber(dur) or 0, 1
    end
    if type(a) == "number" then
      return tonumber(a) or 0, tonumber(b) or 0, 1
    end
  end
  if (entry.type == "item" or entry.type == "toy") and GetItemCooldown then
    local st, dur = GetItemCooldown(entry.id)
    return tonumber(st) or 0, tonumber(dur) or 0, 1
  end
  return 0, 0, 1
end

local function ensureTeleportCooldownFrame(slotBtn, baseLevel)
  if slotBtn._tpCooldown then
    return slotBtn._tpCooldown
  end
  local cd = CreateFrame("Cooldown", nil, slotBtn, "CooldownFrameTemplate")
  cd:SetPoint("TOPLEFT", slotBtn.icon, "TOPLEFT", 0, 0)
  cd:SetPoint("BOTTOMRIGHT", slotBtn.icon, "BOTTOMRIGHT", 0, 0)
  cd:SetFrameLevel((baseLevel or 20) + 5)
  cd:EnableMouse(false)
  if cd.SetHideCountdownNumbers then
    cd:SetHideCountdownNumbers(false)
  end
  if cd.SetDrawSwipe then
    cd:SetDrawSwipe(true)
  end
  slotBtn._tpCooldown = cd
  return cd
end

local function hookTeleportCooldownPulse(slotBtn)
  if slotBtn._tpCDHooked then
    return
  end
  slotBtn._tpCDHooked = true
  slotBtn:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  slotBtn:RegisterEvent("BAG_UPDATE_COOLDOWN")
  slotBtn:SetScript("OnEvent", function(self)
    RW:RefreshTeleportReservedCooldown(self)
  end)
  slotBtn:SetScript("OnUpdate", function(self, elapsed)
    self._tpCDPoll = (self._tpCDPoll or 0) + elapsed
    if self._tpCDPoll < 0.12 then
      return
    end
    self._tpCDPoll = 0
    if self._tpCooldownEntry then
      RW:RefreshTeleportReservedCooldown(self)
    end
  end)
end

function RW:RefreshTeleportReservedCooldown(slotBtn)
  if not slotBtn or slotBtn._widgetId ~= "reserved1" then
    return
  end
  local cd = slotBtn._tpCooldown
  local entry = slotBtn._tpCooldownEntry
  if not cd then
    return
  end
  if not entry or not slotBtn:IsShown() then
    cd:Clear()
    cd:Hide()
    return
  end
  local start, duration, modRate = getTeleportEntryCooldownTimes(entry)
  if duration and duration > 0.001 and start and start > 0 then
    cd:SetCooldown(start, duration, modRate or 1)
    cd:Show()
  else
    cd:Clear()
    cd:Hide()
  end
end

local TP_SLOT_LAYOUT_VERSION = 4

--- Ranuras reserved2–4 (DynamicReservedSlots.lua + Bindings.xml).

local DYN_SLOT_LAYOUT_VERSION = 1
local DYN_SLOT_TO_INDEX = {
  reserved2 = 2,
  reserved3 = 3,
  reserved4 = 4,
}

local function ensureDynamicCooldownFrame(slotBtn, baseLevel)
  if slotBtn._dynCooldown then
    return slotBtn._dynCooldown
  end
  local cd = CreateFrame("Cooldown", nil, slotBtn, "CooldownFrameTemplate")
  cd:SetPoint("TOPLEFT", slotBtn.icon, "TOPLEFT", 0, 0)
  cd:SetPoint("BOTTOMRIGHT", slotBtn.icon, "BOTTOMRIGHT", 0, 0)
  cd:SetFrameLevel((baseLevel or 20) + 5)
  cd:EnableMouse(false)
  if cd.SetHideCountdownNumbers then
    cd:SetHideCountdownNumbers(false)
  end
  if cd.SetDrawSwipe then
    cd:SetDrawSwipe(true)
  end
  slotBtn._dynCooldown = cd
  return cd
end

local function hookDynamicSlotCooldownPulse(slotBtn)
  if slotBtn._dynCDHooked then
    return
  end
  slotBtn._dynCDHooked = true
  slotBtn:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  slotBtn:RegisterEvent("BAG_UPDATE_COOLDOWN")
  slotBtn:SetScript("OnEvent", function(self)
    RW:RefreshDynamicReservedCooldown(self)
  end)
  slotBtn:SetScript("OnUpdate", function(self, elapsed)
    self._dynCDPoll = (self._dynCDPoll or 0) + elapsed
    if self._dynCDPoll < 0.12 then
      return
    end
    self._dynCDPoll = 0
    if self._dynEntry then
      RW:RefreshDynamicReservedCooldown(self)
    end
  end)
end

function RW:RefreshDynamicReservedCooldown(slotBtn)
  if not slotBtn or not DYN_SLOT_TO_INDEX[slotBtn._widgetId or ""] then
    return
  end
  local cd = slotBtn._dynCooldown
  local entry = slotBtn._dynEntry
  if not cd then
    return
  end
  if not entry or not slotBtn:IsShown() or not (ns.DynamicReservedSlots and ns.DynamicReservedSlots.GetEntryCooldownTimes) then
    cd:Clear()
    cd:Hide()
    return
  end
  local start, duration, modRate = ns.DynamicReservedSlots.GetEntryCooldownTimes(entry)
  if duration and duration > 0.001 and start and start > 0 then
    cd:SetCooldown(start, duration, modRate or 1)
    cd:Show()
  else
    cd:Clear()
    cd:Hide()
  end
end

function RW:EnsureDynamicReservedSlot(slotBtn)
  if not slotBtn or not DYN_SLOT_TO_INDEX[slotBtn._widgetId or ""] then
    return
  end
  if slotBtn._dynSlotBuilt and slotBtn._dynLayoutVersion == DYN_SLOT_LAYOUT_VERSION then
    return
  end
  if InCombatLockdown() and slotBtn._dynSlotBuilt then
    self._dynRegenPending = true
    return
  end
  local idx = DYN_SLOT_TO_INDEX[slotBtn._widgetId]
  local gname = ns.DynamicReservedSlots and ns.DynamicReservedSlots._globalNames and ns.DynamicReservedSlots._globalNames[idx]
  if not gname then
    return
  end
  local base = slotBtn:GetFrameLevel() or 20
  local sec = _G[gname]
  if not sec then
    sec = CreateFrame("Button", gname, slotBtn, "SecureActionButtonTemplate")
  else
    sec:SetParent(slotBtn)
  end
  sec:ClearAllPoints()
  sec:SetAllPoints(slotBtn)
  sec:SetFrameLevel(base + 8)
  sec:EnableMouse(true)
  sec:RegisterForClicks("LeftButtonUp")
  if sec.SetAttribute then
    sec:SetAttribute("useOnKeyDown", false)
  end
  sec:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local sech = sec.GetHighlightTexture and sec:GetHighlightTexture()
  if sech and sech.SetBlendMode then
    sech:SetBlendMode("ADD")
  end
  slotBtn._dynDefaultSecure = sec
  slotBtn._dynSlotBuilt = true
  slotBtn._dynLayoutVersion = DYN_SLOT_LAYOUT_VERSION
  ensureDynamicCooldownFrame(slotBtn, base)
  hookDynamicSlotCooldownPulse(slotBtn)
end

function RW:ApplyDynamicReservedVisuals()
  local D = ns.DynamicReservedSlots
  local order = { "reserved2", "reserved3", "reserved4" }
  if not self._buttons or not D or not D.BuildQueue then
    for i = 1, #order do
      local b = self._buttons and self._buttons[order[i]]
      if b then
        applyIconState(b, {
          texture = ICONS.reserved,
          desat = true,
          slashed = true,
          r = 0.55,
          g = 0.55,
          b = 0.55,
        })
        b:SetScript("OnClick", nil)
      end
    end
    return
  end
  if not D.IsFeatureEnabled() then
    for i = 1, #order do
      local b = self._buttons[order[i]]
      if b then
        b:Show()
        applyIconState(b, {
          texture = ICONS.reserved,
          desat = true,
          slashed = true,
          r = 0.55,
          g = 0.55,
          b = 0.55,
        })
        if b._dynDefaultSecure then
          if not InCombatLockdown() then
            D.ClearSecure(b._dynDefaultSecure)
          else
            self._dynRegenPending = true
          end
          b._dynDefaultSecure:Hide()
        end
        b._dynEntry = nil
        if b.EnableMouse then
          b:EnableMouse(true)
        end
        if b.SetMouseClickEnabled then
          b:SetMouseClickEnabled(true)
        end
        self:RefreshDynamicReservedCooldown(b)
      end
    end
    return
  end

  local queue = D.BuildQueue(3)
  for i = 1, #order do
    local id = order[i]
    local slot = self._buttons[id]
    if not slot then
      -- skip
    else
      self:EnsureDynamicReservedSlot(slot)
      local entry = queue[i]
      slot._dynEntry = entry
      local sec = slot._dynDefaultSecure
      if entry and sec then
        local ok = false
        if not InCombatLockdown() then
          ok = D.ApplyEntryToSecureResolved(sec, entry)
          if ok and D.ValidateEntryContext and not D.ValidateEntryContext(entry) then
            ok = false
          end
        else
          self._dynRegenPending = true
          local t = sec.GetAttribute and sec:GetAttribute("type")
          ok = sec.IsShown and sec:IsShown() and t ~= nil and t ~= ""
        end
        if ok then
          slot:Show()
          sec:Show()
          if slot.EnableMouse then
            slot:EnableMouse(false)
          end
          if slot.SetMouseClickEnabled then
            slot:SetMouseClickEnabled(false)
          end
          local tex = D.GetEntryIcon(entry)
          applyIconState(slot, {
            texture = tex or ICONS.reserved,
            desat = not tex,
            slashed = false,
            r = tex and 1 or 0.72,
            g = tex and 1 or 0.72,
            b = tex and 1 or 0.72,
          })
        elseif not InCombatLockdown() then
          sec:Hide()
          D.ClearSecure(sec)
          slot._dynEntry = nil
          slot:Hide()
          if slot.EnableMouse then
            slot:EnableMouse(true)
          end
          if slot.SetMouseClickEnabled then
            slot:SetMouseClickEnabled(true)
          end
        else
          self._dynRegenPending = true
          slot._dynEntry = nil
          slot:Hide()
          if slot.EnableMouse then
            slot:EnableMouse(true)
          end
          if slot.SetMouseClickEnabled then
            slot:SetMouseClickEnabled(true)
          end
        end
        slot:SetScript("OnClick", nil)
      else
        slot:Hide()
        if sec then
          if not InCombatLockdown() then
            D.ClearSecure(sec)
          else
            self._dynRegenPending = true
          end
          sec:Hide()
        end
        slot._dynEntry = nil
        if slot.EnableMouse then
          slot:EnableMouse(true)
        end
        if slot.SetMouseClickEnabled then
          slot:SetMouseClickEnabled(true)
        end
        slot:SetScript("OnClick", nil)
      end
      self:RefreshDynamicReservedCooldown(slot)
    end
  end
  if self._dynRegenPending and not InCombatLockdown() then
    self._dynRegenPending = nil
    self:ApplyDynamicReservedVisuals()
  end
end

function RW:EnsureTeleportReservedSlot(slotBtn)
  if not slotBtn then
    return
  end
  if slotBtn._tpTeleportBuilt and slotBtn._tpTeleportLayoutVersion == TP_SLOT_LAYOUT_VERSION then
    return
  end
  if InCombatLockdown() and slotBtn._tpTeleportBuilt then
    self._teleportRegenPending = true
    return
  end
  if slotBtn._tpDefaultSecure then
    slotBtn._tpDefaultSecure:SetParent(nil)
    slotBtn._tpDefaultSecure = nil
  end
  if slotBtn._tpRightOverlay then
    slotBtn._tpRightOverlay:SetParent(nil)
    slotBtn._tpRightOverlay = nil
  end
  slotBtn._tpTeleportBuilt = true
  slotBtn._tpTeleportLayoutVersion = TP_SLOT_LAYOUT_VERSION
  local base = slotBtn:GetFrameLevel() or 20
  --- Secure debajo; overlay encima con clic izq «atravesado» hacia el secure (Retail) o franja derecha.
  local sec = CreateFrame("Button", "ChukieUi_TpDefaultSecure", slotBtn, "SecureActionButtonTemplate")
  sec:SetAllPoints()
  sec:SetFrameLevel(base + 8)
  sec:EnableMouse(true)
  sec:RegisterForClicks("LeftButtonUp")
  if sec.SetAttribute then
    sec:SetAttribute("useOnKeyDown", false)
  end
  sec:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local sech = sec.GetHighlightTexture and sec:GetHighlightTexture()
  if sech and sech.SetBlendMode then
    sech:SetBlendMode("ADD")
  end
  slotBtn._tpDefaultSecure = sec

  local ov = CreateFrame("Button", "ChukieUi_TpRightOverlay", slotBtn)
  ov:SetAllPoints()
  ov:SetFrameLevel(base + 28)
  ov:EnableMouse(true)
  ov:RegisterForClicks("RightButtonUp")
  if ov.SetNormalTexture then
    ov:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    local nt = ov.GetNormalTexture and ov:GetNormalTexture()
    if nt and nt.SetAlpha then
      nt:SetAlpha(0)
    end
  end
  ov:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local ovh = ov.GetHighlightTexture and ov:GetHighlightTexture()
  if ovh and ovh.SetBlendMode then
    ovh:SetBlendMode("ADD")
  end
  if ov.SetPassThroughButtons then
    pcall(function()
      ov:SetPassThroughButtons("LeftButton")
    end)
  else
    sec:ClearAllPoints()
    sec:SetPoint("TOPLEFT", slotBtn, "TOPLEFT", 0, 0)
    sec:SetPoint("BOTTOMRIGHT", slotBtn, "BOTTOMRIGHT", -40, 0)
    ov:ClearAllPoints()
    ov:SetPoint("TOPRIGHT", slotBtn, "TOPRIGHT", 0, 0)
    ov:SetPoint("BOTTOMRIGHT", slotBtn, "BOTTOMRIGHT", 0, 0)
    ov:SetWidth(44)
  end
  ov:SetScript("OnMouseUp", function(_, btn)
    if btn == "RightButton" then
      RW:ToggleTeleportPopup(slotBtn)
    end
  end)
  slotBtn._tpRightOverlay = ov

  ensureTeleportCooldownFrame(slotBtn, base)
  hookTeleportCooldownPulse(slotBtn)
end

local function sortTeleportEntriesAlphabetically(a, b)
  local la = strlower(tostring(a.label or a.key or ""))
  local lb = strlower(tostring(b.label or b.key or ""))
  if la ~= lb then
    return la < lb
  end
  return tostring(a.key or "") < tostring(b.key or "")
end

function RW:EnsureTeleportListModal()
  if self._teleportListModal then
    return self._teleportListModal
  end
  local f = CreateFrame("Frame", "ChukieUi_TeleportListModal", UIParent, "BackdropTemplate")
  f:SetSize(440, 500)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(250)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:Hide()
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", f, "TOP", 0, -14)
  title:SetText("Chukie UI — Teletransportes")
  f.title = title

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
  subtitle:SetWidth(400)
  subtitle:SetJustifyH("CENTER")
  subtitle:SetText(
    "Lista alfabética de lo que tu personaje puede usar ahora. Clic en una fila = ejecutar. "
      .. "En Opciones (Panel derecho) eliges el default del clic izquierdo y qué filas se listan."
  )
  f.subtitle = subtitle

  local closeTop = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeTop:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  closeTop:SetScript("OnClick", function()
    f:Hide()
  end)

  local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
  panel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -72)
  panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 52)
  panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  panel:SetBackdropColor(0, 0, 0, 0.35)

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 6)
  f.scroll = scroll

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)
  f.content = content
  f.rows = {}

  f.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  f.emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
  f.emptyText:SetWidth(360)
  f.emptyText:SetJustifyH("LEFT")
  f.emptyText:SetText(
    "No hay entradas listables: necesitas tener el ítem en la bolsa, el juguete aprendido o el hechizo conocido. "
      .. "Revisa en Opciones → Chukie UI → Panel derecho que no estén desactivadas las filas «En lista»."
  )
  f.emptyText:Hide()

  local closeBottom = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  closeBottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14)
  closeBottom:SetSize(100, 24)
  closeBottom:SetText("Cerrar")
  closeBottom:SetScript("OnClick", function()
    f:Hide()
  end)

  function f:RefreshFromAnchor(anchorSlot)
    if InCombatLockdown() then
      return
    end
    self._anchorSlot = anchorSlot
    local db = RW:DB()
    local valid = buildTeleportValidList()
    local forGrid = {}
    for i = 1, #valid do
      if isTeleportGridAllowed(db, valid[i]) then
        forGrid[#forGrid + 1] = valid[i]
      end
    end
    local prefer = getTeleportPreferredKey(db)
    local showList = dedupeTeleportEntries(forGrid, prefer)
    local sorted = {}
    for i = 1, #showList do
      sorted[i] = showList[i]
    end
    table.sort(sorted, sortTeleportEntriesAlphabetically)
    local rowH = 36
    local shown = 0
    for i = 1, #sorted do
      shown = shown + 1
      local entry = sorted[i]
      local row = self.rows[shown]
      if not row then
        row = CreateFrame("Button", "ChukieUiTpListRow" .. shown, self.content, "SecureActionButtonTemplate")
        row:SetHeight(rowH)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp")
        if row.SetAttribute then
          row:SetAttribute("useOnKeyDown", false)
        end
        row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        local hh = row.GetHighlightTexture and row:GetHighlightTexture()
        if hh and hh.SetBlendMode then
          hh:SetBlendMode("ADD")
        end
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.06, 0.06, 0.08, 0.65)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.icon:SetSize(24, 24)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.label:SetJustifyH("LEFT")
        row:SetScript("PostClick", function()
          f:Hide()
        end)
        self.rows[shown] = row
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -((shown - 1) * rowH) - 6)
      row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -4, -((shown - 1) * rowH) - 6)
      applyTeleportSecureAttributes(row, entry)
      row.icon:SetTexture(teleportDefaultIconTexture(entry))
      row.label:SetText(tostring(entry.label or entry.key or "?"))
      row:Show()
    end
    for j = shown + 1, #self.rows do
      local row = self.rows[j]
      row:Hide()
      if not InCombatLockdown() then
        clearTeleportSecureAttributes(row)
      end
    end
    self.emptyText:SetShown(shown == 0)
    local cw = math.max(280, (self.scroll:GetWidth() or 360) - 8)
    self.content:SetWidth(cw)
    self.content:SetHeight(math.max(80, shown * rowH + 16))
    self.scroll:SetVerticalScroll(0)
  end

  f:SetScript("OnHide", function(frame)
    frame._anchorSlot = nil
  end)

  if UISpecialFrames then
    table.insert(UISpecialFrames, "ChukieUi_TeleportListModal")
  end
  self._teleportListModal = f
  return f
end

function RW:HideTeleportPopup()
  local m = self._teleportListModal
  if m then
    m:Hide()
  end
end

function RW:ToggleTeleportPopup(anchorSlot)
  if InCombatLockdown() then
    return
  end
  local m = self:EnsureTeleportListModal()
  if m:IsShown() and m._anchorSlot == anchorSlot then
    m:Hide()
    return
  end
  m:RefreshFromAnchor(anchorSlot)
  m:Show()
end

function RW:ApplyTeleportReservedVisuals()
  local slot = self._buttons and self._buttons.reserved1
  if not slot or not self._host or not self._host:IsShown() then
    return
  end
  self:EnsureTeleportReservedSlot(slot)
  local db = self:DB()
  local valid = buildTeleportValidList()
  local prefer = getTeleportPreferredKey(db)
  local deduped = dedupeTeleportEntries(valid, prefer)
  local defaultEntry = nil
  if prefer then
    for i = 1, #deduped do
      if deduped[i].key == prefer then
        defaultEntry = deduped[i]
        break
      end
    end
  end
  if not defaultEntry and #deduped > 0 then
    defaultEntry = deduped[1]
  end
  local sec = slot._tpDefaultSecure
  slot._tpCooldownEntry = defaultEntry
  if defaultEntry and sec then
    if not InCombatLockdown() then
      sec:Show()
      applyTeleportSecureAttributes(sec, defaultEntry)
    else
      self._teleportRegenPending = true
    end
    applyIconState(slot, {
      texture = teleportDefaultIconTexture(defaultEntry),
      desat = false,
      slashed = false,
      r = 1,
      g = 1,
      b = 1,
    })
  else
    if sec then
      if not InCombatLockdown() then
        clearTeleportSecureAttributes(sec)
        sec:Hide()
      else
        self._teleportRegenPending = true
      end
    end
    applyIconState(slot, {
      texture = ICONS.teleport,
      desat = true,
      slashed = false,
      r = 0.65,
      g = 0.65,
      b = 0.72,
    })
  end
  self:RefreshTeleportReservedCooldown(slot)
  if self._teleportListModal and self._teleportListModal:IsShown() and self._teleportListModal._anchorSlot == slot then
    self._teleportListModal:RefreshFromAnchor(slot)
  end
  if self._teleportRegenPending and not InCombatLockdown() then
    self._teleportRegenPending = nil
    self:ApplyTeleportReservedVisuals()
  end
end

function RW:EnsureFrames()
  if self._host and self._host:IsForbidden() then
    self._host = nil
  end
  if not self._host then
    local host = CreateFrame("Frame", "ChukieUi_RightPanelWidgetsHost", UIParent)
    host:SetFrameStrata("MEDIUM")
    host:SetFrameLevel(20)
    host:EnableMouse(false)
    self._host = host
  end
  if not self._grid then
    local grid = CreateFrame("Frame", "ChukieUi_RightPanelWidgetsGrid", self._host)
    grid:SetFrameStrata("MEDIUM")
    grid:SetFrameLevel(21)
    self._grid = grid
  end
  self._buttons = self._buttons or {}
  for i = 1, #WIDGET_IDS do
    local id = WIDGET_IDS[i]
    local b = self._buttons[id]
    if not b or (b.IsForbidden and b:IsForbidden()) then
      b = makeButton(self._grid, "ChukieUi_RightWidget_" .. id)
      b._widgetId = id
      self._buttons[id] = b
    elseif b:GetParent() ~= self._grid then
      b:SetParent(self._grid)
    end
    if id == "reserved1" then
      self:EnsureTeleportReservedSlot(b)
    elseif id == "reserved2" or id == "reserved3" or id == "reserved4" then
      self:EnsureDynamicReservedSlot(b)
    end
  end
  local dt = self._buttons.datetime
  if not dt or (dt.IsForbidden and dt:IsForbidden()) then
    dt = makeButton(self._host, "ChukieUi_RightWidget_DateTime")
    dt._widgetId = "datetime"
    dt.icon:ClearAllPoints()
    dt.icon:SetPoint("LEFT", dt, "LEFT", 6, 0)
    dt.icon:SetSize(16, 16)
    dt.text = nil
    self._buttons.datetime = dt
  elseif dt:GetParent() ~= self._host then
    dt:SetParent(self._host)
  end
  if not dt.text then
    dt.text = dt:CreateFontString(nil, "OVERLAY")
    dt.text:SetPoint("LEFT", dt.icon, "RIGHT", 6, 0)
    dt.text:SetPoint("RIGHT", dt, "RIGHT", -6, 0)
    dt.text:SetJustifyH("CENTER")
    dt.text:SetShadowOffset(1, -1)
    dt.text:SetShadowColor(0, 0, 0, 0.95)
  end
  self._buttons.datetime = dt
  dt.icon:SetTexture(ICONS.datetime)
  dt.text:SetTextColor(0.95, 0.97, 1.0, 1.0)
  dt.text:Show()
end

function RW:GetLeftSlotFrame()
  if ns.RightPanel and ns.RightPanel.GetPanelTreeFrames then
    local left = ns.RightPanel:GetPanelTreeFrames()
    if left and left.GetWidth and (left:GetWidth() or 0) >= 2 then
      return left
    end
  end
  if ns.PanelCore and ns.PanelCore.GetSlotFrame then
    return ns.PanelCore:GetSlotFrame("rightPanel", "left")
  end
  return nil
end

function RW:Layout()
  self:EnsureFrames()
  local host = self._host
  local left = self:GetLeftSlotFrame()
  local db = self:DB()
  if db.enabled == false or not left then
    host:Hide()
    return
  end
  if host:GetParent() ~= left then
    host:SetParent(left)
  end
  host:ClearAllPoints()
  host:SetAllPoints(left)
  host:Show()

  local scale = getPanelScalePct() / 100
  local w = host:GetWidth() or 100
  local h = host:GetHeight() or 100
  local sidePad = clamp((tonumber(db.sidePad) or 8) * scale, 2, 30)
  local topPad = clamp((tonumber(db.topPad) or 6) * scale, 0, 28)
  local bottomPad = clamp((tonumber(db.dateBottomPad) or 6) * scale, 0, 24)
  local gap = clamp((tonumber(db.gridGap) or 4) * scale, 0, 20)
  local baseCell = clamp((tonumber(db.gridCellSize) or 46) * scale, 14, 96)
  local dateH = clamp((tonumber(db.dateHeight) or 24) * scale, 18, 46)
  local cols, rows = 2, 4

  local maxCellByWidth = (w - (sidePad * 2) - ((cols - 1) * gap)) / cols
  local maxCellByHeight = (h - topPad - bottomPad - dateH - 8 - ((rows - 1) * gap)) / rows
  local cell = clamp(math.floor(math.min(baseCell, maxCellByWidth, maxCellByHeight) + 0.5), 14, 110)
  local gridW = (cell * cols) + ((cols - 1) * gap)
  local gridH = (cell * rows) + ((rows - 1) * gap)

  self._grid:ClearAllPoints()
  self._grid:SetSize(gridW, gridH)
  self._grid:SetPoint("TOP", host, "TOP", 0, -topPad)

  for i = 1, #WIDGET_IDS do
    local id = WIDGET_IDS[i]
    local b = self._buttons[id]
    if not b then
      b = makeButton(self._grid, "ChukieUi_RightWidget_" .. id)
      b._widgetId = id
      self._buttons[id] = b
    end
    local col, row = getGridSlotBottomUpRightFirst(i, cols, rows)
    b:ClearAllPoints()
    b:SetSize(cell, cell)
    b:SetPoint("TOPLEFT", self._grid, "TOPLEFT", col * (cell + gap), -(row * (cell + gap)))
    local dynOn = ns.DynamicReservedSlots and ns.DynamicReservedSlots.IsFeatureEnabled and ns.DynamicReservedSlots.IsFeatureEnabled()
    if (id == "reserved2" or id == "reserved3" or id == "reserved4") and dynOn then
      b:Hide()
    else
      b:Show()
    end
    if id == "reserved1" then
      self:EnsureTeleportReservedSlot(b)
    elseif id == "reserved2" or id == "reserved3" or id == "reserved4" then
      self:EnsureDynamicReservedSlot(b)
    end
  end

  local dt = self._buttons.datetime
  dt:ClearAllPoints()
  dt:SetHeight(dateH)
  dt:SetWidth(math.max(30, w - (sidePad * 2)))
  dt:SetPoint("BOTTOM", host, "BOTTOM", 0, bottomPad)
  dt.icon:ClearAllPoints()
  dt.icon:SetPoint("LEFT", dt, "LEFT", 6, 0)
  dt.icon:SetSize(clamp(dateH - 8, 12, 24), clamp(dateH - 8, 12, 24))
  local autoSize = clamp(math.floor(dateH * 0.58 + 0.5), 10, 20)
  local fontSize = clamp(tonumber(db.dateFontSize) or autoSize, 8, 32)
  local fontPath = DATE_FONT_FACES[tonumber(db.dateFontFace) or 0] or STANDARD_TEXT_FONT
  local ok = dt.text:SetFont(fontPath, fontSize, "OUTLINE")
  if not ok then
    dt.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
  end
  dt.text:SetText(formatNowText())
  dt.text:Show()
  dt:Show()
end

function RW:ApplyBehaviorsAndVisuals()
  if not self._buttons or not self._host or not self._host:IsShown() then
    return
  end

  local inQueue = hasQueueActive()
  local hasTracking = hasTrackingContext()
  local hasMail = HasNewMail and HasNewMail() or false
  local hasDifficulty = hasDifficultyContext()

  local lfg = self._buttons.lfg
  applyIconState(lfg, {
    texture = ICONS.lfg_on,
    desat = false,
    pulse = inQueue,
    slashed = false,
    r = 1,
    g = 1,
    b = 1,
  })
  applyLfgEyeVisual(lfg, inQueue)
  lfg:SetScript("OnClick", openGroupFinderUi)

  local tracking = self._buttons.tracking
  applyIconState(tracking, {
    texture = ICONS.tracking,
    desat = not hasTracking,
    slashed = false,
    r = hasTracking and 1 or 0.72,
    g = hasTracking and 1 or 0.72,
    b = hasTracking and 1 or 0.72,
  })
  tracking:SetScript("OnClick", openTrackingUi)

  local mail = self._buttons.mail
  applyIconState(mail, {
    texture = hasMail and ICONS.mail_on or ICONS.mail_off,
    desat = not hasMail,
    slashed = false,
    r = hasMail and 1 or 0.72,
    g = hasMail and 1 or 0.72,
    b = hasMail and 1 or 0.72,
  })
  mail:SetScript("OnClick", showMailSummaryPopup)

  local diff = self._buttons.difficulty
  local diffVisual = getDungeonDifficultyVisual()
  local dr, dg, db = 1, 1, 1
  if diffVisual and diffVisual.tint then
    dr, dg, db = diffVisual.tint[1] or 1, diffVisual.tint[2] or 1, diffVisual.tint[3] or 1
  end
  applyIconState(diff, {
    texture = diffVisual and diffVisual.texture or ICONS.difficulty,
    texCoord = diffVisual and diffVisual.texCoord or nil,
    desat = not hasDifficulty,
    slashed = false,
    r = hasDifficulty and dr or 0.72,
    g = hasDifficulty and dg or 0.72,
    b = hasDifficulty and db or 0.72,
  })
  diff:SetScript("OnClick", openDifficultyUi)

  self:ApplyTeleportReservedVisuals()
  self:ApplyDynamicReservedVisuals()

  local dt = self._buttons.datetime
  dt.text:SetText(formatNowText())
  dt.text:Show()
  dt:SetScript("OnClick", openCalendarUi)
  dt:SetScript("OnMouseUp", openCalendarUi)

  self:ApplyMasque()
end

function RW:EnsureTicker()
  if self._ticker then
    return
  end
  self._ticker = C_Timer.NewTicker(1, function()
    if ns.RightPanelWidgets and ns.RightPanelWidgets._buttons and ns.RightPanelWidgets._buttons.datetime then
      ns.RightPanelWidgets:ApplyBehaviorsAndVisuals()
    end
  end)
end

function RW:EnsureEventFrame()
  if self._eventFrame then
    return
  end
  local f = CreateFrame("Frame")
  self._eventFrame = f
  local events = {
    "PLAYER_ENTERING_WORLD",
    "UPDATE_PENDING_MAIL",
    "MAIL_INBOX_UPDATE",
    "LFG_UPDATE",
    "LFG_PROPOSAL_UPDATE",
    "LFG_QUEUE_STATUS_UPDATE",
    "QUEUE_STATUS_UPDATE",
    "PLAYER_DIFFICULTY_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
    "BAG_UPDATE",
    "SPELLS_CHANGED",
    "TOYS_UPDATED",
    "NEW_TOY_ADDED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
    "UPDATE_EXTRA_ACTION",
    "QUEST_LOG_UPDATE",
    "QUEST_WATCH_LIST_CHANGED",
  }
  for i = 1, #events do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_REGEN_DISABLED" and ns.RightPanelWidgets and ns.RightPanelWidgets.HideTeleportPopup then
      ns.RightPanelWidgets:HideTeleportPopup()
    end
    if ev == "PLAYER_REGEN_ENABLED" and ns.RightPanelWidgets then
      local rw = ns.RightPanelWidgets
      if rw._dynRegenPending then
        rw:ApplyDynamicReservedVisuals()
      end
    end
    if ns.RightPanelWidgets then
      ns.RightPanelWidgets:Refresh()
    end
  end)
end

function RW:Refresh()
  self:Layout()
  self:ApplyBehaviorsAndVisuals()
  self:EnsureTicker()
  self:EnsureEventFrame()
end

