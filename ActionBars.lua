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
local LEFT_BUTTONS_PER_BAR = 6
--- Tope de botones con entrada en Bindings.xml (barras 1–4).
local BINDABLE_BUTTONS_PER_BAR = LEFT_BUTTONS_PER_BAR
local LEFT_BAR_IDS = { 1, 2, 3, 4 }
local RIGHT_BAR_ID = 6
--- Barra que toma las páginas de vehículo / override / possess.
local VEHICLE_BAR_ID = 1
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
  "MainMenuBar", -- arte clásico / ≤11.2.5
  "MainActionBar", -- Retail 11.2.7+ / 12
  "MultiBarBottomLeft",
  "MultiBarBottomRight",
  "MultiBarRight",
  "MultiBarLeft",
  "MultiBar5",
  "MultiBar6",
  "MultiBar7",
  "MultiBar8",
  "StanceBar",
  "PetActionBar",
  "PossessActionBar",
  "StatusTrackingBarManager", -- XP/rep bajo la barra principal
}

local STOCK_BUTTON_PREFIXES = {
  "ActionButton",
  "MultiBarBottomLeftButton",
  "MultiBarBottomRightButton",
  "MultiBarRightButton",
  "MultiBarLeftButton",
  "MultiBar5Button",
  "MultiBar6Button",
  "MultiBar7Button",
  "MultiBar8Button",
}

local function getBlizzHider()
  if not AB._blizzHider then
    local h = CreateFrame("Frame", "ChukieUi_ActionBarBlizzHider")
    h:Hide()
    AB._blizzHider = h
  end
  return AB._blizzHider
end

local function hideBarFrame(frame, clearEvents)
  if not frame then
    return
  end
  if clearEvents and frame.UnregisterAllEvents then
    pcall(frame.UnregisterAllEvents, frame)
  end
  -- Edit Mode sustituye Hide; preferir HideBase para no taint.
  if frame.HideBase then
    pcall(frame.HideBase, frame)
  elseif frame.Hide then
    pcall(frame.Hide, frame)
  end
  if frame.SetParent then
    pcall(frame.SetParent, frame, getBlizzHider())
  end
end

--- Devuelve un marco de Blizzard a UIParent. `show` solo cuando el juego tiene algo que mostrar
--- ahí: forzarlo sin situación activa dejaría un marco vacío en pantalla.
local function restoreBarFrame(frame, show)
  if not frame then
    return
  end
  if frame.SetParent then
    pcall(frame.SetParent, frame, UIParent)
  end
  if not show then
    return
  end
  if frame.ShowBase then
    pcall(frame.ShowBase, frame)
  elseif frame.Show then
    pcall(frame.Show, frame)
  end
end

local function hideBarButton(button)
  if not button then
    return
  end
  if button.SetAttribute then
    pcall(function()
      button:SetAttribute("statehidden", true)
    end)
  end
  if button.UnregisterAllEvents then
    pcall(button.UnregisterAllEvents, button)
  end
  if button.Hide then
    pcall(button.Hide, button)
  end
end

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
  if btn.chargeCooldown and C_ActionBar and C_ActionBar.GetActionChargeDuration and btn.chargeCooldown.SetCooldownFromDurationObject then
    local ok, dur = pcall(C_ActionBar.GetActionChargeDuration, action)
    if ok and dur then
      pcall(btn.chargeCooldown.SetCooldownFromDurationObject, btn.chargeCooldown, dur)
    else
      pcall(function()
        btn.chargeCooldown:Clear()
      end)
    end
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
    if not shown and ns.CdInfo then
      -- En combate el conteo es secreto: deducir cargas de los estados no secretos.
      local st = ns.CdInfo.GetActionState(action)
      if st.hasCharges and st.count then
        btn.Count:SetText(st.count)
        btn.Count:Show()
        shown = true
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
  self:UpdateVehicleExitButton()
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

