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

local addMinimapCaptureList

--- Puntos del minimapa: nodos (hierbas, minerales, peces), correo y el resto
--- del menú de rastreo. Forever 1.60.1 devuelve toda la lista en
--- GetNumTrackingTypes; el menú de Blizzard esconde casi todo si
--- minimapTrackingShowAll está apagado. Acá se listan igual.
--- C_Minimap.GetTrackingInfo / GetTrackingFilter / SetTracking(índice, bool).
--- La clave guardada es el spellID o el filterID, nunca el índice de la lista.
local function secret(v)
  return issecretvalue and issecretvalue(v) or false
end

--- El blanco y el foco marcan unidades, no son puntos del mapa.
local function skipFilterId(field, fallback)
  local e = Enum and Enum.MinimapTrackingFilter
  local v = type(e) == "table" and e[field] or nil
  if secret(v) or type(v) ~= "number" then
    v = fallback
  end
  if type(v) ~= "number" then
    return nil
  end
  return math.floor(v)
end

local skipFilters

local function ensureSkipFilters()
  if skipFilters then
    return
  end
  skipFilters = {}
  local function add(field, fallback)
    local id = skipFilterId(field, fallback)
    if id then
      skipFilters[id] = true
    end
  end
  add("Target", 0x4000)
  add("Focus", 0x8000)
  add("Unfiltered", 0x0)
end

local function trackingCount()
  if not (C_Minimap and C_Minimap.GetNumTrackingTypes) then
    return 0
  end
  local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
  if not ok or secret(n) then
    return 0
  end
  n = tonumber(n)
  if not n or n < 1 then
    return 0
  end
  return math.floor(n)
end

local function readTracking(index)
  if not (C_Minimap and C_Minimap.GetTrackingInfo) then
    return nil
  end
  local ok, a, b, c, d, e, f = pcall(C_Minimap.GetTrackingInfo, index)
  if not ok or secret(a) then
    return nil
  end
  local info
  if type(a) == "table" then
    info = a
  else
    info = { name = a, texture = b, active = c, type = d, subType = e, spellID = f }
  end
  local name = info.name
  if secret(name) or type(name) ~= "string" then
    return nil
  end
  if strtrim then
    name = strtrim(name)
  end
  if name == "" then
    return nil
  end
  local active
  if secret(info.active) then
    active = nil
  else
    active = info.active == true or info.active == 1
  end
  local spellID = info.spellID
  local kind = info.type
  local subType = info.subType
  if secret(spellID) then
    spellID = nil
  end
  if secret(kind) then
    kind = nil
  end
  if secret(subType) then
    subType = nil
  end
  spellID = tonumber(spellID)
  if spellID then
    spellID = math.floor(spellID)
  end
  local filterID
  if C_Minimap.GetTrackingFilter then
    local fok, filter = pcall(C_Minimap.GetTrackingFilter, index)
    if fok and type(filter) == "table" and not secret(filter) then
      local fid = filter.filterID
      local fsid = filter.spellID
      if not secret(fid) then
        fid = tonumber(fid)
        if fid then
          filterID = math.floor(fid)
        end
      end
      if not spellID and not secret(fsid) then
        fsid = tonumber(fsid)
        if fsid then
          spellID = math.floor(fsid)
        end
      end
    end
  end
  local key
  if spellID and spellID > 0 then
    key = "spell:" .. tostring(spellID)
  elseif filterID then
    key = "filter:" .. tostring(filterID)
  end
  if not key then
    return nil
  end
  return {
    index = index,
    key = key,
    name = name,
    active = active,
    kind = type(kind) == "string" and string.lower(kind) or "",
    subType = tonumber(subType),
    spellID = spellID,
    filterID = filterID,
  }
end

local function isListedPin(pin)
  ensureSkipFilters()
  if pin.spellID and pin.spellID > 0 then
    return true
  end
  if pin.filterID and skipFilters[pin.filterID] then
    return false
  end
  return true
end

