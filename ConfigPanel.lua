--[[ Panel de opciones: Esc → Opciones → AddOns → Chukie UI
     Retail 12.1 (Interface 120100): categoría raíz + subcategorías verticales (p. ej. Panel derecho).
     Controles: RegisterProxySetting + CreateCheckbox / CreateSlider. ]]

local _, ns = ...

local function minimapBarDB()
  if ns.Profile and ns.Profile.GetMinimapBarModel then
    return ns.Profile:GetMinimapBarModel()
  end
  local p = ns.Profile:GetActive()
  p.minimapBar = p.minimapBar or {}
  return p.minimapBar
end

local function refreshMinimapBar()
  if ns.MinimapBar and ns.MinimapBar.Refresh then
    ns.MinimapBar:Refresh()
  end
end

local function minimapPosDB()
  if ns.Profile and ns.Profile.GetRightPanelModel then
    return ns.Profile:GetRightPanelModel()
  end
  local p = ns.Profile:GetActive()
  p.minimapPosition = p.minimapPosition or {}
  return p.minimapPosition
end

local function rightWidgetsDB()
  if ns.Profile and ns.Profile.GetRightPanelWidgetsModel then
    return ns.Profile:GetRightPanelWidgetsModel()
  end
  local p = ns.Profile:GetActive()
  p.widgets = p.widgets or {}
  p.widgets.rightPanelWidgets = p.widgets.rightPanelWidgets or {}
  return p.widgets.rightPanelWidgets
end

local function refreshRightPanelLayout()
  if ns.RightPanel and ns.RightPanel.Apply then
    ns.RightPanel:Apply()
  end
  if ns.LeftPanel and ns.LeftPanel.Refresh then
    ns.LeftPanel:Refresh()
  end
  refreshMinimapBar()
  if ns.RightPanelWidgets and ns.RightPanelWidgets.Refresh then
    ns.RightPanelWidgets:Refresh()
  end
  if ns.ActionBars and ns.ActionBars.Refresh then
    ns.ActionBars:Refresh()
  end
end

local function actionBarsDB()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return {}
  end
  p.actionBars = p.actionBars or {}
  return p.actionBars
end

local function refreshActionBars()
  if ns.ActionBars and ns.ActionBars.Refresh then
    ns.ActionBars:Refresh()
  end
end

local function addBoolActionBars(category, uniqueId, key, label, tooltip, defaultOn)
  local function get()
    return actionBarsDB()[key] ~= false
  end
  local function set(v)
    actionBarsDB()[key] = (v == true or v == 1) and true or false
    refreshActionBars()
  end
  local defaultToken = defaultOn and Settings.Default.True or Settings.Default.False
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Boolean,
    label,
    defaultToken,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function addIntSliderActionBars(category, uniqueId, key, label, tooltip, minV, maxV, step, defaultNum)
  local function get()
    local v = tonumber(actionBarsDB()[key])
    if not v then
      return defaultNum
    end
    return math.max(minV, math.min(maxV, v))
  end
  local function set(v)
    actionBarsDB()[key] = math.floor(v + 0.5)
    refreshActionBars()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Number,
    label,
    defaultNum,
    get,
    set
  )
  local options = Settings.CreateSliderOptions(minV, maxV, step)
  Settings.CreateSlider(category, setting, options, tooltip)
end

local LEFT_ALPHA_MIN, LEFT_ALPHA_MAX = 10, 100

local function clampLeftAlphaPercent(value)
  value = math.floor((tonumber(value) or LEFT_ALPHA_MAX) + 0.5)
  return math.max(LEFT_ALPHA_MIN, math.min(LEFT_ALPHA_MAX, value))
end

local function applyLeftAlphaPercent(barId, buttonIndex, value)
  if ns.ActionBars and ns.ActionBars.SetLeftButtonAlphaPercent then
    ns.ActionBars:SetLeftButtonAlphaPercent(barId, buttonIndex, value)
  end
end

--- Canvas 6 × 4 que imita las barras izquierdas. Cada celda previsualiza su icono y
--- controla la opacidad del botón real; el texto queda opaco para que 10 % siga legible.
local function createLeftButtonAlphaCanvas()
  local panel = CreateFrame("Frame")
  panel.cells = {}

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -18)
  title:SetText("Transparencia individual — barras 1–4")

  local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  help:SetWidth(520)
  help:SetJustifyH("LEFT")
  help:SetText(
    "La cuadrícula reproduce las 4 barras de 6 botones. Cada deslizador ajusta el botón "
      .. "que tiene encima (10–100 %) y la caja de abajo acepta el valor exacto: mover el "
      .. "deslizador actualiza la caja y escribir en la caja mueve el deslizador. En combate "
      .. "se guarda el valor y se aplica al terminar."
  )

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(120, 22)
  reset:SetPoint("TOPRIGHT", -22, -20)
  reset:SetText("Restaurar 100 %")

  local left, top = 92, -100
  local cellWidth, rowHeight = 76, 108
  for column = 1, 6 do
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", panel, "TOPLEFT", left + (column - 1) * cellWidth + 25, top + 20)
    label:SetText("Botón " .. column)
  end

  for barId = 1, 4 do
    local rowLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rowLabel:SetPoint("RIGHT", panel, "TOPLEFT", left - 12, top - (barId - 1) * rowHeight - 28)
    rowLabel:SetText("Barra " .. barId)

    for buttonIndex = 1, 6 do
      local cellBarId, cellButtonIndex = barId, buttonIndex
      local x = left + (buttonIndex - 1) * cellWidth
      local y = top - (barId - 1) * rowHeight
      local cell = CreateFrame("Frame", nil, panel)
      cell:SetSize(58, 100)
      cell:SetPoint("TOPLEFT", x, y)

      local preview = CreateFrame("Button", nil, cell, "BackdropTemplate")
      preview:SetSize(48, 48)
      preview:SetPoint("TOP", 0, 0)
      preview:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
      })
      preview:SetBackdropColor(0.03, 0.03, 0.04, 0.85)
      preview:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)

      preview.icon = preview:CreateTexture(nil, "ARTWORK")
      preview.icon:SetPoint("TOPLEFT", 3, -3)
      preview.icon:SetPoint("BOTTOMRIGHT", -3, 3)
      preview.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

      preview.value = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      preview.value:SetPoint("CENTER")
      preview.value:SetTextColor(1, 1, 1)
      preview.value:SetShadowOffset(1, -1)

      preview:SetScript("OnEnter", function()
        GameTooltip:SetOwner(preview, "ANCHOR_RIGHT")
        GameTooltip:SetText("Barra " .. cellBarId .. " · Botón " .. cellButtonIndex)
        GameTooltip:AddLine("Controla la opacidad completa del botón real.", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      preview:SetScript("OnLeave", GameTooltip_Hide)

      local sliderName = "ChukieUi_AB_Alpha_" .. cellBarId .. "_" .. cellButtonIndex
      local slider = CreateFrame("Slider", sliderName, cell, "OptionsSliderTemplate")
      slider:SetWidth(58)
      slider:SetPoint("TOP", preview, "BOTTOM", 0, -14)
      slider:SetMinMaxValues(LEFT_ALPHA_MIN, LEFT_ALPHA_MAX)
      --- Paso de 1 para que cualquier valor tipeado en la caja sea representable acá.
      slider:SetValueStep(1)
      slider:SetObeyStepOnDrag(true)
      _G[sliderName .. "Low"]:SetText("")
      _G[sliderName .. "High"]:SetText("")
      _G[sliderName .. "Text"]:SetText("")

      local box = CreateFrame("EditBox", nil, cell, "InputBoxTemplate")
      box:SetSize(42, 18)
      box:SetPoint("TOP", slider, "BOTTOM", 1, -2)
      box:SetAutoFocus(false)
      box:SetNumeric(true)
      box:SetMaxLetters(3)
      box:SetJustifyH("CENTER")
      box:SetFontObject("GameFontHighlightSmall")

      local function updatePreview(value)
        preview.value:SetText(value .. "%")
        preview.icon:SetAlpha(value / 100)
      end

      local function writeBox(value)
        box._syncing = true
        box:SetText(tostring(value))
        box:SetCursorPosition(0)
        box._syncing = false
      end

      local function moveSlider(value)
        slider._syncing = true
        slider:SetValue(value)
        slider._syncing = false
      end

      slider:SetScript("OnValueChanged", function(s, value)
        value = clampLeftAlphaPercent(value)
        updatePreview(value)
        if s._syncing then
          return
        end
        writeBox(value)
        applyLeftAlphaPercent(cellBarId, cellButtonIndex, value)
      end)

      --- Mientras se tipea sólo se aplica lo que ya es un valor válido: "3" no salta a 10
      --- antes de que el usuario termine de escribir "37".
      box:SetScript("OnTextChanged", function(self, userInput)
        if not userInput or self._syncing then
          return
        end
        local typed = tonumber(self:GetText())
        if not typed or typed < LEFT_ALPHA_MIN or typed > LEFT_ALPHA_MAX then
          return
        end
        typed = clampLeftAlphaPercent(typed)
        moveSlider(typed)
        updatePreview(typed)
        applyLeftAlphaPercent(cellBarId, cellButtonIndex, typed)
      end)

      --- Al confirmar se normaliza: fuera de rango se recorta y vacío vuelve al valor actual.
      local function commitBox()
        local typed = tonumber(box:GetText())
        local value = clampLeftAlphaPercent(typed or slider:GetValue())
        moveSlider(value)
        updatePreview(value)
        writeBox(value)
        if typed then
          applyLeftAlphaPercent(cellBarId, cellButtonIndex, value)
        end
      end

      box:SetScript("OnEnterPressed", function(self)
        commitBox()
        self:ClearFocus()
      end)
      box:SetScript("OnEditFocusLost", commitBox)
      box:SetScript("OnEscapePressed", function(self)
        writeBox(clampLeftAlphaPercent(slider:GetValue()))
        self:ClearFocus()
      end)
      box:SetScript("OnEnter", function()
        GameTooltip:SetOwner(box, "ANCHOR_RIGHT")
        GameTooltip:SetText("Barra " .. cellBarId .. " · Botón " .. cellButtonIndex)
        GameTooltip:AddLine("Valor exacto de 10 a 100 %. Enter para confirmar.", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      box:SetScript("OnLeave", GameTooltip_Hide)

      panel.cells[#panel.cells + 1] = {
        barId = cellBarId,
        buttonIndex = cellButtonIndex,
        action = (cellBarId - 1) * 12 + cellButtonIndex,
        preview = preview,
        slider = slider,
        box = box,
      }
    end
  end

  function panel:Refresh()
    for i = 1, #self.cells do
      local cell = self.cells[i]
      local alpha = 100
      if ns.ActionBars and ns.ActionBars.GetLeftButtonAlphaPercent then
        alpha = ns.ActionBars:GetLeftButtonAlphaPercent(cell.barId, cell.buttonIndex)
      end
      cell.slider._syncing = true
      cell.slider:SetValue(alpha)
      cell.slider._syncing = false
      cell.box._syncing = true
      cell.box:SetText(tostring(alpha))
      cell.box:SetCursorPosition(0)
      cell.box._syncing = false
      cell.preview.value:SetText(alpha .. "%")
      cell.preview.icon:SetAlpha(alpha / 100)
      cell.preview.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
      if GetActionTexture then
        local ok, texture = pcall(GetActionTexture, cell.action)
        if ok and not (issecretvalue and issecretvalue(texture)) then
          if texture ~= nil then
            cell.preview.icon:SetTexture(texture)
          end
        end
      end
    end
  end

  reset:SetScript("OnClick", function()
    if ns.ActionBars and ns.ActionBars.ResetLeftButtonAlphas then
      ns.ActionBars:ResetLeftButtonAlphas()
    end
    panel:Refresh()
  end)
  panel:SetScript("OnShow", function(self)
    self:Refresh()
  end)
  return panel
end

local function addBoolProxy(category, uniqueId, key, label, tooltip, defaultOn)
  local function get()
    return minimapBarDB()[key] ~= false
  end
  local function set(v)
    minimapBarDB()[key] = (v == true or v == 1) and true or false
    refreshMinimapBar()
  end
  local defaultToken = defaultOn and Settings.Default.True or Settings.Default.False
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Boolean,
    label,
    defaultToken,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function addIntSlider(category, uniqueId, key, label, tooltip, minV, maxV, step, defaultNum)
  local function get()
    local v = tonumber(minimapBarDB()[key])
    if not v then
      return defaultNum
    end
    return math.max(minV, math.min(maxV, v))
  end
  local function set(v)
    minimapBarDB()[key] = math.floor(v + 0.5)
    refreshMinimapBar()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Number,
    label,
    defaultNum,
    get,
    set
  )
  local options = Settings.CreateSliderOptions(minV, maxV, step)
  Settings.CreateSlider(category, setting, options, tooltip)
end

--- Igual que `addIntSlider`, más caja de texto si el cliente la ofrece (valor en píxeles).
local function addIntSliderPx(category, uniqueId, key, label, tooltip, minV, maxV, step, defaultNum)
  local function get()
    local v = tonumber(minimapBarDB()[key])
    if not v then
      return defaultNum
    end
    return math.max(minV, math.min(maxV, v))
  end
  local function set(v)
    minimapBarDB()[key] = math.floor(v + 0.5)
    refreshMinimapBar()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Number,
    label,
    defaultNum,
    get,
    set
  )
  local options = Settings.CreateSliderOptions(minV, maxV, step)
  Settings.CreateSlider(category, setting, options, tooltip)
  if Settings.CreateTextBox then
    Settings.CreateTextBox(
      category,
      setting,
      (tooltip or "")
        .. " Puedes escribir un número entero (píxeles de interfaz; respetan la escala de la UI del juego)."
    )
  end
end

--- Política por icono de addon (LibDBIcon, Zygor, etc.). Valores numéricos: Add(valor, texto) en el desplegable.
local POLICY_DEFAULT, POLICY_BAR, POLICY_HIDDEN = 0, 1, 2

local function addonPolicyDropdownOptions()
  local c = Settings.CreateControlTextContainer()
  c:Add(POLICY_DEFAULT, "Defecto (en el mapa)")
  c:Add(POLICY_BAR, "Barra Chukie")
  c:Add(POLICY_HIDDEN, "Oculto")
  return c:GetData()
end

local function addonPolicyUniqueId(frameName)
  local s = tostring(frameName or "x"):gsub("[^%w]", "_")
  if #s > 48 then
    s = strsub(s, 1, 48)
  end
  return "ChukieUi_MM_pol_addon_" .. s
end

local function addAddonPolicyDropdown(category, frameName, label, tooltip)
  local function get()
    local v = minimapBarDB().buttonPolicy[frameName]
    if v == "default" or v == POLICY_DEFAULT then
      return POLICY_DEFAULT
    end
    if v == "hidden" or v == POLICY_HIDDEN then
      return POLICY_HIDDEN
    end
    if v == "bar" or v == POLICY_BAR or v == nil then
      return POLICY_BAR
    end
    local n = tonumber(v)
    if n == POLICY_DEFAULT or n == POLICY_HIDDEN then
      return n
    end
    return POLICY_BAR
  end
  local function set(v)
    v = tonumber(v)
    if v ~= POLICY_DEFAULT and v ~= POLICY_BAR and v ~= POLICY_HIDDEN then
      v = POLICY_BAR
    end
    local db = minimapBarDB().buttonPolicy
    if v == POLICY_BAR then
      db[frameName] = nil
    else
      db[frameName] = v
    end
    refreshMinimapBar()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    addonPolicyUniqueId(frameName),
    Settings.VarType.Number,
    label,
    POLICY_BAR,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    addonPolicyDropdownOptions,
    tooltip
      or "Defecto: deja el icono en el mapa circular. Barra Chukie: fila de addons bajo el mapa. Oculto: oculto. La lista se rellena al detectar iconos (LibDBIcon, etc.)."
  )
end

local function minimenuVisibilityDB()
  local m = minimapBarDB()
  m.minimenuVisibility = m.minimenuVisibility or {}
  return m.minimenuVisibility
end

local MINIMENU_DISPLAY_NAMES = {
  ExpansionLandingPageMinimapButton = "Omnium Folio",
}

local function minimenuDisplayName(frameName)
  if MINIMENU_DISPLAY_NAMES[frameName] then
    return MINIMENU_DISPLAY_NAMES[frameName]
  end
  local s = tostring(frameName or ""):gsub("MicroButton$", "")
  if s == "" then
    return tostring(frameName)
  end
  return s
end

local function minimenuVisibilityUniqueId(frameName)
  local s = tostring(frameName or "x"):gsub("[^%w]", "_")
  if #s > 40 then
    s = strsub(s, 1, 40)
  end
  return "ChukieUi_MM_minimenu_vis_" .. s
end

local function addMinimenuVisibleCheckbox(category, frameName, tooltip)
  local function get()
    return minimenuVisibilityDB()[frameName] ~= false
  end
  local function set(v)
    if v == true or v == 1 then
      minimenuVisibilityDB()[frameName] = nil
    else
      minimenuVisibilityDB()[frameName] = false
    end
    refreshMinimapBar()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    minimenuVisibilityUniqueId(frameName),
    Settings.VarType.Boolean,
    minimenuDisplayName(frameName),
    Settings.Default.True,
    get,
    set
  )
  local tip = tooltip
  if not tip then
    if frameName == "ExpansionLandingPageMinimapButton" then
      tip = "Botón de Landing Page / Omnium Folio (cerca del minimapa en Blizzard). "
        .. "Al activarlo aparece en la fila del micromenú; si está off, queda oculto con «Solo mapa»."
    else
      tip = "Mostrar «" .. minimenuDisplayName(frameName) .. "» en la fila del micromenú del panel derecho."
    end
  end
  Settings.CreateCheckbox(category, setting, tip)
