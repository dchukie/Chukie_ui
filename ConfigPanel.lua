--[[ Panel de opciones: Esc → Opciones → AddOns → Chukie UI
     Retail 12.0.1 (Interface 120001): categoría raíz + subcategorías verticales (p. ej. Panel derecho).
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
  refreshMinimapBar()
  if ns.RightPanelWidgets and ns.RightPanelWidgets.Refresh then
    ns.RightPanelWidgets:Refresh()
  end
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

local function minimenuDisplayName(frameName)
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
  Settings.CreateCheckbox(
    category,
    setting,
    tooltip
      or ("Mostrar «" .. minimenuDisplayName(frameName) .. "» en la fila del micromenú del panel derecho.")
  )
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
  rootLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Chukie-UI"))
  rootLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))
  rootLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Tamaño"))
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
    "Equivale al CVar rotateMinimap de Blizzard: el mapa gira y la flecha del jugador queda fija hacia arriba. Si «Solo mapa» está activo, Chukie mostrará la brújula (MinimapCompassTexture) en lugar de ocultarla. Si cambias esto en Opciones de Blizzard, el siguiente refresco de Chukie puede volver a alinear el CVar con esta casilla.",
    false
  )
  minimapLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Flecha del jugador"))
  addPlayerArrowSettings(minimapCategory)

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

  ns.settingsCategoryID = rootCategory:GetID()
  ns.minimapCategoryID = minimapCategory:GetID()
  ns.minimapButtonsCategoryID = minimapCategory:GetID()
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