local function collectObjectPins()
  local pins = {}
  local n = trackingCount()
  for i = 1, n do
    local pin = readTracking(i)
    if pin and isListedPin(pin) then
      pins[#pins + 1] = pin
    end
  end
  return pins
end

local function findObjectPin(key)
  local pins = collectObjectPins()
  for i = 1, #pins do
    if pins[i].key == key then
      return pins[i]
    end
  end
  return nil
end

local function pinsSaved(create)
  if not (ns.Profile and ns.Profile.GetActive) then
    return nil
  end
  local profile = ns.Profile:GetActive()
  if type(profile) ~= "table" then
    return nil
  end
  if type(profile.minimapMapPins) ~= "table" then
    if not create then
      return nil
    end
    profile.minimapMapPins = {}
  end
  return profile.minimapMapPins
end

local function savedWant(db, key)
  if not db or secret(db[key]) or db[key] == nil then
    return nil
  end
  return db[key] == true or db[key] == 1
end

local function setTrackingAt(index, want)
  want = want and true or false
  if C_Minimap and C_Minimap.SetTracking then
    local ok = pcall(C_Minimap.SetTracking, index, want)
    if ok then
      local again = readTracking(index)
      if again and again.active == want then
        return true
      end
    end
  end
  if type(MinimapUtil) == "table" and type(MinimapUtil.SetTrackingFilterByFilterIndex) == "function" then
    local ok = pcall(MinimapUtil.SetTrackingFilterByFilterIndex, index, want)
    if ok then
      local again = readTracking(index)
      if again and again.active == want then
        return true
      end
    end
  end
  return false
end

local function addMinimapPinHeader(layout)
  if ns._minimapPinHeaderAdded or not layout then
    return
  end
  addHeader(layout, "Puntos en el mapa")
  ns._minimapPinHeaderAdded = true
end

local function addMinimapPinRow(category, pin)
  ns._minimapPinRows = ns._minimapPinRows or {}
  if ns._minimapPinRows[pin.key] then
    return
  end
  local key = pin.key
  local id = "ChukieUi_MMPin_" .. key:gsub("[^%w]", "_")
  local setting
  ns._minimapPinsRegistering = true
  pcall(function()
  setting = Settings.RegisterProxySetting(
    category,
    id,
    Settings.VarType.Boolean,
    pin.name,
    pin.active and Settings.Default.True or Settings.Default.False,
    function()
      local db = pinsSaved(false)
      local want = savedWant(db, key)
      if want ~= nil then
        return want
      end
      local current = findObjectPin(key)
      return current and current.active or false
    end,
    function(v)
      if ns._minimapPinsRegistering or ns._minimapPinsApplying then
        return
      end
      local want = v == true or v == 1
      local current = findObjectPin(key)
      local db = pinsSaved(true)
      if not db or not current then
        return
      end
      if current.active == want then
        db[key] = want
        return
      end
      ns._minimapPinsApplying = true
      local applied = setTrackingAt(current.index, want)
      ns._minimapPinsApplying = false
      if applied then
        db[key] = want
        return
      end
      if setting and setting.SetValue then
        ns._minimapPinsApplying = true
        pcall(setting.SetValue, setting, current.active and true or false)
        ns._minimapPinsApplying = false
      end
    end
  )
  Settings.CreateCheckbox(category, setting, "Muestra este punto en el minimapa.")
  end)
  ns._minimapPinsRegistering = false
  if setting then
    ns._minimapPinRows[pin.key] = true
  end
end

function ns.ReconcileMinimapPins(applySaved)
  if ns._minimapPinsBusy then
    return
  end
  if not (ns._minimapPinsCategory and Settings and Settings.RegisterProxySetting and Settings.CreateCheckbox) then
    return
  end
  ns._minimapPinsBusy = true
  pcall(function()
    local pins = collectObjectPins()
    ns._minimapPinsHaveList = #pins > 0
    if #pins == 0 then
      return
    end
    addMinimapPinHeader(ns._minimapPinsLayout)
    for i = 1, #pins do
      addMinimapPinRow(ns._minimapPinsCategory, pins[i])
    end
    local profile = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
    if type(profile) ~= "table" then
      return
    end
    local first = type(profile.minimapMapPins) ~= "table"
    if first then
      profile.minimapMapPins = {}
      applySaved = false
    end
    local db = profile.minimapMapPins
    ns._minimapPinsApplying = true
    for i = 1, #pins do
      local pin = pins[i]
      local want = savedWant(db, pin.key)
      if want == nil then
        if pin.active ~= nil then
          db[pin.key] = pin.active and true or false
        end
      elseif applySaved and pin.active ~= nil and pin.active ~= want then
        setTrackingAt(pin.index, want)
      end
    end
  end)
  ns._minimapPinsApplying = false
  ns._minimapPinsBusy = false
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
    "ChukieUi_MMPos_showRing",
    "showMinimapRing",
    "Mostrar anillo del mapa",
    "El borde circular alrededor del disco. Apagado, queda solo el mapa. Los botones + y − siguen ocultos; la rueda no cambia.",
    false
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_showZone",
    "showMinimapZone",
    "Mostrar nombre de zona",
    "MinimapZoneText, el texto del nombre. La barra va aparte.",
    false
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_showZoneBar",
    "showMinimapZoneBar",
    "Mostrar barra de zona",
    "MinimapCluster.BorderTop, la barra vacía. El clic de esa barra ya no abre el mapa.",
    false
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_showSunBorder",
    "showMinimapSunBorder",
    "Mostrar círculo de día y noche",
    "MinimapCluster.DielFrame, el sol o la luna de la zona. Queda arriba a la derecha, fuera del disco.",
    false
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_showCalendar",
    "showMinimapCalendar",
    "Mostrar calendario",
    "GameTimeFrame, el botón de calendario al lado del reloj.",
    false
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_showTracking",
    "showMinimapTracking",
    "Mostrar círculo junto al reloj",
    "MinimapCluster.Tracking.Button, el círculo a la derecha de la hora. Si es el ojo de cola, también QueueStatusButton.",
    false
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_showClock",
    "showMinimapClock",
    "Mostrar reloj",
    "TimeManagerClockButton, el recuadro con la hora.",
    false
  )
  rightCheckbox(
    category,
    "ChukieUi_MMPos_showAddonBox",
    "showMinimapAddonBox",
    "Mostrar recuadro de addons",
    "AddonCompartmentFrame, el recuadro con el número de addons.",
    false
  )
  if Settings.CreateDropdown and Settings.CreateControlTextContainer then
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

  local keySetting = Settings.RegisterProxySetting(
    category,
    "ChukieUi_MMPos_keyRing",
    Settings.VarType.Number,
    "Llavero de Classic",
    0,
    function()
      local db = rightModel()
      local v = db and tonumber(db.keyRingPlace) or 0
      if v ~= 1 and v ~= 2 then
        return 0
      end
      return v
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
      db.keyRingPlace = v
      if ns.RightPanel and ns.RightPanel.PlaceKeyRing then
        ns.RightPanel:PlaceKeyRing()
      end
    end
  )
  local keyChoices = Settings.CreateControlTextContainer()
  keyChoices:Add(0, "Oculto")
  keyChoices:Add(1, "Barra del minimapa")
  keyChoices:Add(2, "Junto a los botones libres")
  Settings.CreateDropdown(
    category,
    keySetting,
    keyChoices:GetData(),
    "Forever muestra el botón de llavero de Classic. Oculto lo apaga. Las otras dos lo dejan en el panel derecho, sin volver a la barra de bolsas."
  )
  end
  ns._minimapPinsCategory = category
  ns._minimapPinsLayout = layout
  addMinimapPinHeader(layout)
  ns.ReconcileMinimapPins(false)