end

local function addBoolPos(category, uniqueId, key, label, tooltip, defaultOn)
  local function get()
    local v = minimapPosDB()[key]
    return v == true or v == 1
  end
  local function set(v)
    --- Settings a veces entrega 1 en lugar de true; v == true solo guardaba false y la opción nunca quedaba activa.
    minimapPosDB()[key] = (v == true or v == 1)
    refreshRightPanelLayout()
  end
  local defaultToken = defaultOn and Settings.Default.True or Settings.Default.False
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Boolean,
    label,
    defaultToken,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function compassDB()
  if ns.Profile and ns.Profile.GetHorizontalCompassModel then
    return ns.Profile:GetHorizontalCompassModel()
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return {}
  end
  p.horizontalCompass = p.horizontalCompass or {}
  return p.horizontalCompass
end

local function refreshCompass()
  if ns.RightPanel and ns.RightPanel.RequestApply then
    ns.RightPanel:RequestApply(0)
  elseif ns.RightPanel and ns.RightPanel.Apply then
    ns.RightPanel:Apply()
  elseif ns.HorizontalCompass and ns.HorizontalCompass.Refresh then
    ns.HorizontalCompass:Refresh()
  end
end

local function addBoolCompass(category, uniqueId, key, label, tooltip, defaultOn)
  local function get()
    local v = compassDB()[key]
    if v == nil then
      return defaultOn ~= false
    end
    return v == true or v == 1
  end
  local function set(v)
    compassDB()[key] = (v == true or v == 1)
    refreshCompass()
  end
  local defaultToken = (defaultOn ~= false) and Settings.Default.True or Settings.Default.False
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Boolean,
    label,
    defaultToken,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function addIntSliderCompass(category, uniqueId, key, label, tooltip, minV, maxV, step, defaultNum)
  local function get()
    local v = tonumber(compassDB()[key])
    if not v then
      return defaultNum
    end
    return math.max(minV, math.min(maxV, v))
  end
  local function set(v)
    compassDB()[key] = math.floor(v + 0.5)
    refreshCompass()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Number,
    label,
    defaultNum,
    get,
    set
  )
  local options = Settings.CreateSliderOptions(minV, maxV, step)
  Settings.CreateSlider(category, setting, options, tooltip)
end

local function addBoolPosSub(category, uniqueId, tableKey, subKey, label, tooltip, defaultOn)
  local function get()
    local root = minimapPosDB()
    root[tableKey] = type(root[tableKey]) == "table" and root[tableKey] or {}
    local v = root[tableKey][subKey]
    if v == nil then
      return defaultOn ~= false
    end
    return v == true or v == 1
  end
  local function set(v)
    local root = minimapPosDB()
    root[tableKey] = type(root[tableKey]) == "table" and root[tableKey] or {}
    root[tableKey][subKey] = (v == true or v == 1)
    refreshRightPanelLayout()
  end
  local defaultToken = (defaultOn ~= false) and Settings.Default.True or Settings.Default.False
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Boolean,
    label,
    defaultToken,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local ARROW_DEFAULT, ARROW_THIN, ARROW_CUSTOM = 0, 1, 2

local function playerArrowModeDropdownData()
  local c = Settings.CreateControlTextContainer()
  c:Add(ARROW_DEFAULT, "Defecto (Blizzard)")
  c:Add(ARROW_THIN, "Flecha fina (vehículo)")
  c:Add(ARROW_CUSTOM, "Personalizada")
  return c:GetData()
end

local function addPlayerArrowSettings(minimapCategory)
  local function getMode()
    local v = tonumber(minimapPosDB().playerArrowMode)
    if v == ARROW_THIN or v == ARROW_CUSTOM then
      return v
    end
    return ARROW_DEFAULT
  end
  local function setMode(v)
    v = tonumber(v)
    if v ~= ARROW_THIN and v ~= ARROW_CUSTOM then
      v = ARROW_DEFAULT
    end
    minimapPosDB().playerArrowMode = v
    refreshRightPanelLayout()
  end
  local modeSetting = Settings.RegisterProxySetting(
    minimapCategory,
    "ChukieUi_MMPos_playerArrowMode",
    Settings.VarType.Number,
    "Flecha del jugador (mapa circular)",
    ARROW_DEFAULT,
    getMode,
    setMode
  )
  Settings.CreateDropdown(
    minimapCategory,
    modeSetting,
    playerArrowModeDropdownData,
    "Minimap:SetPlayerTexture. «Fina» usa Media\\ChukieUi_PlayerArrow_Thin128.png (aguja fina del addon). «Personalizada»: campo de ruta abajo o /chukieui mmarrow custom … — PNG con transparencia o TGA/BLP; /reload tras cambiar archivos en la carpeta del addon."
  )
  local arrowPathSetting = Settings.RegisterAddOnSetting(
    minimapCategory,
    "ChukieUi_MMPos_playerArrowCustom",
    "playerArrowCustom",
    minimapPosDB(),
    Settings.VarType.String,
    "Ruta textura (solo personalizada)",
    ""
  )
  arrowPathSetting:SetValueChangedCallback(function()
    refreshRightPanelLayout()
  end)
  if Settings.CreateTextBox then
    Settings.CreateTextBox(
      minimapCategory,
      arrowPathSetting,
      "Ej.: Interface\\AddOns\\Chukie_Ui\\Media\\FlechaPJ.tga — respeta mayúsculas en el nombre de la carpeta del addon."
    )
  end
end

local function addIntSliderPos(category, uniqueId, key, label, tooltip, minV, maxV, step, defaultNum)
  local function get()
    local v = tonumber(minimapPosDB()[key])
    if not v then
      return defaultNum
    end
    return math.max(minV, math.min(maxV, v))
  end
  local function set(v)
    minimapPosDB()[key] = math.floor(v + 0.5)
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Number,
    label,
    defaultNum,
    get,
    set
  )
  local options = Settings.CreateSliderOptions(minV, maxV, step)
  Settings.CreateSlider(category, setting, options, tooltip)
end

local function addBoolRightWidget(category, uniqueId, key, label, tooltip, defaultOn)
  local function get()
    return rightWidgetsDB()[key] ~= false
  end
  local function set(v)
    rightWidgetsDB()[key] = (v == true or v == 1) and true or false
    refreshRightPanelLayout()
  end
  local defaultToken = defaultOn and Settings.Default.True or Settings.Default.False
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Boolean,
    label,
    defaultToken,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function addIntSliderRightWidget(category, uniqueId, key, label, tooltip, minV, maxV, step, defaultNum)
  local function get()
    local v = tonumber(rightWidgetsDB()[key])
    if not v then
      return defaultNum
    end
    return math.max(minV, math.min(maxV, v))
  end
  local function set(v)
    rightWidgetsDB()[key] = math.floor(v + 0.5)
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Number,
    label,
    defaultNum,
    get,
    set
  )
  local options = Settings.CreateSliderOptions(minV, maxV, step)
  Settings.CreateSlider(category, setting, options, tooltip)
end

local function refreshCombatLog()
  if ns.CombatLog and ns.CombatLog.RefreshConfig then
    ns.CombatLog:RefreshConfig()
  else
    refreshRightPanelLayout()
  end
end

local function addCombatLogBool(category, uniqueId, key, label, tooltip, defaultOn)
  local function get()
    local value = rightWidgetsDB()[key]
    if value == nil then
      return defaultOn == true
    end
    return value == true
  end
  local function set(value)
    rightWidgetsDB()[key] = value == true or value == 1
    refreshCombatLog()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    uniqueId,
    Settings.VarType.Boolean,
    label,
    defaultOn and Settings.Default.True or Settings.Default.False,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function combatLogTypesDB()
  local d = rightWidgetsDB()
  d.combatLogTypes = type(d.combatLogTypes) == "table" and d.combatLogTypes or {}
  return d.combatLogTypes
end

local function addCombatLogTypeBool(category, key, label, tooltip, defaultOn)
  local function get()
    local value = combatLogTypesDB()[key]
    if value == nil then
      return defaultOn == true
    end
    return value == true
  end
  local function set(value)
    combatLogTypesDB()[key] = value == true or value == 1
    refreshCombatLog()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_CombatLogType_" .. key,
    Settings.VarType.Boolean,
    label,
    defaultOn and Settings.Default.True or Settings.Default.False,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function addCombatLogSlotDropdown(category)
  local function data()
    local c = Settings.CreateControlTextContainer()
    c:Add(2, "Ranura 2 (izquierda inferior)")
    c:Add(3, "Ranura 3 (izquierda central)")
    c:Add(4, "Ranura 4 (izquierda superior)")
    return c:GetData()
  end
  local function get()
    return math.max(2, math.min(4, math.floor(tonumber(rightWidgetsDB().combatLogWidgetSlot) or 4)))
  end
  local function set(value)
    rightWidgetsDB().combatLogWidgetSlot = math.max(2, math.min(4, math.floor(tonumber(value) or 4)))
    refreshCombatLog()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_CombatLogWidgetSlot",
    Settings.VarType.Number,
    "Ranura del toggle",
    4,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    data,
    "Reemplaza una celda de la mini barra/detección dinámica. La acción Blizzard permanece guardada."
  )
end

