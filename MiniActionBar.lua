--[[ Mini barra de 3 acciones (estilo Dominos) en reserved2–4.
     Enlaza slots Blizzard 145–147 (Action Bar 6 / MultiBar5).
     Nota: 133–144 son Bonus Bar 6 (p. ej. tótems / utilidad de clase), no sirven
     para acciones libres; Dominos también salta ese rango. ]]

local _, ns = ...

local M = {}
ns.MiniActionBar = M

local SHOWGRID_REASON = 32
local SLOT_DEFS = {
  { index = 1, slot = 145, name = "ChukieUi_MiniAct1", widgetId = "reserved2", command = "MULTIACTIONBAR5BUTTON1" },
  { index = 2, slot = 146, name = "ChukieUi_MiniAct2", widgetId = "reserved3", command = "MULTIACTIONBAR5BUTTON2" },
  { index = 3, slot = 147, name = "ChukieUi_MiniAct3", widgetId = "reserved4", command = "MULTIACTIONBAR5BUTTON3" },
}

local STOCK_HIDE = {
  "MultiBar5",
  "MultiBar5ActionButton1",
  "MultiBar5ActionButton2",
  "MultiBar5ActionButton3",
}

local function db()
  if ns.Profile and ns.Profile.GetRightPanelWidgetsModel then
    return ns.Profile:GetRightPanelWidgetsModel()
  end
  return {}
end

function M.IsEnabled()
  local d = db()
  return d.miniActionBarEnabled ~= false
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
  local shouldShow = (value > 0 or has) and not btn:GetAttribute("statehidden")
  if shouldShow then
    btn:Show()
  else
    btn:Hide()
  end
end

local function updateOverrideBindings(btn)
  if not btn or not btn._hotkeyBind or InCombatLockdown() then
    return
  end
  local bind = btn._hotkeyBind
  ClearOverrideBindings(bind)
  local cmd = btn._commandName
  if not cmd or not GetBindingKey then
    return
  end
  local keys = { GetBindingKey(cmd) }
  local name = bind:GetName()
  for i = 1, #keys do
    if keys[i] then
      SetOverrideBindingClick(bind, false, keys[i], name, "LeftButton")
    end
  end
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

local function skinButtonForCell(btn)
  if btn.NormalTexture then
    btn.NormalTexture:SetAlpha(0.35)
  end
  if btn.NewActionTexture then
    btn.NewActionTexture:Hide()
  end
  if btn.SpellHighlightTexture then
    -- leave Blizzard highlight/glow intact
  end
  if btn.HotKey then
    btn.HotKey:SetAlpha(0.85)
  end
  if btn.Name then
    btn.Name:Hide()
  end
end

local function ensureButton(def)
  local btn = _G[def.name]
  if not btn then
    btn = CreateFrame("CheckButton", def.name, UIParent, "ActionBarButtonTemplate")
  end
  btn:SetID(0)
  btn:SetAttribute("action", def.slot)
  btn:SetAttribute("commandName", def.command)
  btn:SetAttribute("useparent-checkfocuscast", true)
  btn:SetAttribute("useparent-checkmouseovercast", true)
  btn:SetAttribute("useparent-checkselfcast", true)
  btn:SetAttribute("statehidden", false)
  btn:EnableMouseWheel(true)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn._commandName = def.command
  btn._miniSlot = def.slot
  btn._miniWidgetId = def.widgetId
  addCastOnKeyPress(btn)
  skinButtonForCell(btn)
  if ActionBarActionEventsFrame and ActionBarActionEventsFrame.RegisterFrame then
    pcall(function()
      ActionBarActionEventsFrame:RegisterFrame(btn)
    end)
  end
  if btn.UpdateAction then
    pcall(function()
      btn:UpdateAction()
    end)
  end
  setShowGridInsecure(btn, true, SHOWGRID_REASON)
  updateOverrideBindings(btn)
  return btn
end

function M:HideStockMultiBar5()
  if InCombatLockdown() then
    self._pendingHideStock = true
    return
  end
  self._pendingHideStock = nil
  for i = 1, #STOCK_HIDE do
    local f = _G[STOCK_HIDE[i]]
    if f then
      if f.UnregisterAllEvents and i == 1 then
        -- keep MultiBar5 quiet; do not wipe shared events from ActionBarActionEventsFrame
        pcall(function()
          f:UnregisterAllEvents()
        end)
      end
      if f.SetAttribute then
        pcall(function()
          f:SetAttribute("statehidden", true)
        end)
      end
      if f.Hide then
        f:Hide()
      end
      if f.SetParent and i > 1 then
        -- leave stock action buttons parented but hidden
      end
    end
  end
  local bar = _G.MultiBar5
  if bar and bar.actionButtons and type(bar.actionButtons) == "table" then
    for _, button in pairs(bar.actionButtons) do
      if button and button.SetAttribute then
        pcall(function()
          button:SetAttribute("statehidden", true)
          button:Hide()
        end)
      end
    end
  end
