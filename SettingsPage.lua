--[[ Esc → Opciones → AddOns → Chukie UI.
     La página raíz es General (perfiles y respaldo).
     Cada módulo cargado tiene su subcategoría. No carga ConfigPanel.lua. ]]

local ADDON_NAME, ns = ...

local function rightModel()
  if ns.Profile and ns.Profile.GetRightPanelModel then
    return ns.Profile:GetRightPanelModel()
  end
  return nil
end

local function barsModel()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return nil
  end
  p.actionBars = p.actionBars or {}
  return p.actionBars
end

local function refreshRight()
  if ns.RightPanel and ns.RightPanel.Apply then
    ns.RightPanel:Apply()
  end
end

local function refreshBars()
  if ns.ActionBars and ns.ActionBars.Refresh then
    ns.ActionBars:Refresh()
  end
end

local function addHeader(layout, text)
  if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
  end
end

local function addButton(layout, label, tooltip, click)
  if not (layout and layout.AddInitializer and CreateSettingsButtonInitializer) then
    return
  end
  layout:AddInitializer(CreateSettingsButtonInitializer("", label, click, tooltip, true, nil, nil))
end

local function addCheckbox(category, id, label, tooltip, defaultOn, get, set)
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

local function addSlider(category, id, label, tooltip, minV, maxV, step, defaultNum, get, set)
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

local function readBool(db, key, defaultOn)
  if not db or db[key] == nil then
    return defaultOn
  end
  local v = db[key]
  return v == true or v == 1
end

local function writeBool(db, key, v)
  if db then
    db[key] = (v == true or v == 1)
  end
end

local function readInt(db, key, minV, maxV, defaultNum)
  local v = db and tonumber(db[key])
  if not v then
    return defaultNum
  end
  return math.max(minV, math.min(maxV, v))
end

local function rightCheckbox(category, id, key, label, tooltip, defaultOn)
  addCheckbox(category, id, label, tooltip, defaultOn, function()
    return readBool(rightModel(), key, defaultOn)
  end, function(v)
    writeBool(rightModel(), key, v)
    refreshRight()
  end)
end

local function rightSlider(category, id, key, label, tooltip, minV, maxV, step, defaultNum)
  addSlider(category, id, label, tooltip, minV, maxV, step, defaultNum, function()
    return readInt(rightModel(), key, minV, maxV, defaultNum)
  end, function(v)
    local db = rightModel()
    if not db then
      return
    end
    db[key] = math.floor((tonumber(v) or defaultNum) + 0.5)
    if ns.RightPanel and ns.RightPanel.ClampOffsets and (key == "offsetX" or key == "offsetY") then
      local ox, oy = ns.RightPanel:ClampOffsets(db.offsetX, db.offsetY)
      db.offsetX, db.offsetY = ox, oy
    end
    refreshRight()
  end)
end

local function barCheckbox(category, id, key, label, tooltip, defaultOn)
  addCheckbox(category, id, label, tooltip, defaultOn, function()
    return readBool(barsModel(), key, defaultOn)
  end, function(v)
    writeBool(barsModel(), key, v)
    refreshBars()
  end)
end

local function barSlider(category, id, key, label, tooltip, minV, maxV, step, defaultNum)
  addSlider(category, id, label, tooltip, minV, maxV, step, defaultNum, function()
    return readInt(barsModel(), key, minV, maxV, defaultNum)
  end, function(v)
    local db = barsModel()
    if not db then
      return
    end
    db[key] = math.floor((tonumber(v) or defaultNum) + 0.5)
    refreshBars()
  end)
end

local function subcategory(parent, parentLayout, name)
  if not (Settings.RegisterVerticalLayoutSubcategory and parent) then
    addHeader(parentLayout, name)
    return parent, parentLayout
  end
  local category = Settings.RegisterVerticalLayoutSubcategory(parent, name)
  local layout = nil
  if category and SettingsPanel and SettingsPanel.GetLayout then
    layout = SettingsPanel:GetLayout(category)
  end
  return category or parent, layout or parentLayout
end

local function categoryId(category)
  if category and category.GetID then
    return category:GetID()
  end
  return category and category.ID
end