local function createCombatLogInstancesCanvas()
  local panel = CreateFrame("Frame")
  panel.rows = {}
  panel.headers = {}

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -18)
  title:SetText("Combat Log — instancias específicas")

  local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  help:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
  help:SetJustifyH("LEFT")
  help:SetText(
    "Sin selecciones se graban todas las instancias de los tipos habilitados. "
      .. "Al marcar una o más, sólo se graban esas instancias."
  )

  local addCurrent = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  addCurrent:SetSize(150, 22)
  addCurrent:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
  addCurrent:SetText("Añadir instancia actual")

  local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  clear:SetSize(130, 22)
  clear:SetPoint("LEFT", addCurrent, "RIGHT", 8, 0)
  clear:SetText("Limpiar selección")

  local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("LEFT", clear, "RIGHT", 10, 0)
  status:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
  status:SetJustifyH("LEFT")

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", addCurrent, "BOTTOMLEFT", 0, -10)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 18)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(520, 1)
  scroll:SetScrollChild(child)
  panel.scrollChild = child

  local function selections()
    local d = rightWidgetsDB()
    d.combatLogInstances = type(d.combatLogInstances) == "table" and d.combatLogInstances or {}
    return d.combatLogInstances
  end

  local function savedNames()
    local d = rightWidgetsDB()
    d.combatLogInstanceNames =
      type(d.combatLogInstanceNames) == "table" and d.combatLogInstanceNames or {}
    return d.combatLogInstanceNames
  end

  local function addEntry(out, seen, group, key, name)
    if not key or seen[key] then
      return
    end
    seen[key] = true
    out[#out + 1] = { group = group, key = key, name = name or key }
  end

  local function buildCatalog()
    local out, seen = {}, {}
    if C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo then
      local ok, maps = pcall(C_ChallengeMode.GetMapTable)
      if ok and type(maps) == "table" then
        for _, mapID in ipairs(maps) do
          local infoOk, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
          if infoOk and name then
            addEntry(out, seen, "Míticas+ de temporada", "challenge:" .. mapID, name)
          end
        end
      end
    end
    if EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex then
      local oldTier = EJ_GetCurrentTier and EJ_GetCurrentTier() or nil
      local ok, tiers = pcall(EJ_GetNumTiers)
      if ok then
        for tier = 1, tonumber(tiers) or 0 do
          pcall(EJ_SelectTier, tier)
          for _, raid in ipairs({ false, true }) do
            for index = 1, 100 do
              local infoOk, instanceID, name = pcall(EJ_GetInstanceByIndex, index, raid)
              if not infoOk or not instanceID then
                break
              end
              addEntry(out, seen, raid and "Raids" or "Mazmorras", "instance:" .. instanceID, name)
            end
          end
        end
      end
      if oldTier then
        pcall(EJ_SelectTier, oldTier)
      end
    end
    for key, selected in pairs(selections()) do
      if selected == true then
        addEntry(out, seen, "Guardadas / actuales", key, savedNames()[key] or key)
      end
    end
    table.sort(out, function(a, b)
      if a.group == b.group then
        return tostring(a.name) < tostring(b.name)
      end
      return tostring(a.group) < tostring(b.group)
    end)
    return out
  end

  function panel:Refresh()
    for i = 1, #self.rows do
      self.rows[i]:Hide()
    end
    for i = 1, #self.headers do
      self.headers[i]:Hide()
    end
    local entries = buildCatalog()
    local y, rowIndex, headerIndex, lastGroup = 0, 0, 0, nil
    for _, entry in ipairs(entries) do
      if entry.group ~= lastGroup then
        headerIndex = headerIndex + 1
        local header = self.headers[headerIndex]
        if not header then
          header = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
          self.headers[headerIndex] = header
        end
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -y)
        header:SetText(entry.group)
        header:Show()
        y = y + 22
        lastGroup = entry.group
      end
      rowIndex = rowIndex + 1
      local row = self.rows[rowIndex]
      if not row then
        row = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate")
        row:SetSize(22, 22)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row, "RIGHT", 2, 0)
        row.label:SetWidth(430)
        row.label:SetJustifyH("LEFT")
        self.rows[rowIndex] = row
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
      row.label:SetText(entry.name)
      row:SetChecked(selections()[entry.key] == true)
      local rowEntry = entry
      row:SetScript("OnClick", function(self)
        selections()[rowEntry.key] = self:GetChecked() and true or nil
        savedNames()[rowEntry.key] = rowEntry.name
        refreshCombatLog()
      end)
      row:Show()
      y = y + 24
    end
    child:SetHeight(math.max(1, y + 8))
    status:SetText(rowIndex == 0 and "No se pudo cargar el catálogo." or (rowIndex .. " instancias disponibles"))
  end

  addCurrent:SetScript("OnClick", function()
    local ok, message = false, "No se pudo añadir."
    if ns.CombatLog and ns.CombatLog.AddCurrentInstance then
      ok, message = ns.CombatLog:AddCurrentInstance()
    end
    panel:Refresh()
    status:SetText(message or (ok and "Instancia añadida." or "No se pudo añadir."))
    refreshCombatLog()
  end)
  clear:SetScript("OnClick", function()
    rightWidgetsDB().combatLogInstances = {}
    panel:Refresh()
    refreshCombatLog()
  end)
  panel:SetScript("OnShow", function(self)
    self:Refresh()
  end)
  return panel
end

local DATE_FONT_AUTO, DATE_FONT_FRIZ, DATE_FONT_ARIAL, DATE_FONT_MORPHEUS, DATE_FONT_SKURRI = 0, 1, 2, 3, 4

local function dateFontFaceDropdownData()
  local c = Settings.CreateControlTextContainer()
  c:Add(DATE_FONT_AUTO, "Por defecto del juego")
  c:Add(DATE_FONT_FRIZ, "Frizqt")
  c:Add(DATE_FONT_ARIAL, "Arial")
  c:Add(DATE_FONT_MORPHEUS, "Morpheus")
  c:Add(DATE_FONT_SKURRI, "Skurri")
  return c:GetData()
end

local function teleportGridVisibilityDB()
  local d = rightWidgetsDB()
  d.teleportGridVisibility = d.teleportGridVisibility or {}
  return d.teleportGridVisibility
end

local function addTeleportGridVisibilityCheckbox(category, key, label)
  local uid = "ChukieUi_RPW_tpvis_" .. tostring(key or "x"):gsub("[^%w]", "_")
  if #uid > 48 then
    uid = strsub(uid, 1, 48)
  end
  local function get()
    return teleportGridVisibilityDB()[key] ~= false
  end
  local function set(v)
    if v == true or v == 1 then
      teleportGridVisibilityDB()[key] = nil
    else
      teleportGridVisibilityDB()[key] = false
    end
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    uid,
    Settings.VarType.Boolean,
    "Lista: " .. tostring(label or key),
    Settings.Default.True,
    get,
    set
  )
  Settings.CreateCheckbox(
    category,
    setting,
    "Si está desmarcado, esta opción no aparece en el modal del clic derecho sobre la celda de teletransporte (panel azul). Sigue pudiendo elegirse como «default» del clic izquierdo en el desplegable de arriba si es válida para tu personaje."
  )
end

local function addTeleportDefaultDropdown(category)
  local function catalogList()
    if ns.TeleportCatalog and ns.TeleportCatalog.GetList then
      return ns.TeleportCatalog.GetList()
    end
    return {}
  end
  local function teleportDefaultDropdownData()
    local c = Settings.CreateControlTextContainer()
    c:Add(0, "(Automático: primera válida)")
    for i, e in ipairs(catalogList()) do
      local label = (ns.TeleportCatalog and ns.TeleportCatalog.GetDisplayLabel and ns.TeleportCatalog.GetDisplayLabel(e))
        or e.label
      c:Add(i, label)
    end
    return c:GetData()
  end
  local function get()
    local list = catalogList()
    local v = tonumber(rightWidgetsDB().teleportDefaultIndex)
    if v and v >= 1 and v <= #list then
      return math.floor(v)
    end
    local k = rightWidgetsDB().teleportDefaultKey
    if type(k) == "string" and k ~= "" then
      for i = 1, #list do
        if list[i].key == k then
          return i
        end
      end
    end
    return 0
  end
  local function set(v)
    v = tonumber(v)
    if not v or v < 0 then
      v = 0
    end
    local list = catalogList()
    if v > #list then
      v = 0
    end
    rightWidgetsDB().teleportDefaultIndex = math.floor(v)
    if v >= 1 and list[v] then
      rightWidgetsDB().teleportDefaultKey = list[v].key
    else
      rightWidgetsDB().teleportDefaultKey = nil
    end
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_RPW_teleportDefaultIndex",
    Settings.VarType.Number,
    "Teletransporte: clic izquierdo (default)",
    0,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    teleportDefaultDropdownData,
    "Clic izquierdo en el icono del panel azul: ejecuta esta entrada (botón seguro). «(Automático)» = la primera del catálogo que sea válida para tu PJ tras quitar duplicados (mismo CD y mismo destino). El desplegable usa números por compatibilidad con el panel de opciones de WoW 12.x."
  )
end

local function addDateFontFaceDropdown(category)
  local function get()
    local v = tonumber(rightWidgetsDB().dateFontFace)
    if v == DATE_FONT_FRIZ or v == DATE_FONT_ARIAL or v == DATE_FONT_MORPHEUS or v == DATE_FONT_SKURRI then
      return v
    end
    return DATE_FONT_AUTO
  end
  local function set(v)
    v = tonumber(v)
    if v ~= DATE_FONT_FRIZ and v ~= DATE_FONT_ARIAL and v ~= DATE_FONT_MORPHEUS and v ~= DATE_FONT_SKURRI then
      v = DATE_FONT_AUTO
    end
    rightWidgetsDB().dateFontFace = v
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_RPW_dateFontFace",
    Settings.VarType.Number,
    "Tipografía Fecha/Hora",
    DATE_FONT_AUTO,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    dateFontFaceDropdownData,
    "Fuente de texto para el botón de fecha/hora del panel azul."
  )
end

local function addRightStripFontFaceDropdown(category)
  local function get()
    local v = tonumber(minimapPosDB().rightStripFontFace)
    if v == DATE_FONT_FRIZ or v == DATE_FONT_ARIAL or v == DATE_FONT_MORPHEUS or v == DATE_FONT_SKURRI then
      return v
    end
    return DATE_FONT_AUTO
  end
  local function set(v)
    v = tonumber(v)
    if v ~= DATE_FONT_FRIZ and v ~= DATE_FONT_ARIAL and v ~= DATE_FONT_MORPHEUS and v ~= DATE_FONT_SKURRI then
      v = DATE_FONT_AUTO
    end
    minimapPosDB().rightStripFontFace = v
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_MMPos_rightStripFontFace",
    Settings.VarType.Number,
    "Tipografía sector amarillo",
    DATE_FONT_AUTO,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    dateFontFaceDropdownData,
    "Fuente de texto para la grilla inferior del sector amarillo (oro + bolsas)."
  )
end

local function addLeftPanelLootTradeFontFaceDropdown(category)
  local function get()
    local v = tonumber(minimapPosDB().leftPanelFeedFontFace)
    if v == DATE_FONT_FRIZ or v == DATE_FONT_ARIAL or v == DATE_FONT_MORPHEUS or v == DATE_FONT_SKURRI then
      return v
    end
    return DATE_FONT_AUTO
  end
  local function set(v)
    v = tonumber(v)
    if v ~= DATE_FONT_FRIZ and v ~= DATE_FONT_ARIAL and v ~= DATE_FONT_MORPHEUS and v ~= DATE_FONT_SKURRI then
      v = DATE_FONT_AUTO
    end
    minimapPosDB().leftPanelFeedFontFace = v
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_MMPos_leftPanelFeedFontFace",
    Settings.VarType.Number,
    "Tipografía sector historial loot/trade",
    DATE_FONT_AUTO,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    dateFontFaceDropdownData,
    "Fuente de texto para la ventana del sector historial loot/trade."
  )
end

local function addLeftPanelGeneralFontFaceDropdown(category)
  local function get()
    local v = tonumber(minimapPosDB().leftPanelGeneralFontFace)
    if v == DATE_FONT_FRIZ or v == DATE_FONT_ARIAL or v == DATE_FONT_MORPHEUS or v == DATE_FONT_SKURRI then
      return v
    end
    return DATE_FONT_AUTO
  end
  local function set(v)
    v = tonumber(v)
    if v ~= DATE_FONT_FRIZ and v ~= DATE_FONT_ARIAL and v ~= DATE_FONT_MORPHEUS and v ~= DATE_FONT_SKURRI then
      v = DATE_FONT_AUTO
    end
    minimapPosDB().leftPanelGeneralFontFace = v
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_MMPos_leftPanelGeneralFontFace",
    Settings.VarType.Number,
    "Tipografía sector chat general",
    DATE_FONT_AUTO,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    dateFontFaceDropdownData,
    "Fuente de texto para la ventana del sector chat general."
  )
end

local function addLeftPanelGeneralInputFontFaceDropdown(category)
  local function get()
    local v = tonumber(minimapPosDB().leftPanelGeneralInputFontFace)
    if v == DATE_FONT_FRIZ or v == DATE_FONT_ARIAL or v == DATE_FONT_MORPHEUS or v == DATE_FONT_SKURRI then
      return v
    end
    return DATE_FONT_AUTO
  end
  local function set(v)
    v = tonumber(v)
    if v ~= DATE_FONT_FRIZ and v ~= DATE_FONT_ARIAL and v ~= DATE_FONT_MORPHEUS and v ~= DATE_FONT_SKURRI then
      v = DATE_FONT_AUTO
    end
    minimapPosDB().leftPanelGeneralInputFontFace = v
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_MMPos_leftPanelGeneralInputFontFace",
    Settings.VarType.Number,
    "Tipografía entrada chat general",
    DATE_FONT_AUTO,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    dateFontFaceDropdownData,
    "Fuente de texto para la caja de entrada del sector chat general."
  )
end

local ZOOM_PREF_AUTO, ZOOM_PREF_MAX_OUT, ZOOM_PREF_MAX_IN = 0, 1, 2

local function minimapZoomPrefDropdownData()
  local c = Settings.CreateControlTextContainer()
  c:Add(ZOOM_PREF_AUTO, "Automático (Blizzard)")
  c:Add(ZOOM_PREF_MAX_OUT, "Siempre máximo alejado")
  c:Add(ZOOM_PREF_MAX_IN, "Siempre máximo acercado")
  return c:GetData()
end