end

local POLICY_ON_MAP, POLICY_BAR, POLICY_HIDDEN = 0, 1, 2

local function minimapBarModel()
  local m
  if ns.Profile and ns.Profile.GetMinimapBarModel then
    m = ns.Profile:GetMinimapBarModel()
  end
  if not m then
    return nil
  end
  m.buttonPolicy = m.buttonPolicy or {}
  m.discoveredOrder = m.discoveredOrder or {}
  return m
end

local function policyId(frameName)
  local s = tostring(frameName or "x"):gsub("[^%w]", "_")
  if #s > 48 then
    s = strsub(s, 1, 48)
  end
  return "ChukieUi_MM_pol_addon_" .. s
end

local function policyChoices()
  local c = Settings.CreateControlTextContainer()
  c:Add(POLICY_ON_MAP, "Dejar en el mapa")
  c:Add(POLICY_BAR, "Capturar a la barra")
  c:Add(POLICY_HIDDEN, "Oculto")
  return c:GetData()
end

local function addCaptureDropdown(category, frameName)
  local function get()
    local db = minimapBarModel()
    local v = db and db.buttonPolicy[frameName]
    if v == "default" or v == POLICY_ON_MAP then
      return POLICY_ON_MAP
    end
    if v == "hidden" or v == POLICY_HIDDEN then
      return POLICY_HIDDEN
    end
    if v == "bar" or v == POLICY_BAR or v == nil then
      return POLICY_BAR
    end
    local n = tonumber(v)
    if n == POLICY_ON_MAP or n == POLICY_HIDDEN then
      return n
    end
    return POLICY_BAR
  end
  local function set(v)
    local db = minimapBarModel()
    if not db then
      return
    end
    v = tonumber(v)
    if v ~= POLICY_ON_MAP and v ~= POLICY_BAR and v ~= POLICY_HIDDEN then
      v = POLICY_BAR
    end
    if v == POLICY_BAR then
      db.buttonPolicy[frameName] = nil
    else
      db.buttonPolicy[frameName] = v
    end
    if ns.MinimapBar and ns.MinimapBar.Refresh then
      ns.MinimapBar:Refresh()
    end
  end
  local setting = Settings.RegisterProxySetting(
    category,
    policyId(frameName),
    Settings.VarType.Number,
    frameName,
    POLICY_BAR,
    get,
    set
  )
  Settings.CreateDropdown(
    category,
    setting,
    policyChoices,
    "Dejar en el mapa lo deja en el círculo. Capturar a la barra lo mueve a la fila de iconos. Oculto lo esconde."
  )