local function addProfiles(category, layout)
  if not (ns.Profile and Settings.CreateDropdown and Settings.CreateControlTextContainer) then
    return
  end
  addHeader(layout, "Perfiles")

  local function options()
    local container = Settings.CreateControlTextContainer()
    local names = ns.Profile.ListSorted and ns.Profile:ListSorted() or {}
    if #names == 0 and ns.Profile.GetCurrentName then
      container:Add(ns.Profile:GetCurrentName(), ns.Profile:GetCurrentName())
    end
    for i = 1, #names do
      container:Add(names[i], names[i])
    end
    return container:GetData()
  end

  local setting
  if Settings.RegisterAddOnSetting and type(ChukieUiDB) == "table" then
    setting = Settings.RegisterAddOnSetting(
      category,
      "ChukieUi_currentProfile",
      "currentProfile",
      ChukieUiDB,
      Settings.VarType.String,
      "Perfil activo",
      ns.Profile:GetCurrentName()
    )
    if setting.SetValueChangedCallback then
      setting:SetValueChangedCallback(function(_, value)
        if ns.Profile._ignoreSetting then
          return
        end
        ns.Profile:PromptSwitch(value or ns.Profile:GetCurrentName())
      end)
    end
  else
    setting = Settings.RegisterProxySetting(
      category,
      "ChukieUi_currentProfile",
      Settings.VarType.String,
      "Perfil activo",
      ns.Profile:GetCurrentName(),
      function()
        return ns.Profile:GetCurrentName()
      end,
      function(value)
        if ns.Profile._ignoreSetting then
          return
        end
        ns.Profile:PromptSwitch(value or ns.Profile:GetCurrentName())
      end
    )
  end

  ns.Profile.SyncSetting = function(name)
    if type(name) ~= "string" then
      return
    end
    ns.Profile._ignoreSetting = true
    if type(ChukieUiDB) == "table" then
      ChukieUiDB.currentProfile = name
    end
    if setting and setting.SetValue then
      pcall(setting.SetValue, setting, name)
    end
    ns.Profile._ignoreSetting = false
  end

  Settings.CreateDropdown(
    category,
    setting,
    options,
    "Cada personaje usa el perfil vinculado. «Default» es la plantilla y no se borra ni se renombra. Elegir otro pide confirmación."
  )

  addButton(layout, "Nuevo (duplicar)", "Crea un perfil copiando el activo y lo deja seleccionado.", function()
    if not ns.Profile.DuplicateCurrent then
      return
    end
    local newName = ns.Profile:DuplicateCurrent()
    print("|cff00ff00Chukie UI|r: nuevo perfil «" .. tostring(newName) .. "». Volvé a abrir Opciones si el desplegable no se actualiza.")
  end)
  addButton(layout, "Renombrar", "Cambia el nombre del perfil activo. «Default» no se puede renombrar.", function()
    if ns.Profile.PromptRename then
      ns.Profile:PromptRename()
    end
  end)
  addButton(layout, "Eliminar", "Borra el perfil activo y vuelve a «Default». No se puede borrar la plantilla.", function()
    if not ns.Profile.DeleteCurrent then
      return
    end
    local ok, err = ns.Profile:DeleteCurrent()
    if ok then
      print("|cff00ff00Chukie UI|r: perfil eliminado. Perfil activo: Default. Volvé a abrir Opciones si el desplegable no se actualiza.")
    elseif err then
      print("|cffff9900Chukie UI|r: " .. err)
    end
  end)
end

local function addBackup(layout)
  addHeader(layout, "Exportar / importar")
  addButton(
    layout,
    "Exportar",
    "Genera el texto del perfil activo. WoW no crea archivos: Copiar y pegalo en un .txt. También: /chukieui backup.",
    function()
      if ns.Backup and ns.Backup.Show and ns.Backup.Encode then
        ns.Backup:Show(ns.Backup:Encode())
        return
      end
      print("|cffff9900Chukie UI|r: el respaldo no está disponible.")
    end
  )
  addButton(
    layout,
    "Importar",
    "Abre el cuadro para pegar un respaldo y aplicarlo al perfil activo.",
    function()
      if ns.Backup and ns.Backup.Show then
        ns.Backup:Show()
        return
      end
      print("|cffff9900Chukie UI|r: el respaldo no está disponible.")
    end
  )
end

