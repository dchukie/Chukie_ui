--[[ Barras de acción estilo Dominos (fase 1).
     - Panel izquierdo: barras 1–4 (filas horizontales).
     - Skyriding ([bonusbar:5]): paginan a barras 8–11.
     - Panel derecho: barra 6 en grilla 2×4 (8 botones).
     IDs de acción = numeración Dominos: barra N botón i → (N-1)*12+i.
     Retail 12+: sin ActionBarActionEventsFrame; visual manual (secret-safe). ]]

local _, ns = ...

local AB = {}
ns.ActionBars = AB

local SHOWGRID_REASON = 32
local BUTTONS_PER_BAR = 12
local LEFT_BAR_IDS = { 1, 2, 3, 4 }
local RIGHT_BAR_ID = 6
local SKY_PAGE = { [1] = 8, [2] = 9, [3] = 10, [4] = 11 }

-- Condición segura usada por Dominos/Bartender para skyriding.
local SKYRIDING_COND = "[bonusbar:5]"

-- Defaults de teclas (barras 1–4, botones 1–5). Barra 4 sin tecla en el 5.º.
local DEFAULT_KEYS = {
  [1] = { "1", "2", "3", "4", "5" },
  [2] = { "Q", "W", "E", "R", "T" },
  [3] = { "A", "S", "D", "F", "G" },
  [4] = { "Z", "X", "C", "V" },
}

local STOCK_BARS_TO_HIDE = {
  "MainActionBar",
  "MultiBarBottomLeft",
  "MultiBarBottomRight",
  "MultiBarRight",
  "MultiBarLeft",
}

local function db()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return {}
  end
  p.actionBars = p.actionBars or {}
  return p.actionBars
end

function AB.IsEnabled()
  local d = db()
  return d.enabled ~= false
end

local function isSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

local function pageOffset(page)
  page = tonumber(page) or 1
  local offset = (page - 1) * BUTTONS_PER_BAR
  -- Dominos: salta la página 12 (slots de possess no usables en esta numeración).
  if offset >= 132 then
    offset = offset + BUTTONS_PER_BAR
  end
  return offset
end

local function actionFor(page, index)
  return pageOffset(page) + index
end

local function setShowGridInsecure(btn, show, reason)
  if not btn or InCombatLockdown() then
    return
  end
  reason = reason or SHOWGRID_REASON
  local value = tonumber(btn:GetAttribute("showgrid")) or 0
  local prev = value
  if show then
    if value % (reason * 2) < reason then
      value = value + reason
    end
  elseif value % (reason * 2) >= reason then
    value = value - reason
  end
  if prev ~= value then
    btn:SetAttribute("showgrid", value)
  end
  local action = tonumber(btn:GetAttribute("action")) or 0
  local has = HasAction and HasAction(action)
  if isSecret(has) then
    has = false
  end
  local shouldShow = (value > 0 or has) and not btn:GetAttribute("statehidden")
  if shouldShow then
    btn:Show()
  else
    btn:Hide()
  end
end

local function disconnectBlizzardActionEvents(btn)
  if not btn then
    return
  end
  if ActionBarActionEventsFrame and ActionBarActionEventsFrame.UnregisterFrame then
    pcall(function()
      ActionBarActionEventsFrame:UnregisterFrame(btn)
    end)
  end
  if btn.UnregisterAllEvents then
    btn:UnregisterAllEvents()
  end
  btn:SetScript("OnEvent", nil)
end

local function applyActionCooldown(cd, action)
  if not cd or not action then
    return
  end
  if cd.SetCooldownFromDurationObject and C_ActionBar and C_ActionBar.GetActionCooldownDuration then
    local ok, dur = pcall(C_ActionBar.GetActionCooldownDuration, action)
    if ok and dur then
      pcall(cd.SetCooldownFromDurationObject, cd, dur)
      return
    end
    pcall(function()
      cd:Clear()
    end)
    return
  end
  local start, duration, enable, modRate = GetActionCooldown(action)
  if isSecret(start) or isSecret(duration) or isSecret(modRate) then
    pcall(function()
      cd:Clear()
    end)
    return
  end
  if enable and duration and duration > 0 then
    pcall(cd.SetCooldown, cd, start or 0, duration, modRate or 1)
  else
    pcall(function()
      cd:Clear()
    end)
  end