end

local function moveDiscovered(frameName, dir)
  local db = minimapBarModel()
  if not db then
    return
  end
  local order = db.discoveredOrder
  local idx
  for i = 1, #order do
    if order[i] == frameName then
      idx = i
    end
  end
  if not idx then
    return
  end
  local j = idx + dir
  if j < 1 or j > #order then
    return
  end
  order[idx], order[j] = order[j], order[idx]
  if ns.MinimapBar and ns.MinimapBar.Refresh then
    ns.MinimapBar:Refresh()
  end
end

local function addOrderButtons(layout, frameName)
  addButton(layout, "Subir " .. frameName, "Lo mueve un lugar a la izquierda en la barra.", function()
    moveDiscovered(frameName, -1)
  end)
  addButton(layout, "Bajar " .. frameName, "Lo mueve un lugar a la derecha en la barra.", function()
    moveDiscovered(frameName, 1)
  end)
end

function addMinimapCaptureList(category, layout)
  if not (Settings.CreateDropdown and Settings.CreateControlTextContainer and category) then
    return
  end
  addHeader(layout, "Captura, ocultar y orden")
  if ns.MinimapBar and ns.MinimapBar.UpdateDiscoveredOrder then
    ns.MinimapBar:UpdateDiscoveredOrder()
  end
  ns._mmAddonPolicyRegistered = ns._mmAddonPolicyRegistered or {}
  ns._minimapAddonPolicyCategory = category
  local db = minimapBarModel()
  local order = db and db.discoveredOrder or {}
  for i = 1, #order do
    local name = order[i]
    if not ns._mmAddonPolicyRegistered[name] then
      ns._mmAddonPolicyRegistered[name] = true
      addCaptureDropdown(category, name)
      addOrderButtons(layout, name)
    end
  end
  if #order == 0 then
    addHeader(layout, "Todavía no hay botones detectados. Entrá al mundo y volvé a abrir esta página.")
  end
  function ns.AppendMinimapDiscoveryPolicyRows()
    if not ns.configPanelRegistered or not ns._minimapAddonPolicyCategory then
      return
    end
    local cat = ns._minimapAddonPolicyCategory
    local model = minimapBarModel()
    local names = model and model.discoveredOrder or {}
    for i = 1, #names do
      local name = names[i]
      if not ns._mmAddonPolicyRegistered[name] then
        ns._mmAddonPolicyRegistered[name] = true
        addCaptureDropdown(cat, name)
        local lay = cat
        if SettingsPanel and SettingsPanel.GetLayout then
          lay = SettingsPanel:GetLayout(cat) or lay
        end
        addOrderButtons(lay, name)
      end
    end
  end