--- Eventos que pueden cambiar la situación (qué barra de reemplazo hay). Los demás solo refrescan
--- iconos y cooldowns, y llegan demasiado seguido para recalcular opacidades en cada uno.
local SITUATION_EVENTS = {
  ACTIONBAR_PAGE_CHANGED = true,
  UPDATE_BONUS_ACTIONBAR = true,
  UPDATE_SHAPESHIFT_FORM = true,
  PLAYER_ENTERING_WORLD = true,
  UNIT_ENTERED_VEHICLE = true,
  UNIT_EXITED_VEHICLE = true,
  UPDATE_VEHICLE_ACTIONBAR = true,
  UPDATE_OVERRIDE_ACTIONBAR = true,
  UPDATE_POSSESS_BAR = true,
  VEHICLE_UPDATE = true,
  PLAYER_DEAD = true,
  PLAYER_ALIVE = true,
  PLAYER_UNGHOST = true,
}

--- Opacidad de la barra 1 y quién muestra las acciones del evento: las dos dependen de la
--- situación, no del contenido de los slots.
function AB:UpdateSituation()
  self:ApplyLeftButtonAlphas()
  self:UpdateOverrideArtBar()
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
    --- Las acciones del vehículo/override llegan después de subirse.
    "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_POSSESS_BAR",
    "VEHICLE_UPDATE",
    --- Morir y volver cambia la situación: es cuando la barra del evento se pierde.
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
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
    if SITUATION_EVENTS[evName] then
      AB:UpdateSituation()
    end
    AB:UpdateAllVisuals()
  end)
end

local function bindingCommand(barId, index)
  return string.format("CLICK ChukieUi_AB%d_B%d:LeftButton", barId, index)
end

local function pressAndHoldEnabled()
  return db().pressAndHoldRelease ~= false
end

--- Evoker empower / hold-cast: Blizzard usa typerelease=actionrelease en el UP.
local function applyPressHoldMode(frame)
  if not frame or InCombatLockdown() then
    return
  end
  if pressAndHoldEnabled() then
    frame:SetAttribute("pressAndHoldAction", true)
    frame:SetAttribute("typerelease", "actionrelease")
  else
    frame:SetAttribute("pressAndHoldAction", nil)
    frame:SetAttribute("typerelease", nil)
  end
end