end

local function skinButton(btn)
  if btn.NormalTexture then
    btn.NormalTexture:SetAlpha(0.35)
  end
  if btn.NewActionTexture then
    btn.NewActionTexture:Hide()
  end
  if btn.Name then
    btn.Name:Hide()
  end
end

function AB:UpdateButtonVisual(btn)
  if not btn then
    return
  end
  -- Preferir atributo (ID=0); si Blizzard expone CalculateAction, usarlo como fallback.
  local action = tonumber(btn:GetAttribute("action")) or 0
  if action <= 0 and ActionButton_CalculateAction then
    local ok, calc = pcall(ActionButton_CalculateAction, btn)
    if ok and type(calc) == "number" then
      action = calc
    end
  end
  if action <= 0 then
    action = btn._chukieAction or 0
  end
  if action <= 0 then
    return
  end
  btn._chukieAction = action

  local has = false
  if HasAction then
    local okH, h = pcall(HasAction, action)
    if okH and not isSecret(h) then
      has = h and true or false
    end
  end

  if btn.icon then
    local tex = GetActionTexture and GetActionTexture(action)
    if isSecret(tex) then
      -- skip
    elseif tex then
      btn.icon:SetTexture(tex)
      btn.icon:Show()
    else
      btn.icon:SetTexture(nil)
      if not has then
        btn.icon:Hide()
      end
    end
  end

  if btn.cooldown then
    applyActionCooldown(btn.cooldown, action)
  end

  if btn.Count then
    local shown = false
    if C_ActionBar and C_ActionBar.GetActionDisplayCount then
      local ok, display = pcall(C_ActionBar.GetActionDisplayCount, action)
      if ok then
        if isSecret(display) then
          -- skip
        elseif type(display) == "string" and display ~= "" then
          btn.Count:SetText(display)
          btn.Count:Show()
          shown = true
        end
      end
    end
    if not shown and GetActionCount then
      local ok, c = pcall(GetActionCount, action)
      if ok and not isSecret(c) then
        local n = tonumber(c)
        if n and n > 1 then
          btn.Count:SetText(n)
          btn.Count:Show()
          shown = true
        elseif n and IsConsumableAction and IsConsumableAction(action) then
          btn.Count:SetText(n)
          btn.Count:Show()
          shown = true
        end
      end
    end
    if not shown then
      btn.Count:SetText("")
    end
  end

  if btn.icon and IsUsableAction then
    local ok, isUsable, notEnoughMana = pcall(IsUsableAction, action)
    if ok and not isSecret(isUsable) and not isSecret(notEnoughMana) then
      if isUsable then
        btn.icon:SetVertexColor(1, 1, 1)
      elseif notEnoughMana then
        btn.icon:SetVertexColor(0.5, 0.5, 1)
      else
        btn.icon:SetVertexColor(0.4, 0.4, 0.4)
      end
    else
      btn.icon:SetVertexColor(1, 1, 1)
    end
  end
end

function AB:UpdateAllVisuals()
  if not self._bars then
    return
  end
  for _, bar in pairs(self._bars) do
    if bar and bar.buttons then
      for i = 1, #bar.buttons do
        self:UpdateButtonVisual(bar.buttons[i])
      end
    end
  end
end

function AB:EnsureVisualEvents()
  if self._visEv then
    return
  end
  local ev = CreateFrame("Frame")
  self._visEv = ev
  local events = {
    "ACTIONBAR_UPDATE",
    "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_SHAPESHIFT_FORM",
    "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "SPELL_UPDATE_USABLE",
    "BAG_UPDATE_COOLDOWN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "UPDATE_BINDINGS",
  }
  for i = 1, #events do
    pcall(ev.RegisterEvent, ev, events[i])
  end
  ev:SetScript("OnEvent", function(_, evName)
    if evName == "UPDATE_BINDINGS" then
      AB:UpdateAllBindings()
      return
    end
    AB:UpdateAllVisuals()
  end)
end

local function bindingCommand(barId, index)
  return string.format("CLICK ChukieUi_AB%d_B%d:LeftButton", barId, index)
end