local function addMinimapZoomPrefDropdown(category)
  local function get()
    local v = tonumber(minimapPosDB().minimapZoomPreference)
    if v == ZOOM_PREF_MAX_OUT or v == ZOOM_PREF_MAX_IN then
      return v
    end
    return ZOOM_PREF_AUTO
  end
  local function set(v)
    v = tonumber(v)
    if v ~= ZOOM_PREF_MAX_OUT and v ~= ZOOM_PREF_MAX_IN then
      v = ZOOM_PREF_AUTO
    end
    minimapPosDB().minimapZoomPreference = v
    refreshRightPanelLayout()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_MMPos_zoomPref",
    Settings.VarType.Number,
    "Zoom del mapa (pasos del juego)",
    ZOOM_PREF_AUTO,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    minimapZoomPrefDropdownData,
    "El cliente solo ofrece un número fijo de niveles (Minimap:GetZoomLevels / botones + y -). No existe API para «más zoom» allá de eso. Aquí solo se fuerza el paso más alejado (0) o el más cercado permitido tras eventos de zoom (interior/exterior, etc.). Si ajustas el zoom a mano, Blizzard puede volver a cambiarlo hasta el próximo evento."
  )
end

function ns.RegisterConfigPanel()
  if ns.configPanelRegistered then
    return
  end
  if not Settings or not Settings.RegisterVerticalLayoutCategory then
    return
  end

  local rootCategory, rootLayout = Settings.RegisterVerticalLayoutCategory("Chukie UI")
  rootCategory.ID = "ChukieUi"

  -- Raíz: opciones globales del addon (otros temas además del panel derecho).
  rootLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Perfiles"))

  do
    local profileSetting = Settings.RegisterAddOnSetting(
      rootCategory,
      "ChukieUi_currentProfile",
      "currentProfile",
      ChukieUiDB,
      Settings.VarType.String,
      "Perfil activo",
      ns.Profile:GetCurrentName()
    )
    profileSetting:SetValueChangedCallback(function()
      ns.Profile:GetActive()
      ns.Profile:NotifyChanged()
    end)
    local function profileDropdownOptions()
      local container = Settings.CreateControlTextContainer()
      for _, name in ipairs(ns.Profile:ListSorted()) do
        container:Add(name, name)
      end
      return container:GetData()
    end
    Settings.CreateDropdown(rootCategory, profileSetting, profileDropdownOptions, "«Default» incluye opciones válidas por defecto. Cada perfil guarda su propia copia de ajustes.")
  end

  rootLayout:AddInitializer(
    CreateSettingsButtonInitializer(
      "",
      "Duplicar",
      function()
        local newName = ns.Profile:DuplicateCurrent()
        print("|cff00ff00Chukie UI|r: nuevo perfil «" .. newName .. "». Vuelve a abrir Opciones si el desplegable no se actualiza.")
      end,
      "Copia el perfil activo a uno nuevo y lo selecciona.",
      true,
      nil,
      nil
    )
  )

  rootLayout:AddInitializer(
    CreateSettingsButtonInitializer(
      "",
      "Eliminar",
      function()
        local ok, err = ns.Profile:DeleteCurrent()
        if ok then
          print("|cff00ff00Chukie UI|r: perfil eliminado. Perfil activo: Default.")
        elseif err then
          print("|cffff9900Chukie UI|r: " .. err)
        end
      end,
      "No se puede eliminar «Default». Debe quedar al menos un perfil.",
      true,
      nil,
      nil
    )
  )

  rootLayout:AddInitializer(
    CreateSettingsButtonInitializer(
      "",
      "Restaurar",
      function()
        ns.Profile:ResetCurrentToTemplate()
        print("|cff00ff00Chukie UI|r: perfil «" .. ns.Profile:GetCurrentName() .. "» restaurado a los valores por defecto del addon.")
      end,
      "Vuelve a poner este perfil como al instalar (valores por defecto del addon).",
      true,
      nil,
      nil
    )
  )

  Settings.RegisterAddOnCategory(rootCategory)

  local minimapCategory = Settings.RegisterVerticalLayoutSubcategory(rootCategory, "Panel derecho")
  local minimapLayout = SettingsPanel:GetLayout(minimapCategory)

  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Panel derecho"))
  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Posición"))
  addIntSliderPos(
    minimapCategory,
    "ChukieUi_MMPos_offsetX",
    "offsetX",
    "Desplazamiento X (desde la esquina inferior derecha)",
    "Distancia horizontal desde la esquina inferior derecha de la pantalla: valores negativos mueven el panel hacia la izquierda.",
    -1200,
    120,
    1,
    0
  )
  addIntSliderPos(
    minimapCategory,
    "ChukieUi_MMPos_offsetY",
    "offsetY",
    "Desplazamiento Y (desde la esquina inferior derecha)",
    "Distancia vertical desde la esquina inferior derecha: positivos suben el panel; negativos lo bajan (hasta −1200 px). El cluster no usa clamp automático a pantalla para que el offset se respete del todo (puedes sacarlo parcialmente del borde si lo llevas al extremo).",
    -1200,
    900,
    1,
    0
  )
  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Tamaño global del panel"))
  addIntSliderPos(
    minimapCategory,
    "ChukieUi_MMPos_panelScalePct",
    "panelScalePercent",
    "Tamaño global del panel (%)",
    "Escala única para todo el cluster del panel derecho: minimapa, barra de addons, micromenú y ranuras. Mantiene proporciones y centrado automático.",
    60,
    220,
    1,
    100
  )
  addBoolPos(
    minimapCategory,
    "ChukieUi_MMPos_lockRightPanelEdit",
    "lockRightPanelInEditMode",
    "No soltar el cluster al modo edición de Blizzard",
    "Si está activo, en modo edición el MinimapCluster sigue en ChukieUi_RightPanel (tamaño fijo) y no pasa a UIParent para el editor nativo del minimapa. Desmárcalo si quieres mover el minimapa con el sistema de Blizzard en modo edición (puede chocar con el panel fijo).",
    true
  )
  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Depuración"))
  addBoolPos(
    minimapCategory,
    "ChukieUi_MMPos_debugBounds",
    "debugRightPanelBounds",
    "Recuadro verde del panel derecho",
    "Borde verde: con panel Chukie activo dibuja la caja que engloba Minimap + barra de addons + micromenú (referencia real del contenido); si aún no hay layout, el marco ChukieUi_RightPanel entero. Franja a la derecha. No captura el ratón.",
    false
  )
  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Zoom del mapa"))
  addMinimapZoomPrefDropdown(minimapCategory)
  addBoolPos(
    minimapCategory,
    "ChukieUi_MMPos_rotateMinimap",
    "rotateMinimap",
    "Rotar el mapa con la dirección del personaje",
    "Equivale al CVar rotateMinimap de Blizzard: el mapa gira y la flecha del jugador queda fija hacia arriba. Si «Solo mapa» está activo, Chukie mostrará la brújula (MinimapCompassTexture) en lugar de ocultarla. Si cambias esto en Opciones de Blizzard, el siguiente refresco de Chukie puede volver a alinear el CVar con esta casilla. "
      .. "En mazmorras/bandas GetPlayerFacing no responde: con esta opción activa la brújula horizontal puede seguir funcionando.",
    false
  )

  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Brújula horizontal"))
  addBoolCompass(
    minimapCategory,
    "ChukieUi_HC_enabled",
    "enabled",
    "Activar brújula horizontal",
    "Línea de rumbo encima del minimapa: el centro es hacia dónde mirás; N/E/S/O se desplazan. "
      .. "Si no hay rumbo (p. ej. instancia sin rotar mapa), congela el último valor o se oculta según la opción de abajo.",
    true
  )
  addIntSliderCompass(
    minimapCategory,
    "ChukieUi_HC_height",
    "height",
    "Altura (px)",
    "Altura de la franja de la brújula (también se reserva encima del minimapa).",
    14,
    48,
    1,
    22
  )
  addIntSliderCompass(
    minimapCategory,
    "ChukieUi_HC_fov",
    "fovDegrees",
    "Campo visual (°)",
    "Cuántos grados caben a lo ancho de la cinta (más bajo = más zoom en el rumbo).",
    60,
    180,
    5,
    120
  )
  addIntSliderCompass(
    minimapCategory,
    "ChukieUi_HC_fontSize",
    "fontSize",
    "Tamaño de fuente",
    "Tamaño de las letras N/NE/E/…",
    8,
    24,
    1,
    12
  )
  addIntSliderCompass(
    minimapCategory,
    "ChukieUi_HC_offsetY",
    "offsetY",
    "Offset Y",
    "Posición vertical medida desde el CENTRO del minimapa (px): valores altos la suben encima del mapa, "
      .. "valores negativos la bajan hasta quedar debajo del minimapa. 0 = justo sobre el centro del mapa.",
    -160,
    160,
    1,
    0
  )
  addBoolCompass(
    minimapCategory,
    "ChukieUi_HC_ticks",
    "showDegreeTicks",
    "Marcas de grados",
    "Rayitas cada 15° entre los cardinales.",
    true
  )
  addBoolCompass(
    minimapCategory,
    "ChukieUi_HC_target",
    "showTarget",
    "Marcador del target",
    "Marca roja hacia el objetivo actual si hay posición de mapa válida. Sin dato o en secreto: no se muestra (sin error).",
    true
  )
  addBoolCompass(
    minimapCategory,
    "ChukieUi_HC_waypoint",
    "showWaypoint",
    "Marcador de waypoint / misión",
    "Marca azul hacia el punto rastreado (SuperTrack) o waypoint de misión, si la API lo permite.",
    true
  )
  addBoolCompass(
    minimapCategory,
    "ChukieUi_HC_group",
    "showGroup",
    "Marcadores de grupo",
    "Marcas verdes hacia miembros de party/raid con posición de mapa. Desactivado por defecto.",
    false
  )
  addBoolCompass(
    minimapCategory,
    "ChukieUi_HC_hideNoFacing",
    "hideWhenNoFacing",
    "Ocultar si no hay rumbo",
    "Si GetPlayerFacing no responde y no se puede leer el anillo del minimapa, oculta la cinta en lugar de congelar el último rumbo.",
    false
  )

  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Flecha del jugador"))
  addPlayerArrowSettings(minimapCategory)

  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Sector amarillo (grilla inferior)"))
  addBoolPos(
    minimapCategory,
    "ChukieUi_MMPos_rightStripUseMasque",
    "rightStripUseMasque",
    "Masque en sector amarillo",
    "Aplica estilo Masque al botón de la grilla inferior del sector amarillo (si Masque está instalado).",
    false
  )
  addIntSliderPos(
    minimapCategory,
    "ChukieUi_MMPos_rightStripGridScale",
    "rightStripGridScalePercent",
    "Tamaño de grilla sector amarillo (%)",
    "Escala visual de la grilla inferior (iconos + espaciado).",
    60,
    180,
    1,
    100
  )
  addRightStripFontFaceDropdown(minimapCategory)
  addIntSliderPos(
    minimapCategory,
    "ChukieUi_MMPos_rightStripFontSize",
    "rightStripFontSize",
    "Tamaño fuente sector amarillo",
    "Tamaño de texto de la grilla inferior. 0 = automático.",
    0,
    32,
    1,
    0
  )

  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Barra de addons"))

  addBoolProxy(
    minimapCategory,
    "ChukieUi_MMBar_stripBlizz",
    "stripBlizzardMinimap",
    "Solo mapa (ocultar UI de Blizzard)",
    "Oculta zoom, rastreo, correo, cola, reloj, dificultad, compartimento de addons (contador), franja de ubicación y similares; deja solo el círculo del mapa. Blizzard puede volver a mostrar algún marco: se fuerza el oculto al refrescar. Desmarcar restaura la interfaz por defecto.",
    true
  )
  addBoolProxy(
    minimapCategory,
    "ChukieUi_MMBar_enabled",
    "enabled",
    "Activar barra de iconos (addons)",
    "Coloca en una fila bajo el mapa solo los iconos de addons (LibDBIcon, Zygor, otros botones pequeños junto al mapa). No mueve botones de Blizzard.",
    true
  )
  addBoolProxy(
    minimapCategory,
    "ChukieUi_MMBar_lockLdb",
    "lockLdb",
    "Bloquear arrastre LibDBIcon",
    "Desactiva arrastre (Lock de LibDBIcon y RegisterForDrag) para que no reposicionen el icono en el borde del mapa al soltarlo.",
    true
  )
  addBoolProxy(
    minimapCategory,
    "ChukieUi_MMBar_useMasque",
    "useMasque",
    "Masque en la barra de addons",
    "Si tienes Masque instalado, el grupo «Chukie UI» → «MinimapBar» aplica a los botones proxy de la barra (iconos propios, no el marco LibDBIcon).",
    true
  )
  addBoolProxy(
    minimapCategory,
    "ChukieUi_MMBar_useMasqueMicro",
    "useMasqueMicromenu",
    "Masque en el micromenú",
    "Independiente de la barra de addons. En Masque aparece el subgrupo «Chukie UI» → «MinimapBarMicroMenu». Algunos botones de Blizzard no exponen textura «Icon» y pueden no skinerse bien; prueba y desmarca si algo raro.",
    false
  )
  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Barra minimenú"))
  addBoolProxy(
    minimapCategory,
    "ChukieUi_MMBar_minimenuBar",
    "minimenuBarEnabled",
    "Activar segunda fila (minimenú)",
    "Muestra la fila del micromenú de Blizzard bajo la barra de addons, alineada con el ancho del mapa circular. Desmarcar devuelve los botones a la barra inferior por defecto.",
    true
  )
  minimapLayout:AddInitializer(
    CreateSettingsListSectionHeaderInitializer("Las barras se centran automáticamente bajo el minimapa. Tamaño y proporciones dependen del slider global.")
  )
  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Ajustes de barra de addons"))
  addIntSliderPx(
    minimapCategory,
    "ChukieUi_MMBar_addonIconWidth",
    "addonBarIconWidth",
    "Ancho de botón (addons, px)",
    "Ancho objetivo de cada botón en la barra de addons. A mayor ancho, mayor ancho total de la barra; el centrado horizontal se mantiene automático.",
    16,
    72,
    1,
    34
  )
  addIntSliderPx(
    minimapCategory,
    "ChukieUi_MMBar_addonSpacing",
    "addonBarSpacing",
    "Separación entre botones (addons, px)",
    "Espacio horizontal entre botones de addons. Impacta el ancho total y se recalcúla manteniendo el centrado.",
    0,
    24,
    1,
    4
  )
  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Ajustes de barra de micromenú"))
  addIntSliderPx(
    minimapCategory,
    "ChukieUi_MMBar_microIconWidth",
    "minimenuIconWidth",
    "Ancho de botón (micromenú, px)",
    "Ancho objetivo de cada botón del micromenú. Ajusta el ancho total de la barra y conserva centrado automático.",
    12,
    56,
    1,
    28
  )
  addIntSliderPx(
    minimapCategory,
    "ChukieUi_MMBar_microSpacing",
    "minimenuSpacing",
    "Separación entre botones (micromenú, px)",
    "Espacio horizontal entre botones del micromenú. Se aplica con centrado automático respecto al bloque central.",
    0,
    24,
    1,
    2
  )

  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Panel azul: widgets de sistema"))
  addBoolRightWidget(
    minimapCategory,
    "ChukieUi_RPW_enabled",
    "enabled",
    "Activar widgets del panel azul",
    "Muestra la grilla 2x4 de widgets proxy y el boton ancho de fecha/hora en el bloque azul izquierdo del panel derecho.",
    true
  )
  addBoolRightWidget(
    minimapCategory,
    "ChukieUi_RPW_useMasque",
    "useMasque",
    "Masque en widgets del panel azul",
    "Aplica Masque al grupo «Chukie UI» -> «RightPanelWidgets».",
    true
  )
  addIntSliderRightWidget(
    minimapCategory,
    "ChukieUi_RPW_gridCell",
    "gridCellSize",
    "Tamaño de celda de grilla (px)",
    "Tamaño base de cada boton de la grilla del panel azul. Escala con el slider global.",
    14,
    120,
    1,
    46
  )
  addIntSliderRightWidget(
    minimapCategory,
    "ChukieUi_RPW_gridGap",
    "gridGap",
    "Separación de grilla (px)",
    "Espacio horizontal y vertical entre botones de la grilla del panel azul.",
    0,
    20,
    1,
    4
  )
  addIntSliderRightWidget(
    minimapCategory,
    "ChukieUi_RPW_dateHeight",
    "dateHeight",
    "Alto botón Fecha/Hora (px)",
    "Altura del boton ancho inferior de fecha/hora en el panel azul.",
    18,
    46,
    1,
    24
  )
  addDateFontFaceDropdown(minimapCategory)
  addIntSliderRightWidget(
    minimapCategory,
    "ChukieUi_RPW_dateFontSize",
    "dateFontSize",
    "Tamaño fuente Fecha/Hora",
    "Tamaño de texto del botón fecha/hora. Si lo dejas en 0 usa tamaño automático según altura del botón.",
    0,
    32,
    1,
    0
  )

  minimapLayout:AddInitializer(
    CreateSettingsListSectionHeaderInitializer(
      "Teletransporte (panel azul, celda reservada 1): qué es cada cosa"
    )
  )
  addTeleportDefaultDropdown(minimapCategory)
  if ns.TeleportCatalog and ns.TeleportCatalog.GetList then
    for _, e in ipairs(ns.TeleportCatalog.GetList()) do
      local label = (ns.TeleportCatalog.GetDisplayLabel and ns.TeleportCatalog.GetDisplayLabel(e)) or e.label
      addTeleportGridVisibilityCheckbox(minimapCategory, e.key, label)
    end
  end

  minimapLayout:AddInitializer(
    CreateSettingsListSectionHeaderInitializer("Mini barra de acciones (celdas 2, 3 y 4)")
  )
  addBoolRightWidget(
    minimapCategory,
    "ChukieUi_RPW_miniActionBarEnabled",
    "miniActionBarEnabled",
    "Barra de 3 acciones (Action Bar 6)",
    "Convierte las tres celdas reservadas en botones de acción normales (slots 145–147, Action Bar 6 / MultiBar5). "
      .. "Si el toggle de Combat Log está activo, su celda queda excluida y permanecen dos acciones visibles. "
      .. "Acepta cualquier hechizo, macro o ítem (no usa Bonus Bar 6 / tótems). "
      .. "Arrastra como en Dominos o una barra Blizzard. "
      .. "Teclas: Esc → Controles → «Chukie UI - mini barra acción 1/2/3», o Multi Action Bar 5 botones 1–3. "
      .. "Si ves errores SetAttribute/SetCooldown en ChukieUi_MiniAct*, desactivá esta opción y /reload.",
    true
  )
  minimapLayout:AddInitializer(
    CreateSettingsListSectionHeaderInitializer("Ranuras dinámicas (alternativa si la mini barra está off)")
  )
  addBoolRightWidget(
    minimapCategory,
    "ChukieUi_RPW_dynamicActionSlotsEnabled",
    "dynamicActionSlotsEnabled",
    "Activar detección automática",
    "Solo aplica si «Barra de 3 acciones» está desactivada. Rellena las tres celdas: (1) acción extra, (2) habilidad de zona, (3) ítems de misiones rastreadas. "
      .. "La celda ocupada por Combat Log se omite y la cola se compacta en las restantes. "
      .. "Teclas en Esc → Controles → «Chukie UI - ranura dinámica 2/3/4».",
    true
  )
  addBoolRightWidget(
    minimapCategory,
    "ChukieUi_RPW_staticSessionMode",
    "staticSessionMode",
    "Modo estático (sin detección dinámica)",
    "Solo afecta si la mini barra está off: desactiva la lógica situacional de combate/zona/quests en las ranuras reservadas.",
    true
  )

  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Micromenú: mostrar botones"))
  ns._mmMinimenuRegistered = {}
  ns._minimenuVisibilityCategory = minimapCategory
  if ns.MinimapBar and ns.MinimapBar.GetMinimenuButtonNameList then
    for _, name in ipairs(ns.MinimapBar:GetMinimenuButtonNameList()) do
      addMinimenuVisibleCheckbox(minimapCategory, name, nil)
      ns._mmMinimenuRegistered[name] = true
    end
  end

  function ns.AppendMinimenuVisibilityRows()
    if not ns.configPanelRegistered or not ns._minimenuVisibilityCategory then
      return
    end
    if not ns.MinimapBar or not ns.MinimapBar.GetMinimenuButtonNameList then
      return
    end
    local cat = ns._minimenuVisibilityCategory
    for _, name in ipairs(ns.MinimapBar:GetMinimenuButtonNameList()) do
      if not ns._mmMinimenuRegistered[name] then
        ns._mmMinimenuRegistered[name] = true
        addMinimenuVisibleCheckbox(cat, name, nil)
      end
    end
  end

  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Addons (LibDBIcon y detectados)"))
  ns._mmAddonPolicyRegistered = {}
  ns._minimapAddonPolicyCategory = minimapCategory
  for _, name in ipairs(minimapBarDB().discoveredOrder or {}) do
    addAddonPolicyDropdown(minimapCategory, name, name, nil)
    ns._mmAddonPolicyRegistered[name] = true
  end

  function ns.AppendMinimapDiscoveryPolicyRows()
    if not ns.configPanelRegistered or not ns._minimapAddonPolicyCategory then
      return
    end
    local cat = ns._minimapAddonPolicyCategory
    for _, name in ipairs(minimapBarDB().discoveredOrder or {}) do
      if not ns._mmAddonPolicyRegistered[name] then
        ns._mmAddonPolicyRegistered[name] = true
        addAddonPolicyDropdown(cat, name, name, nil)
      end
    end
  end

  local barsCategory = Settings.RegisterVerticalLayoutSubcategory(rootCategory, "Barras de acción")
  local barsLayout = SettingsPanel:GetLayout(barsCategory)
  barsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_enabled",
    "enabled",
    "Activar barras Chukie",
    "Reemplaza Dominos para las barras 1–4 (panel izquierdo) y la barra 6 (panel derecho). "
      .. "Usa la misma numeración de slots que Dominos (barra N = slots (N−1)×12+…). "
      .. "Desactivá Dominos (o esas barras) para no duplicar botones.",
    true
  )
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_hideBlizz",
    "hideBlizzardArt",
    "Ocultar arte Blizzard",
    "Oculta MainActionBar / MultiBars / XP y botones stock (mismo enfoque que Bartender/Dominos). "
      .. "No toca el micromenú ni las bolsas que gestiona Chukie. Activo por defecto.",
    true
  )
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_skyriding",
    "skyridingPaging",
    "Paging skyriding 1–4 → 8–11",
    "Con [bonusbar:5] (skyriding), la barra 1 muestra la 8, la 2→9, la 3→10 y la 4→11.",
    true
  )
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_vehicle",
    "vehiclePaging",
    "Barra de vehículo en la barra 1",
    "En vehículos, misiones con barra propia (override) y posesión, la barra 1 muestra esas acciones "
      .. "y vuelve sola al salir. Tiene prioridad sobre el paging de skyriding.",
    true
  )
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_bonus",
    "bonusPaging",
    "Barras de bonus en la barra 1",
    "Con [bonusbar:1..4] la barra 1 muestra las páginas 7–10: formas, sigilo y las habilidades "
      .. "temporales que dan algunas misiones o eventos. Es el mismo cálculo que hace Blizzard; "
      .. "apagado, la barra 1 se queda en la página normal cuando el juego cambia de situación.",
    true
  )
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_vehicleExit",
    "vehicleExitButton",
    "Botón de bajarse sobre la barra 1",
    "Muestra el botón de salida (vehículo, taxi y posesión) justo encima de la barra 1, un tercio "
      .. "más grande que sus botones, y oculta el de Blizzard. Requiere /reload para volver al de Blizzard.",
    true
  )
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_useMasque",
    "useMasque",
    "Masque en barras de acción",
    "Si Masque está instalado, aplica el grupo «Chukie UI» → «ActionBars» a los botones. "
      .. "Tras cambiar tamaño, Masque re-skinea para que el borde acompañe al botón.",
    true
  )
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_pressAndHoldRelease",
    "pressAndHoldRelease",
    "Hold and release (empower)",
    "Mantiene la tecla/clic para empower de Evoker (Fire Breath, Eternity Surge, etc.) y "
      .. "suelta para castear. Desactivá para el comportamiento anterior de tecla (sin typerelease).",
    true
  )
  do
    local function get()
      return actionBarsDB().applyDefaultKeybinds ~= false
    end
    local function set(v)
      local d = actionBarsDB()
      local on = (v == true or v == 1)
      d.applyDefaultKeybinds = on
      if on then
        d._defaultKeybindsApplied = nil
      end
      refreshActionBars()
    end
    local setting = Settings.RegisterProxySetting(
      barsCategory,
      "ChukieUi_AB_applyDefaultKeys",
      Settings.VarType.Boolean,
      "Teclas por defecto (1–4)",
      Settings.Default.True,
      get,
      set
    )
    Settings.CreateCheckbox(
      barsCategory,
      setting,
      "En el primer uso (o al reactivar esta opción) asigna: barra1=12345, barra2=QWERTY, barra3=ASDFG, barra4=ZXCV. "
        .. "También en Esc → Teclado → Chukie UI - Barras 1–4. Desmarcá y volvé a marcar para reaplicar."
    )
  end

  barsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Bloque 6 × 4 (barras 1–4)"))
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_leftEnabled",
    "leftEnabled",
    "Mostrar barras 1–4",
    "Cuatro filas horizontales que forman un bloque centrado en la pantalla.",
    true
  )
  barsLayout:AddInitializer(
    CreateSettingsListSectionHeaderInitializer(
      "Fijas en 6 botones por fila (matriz 6 × 4). El centro del bloque se ancla al centro "
        .. "de la pantalla; Offset X/Y lo mueven desde ahí."
    )
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_leftSize",
    "leftButtonSize",
    "Tamaño botón (px)",
    "Tamaño de cada botón de las barras izquierdas.",
    18,
    64,
    1,
    36
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_leftGap",
    "leftSpacing",
    "Espacio entre botones",
    "Separación horizontal entre botones.",
    0,
    16,
    1,
    2
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_leftBarGap",
    "leftBarSpacing",
    "Espacio entre filas",
    "Separación vertical entre barras 1–4.",
    0,
    24,
    1,
    4
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_leftOffX",
    "leftOffsetX",
    "Offset X",
    "Desplazamiento horizontal del bloque 6×4 desde el centro de la pantalla.",
    -1800,
    1800,
    1,
    0
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_leftOffY",
    "leftOffsetY",
    "Offset Y",
    "Desplazamiento vertical del bloque 6×4 desde el centro de la pantalla.",
    -1200,
    1200,
    1,
    0
  )

  local alphaCanvas = createLeftButtonAlphaCanvas()
  local alphaCategory, alphaLayout =
    Settings.RegisterCanvasLayoutSubcategory(barsCategory, alphaCanvas, "Transparencia 6 × 4")
  alphaCategory.ID = "ChukieUi_ActionBars_AlphaGrid"
  if alphaLayout and alphaLayout.AddAnchorPoint then
    alphaLayout:AddAnchorPoint("TOPLEFT", 0, 0)
    alphaLayout:AddAnchorPoint("BOTTOMRIGHT", 0, 0)
  end

  barsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Guardar acciones (barras 1–4)"))
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_saveLeftLayout",
    "saveLeftLayout",
    "Guardar acciones de las barras 1–4",
    "Recuerda qué hay en cada ranura de las barras 1–4 (y sus páginas de skyriding) por personaje "
      .. "y especialización. Se guarda solo cuando arrastrás algo, no durante un cambio de talentos.",
    true
  )
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_restoreLeftLayout",
    "restoreLeftLayoutOnTalents",
    "Restaurar al cambiar talentos",
    "Blizzard guarda un juego de barras por loadout de talentos: al cambiar de build las ranuras se pisan. "
      .. "Con esto activo, unos segundos después vuelve a colocar lo guardado. Nunca vacía ranuras: solo repone "
      .. "lo que estaba guardado, y siempre fuera de combate.",
    true
  )
  do
    local function layouts()
      return ns.ActionBarLayouts
    end
    barsLayout:AddInitializer(
      CreateSettingsButtonInitializer(
        "",
        "Guardar acciones ahora",
        function()
          local m = layouts()
          if not m then
            return
          end
          m:SaveNow()
          print("|cff00ff00Chukie UI|r: " .. m:GetStatusText())
        end,
        "Toma una foto de las barras 1–4 tal como están y la guarda para este personaje y especialización.",
        true,
        nil,
        nil
      )
    )
    barsLayout:AddInitializer(
      CreateSettingsButtonInitializer(
        "",
        "Restaurar acciones",
        function()
          local m = layouts()
          if m then
            m:RestoreNow()
          end
        end,
        "Vuelve a colocar las acciones guardadas en las barras 1–4. Fuera de combate y con el cursor vacío.",
        true,
        nil,
        nil
      )
    )
    barsLayout:AddInitializer(
      CreateSettingsButtonInitializer(
        "",
        "Borrar guardado",
        function()
          local m = layouts()
          if m then
            m:ClearSaved()
          end
        end,
        "Olvida las acciones guardadas de esta especialización. No toca las barras actuales.",
        true,
        nil,
        nil
      )
    )
  end

  barsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Panel derecho (barra 6)"))
  addBoolActionBars(
    barsCategory,
    "ChukieUi_AB_right6",
    "rightBar6Enabled",
    "Mostrar barra 6 (2×4)",
    "Ocho botones en 2 columnas × 4 filas (slots Dominos 61–68).",
    true
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_right6Size",
    "rightBar6ButtonSize",
    "Tamaño botón barra 6",
    "Tamaño de cada botón de la barra 6.",
    18,
    64,
    1,
    36
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_right6Gap",
    "rightBar6Spacing",
    "Espacio barra 6",
    "Separación entre botones de la barra 6.",
    0,
    16,
    1,
    2
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_right6OffX",
    "rightBar6OffsetX",
    "Offset X barra 6",
    "Desde BOTTOMLEFT del panel derecho.",
    -400,
    800,
    1,
    8
  )
  addIntSliderActionBars(
    barsCategory,
    "ChukieUi_AB_right6OffY",
    "rightBar6OffsetY",
    "Offset Y barra 6",
    "Desde BOTTOMLEFT del panel derecho.",
    -200,
    400,
    1,
    8
  )

  local leftCategory = Settings.RegisterVerticalLayoutSubcategory(rootCategory, "Panel izquierdo")
  local leftLayout = SettingsPanel:GetLayout(leftCategory)
  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Panel izquierdo (nuevo)"))
  addBoolPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelEnabled",
    "leftPanelEnabled",
    "Activar panel izquierdo",
    "Muestra el panel izquierdo y habilita el sector historial loot/trade y el sector chat general.",
    true
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelScalePct",
    "leftPanelScalePercent",
    "Tamaño panel izquierdo (%)",
    "Escala global del panel izquierdo, independiente del panel derecho.",
    60,
    220,
    1,
    100
  )
  addBoolPos(
    leftCategory,
    "ChukieUi_MMPos_debugLeftBounds",
    "debugLeftPanelBounds",
    "Mostrar referencias del panel izquierdo",
    "Dibuja los 5 sectores del panel izquierdo con la forma proporcional de la maqueta (bloques rojos).",
    false
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_debugLeftOffsetX",
    "leftPanelDebugOffsetX",
    "Mover conjunto X (panel izquierdo)",
    "Mueve horizontalmente los 5 sectores del panel izquierdo como un bloque único, tomando como referencia la esquina inferior izquierda del root.",
    -1200,
    1200,
    1,
    0
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_debugLeftOffsetY",
    "leftPanelDebugOffsetY",
    "Mover conjunto Y (panel izquierdo)",
    "Mueve verticalmente los 5 sectores del panel izquierdo como un bloque único, tomando como referencia la esquina inferior izquierda del root.",
    -1200,
    1200,
    1,
    0
  )
  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Combat Log"))
  addCombatLogBool(
    leftCategory,
    "ChukieUi_CombatLogWidgetEnabled",
    "combatLogWidgetEnabled",
    "Toggle en la grilla 2 × 4",
    "Reemplaza una de las tres ranuras de acción del bloque azul por un botón que inicia/detiene Logs\\WoWCombatLog.txt.",
    true
  )
  addCombatLogSlotDropdown(leftCategory)
  addCombatLogBool(
    leftCategory,
    "ChukieUi_CombatLogStopOnExit",
    "combatLogStopOnExit",
    "Detener al salir",
    "Sólo detiene una grabación iniciada automáticamente por Chukie UI; nunca apaga una sesión manual o de otro addon.",
    true
  )
  addCombatLogBool(
    leftCategory,
    "ChukieUi_CombatLogAdvanced",
    "combatLogAdvanced",
    "Advanced Combat Logging",
    "Controla el CVar advancedCombatLogging, recomendado para Warcraft Logs.",
    true
  )
  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Auto-logging: mazmorras"))
  addCombatLogTypeBool(leftCategory, "dungeonNormal", "Mazmorra normal", "Autoactivar en dificultad normal.", false)
  addCombatLogTypeBool(leftCategory, "dungeonHeroic", "Mazmorra heroica", "Autoactivar en dificultad heroica.", false)
  addCombatLogTypeBool(leftCategory, "dungeonMythic", "Mazmorra mítica (0)", "Autoactivar en mítica sin piedra.", false)
  addCombatLogTypeBool(leftCategory, "dungeonMythicPlus", "Mazmorra mítica+", "Autoactivar al comenzar una instancia M+.", true)
  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Auto-logging: raids"))
  addCombatLogTypeBool(leftCategory, "raidLfr", "Raid LFR", "Autoactivar en Buscador de bandas.", false)
  addCombatLogTypeBool(leftCategory, "raidNormal", "Raid normal", "Autoactivar en raid normal.", false)
  addCombatLogTypeBool(leftCategory, "raidHeroic", "Raid heroica", "Autoactivar en raid heroica.", false)
  addCombatLogTypeBool(leftCategory, "raidMythic", "Raid mítica", "Autoactivar en raid mítica.", true)
  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Auto-logging: otros"))
  addCombatLogTypeBool(leftCategory, "timewalking", "Paseo en el tiempo", "Autoactivar en contenido Timewalking.", false)
  addCombatLogTypeBool(leftCategory, "delve", "Delves / escenarios", "Autoactivar en instancias de tipo escenario.", false)
  addCombatLogTypeBool(leftCategory, "pvp", "Arena / campo de batalla", "Autoactivar en PvP instanciado.", false)

  local combatInstancesCanvas = createCombatLogInstancesCanvas()
  local combatInstancesCategory, combatInstancesLayout =
    Settings.RegisterCanvasLayoutSubcategory(leftCategory, combatInstancesCanvas, "Instancias específicas")
  combatInstancesCategory.ID = "ChukieUi_CombatLogInstances"
  combatInstancesLayout:AddAnchorPoint("TOPLEFT", 0, 0)
  combatInstancesLayout:AddAnchorPoint("BOTTOMRIGHT", 0, 0)

  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Sector historial loot/trade"))
  addLeftPanelLootTradeFontFaceDropdown(leftCategory)
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelFeedFontSize",
    "leftPanelFeedFontSize",
    "Tamaño fuente sector historial loot/trade",
    "Tamaño de texto del sector historial loot/trade. 0 = automático.",
    0,
    32,
    1,
    0
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelFeedBgAlpha",
    "leftPanelFeedBgAlphaPercent",
    "Transparencia fondo historial loot/trade (%)",
    "Opacidad del fondo de la ventana del sector historial loot/trade. 0 = transparente, 100 = opaco.",
    0,
    100,
    1,
    45
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelFeedHistoryMax",
    "leftPanelFeedHistoryMax",
    "Tamaño historial loot/trade (líneas)",
    "Cantidad máxima de líneas guardadas en la ventana del sector historial loot/trade.",
    50,
    2000,
    10,
    300
  )
  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Suscripciones L1 (informes de máquina)"))
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_loot",
    "leftPanelL1Subs",
    "loot",
    "Loot",
    "Mensajes de botín.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_money",
    "leftPanelL1Subs",
    "money",
    "Dinero",
    "Mensajes de ganancia/pérdida de oro.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_currency",
    "leftPanelL1Subs",
    "currency",
    "Monedas (currency)",
    "Mensajes de currencies.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_tradeskills",
    "leftPanelL1Subs",
    "tradeskills",
    "Profesiones",
    "Mensajes de tradeskills.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_system",
    "leftPanelL1Subs",
    "system",
    "Sistema",
    "Mensajes CHAT_MSG_SYSTEM.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_combatMisc",
    "leftPanelL1Subs",
    "combatMisc",
    "Sistema combate",
    "Mensajes CHAT_MSG_COMBAT_MISC_INFO.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_skill",
    "leftPanelL1Subs",
    "skill",
    "Subida de habilidad",
    "Mensajes CHAT_MSG_SKILL.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_bgSystem",
    "leftPanelL1Subs",
    "bgSystem",
    "Avisos BG",
    "Mensajes de sistema de campos de batalla.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_raidWarning",
    "leftPanelL1Subs",
    "raidWarning",
    "Raid warning",
    "Mensajes CHAT_MSG_RAID_WARNING.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_uiError",
    "leftPanelL1Subs",
    "uiError",
    "Errores UI",
    "Mensajes UI_ERROR_MESSAGE.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_uiInfo",
    "leftPanelL1Subs",
    "uiInfo",
    "Info UI",
    "Mensajes UI_INFO_MESSAGE.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_tradeChannel",
    "leftPanelL1Subs",
    "tradeChannel",
    "Canal Trade",
    "Mensajes humanos del canal Trade hacia L1.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL1Sub_blizzMirror",
    "leftPanelL1Subs",
    "blizzardGeneralMirror",
    "Espejo General Blizzard",
    "Replica avisos automáticos desde el chat General de Blizzard hacia L1 (evita faltantes de addons/sistema).",
    true
  )
  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Sector chat general"))
  addBoolPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralMirrorFromBlizzard",
    "leftPanelGeneralMirrorFromBlizzard",
    "Replicar chat General de Blizzard",
    "Muestra en L3 exactamente lo que aparece en el chat oficial de Blizzard (según su configuración de filtros/canales).",
    true
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralMirrorFrame",
    "leftPanelGeneralMirrorFrame",
    "Frame origen chat Blizzard (1-10)",
    "Número de ChatFrame que quieres reflejar en L3. Normalmente 1 = General.",
    1,
    10,
    1,
    1
  )
  addLeftPanelGeneralFontFaceDropdown(leftCategory)
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralFontSize",
    "leftPanelGeneralFontSize",
    "Tamaño fuente sector chat general",
    "Tamaño de texto del sector chat general. 0 = automático.",
    0,
    32,
    1,
    0
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralBgAlpha",
    "leftPanelGeneralBgAlphaPercent",
    "Transparencia fondo chat general (%)",
    "Opacidad del fondo de la ventana del sector chat general. 0 = transparente, 100 = opaco.",
    0,
    100,
    1,
    35
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralHistoryMax",
    "leftPanelGeneralHistoryMax",
    "Tamaño historial chat general (líneas)",
    "Cantidad máxima de líneas guardadas en la ventana del sector chat general.",
    50,
    2000,
    10,
    500
  )
  addLeftPanelGeneralInputFontFaceDropdown(leftCategory)
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputFontSize",
    "leftPanelGeneralInputFontSize",
    "Tamaño fuente entrada chat",
    "Tamaño de texto de la caja de entrada en el sector chat general. 0 = automático.",
    0,
    32,
    1,
    0
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputBgAlpha",
    "leftPanelGeneralInputBgAlphaPercent",
    "Transparencia fondo entrada chat (%)",
    "Opacidad del fondo de la caja de entrada del sector chat general. 0 = transparente, 100 = opaco.",
    0,
    100,
    1,
    55
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputHeight",
    "leftPanelGeneralInputHeight",
    "Alto caja entrada chat (px)",
    "Altura de la caja de entrada anclada al sector chat general.",
    18,
    40,
    1,
    24
  )
  addBoolPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputCleanStyle",
    "leftPanelGeneralInputCleanStyle",
    "Estilo limpio entrada chat",
    "Oculta la gráfica clásica de Blizzard y aplica un marco limpio acorde al panel (estilo tipo masque).",
    true
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputBorderAlpha",
    "leftPanelGeneralInputBorderAlphaPercent",
    "Opacidad borde entrada chat (%)",
    "Intensidad del borde del estilo limpio de la caja de entrada.",
    0,
    100,
    1,
    45
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputBorderSize",
    "leftPanelGeneralInputBorderSize",
    "Grosor borde entrada chat",
    "Grosor del borde del estilo limpio (1 a 3 px).",
    1,
    3,
    1,
    1
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputHorizontalPad",
    "leftPanelGeneralInputHorizontalPad",
    "Margen horizontal entrada chat",
    "Separación izquierda/derecha de la caja de entrada dentro del sector L3.",
    0,
    24,
    1,
    4
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputOffsetX",
    "leftPanelGeneralInputOffsetX",
    "Mover entrada chat X (px)",
    "Desplaza la caja de entrada en horizontal sin cambiar su ancho. Positivo = hacia la derecha.",
    -600,
    600,
    1,
    0
  )
  addIntSliderPos(
    leftCategory,
    "ChukieUi_MMPos_leftPanelGeneralInputOffsetY",
    "leftPanelGeneralInputOffsetY",
    "Mover entrada chat Y (px)",
    "Desplaza la caja de entrada en vertical respecto de la banda L3/L4. Positivo = hacia arriba.",
    -600,
    600,
    1,
    0
  )
  leftLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Suscripciones L3 (chat humano)"))
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_say",
    "leftPanelL3Subs",
    "say",
    "Say",
    "CHAT_MSG_SAY.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_yell",
    "leftPanelL3Subs",
    "yell",
    "Yell",
    "CHAT_MSG_YELL.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_emote",
    "leftPanelL3Subs",
    "emote",
    "Emotes",
    "CHAT_MSG_EMOTE / CHAT_MSG_TEXT_EMOTE.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_guild",
    "leftPanelL3Subs",
    "guild",
    "Guild",
    "CHAT_MSG_GUILD.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_officer",
    "leftPanelL3Subs",
    "officer",
    "Officer",
    "CHAT_MSG_OFFICER.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_party",
    "leftPanelL3Subs",
    "party",
    "Party",
    "CHAT_MSG_PARTY / CHAT_MSG_PARTY_LEADER.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_raid",
    "leftPanelL3Subs",
    "raid",
    "Raid",
    "CHAT_MSG_RAID / CHAT_MSG_RAID_LEADER.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_instance",
    "leftPanelL3Subs",
    "instance",
    "Instancia",
    "CHAT_MSG_INSTANCE_CHAT / LEADER.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_whisper",
    "leftPanelL3Subs",
    "whisper",
    "Susurro recibido",
    "CHAT_MSG_WHISPER.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_whisperInform",
    "leftPanelL3Subs",
    "whisperInform",
    "Susurro enviado",
    "CHAT_MSG_WHISPER_INFORM.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_bnWhisper",
    "leftPanelL3Subs",
    "bnWhisper",
    "BN susurro recibido",
    "CHAT_MSG_BN_WHISPER.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_bnWhisperInform",
    "leftPanelL3Subs",
    "bnWhisperInform",
    "BN susurro enviado",
    "CHAT_MSG_BN_WHISPER_INFORM.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_channel",
    "leftPanelL3Subs",
    "channel",
    "Canales (General, LocalDefense, etc.)",
    "CHAT_MSG_CHANNEL excepto Trade.",
    true
  )
  addBoolPosSub(
    leftCategory,
    "ChukieUi_MMPos_leftPanelL3Sub_communities",
    "leftPanelL3Subs",
    "communities",
    "Comunidades",
    "CHAT_MSG_COMMUNITIES_CHANNEL.",
    true
  )

  local framesCategory = Settings.RegisterVerticalLayoutSubcategory(rootCategory, "Marcos")
  local framesLayout = SettingsPanel:GetLayout(framesCategory)

  framesLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Party: grilla clickeable"))
  do
    local function partyDB()
      if ns.PartyGrid and ns.PartyGrid.DB then
        return ns.PartyGrid:DB()
      end
      local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
      if not p then
        return {}
      end
      if type(p.partyGrid) ~= "table" then
        --- Ni siquiera crear el esquema está permitido en combate.
        if InCombatLockdown and InCombatLockdown() then
          return {}
        end
        p.partyGrid = {}
      end
      return p.partyGrid
    end
    --[[ Cada control queda anotado con su lector: cuando PartyGrid rechaza un cambio en
         combate, reescribe el valor real en el control y así el panel no queda mostrando
         algo que nunca se guardó. ]]
    local function registerPartySetting(setting, get)
      if ns.PartyGrid and ns.PartyGrid.RegisterSetting then
        ns.PartyGrid:RegisterSetting(setting, get)
      end
      return setting
    end

    --- Ese rebote no es una edición del usuario: el setter tiene que dejarlo pasar.
    local function settingsLocked()
      return (ns.PartyGrid and ns.PartyGrid.SettingsLocked and ns.PartyGrid:SettingsLocked()) == true
    end

    --- Layout recoloca y redimensiona; Refresh además crea, vigila u oculta las celdas.
    local function relayout()
      if ns.PartyGrid and ns.PartyGrid.Layout then
        ns.PartyGrid:Layout()
      end
    end

    --- Rangos y listas los publica PartyGrid: los valores de reserva son solo por si el
    --- módulo no cargó (ahí las opciones no hacen nada, pero tampoco rompen el panel).
    local limits = (ns.PartyGrid and ns.PartyGrid.LIMITS) or {}
    local function range(name, lo, hi)
      local r = limits[name]
      if type(r) == "table" and tonumber(r[1]) and tonumber(r[2]) then
        return r[1], r[2]
      end
      return lo, hi
    end

    local function addBool(uniqueId, key, label, tooltip, defaultOn, apply)
      local function get()
        local v = partyDB()[key]
        if v == nil then
          return defaultOn ~= false
        end
        return v == true or v == 1
      end
      local function set(v)
        if settingsLocked() then
          return
        end
        if ns.PartyGrid and ns.PartyGrid.SetOption then
          ns.PartyGrid:SetOption(key, (v == true or v == 1), apply == relayout and "layout" or "refresh")
        end
      end
      local defaultToken = (defaultOn ~= false) and Settings.Default.True or Settings.Default.False
      local setting = Settings.RegisterProxySetting(
        framesCategory,
        uniqueId,
        Settings.VarType.Boolean,
        label,
        defaultToken,
        get,
        set
      )
      registerPartySetting(setting, get)
      Settings.CreateCheckbox(framesCategory, setting, tooltip)
    end

    local function addInt(uniqueId, key, label, tooltip, minV, maxV, step, defaultNum)
      local function get()
        local v = tonumber(partyDB()[key])
        if not v then
          return defaultNum
        end
        return math.max(minV, math.min(maxV, v))
      end
      local function set(v)
        if settingsLocked() then
          return
        end
        if ns.PartyGrid and ns.PartyGrid.SetOption then
          ns.PartyGrid:SetOption(key, math.floor(v + 0.5), "layout")
        end
      end
      local setting = Settings.RegisterProxySetting(
        framesCategory,
        uniqueId,
        Settings.VarType.Number,
        label,
        defaultNum,
        get,
        set
      )
      registerPartySetting(setting, get)
      Settings.CreateSlider(framesCategory, setting, Settings.CreateSliderOptions(minV, maxV, step), tooltip)
    end

    --- Listas por índice numérico, como el resto de los desplegables del panel.
    local function addListDropdown(uniqueId, key, label, tooltip, values, labels, currentGetter)
      local function dropdownData()
        local c = Settings.CreateControlTextContainer()
        for i = 1, #values do
          c:Add(i, labels[values[i]] or values[i])
        end
        return c:GetData()
      end
      local function get()
        local current = currentGetter()
        for i = 1, #values do
          if values[i] == current then
            return i
          end
        end
        return 1
      end
      local function set(v)
        if settingsLocked() then
          return
        end
        if ns.PartyGrid and ns.PartyGrid.SetOption then
          ns.PartyGrid:SetOption(key, values[tonumber(v) or 1] or values[1], "layout")
        end
      end
      local setting = Settings.RegisterProxySetting(
        framesCategory,
        uniqueId,
        Settings.VarType.Number,
        label,
        1,
        get,
        set
      )
      registerPartySetting(setting, get)
      Settings.CreateDropdown(framesCategory, setting, dropdownData, tooltip)
    end

    do
      local function get()
        return partyDB().enabled == true
      end
      local function set(v)
        if settingsLocked() then
          return
        end
        --- Apagarla también es configurar: en combate se rechaza igual que encenderla.
        local on = (v == true or v == 1)
        if ns.PartyGrid and ns.PartyGrid.SetEnabled then
          ns.PartyGrid:SetEnabled(on)
        end
      end
      local setting = Settings.RegisterProxySetting(
        framesCategory,
        "ChukieUi_PartyGrid_enabled",
        Settings.VarType.Boolean,
        "Activar grilla de party clickeable",
        Settings.Default.False,
        get,
        set
      )
      registerPartySetting(setting, get)
      Settings.CreateCheckbox(
        framesCategory,
        setting,
        "Cada columna lanza su hechizo sobre player/party1..4. En columnas ciclo, clic derecho fuera de combate prende o apaga esa unidad. Toda configuración se rechaza durante el combate."
      )
    end

    do
      local lo, hi = range("size", 16, 100)
      addInt(
        "ChukieUi_PartyGrid_size",
        "size",
        "Tamaño de celda (px)",
        "Lado de la celda: es cuadrada, pensada para llevar el icono de un debuff por unidad.",
        lo,
        hi,
        1,
        34
      )
    end

    do
      local lo, hi = range("spacing", 0, 20)
      addInt(
        "ChukieUi_PartyGrid_spacing",
        "spacing",
        "Separación entre jugadores (px)",
        "Solo se aplica a las filas que van en columna propia; las que se anclan a una fila de Blizzard siguen su altura.",
        lo,
        hi,
        1,
        2
      )
    end

    do
      local lo, hi = range("columns", 1, 8)
      addInt(
        "ChukieUi_PartyGrid_columns",
        "columns",
        "Columnas por jugador",
        "Cada columna lleva una habilidad distinta y todas sus celdas la lanzan sobre la unidad de su fila. Este cambio se rechaza durante el combate.",
        lo,
        hi,
        1,
        1
      )
    end

    do
      local lo, hi = range("columnSpacing", 0, 20)
      addInt(
        "ChukieUi_PartyGrid_columnSpacing",
        "columnSpacing",
        "Separación entre columnas (px)",
        "Hueco entre las celdas de un mismo jugador.",
        lo,
        hi,
        1,
        2
      )
    end

    do
      local lo, hi = range("alphaPercent", 10, 100)
      addInt(
        "ChukieUi_PartyGrid_alphaPercent",
        "alphaPercent",
        "Opacidad de la grilla (%)",
        "Transparencia de la grilla completa: se aplica al conjunto, así que afecta iconos, vida, cooldown, rol y bordes por igual. Mientras la estés moviendo se muestra opaca.",
        lo,
        hi,
        5,
        100
      )
    end

    addListDropdown(
      "ChukieUi_PartyGrid_growth",
      "growth",
      "Las columnas crecen",
      "Desde la celda anclada a cada jugador, hacia dónde se agregan las columnas siguientes. Con la grilla a la derecha de la de Blizzard, lo natural es hacia la derecha.",
      (ns.PartyGrid and ns.PartyGrid.GROWTHS) or { "RIGHT", "LEFT", "DOWN", "UP" },
      (ns.PartyGrid and ns.PartyGrid.GROWTH_LABELS) or {},
      function()
        if ns.PartyGrid and ns.PartyGrid.Growth then
          return ns.PartyGrid:Growth()
        end
        return partyDB().growth or "RIGHT"
      end
    )

    addListDropdown(
      "ChukieUi_PartyGrid_orientation",
      "orientation",
      "Orientación (jugadores)",
      "Cómo se apilan los jugadores cuando la grilla no está anclada fila a fila a la de Blizzard: en columna (vertical) o en fila (horizontal).",
      (ns.PartyGrid and ns.PartyGrid.ORIENTATIONS) or { "vertical", "horizontal" },
      (ns.PartyGrid and ns.PartyGrid.ORIENTATION_LABELS) or {},
      function()
        if ns.PartyGrid and ns.PartyGrid.Orientation then
          return ns.PartyGrid:Orientation()
        end
        return partyDB().orientation or "vertical"
      end
    )

    addBool(
      "ChukieUi_PartyGrid_includePlayer",
      "includePlayer",
      "Incluir al jugador",
      "Suma una celda para «player». Sin esto la grilla solo lleva party1..4.",
      true
    )

    addBool(
      "ChukieUi_PartyGrid_showHealth",
      "showHealth",
      "Barra de vida",
      "Barra de fondo con color de clase. La vida se pasa tal cual al widget: en 12.1 puede venir como valor secreto, así que el addon nunca la lee.",
      true
    )

    addBool(
      "ChukieUi_PartyGrid_showRole",
      "showRole",
      "Icono de rol",
      "Icono de tanque, sanador o daño en la esquina inferior izquierda, para dejar el centro de la celda libre.",
      true
    )

    addBool(
      "ChukieUi_PartyGrid_useMasque",
      "useMasque",
      "Usar Masque",
      "Registra las celdas en el grupo independiente «Chukie UI → PartyGrid». Podés asignarle una skin distinta a ActionBars y RightStrip.",
      true
    )

    framesLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Party: habilidades por columna"))
    framesLayout:AddInitializer(
      CreateSettingsListSectionHeaderInitializer(
        "Arrastrá hechizos sobre las celdas, o escribí nombre/ID en la ventana /chukie-party. Una columna ciclo publica una acción /click ch-cl-Hechizo."
      )
    )
    --[[ El panel de Settings no tiene control de texto (no existe Settings.CreateTextBox), así
         que las cajas de hechizo y de macro de más abajo no se dibujan en este cliente: sin
         este atajo la sección quedaría con el interruptor de ciclo y nada donde escribir. ]]
    if not Settings.CreateTextBox and CreateSettingsButtonInitializer then
      framesLayout:AddInitializer(
        CreateSettingsButtonInitializer(
          "Hechizo y macro de cada columna",
          "Abrir /chukie-party",
          function()
            if ns.PartyGrid and ns.PartyGrid.ShowConfig then
              ns.PartyGrid:ShowConfig()
            end
          end,
          "La ventana propia tiene la caja para escribir nombre o ID por columna y la línea /click lista para copiar a una macro.",
          true,
          nil,
          nil
        )
      )
    end
    for column = 1, 8 do
      local columnIndex = column
      do
        local function getCycle()
          return ns.PartyGrid and ns.PartyGrid.IsCycleColumn and ns.PartyGrid:IsCycleColumn(columnIndex) or false
        end
        local function setCycle(value)
          if settingsLocked() then
            return
          end
          if ns.PartyGrid and ns.PartyGrid.SetColumnCycle then
            ns.PartyGrid:SetColumnCycle(columnIndex, value == true or value == 1)
          end
        end
        local cycleSetting = Settings.RegisterProxySetting(
          framesCategory,
          "ChukieUi_PartyGrid_columnCycle" .. columnIndex,
          Settings.VarType.Boolean,
          "Columna " .. columnIndex .. ": usar como ciclo",
          Settings.Default.False,
          getCycle,
          setCycle
        )
        registerPartySetting(cycleSetting, getCycle)
        Settings.CreateCheckbox(
          framesCategory,
          cycleSetting,
          "Fuera de combate, clic derecho sobre cada jugador lo incluye o excluye. En combate, usá el /click indicado para lanzar al siguiente incluido."
        )
      end
      if Settings.CreateTextBox then
        local function getAssigned()
          local spellId = ns.PartyGrid and ns.PartyGrid.ColumnSpell and ns.PartyGrid:ColumnSpell(columnIndex)
          if not spellId then
            return "(vacía)"
          end
          local info
          if C_Spell and C_Spell.GetSpellInfo then
            local ok, value = pcall(C_Spell.GetSpellInfo, spellId)
            info = ok and value or nil
          end
          return ((type(info) == "table" and info.name) or "Hechizo") .. " (" .. spellId .. ")"
        end
        local function assignEdit(value)
          if settingsLocked() or value == getAssigned() then
            return
          end
          if ns.PartyGrid and ns.PartyGrid.SetColumnSpellInput then
            ns.PartyGrid:SetColumnSpellInput(columnIndex, value)
          end
        end
        local assignedSetting = Settings.RegisterProxySetting(
          framesCategory,
          "ChukieUi_PartyGrid_columnSpell" .. columnIndex,
          Settings.VarType.String,
          "Habilidad columna " .. columnIndex .. " (nombre o ID)",
          "",
          getAssigned,
          assignEdit
        )
        registerPartySetting(assignedSetting, getAssigned)
        Settings.CreateTextBox(
          framesCategory,
          assignedSetting,
          "Podés escribir el nombre exacto o ID en cualquier columna, o arrastrar un hechizo sobre una celda."
        )

        local function getAction()
          local action = ns.PartyGrid and ns.PartyGrid.CycleActionName
            and ns.PartyGrid:CycleActionName(columnIndex)
          if not action then
            return "(activá ciclo y asigná un hechizo)"
          end
          return "/click " .. action
        end
        local function rejectActionEdit(value)
          if settingsLocked() or value == getAction() then
            return
          end
          print("|cffff9900Chukie UI|r: copiá esa línea a una macro; la lista se edita con clic derecho en la grilla.")
          if ns.PartyGrid and ns.PartyGrid.RefreshSettings then
            ns.PartyGrid:RefreshSettings()
          end
        end
        local actionSetting = Settings.RegisterProxySetting(
          framesCategory,
          "ChukieUi_PartyGrid_columnCycleAction" .. columnIndex,
          Settings.VarType.String,
          "Macro ciclo columna " .. columnIndex .. " (solo lectura)",
          "",
          getAction,
          rejectActionEdit
        )
        registerPartySetting(actionSetting, getAction)
        Settings.CreateTextBox(
          framesCategory,
          actionSetting,
          "Copiá esta línea a una macro. Las celdas prendidas muestran qué unidades integran el ciclo."
        )
      end
      framesLayout:AddInitializer(
        CreateSettingsButtonInitializer(
          "Columna " .. columnIndex,
          "Limpiar",
          function()
            if ns.PartyGrid and ns.PartyGrid.SetColumnSpell then
              local spellId = ns.PartyGrid:ColumnSpell(columnIndex)
              if spellId then
                ns.PartyGrid:SetColumnSpell(columnIndex, nil)
              else
                print("|cff00ff00Chukie UI|r: la columna " .. columnIndex .. " ya está vacía.")
              end
            end
          end,
          "Borra la habilidad asignada a esta columna. En combate se rechaza sin modificar el perfil.",
          true,
          nil,
          nil
        )
      )
    end

    framesLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Party: posición"))

    addBool(
      "ChukieUi_PartyGrid_attachToBlizzard",
      "attachToBlizzard",
      "Pegada a la grilla de Blizzard",
      "La grilla cuelga del marco de party de Blizzard: aparece y desaparece con él, y cada celda se ancla enfrente de la fila de su unidad. Sin esto queda en posición propia, arrastrable.",
      true,
      relayout
    )

    addBool(
      "ChukieUi_PartyGrid_perUnitAnchor",
      "perUnitAnchor",
      "Anclar cada grupo a su jugador",
      "Pega las celdas de cada unidad a su propio marco Blizzard, también cuando la party está en horizontal y las celdas van arriba o abajo.",
      true,
      relayout
    )

    addListDropdown(
      "ChukieUi_PartyGrid_side",
      "side",
      "Lado (pegada a Blizzard)",
      "De qué lado se colocan las celdas. Con «Anclar cada grupo» es respecto al marco de cada jugador; sin eso, respecto al conjunto.",
      (ns.PartyGrid and ns.PartyGrid.SIDES) or { "RIGHT", "LEFT", "TOP", "BOTTOM" },
      (ns.PartyGrid and ns.PartyGrid.SIDE_LABELS) or {},
      function()
        if ns.PartyGrid and ns.PartyGrid.Side then
          return ns.PartyGrid:Side()
        end
        return partyDB().side or "RIGHT"
      end
    )

    do
      local lo, hi = range("gap", -600, 600)
      addInt(
        "ChukieUi_PartyGrid_gap",
        "gap",
        "Distancia a la grilla de Blizzard (px)",
        "Separación respecto de su marco. En negativo la grilla se mete por encima del marco. Solo cuenta con «Pegada a la grilla de Blizzard» activo.",
        lo,
        hi,
        1,
        8
      )
    end

    do
      local lo, hi = range("offset", -600, 600)
      addInt(
        "ChukieUi_PartyGrid_offsetX",
        "offsetX",
        "Ajuste X (px)",
        "Corrección horizontal sobre la posición calculada.",
        lo,
        hi,
        1,
        0
      )
      addInt(
        "ChukieUi_PartyGrid_offsetY",
        "offsetY",
        "Ajuste Y (px)",
        "Corrección vertical sobre la posición calculada.",
        lo,
        hi,
        1,
        0
      )
    end

    addBool(
      "ChukieUi_PartyGrid_showSolo",
      "showSolo",
      "Mostrar en solitario",
      "Sin grupo la grilla se oculta salvo que pidas lo contrario. Pegada a la de Blizzard no cambia nada: manda su marco.",
      false,
      relayout
    )

    framesLayout:AddInitializer(
      CreateSettingsButtonInitializer(
        "",
        "Abrir ventana de la grilla…",
        function()
          if ns.PartyGrid and ns.PartyGrid.ShowConfig then
            ns.PartyGrid:ShowConfig()
          else
            print("|cffff9900Chukie UI|r: módulo Grilla de party no disponible.")
          end
        end,
        "Abre la ventana propia (también /chukie-party). Ahí está el botón «Mover», que necesita la pantalla despejada para arrastrar la grilla.",
        true,
        nil,
        nil
      )
    )

    framesLayout:AddInitializer(
      CreateSettingsListSectionHeaderInitializer(
        "En combate toda configuración de PartyGrid se rechaza: no se guarda ni se aplaza. Al salir se resincronizan los controles y atributos seguros."
      )
    )
  end

  local alertsCategory = Settings.RegisterVerticalLayoutSubcategory(rootCategory, "Alertas (CD / procs / auras)")
  local alertsLayout = SettingsPanel:GetLayout(alertsCategory)

  local function alertsDB()
    if ns.Profile and ns.Profile.GetAlertsModel then
      return ns.Profile:GetAlertsModel()
    end
    local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
    p.alerts = p.alerts or { enabled = false, nextId = 1, rules = {} }
    if ns.Alerts and ns.Alerts.EnsureSchema then
      ns.Alerts:EnsureSchema(p.alerts)
    end
    return p.alerts
  end

  local function refreshAlerts()
    if ns.Alerts and ns.Alerts.Refresh then
      ns.Alerts:Refresh()
    end
  end

  alertsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Módulo"))
  do
    local function get()
      return alertsDB().enabled == true
    end
    local function set(v)
      alertsDB().enabled = (v == true or v == 1) and true or false
      refreshAlerts()
    end
    local setting = Settings.RegisterProxySetting(
      alertsCategory,
      "ChukieUi_Alerts_enabled",
      Settings.VarType.Boolean,
      "Activar módulo de alertas",
      Settings.Default.False,
      get,
      set
    )
    Settings.CreateCheckbox(
      alertsCategory,
      setting,
      "Las alertas se apilan por perfil (CD, proc o aura). Usá «Gestionar alertas…» o /chukie-aura para abrir el wizard (cierra Opciones para pantallar limpia)."
    )
  end

  do
    -- Valores en centésimas de segundo (5 = 0.05 s) para el dropdown de Settings.
    local TICK_CS = { 5, 10, 15, 20, 25, 50 }
    local TICK_LABELS = {
      [5] = "Muy alta (20 Hz)",
      [10] = "Alta",
      [15] = "Media (recomendado)",
      [20] = "Baja",
      [25] = "Muy baja",
      [50] = "Mínima",
    }
    local function tickDropdownData()
      local c = Settings.CreateControlTextContainer()
      for i = 1, #TICK_CS do
        local cs = TICK_CS[i]
        c:Add(cs, TICK_LABELS[cs] or tostring(cs))
      end
      return c:GetData()
    end
    local function get()
      local sec = tonumber(alertsDB().tickInterval) or 0.15
      if ns.Alerts and ns.Alerts.GetTickInterval then
        sec = ns.Alerts:GetTickInterval()
      end
      local cs = math.floor(sec * 100 + 0.5)
      for i = 1, #TICK_CS do
        if TICK_CS[i] == cs then
          return cs
        end
      end
      return 15
    end
    local function set(v)
      v = tonumber(v) or 15
      local ok = false
      for i = 1, #TICK_CS do
        if TICK_CS[i] == v then
          ok = true
          break
        end
      end
      if not ok then
        v = 15
      end
      alertsDB().tickInterval = v / 100
      refreshAlerts()
    end
    local setting = Settings.RegisterProxySetting(
      alertsCategory,
      "ChukieUi_Alerts_tickInterval",
      Settings.VarType.Number,
      "Frecuencia de actualización",
      15,
      get,
      set
    )
    Settings.CreateDropdown(
      alertsCategory,
      setting,
      tickDropdownData,
      "Poll en segundo plano (fin de CD / rango al moverse). Más alto = menos CPU. La respuesta a CD/proc sigue yendo por eventos."
    )
  end

  alertsLayout:AddInitializer(
    CreateSettingsButtonInitializer(
      "",
      "Gestionar alertas…",
      function()
        if ns.AlertsManager and ns.AlertsManager.Show then
          ns.AlertsManager:Show()
        else
          print("|cffff9900Chukie UI|r: gestor de alertas no disponible.")
        end
      end,
      "Abre la ventana de alertas y cierra Opciones (también: /chukie-aura).",
      true,
      nil,
      nil
    )
  )

  alertsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Media cargada"))
  do
    local c = (ns.Alerts and ns.Alerts.GetMediaCounts and ns.Alerts:GetMediaCounts()) or {}
    local glowOk = (ns.Alerts and ns.Alerts.GetLibCustomGlow and ns.Alerts:GetLibCustomGlow()) and "sí" or "no"
    local nRules = 0
    if ns.Alerts and ns.Alerts.GetGroups then
      nRules = #(ns.Alerts:GetGroups() or {})
    else
      nRules = #(alertsDB().groups or alertsDB().rules or {})
    end
    alertsLayout:AddInitializer(
      CreateSettingsListSectionHeaderInitializer(
        string.format(
          "Texturas %d · shapes %d · rings %d · borders %d · bars %d",
          tonumber(c.textures) or 0,
          tonumber(c.shapes) or 0,
          tonumber(c.rings) or 0,
          tonumber(c.borders) or 0,
          tonumber(c.statusbars) or 0
        )
      )
    )
    alertsLayout:AddInitializer(
      CreateSettingsListSectionHeaderInitializer(
        string.format(
          "Fonts %d · sounds %d · powerAuras %d · paSounds %d",
          tonumber(c.fonts) or 0,
          tonumber(c.sounds) or 0,
          tonumber(c.powerAuras) or 0,
          tonumber(c.powerAurasSounds) or 0
        )
      )
    )
    alertsLayout:AddInitializer(
      CreateSettingsListSectionHeaderInitializer(
        string.format(
          "User %d · LibSharedMedia entries %d · glow %s · grupos %d",
          tonumber(c.user) or 0,
          tonumber(c.lsm) or 0,
          glowOk,
          nRules
        )
      )
    )
  end

  ns.settingsCategoryID = rootCategory:GetID()
  ns.minimapCategoryID = minimapCategory:GetID()
  ns.minimapButtonsCategoryID = minimapCategory:GetID()
  ns.framesCategoryID = framesCategory:GetID()
  ns.alertsCategoryID = alertsCategory:GetID()
  ns.configPanelRegistered = true