end

local function refreshMinimapBar()
  if ns.MinimapBar and ns.MinimapBar.Refresh then
    ns.MinimapBar:Refresh()
  end
end

local function refreshStrip()
  if ns.RightStrip and ns.RightStrip.Refresh then
    ns.RightStrip:Refresh()
  elseif ns.RightPanel and ns.RightPanel.Apply then
    ns.RightPanel:Apply()
  end
end

local function mmCheckbox(category, id, key, label, tooltip, defaultOn)
  addCheckbox(category, id, label, tooltip, defaultOn, function()
    return readBool(minimapBarModel(), key, defaultOn)
  end, function(v)
    writeBool(minimapBarModel(), key, v)
    refreshMinimapBar()
  end)
end

local function mmSlider(category, id, key, label, tooltip, minV, maxV, step, defaultNum)
  addSlider(category, id, label, tooltip, minV, maxV, step, defaultNum, function()
    return readInt(minimapBarModel(), key, minV, maxV, defaultNum)
  end, function(v)
    local db = minimapBarModel()
    if not db then
      return
    end
    db[key] = math.floor((tonumber(v) or defaultNum) + 0.5)
    refreshMinimapBar()
  end)
end

local function addAddonBarPage(category, layout)
  addHeader(layout, "Barra de iconos")
  mmCheckbox(
    category,
    "ChukieUi_MMBar_enabled",
    "enabled",
    "Mostrar barra de addons",
    "Fila de iconos capturados, debajo del mapa. Si está apagada, los botones vuelven al círculo.",
    true
  )
  mmCheckbox(
    category,
    "ChukieUi_MMBar_lockLdb",
    "lockLdb",
    "Bloquear arrastre",
    "Evita que LibDBIcon vuelva a pegar el icono en el borde del mapa.",
    true
  )
  mmCheckbox(
    category,
    "ChukieUi_MMBar_useMasque",
    "useMasque",
    "Masque en la barra",
    "Grupo «Chukie UI» → «MinimapBar», si Masque está instalado.",
    true
  )
  addHeader(layout, "Tamaño")
  mmSlider(category, "ChukieUi_MMBar_addonIconWidth", "addonBarIconWidth", "Ancho del icono", "Ancho de cada icono de la barra, en píxeles.", 16, 72, 1, 34)
  mmSlider(category, "ChukieUi_MMBar_addonIconHeight", "addonBarIconHeight", "Alto del icono", "Alto de cada icono. La barra crece con este valor.", 16, 72, 1, 34)
  mmSlider(category, "ChukieUi_MMBar_addonSpacing", "addonBarSpacing", "Separación", "Espacio horizontal entre iconos.", 0, 24, 1, 4)
  addMinimapCaptureList(category, layout)
end

local MICRO_LABELS = {
  CharacterMicroButton = "Personaje",
  PlayerSpellsMicroButton = "Hechizos",
  SpellbookMicroButton = "Libro de hechizos",
  ProfessionMicroButton = "Profesiones",
  TalentMicroButton = "Talentos",
  AchievementMicroButton = "Logros",
  QuestLogMicroButton = "Misiones",
  GuildMicroButton = "Hermandad",
  LFDMicroButton = "Buscador",
  CollectionsMicroButton = "Colecciones",
  EJMicroButton = "Guía",
  StoreMicroButton = "Tienda",
  ExpansionLandingPageMinimapButton = "Página de expansión",
}

local function microLabel(frameName)
  if MICRO_LABELS[frameName] then
    return MICRO_LABELS[frameName]
  end
  local s = tostring(frameName or ""):gsub("MicroButton$", "")
  if s == "" then
    return tostring(frameName)
  end
  return s
end