local function addCastOnKeyPress(btn)
  if btn._hotkeyBind then
    return
  end
  local bind = CreateFrame("Button", btn:GetName() .. "Hotkey", btn, "SecureActionButtonTemplate")
  bind:SetAttribute("type", "action")
  bind:SetAttribute("useparent-action", true)
  bind:SetAttribute("useparent-unit", true)
  bind:SetAttribute("useparent-checkselfcast", true)
  bind:SetAttribute("useparent-checkfocuscast", true)
  bind:SetAttribute("useparent-checkmouseovercast", true)
  bind:RegisterForClicks("AnyUp", "AnyDown")
  bind:SetScript("PreClick", function(self, _, down)
    local owner = self:GetParent()
    if not owner then
      return
    end
    if down then
      if owner:GetButtonState() == "NORMAL" then
        owner:SetButtonState("PUSHED")
      end
    else
      if owner:GetButtonState() == "PUSHED" then
        owner:SetButtonState("NORMAL")
      end
    end
  end)
  btn._hotkeyBind = bind
end

local function updateHotkeyText(btn)
  if not btn or not btn.HotKey then
    return
  end
  local cmd = btn._commandName
  local key = cmd and GetBindingKey and GetBindingKey(cmd)
  if key and key ~= "" then
    local text = GetBindingText and GetBindingText(key, 1) or key
    btn.HotKey:SetText(text)
    btn.HotKey:Show()
    btn.HotKey:SetAlpha(0.9)
  else
    btn.HotKey:SetText("")
  end
end

local function updateOverrideBindings(btn)
  if not btn or InCombatLockdown() then
    return
  end
  addCastOnKeyPress(btn)
  local bind = btn._hotkeyBind
  if not bind then
    return
  end
  ClearOverrideBindings(bind)
  local cmd = btn._commandName
  if not cmd or not GetBindingKey then
    updateHotkeyText(btn)
    return
  end
  local keys = { GetBindingKey(cmd) }
  local name = bind:GetName()
  for i = 1, #keys do
    if keys[i] then
      SetOverrideBindingClick(bind, false, keys[i], name, "LeftButton")
    end
  end
  updateHotkeyText(btn)
end

function AB:EnsureDefaultKeybinds()
  if InCombatLockdown() or not SetBinding then
    return
  end
  local d = db()
  if d.applyDefaultKeybinds == false then
    return
  end
  if d._defaultKeybindsApplied then
    return
  end
  local changed = false
  for barId = 1, 4 do
    local keys = DEFAULT_KEYS[barId]
    for i = 1, #keys do
      local cmd = bindingCommand(barId, i)
      if not GetBindingKey(cmd) then
        if SetBinding(keys[i], cmd) then
          changed = true
        end
      end
    end
  end
  d._defaultKeybindsApplied = true
  if changed and SaveBindings and GetCurrentBindingSet then
    pcall(SaveBindings, GetCurrentBindingSet())
  end
end