local function addCastOnKeyPress(btn)
  if not btn._hotkeyBind then
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
  applyPressHoldMode(btn._hotkeyBind)
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
      for i = 1, math.min(BINDABLE_BUTTONS_PER_BAR, #bar.buttons) do
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
    applyPressHoldMode(btn)
    setShowGridInsecure(btn, true, SHOWGRID_REASON)
  end
  btn._chukieBarId = barId
  btn._chukieIndex = index
  btn._chukieAction = actionFor(barId, index)
  skinButton(btn)
  if barId <= 4 and index <= BINDABLE_BUTTONS_PER_BAR then
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
  if barId <= 4 and index <= BINDABLE_BUTTONS_PER_BAR and not InCombatLockdown() then
    updateOverrideBindings(btn)
  end
  return btn
end

--- Vehículo / override / possess: el offset es directo, sin el salto de la página 12 de Dominos
--- (esas páginas apuntan a slots reales, no a la numeración de barras del usuario).
local function specialPageOffset(page)
  page = tonumber(page)
  if not page or page < 1 then
    return nil
  end
  return (page - 1) * BUTTONS_PER_BAR
end

--- Aplica `offset-<estado>` a los botones. `newstate` existe en `_onstate-page`; en `Execute` no.
local APPLY_PAGE_OFFSET = [[
  local state = newstate or self:GetAttribute("state-page") or "normal"
  local offset = self:GetAttribute("offset-" .. state)
  if not offset then
    offset = self:GetAttribute("offset-normal") or 0
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

--- Barras de bonus: el juego pagina a 6 + GetBonusBarOffset() (formas, sigilo y las habilidades
--- temporales que dan algunas misiones o eventos). La 5 es skyriding y tiene su propio mapeo.
local BONUS_PAGE = { [1] = 7, [2] = 8, [3] = 9, [4] = 10 }

--- Situaciones que el juego impone y que la barra 1 muestra opaca. Skyriding queda afuera: es un
--- modo que el jugador elige, con su propio paginado, no una barra circunstancial de misión.
local OPAQUE_STATES = {
  vehicle = true,
  override = true,
  shapeshift = true,
  bonus1 = true,
  bonus2 = true,
  bonus3 = true,
  bonus4 = true,
}

--- Consulta booleana tolerante: la API puede no existir en esta versión del cliente y, desde
--- 12.0, devolver un valor secreto que no se puede testear.
local function apiFlag(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  local ok, value = pcall(fn, ...)
  if not ok or isSecret(value) then
    return false
  end
  return value and true or false
end

local function bonusBarOffset()
  if type(GetBonusBarOffset) ~= "function" then
    return 0
  end
  local ok, value = pcall(GetBonusBarOffset)
  if not ok or isSecret(value) then
    return 0
  end
  return math.floor(tonumber(value) or 0)
end

--[[ Qué barra de reemplazo puso el juego, con el mismo orden de prioridad que su
     ActionBarController, o nil si el jugador tiene su barra normal. Hace falta el dato en Lua,
     y no solo dentro del entorno seguro, para decidir dos cosas que las condiciones de macro no
     pueden: la opacidad de la fila y si conviene devolverle la barra con arte a Blizzard. ]]
function AB:ReplacementBarState()
  if apiFlag(UnitHasVehicleUI, "player") or apiFlag(HasVehicleActionBar) or apiFlag(IsPossessBarVisible) then
    return "vehicle"
  end
  if apiFlag(HasOverrideActionBar) then
    return "override"
  end
  if apiFlag(HasTempShapeshiftActionBar) then
    return "shapeshift"
  end
  local bonus = bonusBarOffset()
  if bonus == 5 then
    return "sky"
  end
  if bonus >= 1 and bonus <= 4 then
    return "bonus" .. bonus
  end
  return nil
end

--[[ El estado activo y si la barra 1 lo tiene cubierto. «Cubierto» significa que su driver
     seguro tiene un `offset-<estado>` para ese caso: sin él, la barra sigue en la página normal
     mostrando las habilidades del jugador aunque el juego haya cambiado de situación. ]]
function AB:ReplacementCoverage()
  local state = self:ReplacementBarState()
  if not state then
    return nil, false
  end
  local bar = self._bars and self._bars[tostring(VEHICLE_BAR_ID)]
  if not bar then
    return state, false
  end
  return state, bar:GetAttribute("offset-" .. state) ~= nil
end

--- Estados de página por barra, en orden de prioridad (vehículo gana sobre skyriding).
local function buildPageStates(bar, barId)
  local conditions = {}
  bar:SetAttribute("offset-normal", pageOffset(barId))
  bar:SetAttribute("offset-vehicle", nil)
  bar:SetAttribute("offset-override", nil)
  bar:SetAttribute("offset-shapeshift", nil)
  bar:SetAttribute("offset-sky", nil)
  for bonus = 1, 4 do
    bar:SetAttribute("offset-bonus" .. bonus, nil)
  end

  --- Mismo orden que ActionBarController de Blizzard: vehículo, override, shapeshift temporal.
  if barId == VEHICLE_BAR_ID and db().vehiclePaging ~= false then
    local vehicle = specialPageOffset(GetVehicleBarIndex and GetVehicleBarIndex())
    local override = specialPageOffset(GetOverrideBarIndex and GetOverrideBarIndex())
    local shapeshift = specialPageOffset(GetTempShapeshiftBarIndex and GetTempShapeshiftBarIndex())
    if vehicle then
      bar:SetAttribute("offset-vehicle", vehicle)
      conditions[#conditions + 1] = "[vehicleui][possessbar] vehicle"
    end
    if override then
      bar:SetAttribute("offset-override", override)
      conditions[#conditions + 1] = "[overridebar] override"
    end
    if shapeshift then
      bar:SetAttribute("offset-shapeshift", shapeshift)
      conditions[#conditions + 1] = "[shapeshift] shapeshift"
    end
  end

  --[[ Barras de bonus 1–4 (páginas 7–10). Sin estos estados la barra 1 se queda en la página
       normal justo cuando el juego cambió de situación —una habilidad temporal de misión, una
       forma, el sigilo—, y como el arte de Blizzard está oculto esas acciones no aparecen en
       ninguna parte. Es el mismo cálculo que hace su ActionBarController. ]]
  if barId == VEHICLE_BAR_ID and db().bonusPaging ~= false then
    for bonus = 1, 4 do
      bar:SetAttribute("offset-bonus" .. bonus, pageOffset(BONUS_PAGE[bonus]))
      conditions[#conditions + 1] = "[bonusbar:" .. bonus .. "] bonus" .. bonus
    end
  end

  local skyPage = SKY_PAGE[barId]
  if skyPage and db().skyridingPaging ~= false then
    bar:SetAttribute("offset-sky", pageOffset(skyPage))
    conditions[#conditions + 1] = SKYRIDING_COND .. " sky"
  end

  if #conditions == 0 then
    return nil
  end
  conditions[#conditions + 1] = "normal"
  return table.concat(conditions, "; ")
end

local function applySecurePaging(bar, barId)
  if InCombatLockdown() then
    return
  end
  local driver = buildPageStates(bar, barId)
  if not driver then
    UnregisterStateDriver(bar, "page")
    bar:SetAttribute("state-page", "normal")
    bar:Execute(APPLY_PAGE_OFFSET)
    return
  end
  bar:SetAttribute("_onstate-page", APPLY_PAGE_OFFSET)
  RegisterStateDriver(bar, "page", driver)
end

-- ActionBarButtonTemplate fija cromado (Normal/borde) en tamaño nativo;
-- SetSize solo no lo escala (IgnoreParentScale). Escalar el botón entero.
local function applyButtonSize(btn, size)
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
    applyButtonSize(btn, size)
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

--- Botón de bajarse: vive sobre la barra 1 y un tercio más grande que sus botones.
local VEHICLE_EXIT_SIZE_FACTOR = 4 / 3
local VEHICLE_EXIT_ICON = [[Interface\Vehicles\UI-Vehicles-Button-Exit-Up]]
--- Mismo estado que usa Dominos: sirve para vehículo, taxi y posesión.
local VEHICLE_EXIT_VISIBILITY = "[canexitvehicle][possessbar] show; hide"

local function vehicleExitIcon(btn)
  return btn.icon or btn.Icon
end

local function vehicleExitOnClick(btn)
  btn:SetChecked(false)
  if UnitOnTaxi and UnitOnTaxi("player") then
    if TaxiRequestEarlyLanding then
      TaxiRequestEarlyLanding()
      local icon = vehicleExitIcon(btn)
      if icon then
        icon:SetDesaturated(true)
      end
      btn:SetChecked(true)
      btn:Disable()
    end
    return
  end
  if CanExitVehicle and CanExitVehicle() then
    if VehicleExit then
      VehicleExit()
    end
    return
  end
  if CancelPetPossess then
    CancelPetPossess()
  end
end

local function vehicleExitOnEnter(btn)
  GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
  if UnitOnTaxi and UnitOnTaxi("player") then
    GameTooltip:SetText(_G.TAXI_CANCEL or "Cancelar vuelo", 1, 1, 1)
    if _G.TAXI_CANCEL_DESCRIPTION then
      GameTooltip:AddLine(_G.TAXI_CANCEL_DESCRIPTION, nil, nil, nil, true)
    end
  elseif CanExitVehicle and CanExitVehicle() then
    GameTooltip:SetText(_G.LEAVE_VEHICLE or "Bajarse", 1, 1, 1)
  else
    GameTooltip:SetText(_G.CANCEL or "Cancelar", 1, 1, 1)
  end
  GameTooltip:Show()
end

local function vehicleExitOnLeave(btn)
  if GameTooltip:IsOwned(btn) then
    GameTooltip:Hide()
  end
end

function AB:EnsureVehicleExitButton()
  if self._vehicleExit then
    return self._vehicleExit
  end
  if InCombatLockdown() then
    return nil
  end
  local template = _G.SmallActionButtonMixin and "SmallActionButtonTemplate" or "ActionButtonTemplate"
  local id = _G.POSSESS_CANCEL_SLOT or 2
  local ok, btn = pcall(CreateFrame, "CheckButton", "ChukieUi_VehicleExit", UIParent, template, id)
  if not ok or not btn then
    return nil
  end
  btn:SetScript("OnClick", vehicleExitOnClick)
  btn:SetScript("OnEnter", vehicleExitOnEnter)
  btn:SetScript("OnLeave", vehicleExitOnLeave)
  if btn.cooldown and btn.cooldown.SetSwipeColor then
    btn.cooldown:SetSwipeColor(0, 0, 0)
  end
  self._vehicleExit = btn
  return btn
end

--- En posesión el icono es el de cancelar; en vehículo/taxi, la flecha de salida.
function AB:UpdateVehicleExitButton()
  local btn = self._vehicleExit
  if not btn then
    return
  end
  local icon = vehicleExitIcon(btn)
  if not icon then
    return
  end
  local texture = GetPossessInfo and GetPossessInfo(btn:GetID())
  if isSecret(texture) then
    texture = nil
  end
  local exiting = UnitControllingVehicle
    and UnitControllingVehicle("player")
    and CanExitVehicle
    and CanExitVehicle()
  if exiting or not texture then
    icon:SetTexture(VEHICLE_EXIT_ICON)
    icon:SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
  else
    icon:SetTexture(texture)
    icon:SetTexCoord(0, 1, 0, 1)
  end
  icon:SetVertexColor(1, 1, 1)
  icon:SetDesaturated(false)
  btn:SetChecked(false)
  btn:Enable()
end

function AB:LayoutVehicleExitButton(bar, size, gap)
  local d = db()
  local wanted = bar and d.vehiclePaging ~= false and d.vehicleExitButton ~= false
  if not wanted then
    local btn = self._vehicleExit
    if btn then
      UnregisterStateDriver(btn, "visibility")
      btn:Hide()
    end
    return
  end
  local btn = self:EnsureVehicleExitButton()
  if not btn then
    return
  end
  applyButtonSize(btn, size * VEHICLE_EXIT_SIZE_FACTOR)
  if btn:GetParent() ~= bar then
    btn:SetParent(bar)
  end
  btn:ClearAllPoints()
  --- El offset va en la escala del propio botón: compensar para que el hueco sea el pedido.
  local scale = btn:GetScale()
  if not scale or scale <= 0 then
    scale = 1
  end
  btn:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, gap / scale)
  self:UpdateVehicleExitButton()
  RegisterStateDriver(btn, "visibility", VEHICLE_EXIT_VISIBILITY)
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

--- Slots (numeración Dominos) que muestran las barras 1–4, incluidas las páginas de skyriding y
--- de bonus a las que pagina la barra 1. Una página puede repetirse entre mapeos, así que se
--- filtra: un slot duplicado se guardaría y repondría dos veces.
function AB:GetLeftActionSlots()
  local slots, seen = {}, {}
  local function addPage(page)
    local offset = pageOffset(page)
    for i = 1, BUTTONS_PER_BAR do
      local slot = offset + i
      if not seen[slot] then
        seen[slot] = true
        slots[#slots + 1] = slot
      end
    end
  end
  local skyriding = db().skyridingPaging ~= false
  local bonus = db().bonusPaging ~= false
  for i = 1, #LEFT_BAR_IDS do
    local id = LEFT_BAR_IDS[i]
    addPage(id)
    local sky = SKY_PAGE[id]
    if sky and skyriding then
      addPage(sky)
    end
    if id == VEHICLE_BAR_ID and bonus then
      for index = 1, 4 do
        addPage(BONUS_PAGE[index])
      end
    end
  end
  return slots
end

function AB:HideStockBars()
  if InCombatLockdown() then
    return
  end
  if db().hideBlizzardArt == false then
    return
  end
  for i = 1, #STOCK_BARS_TO_HIDE do
    -- clearEvents en MultiBars; MainMenuBar/MainActionBar conservan algunos eventos.
    local name = STOCK_BARS_TO_HIDE[i]
    local clearEvents = name ~= "MainMenuBar" and name ~= "MainActionBar"
    hideBarFrame(_G[name], clearEvents)
  end
  for p = 1, #STOCK_BUTTON_PREFIXES do
    local prefix = STOCK_BUTTON_PREFIXES[p]
    for i = 1, 12 do
      hideBarButton(_G[prefix .. i])
    end
  end
  -- El botón de bajarse de Blizzard duplicaría el nuestro.
  if db().vehicleExitButton ~= false then
    hideBarFrame(_G.MainMenuBarVehicleLeaveButton, true)
  end
  -- MainMenuBar: eventos que la vuelven a mostrar.
  if MainMenuBar and MainMenuBar.UnregisterEvent then
    pcall(MainMenuBar.UnregisterEvent, MainMenuBar, "PLAYER_REGEN_ENABLED")
    pcall(MainMenuBar.UnregisterEvent, MainMenuBar, "PLAYER_REGEN_DISABLED")
    pcall(MainMenuBar.UnregisterEvent, MainMenuBar, "ACTIONBAR_SHOWGRID")
    pcall(MainMenuBar.UnregisterEvent, MainMenuBar, "ACTIONBAR_HIDEGRID")
  end
end

--[[ Barra de misión / vehículo con arte propio (OverrideActionBar): Blizzard la muestra flotando
     cuando hay override/vehículo con skin. Mientras nuestra barra 1 pagine a esas acciones
     ([overridebar]/[vehicleui], índices 12/14/13) la de Blizzard duplica, así que va a un
     contenedor oculto, que resiste los Show() del juego incluso en combate.

     La excepción es lo que importa: si el juego tiene una barra de reemplazo que nuestro
     paginado NO cubre —el paginado apagado, o un estado que el driver seguro no contempla tras
     morir o cambiar de situación—, ocultarla dejaría al jugador sin ninguna forma de usar la
     habilidad del evento y sin poder avanzar. En ese caso se devuelve a UIParent y manda
     Blizzard. Son llamadas protegidas: en combate quedan pendientes hasta salir. ]]
function AB:UpdateOverrideArtBar()
  local bar = _G.OverrideActionBar
  if not bar then
    return
  end
  local state, covered = self:ReplacementCoverage()
  local routed = self.IsEnabled() and db().leftEnabled ~= false and db().vehiclePaging ~= false
  local uncovered = state ~= nil and not covered
  local hide = routed and not uncovered
  if self._overrideArtHidden == hide then
    return
  end
  if InCombatLockdown() then
    self._pendingOverrideArt = true
    return
  end
  self._pendingOverrideArt = nil
  if hide then
    hideBarFrame(bar, false)
  else
    --- La habíamos escondido con Hide(), así que el juego no la va a volver a mostrar solo:
    --- se fuerza, pero únicamente en las situaciones que este marco atiende.
    restoreBarFrame(bar, state == "vehicle" or state == "override")
  end
  self._overrideArtHidden = hide
end

function AB:HideAll()
  self:LayoutVehicleExitButton(nil)
  if self._leftBlock then
    self._leftBlock:Hide()
  end
  if not self._bars then
    return
  end
  for _, bar in pairs(self._bars) do
    if bar then
      bar:Hide()
    end
  end
end

--- Las barras 1–4 viven en un contenedor propio anclado al centro de la pantalla.
--- Límite de los offsets: el triple del rango anterior y simétrico respecto al centro.
local LEFT_OFFSET_LIMIT = 1800

local function clampLeftOffset(value)
  value = tonumber(value) or 0
  return math.max(-LEFT_OFFSET_LIMIT, math.min(LEFT_OFFSET_LIMIT, value))
end

--- Capa de barras de acción: por debajo de menús, diálogos y alertas.
local LEFT_BLOCK_STRATA = "MEDIUM"
local LEFT_BLOCK_LEVEL = 20

function AB:EnsureLeftBlock()
  local block = self._leftBlock
  if not block then
    block = CreateFrame("Frame", "ChukieUi_LeftBarsBlock", UIParent)
    block:EnableMouse(false)
    self._leftBlock = block
  end
  block:SetFrameStrata(LEFT_BLOCK_STRATA)
  block:SetFixedFrameStrata(true)
  block:SetFrameLevel(LEFT_BLOCK_LEVEL)
  return block
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

--- Opacidad individual de las 24 celdas fijas (4 barras × 6 botones).
function AB:GetLeftButtonAlphaPercent(barId, buttonIndex)
  local rows = db().leftButtonAlphaPercent
  local row = type(rows) == "table" and rows[barId] or nil
  local value = type(row) == "table" and tonumber(row[buttonIndex]) or 100
  return math.max(10, math.min(100, math.floor((value or 100) + 0.5)))
end

function AB:ApplyLeftButtonAlphas()
  --[[ Mientras el juego reemplaza la barra 1 (vehículo, misión, evento, forma) esa fila deja de
       ser la del jugador: son acciones que aparecieron solas y que hay que poder leer, así que
       se muestran opacas y recuperan la opacidad configurada al terminar la situación. Solo se
       fuerza si nuestro paginado cubre el estado; si no, la barra sigue mostrando las
       habilidades normales y no hay motivo para cambiarle nada. ]]
  local state, covered = self:ReplacementCoverage()
  local opaqueBar = (state and covered and OPAQUE_STATES[state]) and VEHICLE_BAR_ID or nil
  for barId = 1, 4 do
    local bar = self._bars and self._bars[tostring(barId)]
    if bar and bar.buttons then
      for buttonIndex = 1, LEFT_BUTTONS_PER_BAR do
        local btn = bar.buttons[buttonIndex]
        if btn then
          local percent = 100
          if barId ~= opaqueBar then
            percent = self:GetLeftButtonAlphaPercent(barId, buttonIndex)
          end
          btn:SetAlpha(percent / 100)
        end
      end
    end
  end
end

function AB:SetLeftButtonAlphaPercent(barId, buttonIndex, value)
  barId = math.floor(tonumber(barId) or 0)
  buttonIndex = math.floor(tonumber(buttonIndex) or 0)
  if barId < 1 or barId > 4 or buttonIndex < 1 or buttonIndex > LEFT_BUTTONS_PER_BAR then
    return false
  end
  value = math.max(10, math.min(100, math.floor((tonumber(value) or 100) + 0.5)))
  local d = db()
  d.leftButtonAlphaPercent = type(d.leftButtonAlphaPercent) == "table" and d.leftButtonAlphaPercent or {}
  d.leftButtonAlphaPercent[barId] =
    type(d.leftButtonAlphaPercent[barId]) == "table" and d.leftButtonAlphaPercent[barId] or {}
  d.leftButtonAlphaPercent[barId][buttonIndex] = value
  if InCombatLockdown() then
    self._pendingRefresh = true
  else
    self:ApplyLeftButtonAlphas()
  end
  return true
end

function AB:ResetLeftButtonAlphas()
  db().leftButtonAlphaPercent = {}
  if InCombatLockdown() then
    self._pendingRefresh = true
  else
    self:ApplyLeftButtonAlphas()
  end
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
    self:LayoutVehicleExitButton(nil)
    if self._leftBlock then
      self._leftBlock:Hide()
    end
    return
  end

  local block = self:EnsureLeftBlock()
  local numButtons = LEFT_BUTTONS_PER_BAR
  local size = math.max(18, math.min(64, tonumber(d.leftButtonSize) or 36))
  local gap = math.max(0, math.min(16, tonumber(d.leftSpacing) or 2))
  local barGap = math.max(0, math.min(24, tonumber(d.leftBarSpacing) or 4))
  local offX = clampLeftOffset(d.leftOffsetX)
  local offY = clampLeftOffset(d.leftOffsetY)

  local totalW, totalH = 0, 0
  local bars = {}
  for i = 1, #LEFT_BAR_IDS do
    local id = LEFT_BAR_IDS[i]
    local bar = self:EnsureBar(id, numButtons)
    layoutBarButtons(bar, numButtons, size, gap)
    if bar:GetParent() ~= block then
      bar:SetParent(block)
    end
    --- Reafirmar la capa: SetParent propaga la del padre y una sesión vieja pudo dejarla arriba.
    bar:SetFrameStrata(LEFT_BLOCK_STRATA)
    bar:SetFrameLevel(LEFT_BLOCK_LEVEL + 5)
    bar:Show()
    bars[i] = bar
    totalW = math.max(totalW, bar:GetWidth())
    totalH = totalH + bar:GetHeight()
    if i < #LEFT_BAR_IDS then
      totalH = totalH + barGap
    end
  end

  --- El centro del bloque queda en el centro de la pantalla más el offset elegido.
  block:ClearAllPoints()
  block:SetSize(math.max(1, totalW), math.max(1, totalH))
  block:SetPoint("CENTER", UIParent, "CENTER", offX, offY)
  block:Show()

  self:LayoutVehicleExitButton(bars[1], size, barGap)

  -- Barra 1 arriba → 4 abajo (como Dominos en el screenshot).
  local y = 0
  for i = 1, #bars do
    local bar = bars[i]
    bar:ClearAllPoints()
    bar:SetPoint("TOP", block, "TOP", 0, -y)
    y = y + bar:GetHeight() + barGap
  end
  self:ApplyLeftButtonAlphas()
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
    --- Sin barras propias, la barra con arte de Blizzard vuelve a ser la única opción.
    self:UpdateOverrideArtBar()
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
  --- Después del layout: la cobertura se lee de los atributos que acaba de fijar el paginado.
  self:UpdateSituation()
end

--- Diagnóstico de situación: sirve para saber, cuando una barra de evento no aparece, si el
--- juego declaró un reemplazo, si nuestra barra 1 lo cubre y quién está mostrando las acciones.
function AB:PrintDiagnostics()
  local d = db()
  local state, covered = self:ReplacementCoverage()
  print("|cff00ff00Chukie UI|r barras de acción:")
  print(
    "  reemplazo del juego="
      .. tostring(state or "ninguno")
      .. " cubierto por la barra 1="
      .. tostring(covered)
      .. " bonusbar="
      .. bonusBarOffset()
  )
  print(
    "  paginado: vehículo="
      .. tostring(d.vehiclePaging ~= false)
      .. " bonus="
      .. tostring(d.bonusPaging ~= false)
      .. " skyriding="
      .. tostring(d.skyridingPaging ~= false)
  )
  local bar = self._bars and self._bars[tostring(VEHICLE_BAR_ID)]
  if bar then
    local first = bar.buttons and bar.buttons[1]
    print(
      "  barra 1: estado="
        .. tostring(bar:GetAttribute("state-page") or "sin driver")
        .. " offset="
        .. tostring(bar:GetAttribute("actionOffset"))
        .. " acción del botón 1="
        .. tostring(first and first:GetAttribute("action"))
    )
  else
    print("  barra 1: todavía no creada.")
  end
  local art = _G.OverrideActionBar
  if art then
    local parent = art:GetParent()
    print(
      "  OverrideActionBar: padre="
        .. tostring((parent and parent.GetName and parent:GetName()) or parent)
        .. " visible="
        .. tostring(apiFlag(art.IsShown, art))
        .. " la ocultamos="
        .. tostring(self._overrideArtHidden == true)
        .. " pendiente="
        .. tostring(self._pendingOverrideArt == true)
    )
  else
    print("  OverrideActionBar: no existe en este cliente.")
  end
end

function AB:OnRegenEnabled()
  if self._pendingRefresh then
    self:Refresh()
  elseif self._pendingOverrideArt then
    self:UpdateOverrideArtBar()
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