local function microId(frameName)
  local s = tostring(frameName or "x"):gsub("[^%w]", "_")
  if #s > 40 then
    s = strsub(s, 1, 40)
  end
  return "ChukieUi_MM_minimenu_vis_" .. s
end

local function addMicroVisible(category, frameName)
  local label = microLabel(frameName)
  addCheckbox(category, microId(frameName), label, "Mostrar «" .. label .. "» en la fila del micromenú.", true, function()
    local db = minimapBarModel()
    local t = db and db.minimenuVisibility
    if not t then
      return true
    end
    return t[frameName] ~= false
  end, function(v)
    local db = minimapBarModel()
    if not db then
      return
    end
    db.minimenuVisibility = db.minimenuVisibility or {}
    if v == true or v == 1 then
      db.minimenuVisibility[frameName] = nil
    else
      db.minimenuVisibility[frameName] = false
    end
    refreshMinimapBar()
  end)
end

local function addMicroMenuPage(category, layout)
  addHeader(layout, "Fila del micromenú")
  mmCheckbox(
    category,
    "ChukieUi_MMBar_minimenuBar",
    "minimenuBarEnabled",
    "Mostrar micromenú",
    "Segunda fila, debajo de la barra de addons. Apagada, los botones vuelven a la barra de Blizzard.",
    true
  )
  mmCheckbox(
    category,
    "ChukieUi_MMBar_useMasqueMicro",
    "useMasqueMicromenu",
    "Masque en el micromenú",
    "Grupo «Chukie UI» → «MinimapBarMicroMenu». Algunos botones de Blizzard no tienen icono y pueden verse raros.",
    false
  )
  addHeader(layout, "Tamaño y separación")
  mmSlider(category, "ChukieUi_MMBar_microRow", "minimenuRowHeight", "Alto de la fila", "Alto de la fila del micromenú, en píxeles.", 20, 80, 1, 42)
  mmSlider(category, "ChukieUi_MMBar_microIconWidth", "minimenuIconWidth", "Ancho del icono", "Ancho de cada botón del micromenú.", 12, 56, 1, 28)
  mmSlider(category, "ChukieUi_MMBar_microSpacing", "minimenuSpacing", "Separación", "Espacio horizontal entre botones. Puede quedar en cero.", 0, 24, 1, 2)
  mmSlider(
    category,
    "ChukieUi_MMBar_microGap",
    "minimenuGapBelowAddonBar",
    "Distancia a la barra de addons",
    "Píxeles entre la barra de addons y el micromenú.",
    0,
    48,
    1,
    8
  )
  addHeader(layout, "Botones")
  ns._mmMinimenuRegistered = ns._mmMinimenuRegistered or {}
  ns._minimenuVisibilityCategory = category
  if ns.MinimapBar and ns.MinimapBar.GetMinimenuButtonNameList then
    local names = ns.MinimapBar:GetMinimenuButtonNameList()
    for i = 1, #names do
      local name = names[i]
      if not ns._mmMinimenuRegistered[name] then
        ns._mmMinimenuRegistered[name] = true
        addMicroVisible(category, name)
      end
    end
    if #names == 0 then
      addHeader(layout, "Los botones aparecen al entrar al mundo. Volvé a abrir esta página.")
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
    local names = ns.MinimapBar:GetMinimenuButtonNameList()
    for i = 1, #names do
      local name = names[i]
      if not ns._mmMinimenuRegistered[name] then
        ns._mmMinimenuRegistered[name] = true
        addMicroVisible(cat, name)
      end
    end
  end
end