function AB:UpdateAllBindings()
  if InCombatLockdown() or not self._bars then
    return
  end
  for barId = 1, 4 do
    local bar = self._bars[tostring(barId)]
    if bar and bar.buttons then
      for i = 1, math.min(5, #bar.buttons) do
        updateOverrideBindings(bar.buttons[i])
      end
    end
  end
end

local function ensureButton(bar, barId, index)
  local name = string.format("ChukieUi_AB%d_B%d", barId, index)
  local btn = _G[name]
  if not btn then
    btn = CreateFrame("CheckButton", name, bar, "ActionBarButtonTemplate")
  end
  disconnectBlizzardActionEvents(btn)
  if not btn._chukieNativeW then
    local w = btn:GetWidth() or 0
    local h = btn:GetHeight() or 0
    btn._chukieNativeW = w > 1 and w or 45
    btn._chukieNativeH = h > 1 and h or btn._chukieNativeW
  end
  btn._commandName = bindingCommand(barId, index)
  if not InCombatLockdown() then
    -- ID>0 hace que Blizzard calcule action con GetActionBarPage() (barra 1) al hover/Update.
    btn:SetID(0)
    btn:SetAttribute("type", "action")
    btn:SetAttribute("index", index)
    btn:SetAttribute("action", actionFor(barId, index))
    btn:SetAttribute("checkselfcast", true)
    btn:SetAttribute("checkfocuscast", true)
    btn:SetAttribute("checkmouseovercast", true)
    btn:SetAttribute("statehidden", false)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:EnableMouseWheel(true)
    setShowGridInsecure(btn, true, SHOWGRID_REASON)
  end
  btn._chukieBarId = barId
  btn._chukieIndex = index
  btn._chukieAction = actionFor(barId, index)
  skinButton(btn)
  if barId <= 4 and index <= 5 then
    addCastOnKeyPress(btn)
  end
  if not btn._chukieAttrHook then
    btn._chukieAttrHook = true
    btn:HookScript("OnAttributeChanged", function(self, attr)
      if attr == "action" then
        AB:UpdateButtonVisual(self)
      end
    end)
    btn:HookScript("OnEnter", function(self)
      AB:UpdateButtonVisual(self)
    end)
  end
  AB:UpdateButtonVisual(btn)
  if barId <= 4 and index <= 5 and not InCombatLockdown() then
    updateOverrideBindings(btn)
  end
  return btn
end

local function applySecurePaging(bar, barId)
  if InCombatLockdown() then
    return
  end
  local skyPage = SKY_PAGE[barId]
  if not skyPage or db().skyridingPaging == false then
    UnregisterStateDriver(bar, "page")
    bar:SetAttribute("state-page", barId)
    bar:Execute([[
      local page = self:GetAttribute("state-page") or 1
      local offset = (page - 1) * 12
      if offset >= 132 then
        offset = offset + 12
      end
      self:SetAttribute("actionOffset", offset)
      local n = self:GetAttribute("numButtons") or 12
      for i = 1, n do
        local b = self:GetFrameRef("btn" .. i)
        if b then
          local idx = b:GetAttribute("index") or i
          b:SetAttribute("action", idx + offset)
        end
      end
    ]])
    return
  end

  bar:SetAttribute(
    "_onstate-page",
    [[
    local page = tonumber(newstate) or 1
    local offset = (page - 1) * 12
    if offset >= 132 then
      offset = offset + 12
    end
    self:SetAttribute("actionOffset", offset)
    local n = self:GetAttribute("numButtons") or 12
    for i = 1, n do
      local b = self:GetFrameRef("btn" .. i)
      if b then
        local idx = b:GetAttribute("index") or i
        b:SetAttribute("action", idx + offset)
      end
    end
  ]]
  )
  RegisterStateDriver(bar, "page", string.format("%s %d; %d", SKYRIDING_COND, skyPage, barId))
end

local function layoutBarButtons(bar, cols, buttonSize, spacing)
  local buttons = bar.buttons
  local n = #buttons
  cols = math.max(1, cols or n)
  local rows = math.ceil(n / cols)
  local gap = spacing or 2
  local size = buttonSize or 36
  for i = 1, n do
    local btn = buttons[i]
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    btn:ClearAllPoints()
    -- ActionBarButtonTemplate fija cromado (Normal/borde) en tamaño nativo;
    -- SetSize solo no lo escala (IgnoreParentScale). Escalar el botón entero.
    local native = btn._chukieNativeW
    if not native or native < 1 then
      native = btn:GetWidth() or 0
      if native < 1 then
        native = 45
      end
      btn._chukieNativeW = native
      btn._chukieNativeH = btn:GetHeight() > 0 and btn:GetHeight() or native
    end
    local nativeH = btn._chukieNativeH or native
    btn:SetSize(native, nativeH)
    btn:SetScale(size / native)
    for _, r in ipairs({
      btn.icon,
      btn.Icon,
      btn.NormalTexture,
      btn.GetNormalTexture and btn:GetNormalTexture() or nil,
      btn.PushedTexture,
      btn.GetPushedTexture and btn:GetPushedTexture() or nil,
      btn.HighlightTexture,
      btn.GetHighlightTexture and btn:GetHighlightTexture() or nil,
      btn.CheckedTexture,
      btn.GetCheckedTexture and btn:GetCheckedTexture() or nil,
      btn.Flash,
      btn.Border,
      btn.NewActionTexture,
      btn.SlotBackground,
      btn.IconMask,
    }) do
      if r and r.SetIgnoreParentScale then
        r:SetIgnoreParentScale(false)
      end
    end
    btn:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (size + gap), -row * (size + gap))
    if not InCombatLockdown() then
      btn:SetAttribute("statehidden", false)
    end
    btn:Show()
  end
  local w = cols * size + math.max(0, cols - 1) * gap
  local h = rows * size + math.max(0, rows - 1) * gap
  bar:SetSize(math.max(1, w), math.max(1, h))