end

function ns.OpenConfigPanel()
  if not ns.settingsCategoryID then
    return false
  end
  if ns.AppendMinimapDiscoveryPolicyRows then
    ns.AppendMinimapDiscoveryPolicyRows()
  end
  if ns.AppendMinimenuVisibilityRows then
    ns.AppendMinimenuVisibilityRows()
  end
  Settings.OpenToCategory(ns.settingsCategoryID)
  return true
end

function ns.OpenFramesConfigPanel()
  if not ns.framesCategoryID then
    return false
  end
  Settings.OpenToCategory(ns.framesCategoryID)
  return true
end

function ns.OpenMinimapConfigPanel()
  if not ns.minimapCategoryID then
    return false
  end
  if ns.AppendMinimapDiscoveryPolicyRows then
    ns.AppendMinimapDiscoveryPolicyRows()
  end
  if ns.AppendMinimenuVisibilityRows then
    ns.AppendMinimenuVisibilityRows()
  end
  Settings.OpenToCategory(ns.minimapCategoryID)
  return true
end

function ns.OpenMinimapButtonsPanel()
  if not ns.minimapButtonsCategoryID then
    return false
  end
  if ns.AppendMinimapDiscoveryPolicyRows then
    ns.AppendMinimapDiscoveryPolicyRows()
  end
  if ns.AppendMinimenuVisibilityRows then
    ns.AppendMinimenuVisibilityRows()
  end
  Settings.OpenToCategory(ns.minimapButtonsCategoryID)
  return true
end
