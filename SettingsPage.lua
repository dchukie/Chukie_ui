--[[ Página mínima en Esc → Opciones → AddOns → Chukie UI.
     Solo lo que RightPanel ya aplica: posición, tamaño, bloqueo, zoom, rotación
     y el recuadro de depuración. No carga ConfigPanel.lua. ]]

local ADDON_NAME, ns = ...

local function model()
  if ns.Profile and ns.Profile.GetRightPanelModel then
    return ns.Profile:GetRightPanelModel()
  end
  return nil
end

local function refresh()
  if ns.RightPanel and ns.RightPanel.Apply then
    ns.RightPanel:Apply()
  end
end

local function addCheckbox(category, id, key, label, tooltip, defaultOn)
  local function get()
    local db = model()
    if not db then
      return defaultOn
    end
    local v = db[key]
    if v == nil then
      return defaultOn
    end
    return v == true or v == 1
  end
  local function set(v)
    local db = model()
    if not db then
      return
    end
    db[key] = (v == true or v == 1)
    refresh()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    id,
    Settings.VarType.Boolean,
    label,
    defaultOn and Settings.Default.True or Settings.Default.False,
    get,
    set
  )
  Settings.CreateCheckbox(category, setting, tooltip)
end

local function addSlider(category, id, key, label, tooltip, minV, maxV, step, defaultNum)
  local function get()
    local db = model()
    local v = db and tonumber(db[key])
    if not v then
      return defaultNum
    end
    return math.max(minV, math.min(maxV, v))
  end
  local function set(v)
    local db = model()
    if not db then
      return
    end
    db[key] = math.floor((tonumber(v) or defaultNum) + 0.5)
    if ns.RightPanel and ns.RightPanel.ClampOffsets and (key == "offsetX" or key == "offsetY") then
      local dbNow = model()
      local ox, oy = ns.RightPanel:ClampOffsets(dbNow.offsetX, dbNow.offsetY)
      dbNow.offsetX, dbNow.offsetY = ox, oy
    end
    refresh()
  end
  local setting = Settings.RegisterProxySetting(
    category,
    id,
    Settings.VarType.Number,
    label,
    defaultNum,
    get,
    set
  )
  local options = Settings.CreateSliderOptions(minV, maxV, step)
  Settings.CreateSlider(category, setting, options, tooltip)
end

function ns.RegisterConfigPanel()
  if ns.configPanelRegistered then
    return
  end
  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory and Settings.RegisterProxySetting and Settings.CreateCheckbox and Settings.CreateSlider) then
    return
  end
  if not model() then
    return
  end

  local category, layout = Settings.RegisterVerticalLayoutCategory("Chukie UI")
  if not category then
    return
  end
  category.ID = "ChukieUi"

  if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Posición"))
  end
  addSlider(
    category,
    "ChukieUi_MMPos_offsetX",
    "offsetX",
    "Desplazamiento X (desde la esquina inferior derecha)",
    "Negativo mueve el panel hacia la izquierda.",
    -1200,
    120,
    1,
    0
  )
  addSlider(
    category,
    "ChukieUi_MMPos_offsetY",
    "offsetY",
    "Desplazamiento Y (desde la esquina inferior derecha)",
    "Positivo sube el panel. Negativo lo baja.",
    -1200,
    900,
    1,
    0
  )
  if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Tamaño y bloqueo"))
  end
  addSlider(
    category,
    "ChukieUi_MMPos_panelScalePct",
    "panelScalePercent",
    "Tamaño global del panel (%)",
    "Escala el minimapa, la barra de addons y el micromenú juntos.",
    60,
    220,
    1,
    100
  )
  addCheckbox(
    category,
    "ChukieUi_MMPos_lockRightPanelEdit",
    "lockRightPanelInEditMode",
    "No soltar el cluster al modo edición de Blizzard",
    "Con esto activo, el modo edición de Blizzard no saca el minimapa del panel.",
    true
  )
  addCheckbox(
    category,
    "ChukieUi_MMPos_rotateMinimap",
    "rotateMinimap",
    "Rotar el mapa con la dirección del personaje",
    "El mapa gira y la flecha queda hacia arriba.",
    false
  )
  addCheckbox(
    category,
    "ChukieUi_MMPos_debugBounds",
    "debugRightPanelBounds",
    "Recuadro verde del panel derecho",
    "Dibuja el borde del panel para ver hasta dónde llega. No captura el ratón.",
    false
  )

  if Settings.CreateDropdown and Settings.CreateControlTextContainer then
    local function zoomGet()
      local db = model()
      local v = db and tonumber(db.minimapZoomPreference)
      if v == 1 or v == 2 then
        return v
      end
      return 0
    end
    local function zoomSet(v)
      local db = model()
      if not db then
        return
      end
      v = tonumber(v)
      if v ~= 1 and v ~= 2 then
        v = 0
      end
      db.minimapZoomPreference = v
      refresh()
    end
    local setting = Settings.RegisterProxySetting(
      category,
      "ChukieUi_MMPos_zoomPref",
      Settings.VarType.Number,
      "Zoom del mapa",
      0,
      zoomGet,
      zoomSet
    )
    local choices = Settings.CreateControlTextContainer()
    choices:Add(0, "Automático (Blizzard)")
    choices:Add(1, "Siempre máximo alejado")
    choices:Add(2, "Siempre máximo acercado")
    Settings.CreateDropdown(category, setting, choices:GetData(), "Usa los niveles de zoom que ya tiene el minimapa.")
  end

  Settings.RegisterAddOnCategory(category)
  ns.settingsCategoryID = category.GetID and category:GetID() or category.ID
  ns.minimapCategoryID = ns.settingsCategoryID
  ns.configPanelRegistered = true
end

function ns.OpenConfigPanel()
  if not ns.settingsCategoryID or not (Settings and Settings.OpenToCategory) then
    return false
  end
  Settings.OpenToCategory(ns.settingsCategoryID)
  return true
end

ns.OpenMinimapConfigPanel = ns.OpenConfigPanel

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon ~= ADDON_NAME then
    return
  end
  ns.RegisterConfigPanel()
end)