local function addFreeBarsPage(category, layout)
  addHeader(layout, "Los 4 botones libres")
  addHeader(
    layout,
    "Columna a la izquierda del mapa. De arriba a abajo: teletransporte, acción extra, habilidad de zona y objeto de misión. Cada uno acepta lo que le sueltes."
  )
  rightCheckbox(
    category,
    "ChukieUi_Free_show",
    "showFreeButtons",
    "Mostrar los 4 botones",
    "La columna junto al mapa. Apagada, no se ve ninguno.",
    true
  )
  rightCheckbox(category, "ChukieUi_Free_teleport", "showFreeTeleport", "Teletransporte", "El de arriba. Ranura 133.", true)
  rightCheckbox(category, "ChukieUi_Free_extra", "showFreeExtra", "Acción extra", "Ranura 134.", true)
  rightCheckbox(category, "ChukieUi_Free_zone", "showFreeZone", "Habilidad de zona", "Ranura 135.", true)
  rightCheckbox(category, "ChukieUi_Free_quest", "showFreeQuest", "Objeto de misión", "Ranura 136.", true)
  rightSlider(category, "ChukieUi_Free_size", "freeButtonSize", "Tamaño", "Lado de cada botón, en píxeles. Se achica si la columna no entra.", 18, 64, 1, 36)
  rightSlider(category, "ChukieUi_Free_gap", "freeButtonGap", "Separación", "Espacio vertical entre los cuatro.", 0, 16, 1, 2)

  addHeader(layout, "Barra 6")
  barCheckbox(
    category,
    "ChukieUi_AB_right6",
    "rightBar6Enabled",
    "Mostrar barra 6",
    "Ocho botones en el panel derecho (ranuras 61–68). No es la botonera Keyzen.",
    false
  )
  barSlider(category, "ChukieUi_AB_right6Count", "rightBar6NumButtons", "Cantidad de botones", "Entre 1 y 12.", 1, 12, 1, 8)
  barSlider(category, "ChukieUi_AB_right6Cols", "rightBar6Cols", "Columnas", "Cuántos botones por fila.", 1, 8, 1, 2)
  barSlider(category, "ChukieUi_AB_right6Size", "rightBar6ButtonSize", "Tamaño", "Lado de cada botón de la barra 6.", 18, 64, 1, 36)
  barSlider(category, "ChukieUi_AB_right6Gap", "rightBar6Spacing", "Separación", "Espacio entre botones de la barra 6.", 0, 16, 1, 2)
  barSlider(category, "ChukieUi_AB_right6OffX", "rightBar6OffsetX", "Desplazamiento X", "Desde la esquina inferior izquierda del panel.", -400, 800, 1, 8)
  barSlider(category, "ChukieUi_AB_right6OffY", "rightBar6OffsetY", "Desplazamiento Y", "Desde la esquina inferior izquierda del panel.", -200, 400, 1, 8)
end