end

function AB:GetMasqueGroup()
  if db().useMasque == false then
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
    self._masqueGroup = msq:Group("Chukie UI", "ActionBars")
  end
  return self._masqueGroup
end

function AB:MasqueStrip()
  local grp = self._masqueGroup
  if not grp or type(grp.RemoveButton) ~= "function" or not self._bars then
    return
  end
  for _, bar in pairs(self._bars) do
    if bar and bar.buttons then
      for i = 1, #bar.buttons do
        grp:RemoveButton(bar.buttons[i])
      end
    end
  end
end

function AB:MasqueApply()
  if db().useMasque == false then
    self:MasqueStrip()
    return
  end
  local grp = self:GetMasqueGroup()
  if not grp or not self._bars then
    self:MasqueStrip()
    return
  end
  self:MasqueStrip()
  for _, bar in pairs(self._bars) do
    if bar and bar:IsShown() and bar.buttons then
      for i = 1, #bar.buttons do
        local btn = bar.buttons[i]
        if btn and btn:IsShown() and grp.AddButton then
          -- Tipo Action: Masque toma Icon/Normal/borde del ActionBarButtonTemplate.
          grp:AddButton(btn, nil, "Action")
        end
      end
    end
  end
  if grp.ReSkin then
    grp:ReSkin()
  end
end

