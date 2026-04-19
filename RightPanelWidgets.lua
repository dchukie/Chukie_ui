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
  lfg_off = 136140,
  lfg_on = "Interface\\LFGFrame\\LFG-Eye",
  tracking = "Interface\\Icons\\Ability_Tracking",
  mail_off = "Interface\\Icons\\INV_Letter_15",
  mail_on = "Interface\\Icons\\INV_Letter_17",
  difficulty = "Interface\\Icons\\Achievement_ChallengeMode_Bronze",
  reserved = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}

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

local function hasTrackingContext()
  if MinimapCluster and MinimapCluster.TrackingFrame then
    return true
  end
  return MiniMapTrackingButton ~= nil or MiniMapTracking ~= nil or MiniMapTrackingDropDown ~= nil
end

local function hasDifficultyContext()
  local inInst = IsInInstance and select(1, IsInInstance())
  return inInst == true
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

local function openTrackingUi()
  local tf = MinimapCluster and MinimapCluster.TrackingFrame
  if tf and tf.Button and tf.Button.Click then
    tf.Button:Click()
    return
  end
  if MiniMapTrackingButton and MiniMapTrackingButton.Click then
    MiniMapTrackingButton:Click()
    return
  end
  if MiniMapTrackingDropDown and ToggleDropDownMenu then
    ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor", 3, -3)
  end
end

local function openDifficultyUi()
  for _, f in ipairs({ MiniMapChallengeMode, MiniMapInstanceDifficulty, GuildInstanceDifficulty }) do
    if f and f.IsShown and f:IsShown() and f.Click then
      f:Click()
      return
    end
  end
  openGroupFinderUi()
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
  if state.texture then
    icon:SetTexture(state.texture)
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
    b:Show()
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
    texture = inQueue and ICONS.lfg_on or ICONS.lfg_off,
    desat = not inQueue,
    pulse = inQueue,
    slashed = not inQueue,
    r = inQueue and 1 or 0.72,
    g = inQueue and 1 or 0.72,
    b = inQueue and 1 or 0.72,
  })
  lfg:SetScript("OnClick", openGroupFinderUi)

  local tracking = self._buttons.tracking
  applyIconState(tracking, {
    texture = ICONS.tracking,
    desat = not hasTracking,
    slashed = not hasTracking,
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
  applyIconState(diff, {
    texture = ICONS.difficulty,
    desat = not hasDifficulty,
    slashed = not hasDifficulty,
    r = hasDifficulty and 1 or 0.72,
    g = hasDifficulty and 1 or 0.72,
    b = hasDifficulty and 1 or 0.72,
  })
  diff:SetScript("OnClick", openDifficultyUi)

  for _, id in ipairs({ "reserved1", "reserved2", "reserved3", "reserved4" }) do
    local b = self._buttons[id]
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
  }
  for i = 1, #events do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function()
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