local function addBagsPage(category, layout)
  addHeader(layout, "Oro y bolsas")
  rightCheckbox(
    category,
    "ChukieUi_RS_money",
    "showRightStripMoney",
    "Mostrar oro",
    "El dinero que lleva el personaje, en la franja del panel.",
    true
  )
  rightCheckbox(
    category,
    "ChukieUi_RS_bags",
    "showRightStripBags",
    "Mostrar espacio de bolsas",
    "Huecos libres sobre el total. El clic de la franja abre las bolsas.",
    true
  )
  if Settings.CreateDropdown and Settings.CreateControlTextContainer then
    local setting = Settings.RegisterProxySetting(
      category,
      "ChukieUi_RS_orientation",
      Settings.VarType.String,
      "Orientación",
      "vertical",
      function()
        local db = rightModel()
        if db and db.rightStripOrientation == "horizontal" then
          return "horizontal"
        end
        return "vertical"
      end,
      function(v)
        local db = rightModel()
        if not db then
          return
        end
        if v == "horizontal" then
          db.rightStripOrientation = "horizontal"
        else
          db.rightStripOrientation = "vertical"
        end
        refreshStrip()
      end
    )
    local choices = Settings.CreateControlTextContainer()
    choices:Add("vertical", "Vertical (oro arriba)")
    choices:Add("horizontal", "Horizontal (en una fila)")
    Settings.CreateDropdown(category, setting, choices:GetData(), "Cómo se acomodan el oro y el espacio de bolsas.")
  end
  addHeader(layout, "Texto")
  rightSlider(
    category,
    "ChukieUi_RS_scale",
    "rightStripGridScalePercent",
    "Tamaño (%)",
    "Escala del icono y del texto.",
    60,
    180,
    1,
    100
  )
  rightSlider(
    category,
    "ChukieUi_RS_fontSize",
    "rightStripFontSize",
    "Tamaño de fuente",
    "0 usa un tamaño automático según el ancho de la franja.",
    0,
    32,
    1,
    0
  )
  if Settings.CreateDropdown and Settings.CreateControlTextContainer then
    local setting = Settings.RegisterProxySetting(
      category,
      "ChukieUi_RS_fontFace",
      Settings.VarType.Number,
      "Fuente",
      0,
      function()
        local db = rightModel()
        local v = db and tonumber(db.rightStripFontFace) or 0
        if v < 0 or v > 4 then
          return 0
        end
        return v
      end,
      function(v)
        local db = rightModel()
        if not db then
          return
        end
        v = tonumber(v) or 0
        if v < 0 or v > 4 then
          v = 0
        end
        db.rightStripFontFace = v
        refreshStrip()
      end
    )
    local faces = Settings.CreateControlTextContainer()
    faces:Add(0, "La del juego")
    faces:Add(1, "Friz Quadrata")
    faces:Add(2, "Arial Narrow")
    faces:Add(3, "Morpheus")
    faces:Add(4, "Skurri")
    Settings.CreateDropdown(category, setting, faces:GetData(), "Fuente del oro y del espacio de bolsas.")
  end
  rightCheckbox(
    category,
    "ChukieUi_RS_masque",
    "rightStripUseMasque",
    "Masque en la franja",
    "Aplica Masque al botón de la franja, si está instalado.",
    false
  )
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
  addHeader(rightLayout, "Panel derecho")
  rightCheckbox(
    rightCategory,
    "ChukieUi_MMPos_debugBounds",
    "debugRightPanelBounds",
    "Recuadro verde del panel derecho",
    "Dibuja el borde del panel para ver hasta dónde llega. No captura el ratón.",
    false
  )
  local addonCategory, addonLayout = subcategory(rightCategory, rightLayout, "Botones addons")
  addAddonBarPage(addonCategory, addonLayout)
  local microCategory, microLayout = subcategory(rightCategory, rightLayout, "Botones micromenú")
  addMicroMenuPage(microCategory, microLayout)
  local freeCategory, freeLayout = subcategory(rightCategory, rightLayout, "Barras de botones")
  addFreeBarsPage(freeCategory, freeLayout)
  local mapCategory, mapLayout = subcategory(rightCategory, rightLayout, "Minimapa")
  addRightPanel(mapCategory, mapLayout)
  local bagsCategory, bagsLayout = subcategory(rightCategory, rightLayout, "Bolsas")
  addBagsPage(bagsCategory, bagsLayout)

  local barsCategory, barsLayout = subcategory(root, rootLayout, "Botonera")
  addButtonPad(barsCategory, barsLayout)

  Settings.RegisterAddOnCategory(root)
  ns.settingsCategoryID = categoryId(root)
  ns.minimapCategoryID = categoryId(mapCategory)
  ns.actionBarsCategoryID = categoryId(barsCategory)
end

function ns.OpenConfigPanel()
  if ns.ReconcileMinimapPins then
    ns.ReconcileMinimapPins(false)
  end
  if not ns.settingsCategoryID or not (Settings and Settings.OpenToCategory) then
    return false
  end
  Settings.OpenToCategory(ns.settingsCategoryID)
  return true
end

function ns.OpenMinimapConfigPanel()
  if ns.ReconcileMinimapPins then
    ns.ReconcileMinimapPins(false)
  end
  if not ns.minimapCategoryID or not (Settings and Settings.OpenToCategory) then
    return false
  end
  Settings.OpenToCategory(ns.minimapCategoryID)
  return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SPELLS_CHANGED")
ev:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon ~= ADDON_NAME then
    return
  end
  if event == "SPELLS_CHANGED" then
    local apply = ns._minimapPinsLoginApply == true
    ns.ReconcileMinimapPins(apply)
    if apply and ns._minimapPinsHaveList then
      ns._minimapPinsLoginApply = false
    end
    return
  end
  ns.RegisterConfigPanel()
  if event == "PLAYER_LOGIN" then
    ns._minimapPinsLoginApply = true
    ns.ReconcileMinimapPins(true)
    if ns._minimapPinsHaveList then
      ns._minimapPinsLoginApply = false
    end
  end
end)