local function addRightPanel(category, layout)
  addHeader(layout, "Posición")
  rightSlider(
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
  rightSlider(
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
  addHeader(layout, "Tamaño y bloqueo")
  rightSlider(
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
  rightCheckbox(
    category,
    "ChukieUi_MMPos_lockRightPanelEdit",
    "lockRightPanelInEditMode",
    "No soltar el cluster al modo edición de Blizzard",
    "Con esto activo, el modo edición de Blizzard no saca el minimapa del panel.",
    true
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_rotateMinimap",
    "rotateMinimap",
    "Rotar el mapa con la dirección del personaje",
    "El mapa gira y la flecha queda hacia arriba.",
    false
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_debugBounds",
    "debugRightPanelBounds",
    "Recuadro verde del panel derecho",
    "Dibuja el borde del panel para ver hasta dónde llega. No captura el ratón.",
    false
  )
  if not (Settings.CreateDropdown and Settings.CreateControlTextContainer) then
    return
  end
  local setting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_MMPos_zoomPref",
    Settings.VarType.Number,
    "Zoom del mapa",
    0,
    function()
      local db = rightModel()
      local v = db and tonumber(db.minimapZoomPreference)
      if v == 1 or v == 2 then
        return v
      end
      return 0
    end,
    function(v)
      local db = rightModel()
      if not db then
        return
      end
      v = tonumber(v)
      if v ~= 1 and v ~= 2 then
        v = 0
      end
      db.minimapZoomPreference = v
      refreshRight()
    end
  )
  local choices = Settings.CreateControlTextContainer()
  choices:Add(0, "Automático (Blizzard)")
  choices:Add(1, "Siempre máximo alejado")
  choices:Add(2, "Siempre máximo acercado")
  Settings.CreateDropdown(category, setting, choices:GetData(), "Usa los niveles de zoom que ya tiene el minimapa.")
end

local function padModes()
  local modes = ns.ButtonPad and ns.ButtonPad.Modes
  if type(modes) == "table" and #modes > 0 then
    return modes
  end
  return {
    { id = "keyzen", label = "Modo Keyzen" },
    { id = "nostromo", label = "Modo Nostromo" },
  }
end

local function addButtonPad(category, layout)
  addHeader(layout, "Botonera")
  barCheckbox(
    category,
    "ChukieUi_AB_enabled",
    "enabled",
    "Activar botonera",
    "Muestra las barras de Chukie. Apagada, vuelve el arte de barras de Blizzard.",
    true
  )
  if Settings.CreateDropdown and Settings.CreateControlTextContainer then
    local setting = Settings.RegisterProxySetting(
      category,
      "ChukieUi_AB_buttonPadMode",
      Settings.VarType.String,
      "Formato de la botonera",
      "keyzen",
      function()
        local db = barsModel()
        local id = db and db.buttonPadMode
        local modes = padModes()
        for i = 1, #modes do
          if modes[i].id == id then
            return id
          end
        end
        return modes[1].id
      end,
      function(value)
        local db = barsModel()
        if not db then
          return
        end
        local picked = padModes()[1].id
        local modes = padModes()
        for i = 1, #modes do
          if modes[i].id == value then
            picked = value
          end
        end
        db.buttonPadMode = picked
        refreshBars()
      end
    )
    local function dropdownData()
      local container = Settings.CreateControlTextContainer()
      local modes = padModes()
      for i = 1, #modes do
        container:Add(modes[i].id, modes[i].label or modes[i].id)
      end
      return container:GetData()
    end
    Settings.CreateDropdown(
      category,
      setting,
      dropdownData,
      "Keyzen usa la forma del keypad. Nostromo pone los mismos 24 botones en 4 filas."
    )
  end
  barCheckbox(
    category,
    "ChukieUi_AB_leftEnabled",
    "leftEnabled",
    "Mostrar barras 1–4",
    "El bloque de 24 botones, centrado en la pantalla.",
    true
  )
  barCheckbox(
    category,
    "ChukieUi_AB_keyzenLock",
    "keyzenPadLocked",
    "Bloquear posición",
    "Con el candado activo la botonera no se arrastra. En Keyzen el botón de la esquina también lo cambia.",
    true
  )
  addCheckbox(
    category,
    "ChukieUi_AB_applyDefaultKeys",
    "Teclas por defecto (1–5, QWERT, ASDFG, ZXCV)",
    "La próxima vez que se muestre la botonera asigna esas teclas si el botón todavía no tiene una.",
    true,
    function()
      return readBool(barsModel(), "applyDefaultKeybinds", true)
    end,
    function(v)
      local db = barsModel()
      if not db then
        return
      end
      local on = (v == true or v == 1)
      db.applyDefaultKeybinds = on
      if on then
        db._defaultKeybindsApplied = nil
      end
      refreshBars()
    end
  )
  barCheckbox(
    category,
    "ChukieUi_AB_hideBlizz",
    "hideBlizzardArt",
    "Ocultar barras de Blizzard",
    "Oculta las barras de acción de Blizzard mientras la botonera de Chukie está activa.",
    true
  )

  addHeader(layout, "Tamaño y posición")
  barSlider(category, "ChukieUi_AB_leftSize", "leftButtonSize", "Tamaño botón (px)", "Tamaño de cada botón.", 18, 64, 1, 36)
  barSlider(category, "ChukieUi_AB_leftGap", "leftSpacing", "Espacio entre botones", "Separación entre botones de la misma fila.", 0, 16, 1, 2)
  barSlider(category, "ChukieUi_AB_leftBarGap", "leftBarSpacing", "Espacio entre filas", "En Nostromo separa las filas. En Keyzen separa las filas del keypad.", 0, 24, 1, 4)
  barSlider(category, "ChukieUi_AB_leftOffX", "leftOffsetX", "Desplazamiento X", "Desde el centro de la pantalla.", -1800, 1800, 1, 0)
  barSlider(category, "ChukieUi_AB_leftOffY", "leftOffsetY", "Desplazamiento Y", "Desde el centro de la pantalla.", -1200, 1200, 1, 0)

  addHeader(layout, "Situación")
  barCheckbox(
    category,
    "ChukieUi_AB_skyriding",
    "skyridingPaging",
    "Paging de vuelo (barras 1–4 → 8–11)",
    "Con el vuelo del juego, la botonera muestra las páginas 8 a 11.",
    false
  )
  barCheckbox(
    category,
    "ChukieUi_AB_vehicle",
    "vehiclePaging",
    "Barra de vehículo en la barra 1",
    "En vehículo, misión con barra propia o posesión, la barra 1 muestra esas acciones.",
    false
  )
  barCheckbox(
    category,
    "ChukieUi_AB_bonus",
    "bonusPaging",
    "Barras de bonus en la barra 1",
    "Formas, sigilo y habilidades temporales pasan a la barra 1.",
    false
  )
  barCheckbox(
    category,
    "ChukieUi_AB_vehicleExit",
    "vehicleExitButton",
    "Botón de bajarse",
    "Muestra el botón de salida encima de la barra 1 cuando el paging de vehículo está activo.",
    true
  )
end

function ns.RegisterConfigPanel()
  if ns.configPanelRegistered then
    return
  end
  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory and Settings.RegisterProxySetting and Settings.CreateCheckbox and Settings.CreateSlider) then
    return
  end
  if not (ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()) then
    return
  end

  local root, rootLayout = Settings.RegisterVerticalLayoutCategory("Chukie UI")
  if not root then
    return
  end
  root.ID = "ChukieUi"
  ns.configPanelRegistered = true

  addHeader(rootLayout, "General")
  addProfiles(root, rootLayout)
  addBackup(rootLayout)

  local rightCategory, rightLayout = subcategory(root, rootLayout, "Panel derecho")
  addRightPanel(rightCategory, rightLayout)

  local barsCategory, barsLayout = subcategory(root, rootLayout, "Botonera")
  addButtonPad(barsCategory, barsLayout)

  Settings.RegisterAddOnCategory(root)
  ns.settingsCategoryID = categoryId(root)
  ns.minimapCategoryID = categoryId(rightCategory)
  ns.actionBarsCategoryID = categoryId(barsCategory)
end

function ns.OpenConfigPanel()
  if not ns.settingsCategoryID or not (Settings and Settings.OpenToCategory) then
    return false
  end
  Settings.OpenToCategory(ns.settingsCategoryID)
  return true
end

function ns.OpenMinimapConfigPanel()
  if not ns.minimapCategoryID or not (Settings and Settings.OpenToCategory) then
    return false
  end
  Settings.OpenToCategory(ns.minimapCategoryID)
  return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon ~= ADDON_NAME then
    return
  end
  ns.RegisterConfigPanel()
end)