end

function M:EnsureButtons()
  if InCombatLockdown() then
    self._pendingEnsure = true
    return self._buttons
  end
  self._pendingEnsure = nil
  self._buttons = self._buttons or {}
  for i = 1, #SLOT_DEFS do
    local def = SLOT_DEFS[i]
    local btn = ensureButton(def)
    self._buttons[def.widgetId] = btn
    self._buttons[i] = btn
  end
  self:HideStockMultiBar5()
  return self._buttons
end

local function fitButtonToSlot(btn, slotBtn)
  if not btn or not slotBtn then
    return
  end
  btn:SetAttribute("statehidden", false)
  btn:SetParent(slotBtn)
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", slotBtn, "CENTER", 0, 0)
  local cell = math.max(14, math.floor((slotBtn:GetWidth() or 36) + 0.5))
  local base = btn:GetWidth() or 0
  if base < 1 then
    base = 45
  end
  btn:SetScale(cell / base)
  btn:SetFrameLevel((slotBtn:GetFrameLevel() or 20) + 10)
  btn:EnableMouse(true)
  btn:Show()
end

local function prepareProxySlot(slotBtn)
  if not slotBtn then
    return
  end
  if slotBtn.icon then
    slotBtn.icon:Hide()
  end
  if slotBtn._slash then
    slotBtn._slash:Hide()
  end
  if slotBtn.bg then
    slotBtn.bg:SetAlpha(0.2)
  end
  slotBtn:SetScript("OnClick", nil)
  if slotBtn.EnableMouse then
    slotBtn:EnableMouse(false)
  end
  if slotBtn._dynDefaultSecure and not InCombatLockdown() then
    slotBtn._dynDefaultSecure:Hide()
    slotBtn._dynDefaultSecure:EnableMouse(false)
  end
end

function M:AttachToSlots(buttonsById)
  if not self.IsEnabled() then
    return
  end
  if InCombatLockdown() then
    self._pendingAttach = true
    return
  end
  self._pendingAttach = nil
  self:EnsureButtons()
  for i = 1, #SLOT_DEFS do
    local def = SLOT_DEFS[i]
    local slotBtn = buttonsById and buttonsById[def.widgetId]
    local act = self._buttons and self._buttons[def.widgetId]
    if slotBtn and act then
      prepareProxySlot(slotBtn)
      if not InCombatLockdown() then
        slotBtn:Show()
      end
      fitButtonToSlot(act, slotBtn)
      setShowGridInsecure(act, true, SHOWGRID_REASON)
      updateOverrideBindings(act)
    end
  end
  self:HideStockMultiBar5()
end

function M:Detach()
  if InCombatLockdown() then
    self._pendingDetach = true
    return
  end
  self._pendingDetach = nil
  if not self._buttons then
    return
  end
  for i = 1, #SLOT_DEFS do
    local btn = self._buttons[i]
    if btn then
      btn:SetAttribute("statehidden", true)
      btn:Hide()
      btn:SetParent(UIParent)
      ClearOverrideBindings(btn._hotkeyBind or btn)
    end
  end
end

function M:OnRegenEnabled()
  if self._pendingEnsure or self._pendingAttach or self._pendingHideStock or self._pendingDetach then
    if self._pendingDetach and not self.IsEnabled() then
      self:Detach()
    end
    if self.IsEnabled() then
      self:EnsureButtons()
      if ns.RightPanelWidgets and ns.RightPanelWidgets._buttons then
        self:AttachToSlots(ns.RightPanelWidgets._buttons)
      end
    end
  end
end

function M:EnsureEventFrame()
  if self._ev then
    return
  end
  local f = CreateFrame("Frame")
  self._ev = f
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("UPDATE_BINDINGS")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(_, ev)
    if ev == "UPDATE_BINDINGS" then
      if M._buttons and not InCombatLockdown() then
        for i = 1, #SLOT_DEFS do
          updateOverrideBindings(M._buttons[i])
        end
      end
      return
    end
    if ev == "PLAYER_REGEN_ENABLED" then
      M:OnRegenEnabled()
    end
    if M.IsEnabled() then
      M:Refresh()
    end
  end)
end

function M:Refresh()
  self:EnsureEventFrame()
  if not self.IsEnabled() then
    self:Detach()
    return
  end
  if ns.RightPanelWidgets and ns.RightPanelWidgets._buttons then
    self:AttachToSlots(ns.RightPanelWidgets._buttons)
  else
    self:EnsureButtons()
  end
end