function AB:EnsureBar(barId, numButtons)
  self._bars = self._bars or {}
  local key = tostring(barId)
  local bar = self._bars[key]
  if not bar then
    bar = CreateFrame("Frame", "ChukieUi_ActionBar" .. barId, UIParent, "SecureHandlerStateTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(50)
    bar.barId = barId
    bar.buttons = {}
    self._bars[key] = bar
  end
  if InCombatLockdown() then
    self._pendingRefresh = true
    return bar
  end

  numButtons = math.max(1, math.min(BUTTONS_PER_BAR, tonumber(numButtons) or BUTTONS_PER_BAR))
  bar:SetAttribute("numButtons", numButtons)

  for i = 1, numButtons do
    local btn = ensureButton(bar, barId, i)
    if btn:GetParent() ~= bar then
      btn:SetParent(bar)
    end
    bar:SetFrameRef("btn" .. i, btn)
    bar.buttons[i] = btn
  end
  for i = numButtons + 1, #bar.buttons do
    local btn = bar.buttons[i]
    if btn then
      btn:SetAttribute("statehidden", true)
      btn:Hide()
    end
  end
  -- trim extras from table length used by layout
  for i = #bar.buttons, numButtons + 1, -1 do
    bar.buttons[i] = nil
  end

  if SKY_PAGE[barId] then
    applySecurePaging(bar, barId)
  else
    UnregisterStateDriver(bar, "page")
    local offset = pageOffset(barId)
    bar:SetAttribute("actionOffset", offset)
    for i = 1, numButtons do
      bar.buttons[i]:SetAttribute("action", actionFor(barId, i))
    end
  end

  return bar
end

function AB:HideStockBars()
  if InCombatLockdown() then
    return
  end
  for i = 1, #STOCK_BARS_TO_HIDE do
    local f = _G[STOCK_BARS_TO_HIDE[i]]
    if f then
      if f.SetAttribute then
        pcall(function()
          f:SetAttribute("statehidden", true)
        end)
      end
      if f.Hide then
        f:Hide()
      end
      if f.actionButtons and type(f.actionButtons) == "table" then
        for _, button in pairs(f.actionButtons) do
          if button then
            pcall(function()
              if button.SetAttribute then
                button:SetAttribute("statehidden", true)
              end
              button:Hide()
            end)
          end
        end
      end
    end
  end
  -- Botones sueltos de la barra principal.
  for i = 1, 12 do
    local b = _G["ActionButton" .. i]
    if b then
      pcall(function()
        if b.SetAttribute then
          b:SetAttribute("statehidden", true)
        end
        b:Hide()
      end)
    end
  end
end

function AB:HideAll()
  if not self._bars then
    return
  end
  for _, bar in pairs(self._bars) do
    if bar then
      bar:Hide()
    end
  end
end

local function getLeftHost()
  if ns.LeftPanel and ns.LeftPanel._group then
    return ns.LeftPanel._group
  end
  return UIParent
end

local function getRightHost()
  if ns.RightPanel and ns.RightPanel.EnsureRightPanel then
    local h = ns.RightPanel:EnsureRightPanel()
    if h then
      return h
    end
  end
  return _G.ChukieUi_RightPanel or UIParent
end

function AB:LayoutLeftBars()
  local d = db()
  if not self.IsEnabled() or d.leftEnabled == false then
    for _, id in ipairs(LEFT_BAR_IDS) do
      local bar = self._bars and self._bars[tostring(id)]
      if bar then
        bar:Hide()
      end
    end
    return
  end

  local host = getLeftHost()
  local numButtons = math.max(1, math.min(12, tonumber(d.leftNumButtons) or 6))
  local size = math.max(18, math.min(64, tonumber(d.leftButtonSize) or 36))
  local gap = math.max(0, math.min(16, tonumber(d.leftSpacing) or 2))
  local barGap = math.max(0, math.min(24, tonumber(d.leftBarSpacing) or 4))
  local padX = tonumber(d.leftOffsetX) or 8
  local padY = tonumber(d.leftOffsetY) or 8

  local totalH = 0
  local bars = {}
  for i = 1, #LEFT_BAR_IDS do
    local id = LEFT_BAR_IDS[i]
    local bar = self:EnsureBar(id, numButtons)
    layoutBarButtons(bar, numButtons, size, gap)
    if bar:GetParent() ~= host then
      bar:SetParent(host)
    end
    bar:Show()
    bars[i] = bar
    totalH = totalH + bar:GetHeight()
    if i < #LEFT_BAR_IDS then
      totalH = totalH + barGap
    end
  end

  -- Barra 1 arriba → 4 abajo (como Dominos en el screenshot).
  local y = padY + totalH
  for i = 1, #bars do
    local bar = bars[i]
    y = y - bar:GetHeight()
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", padX, y)
    if i < #bars then
      y = y - barGap
    end
  end
end

function AB:LayoutRightBar6()
  local d = db()
  if not self.IsEnabled() or d.rightBar6Enabled == false then
    local bar = self._bars and self._bars[tostring(RIGHT_BAR_ID)]
    if bar then
      bar:Hide()
    end
    return
  end

  local host = getRightHost()
  local numButtons = math.max(1, math.min(12, tonumber(d.rightBar6NumButtons) or 8))
  local cols = math.max(1, math.min(8, tonumber(d.rightBar6Cols) or 2))
  local size = math.max(18, math.min(64, tonumber(d.rightBar6ButtonSize) or 36))
  local gap = math.max(0, math.min(16, tonumber(d.rightBar6Spacing) or 2))
  local ox = tonumber(d.rightBar6OffsetX) or 8
  local oy = tonumber(d.rightBar6OffsetY) or 8

  local bar = self:EnsureBar(RIGHT_BAR_ID, numButtons)
  layoutBarButtons(bar, cols, size, gap)
  if bar:GetParent() ~= host then
    bar:SetParent(host)
  end
  bar:ClearAllPoints()
  bar:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", ox, oy)
  bar:Show()
end

function AB:Refresh()
  if InCombatLockdown() then
    self._pendingRefresh = true
    return
  end
  self._pendingRefresh = nil

  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or not p.enabled or not self.IsEnabled() then
    self:MasqueStrip()
    self:HideAll()
    return
  end

  self:EnsureVisualEvents()
  self:HideStockBars()
  self:EnsureDefaultKeybinds()
  self:LayoutLeftBars()
  self:LayoutRightBar6()
  self:UpdateAllBindings()
  self:MasqueApply()
  self:UpdateAllVisuals()
end

function AB:OnRegenEnabled()
  if self._pendingRefresh then
    self:Refresh()
  end
end

local combatEv = CreateFrame("Frame")
combatEv:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEv:RegisterEvent("ADDON_LOADED")
combatEv:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "Masque" then
    if AB.IsEnabled and AB.IsEnabled() then
      AB:Refresh()
    end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    AB:OnRegenEnabled()
  end
end)
