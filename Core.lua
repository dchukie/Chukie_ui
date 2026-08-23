--[[ Chukie UI — núcleo del addon. Aquí se fusionan opciones por defecto,
     se aplican CVars y puedes ir añadiendo hooks a marcos de la UI.
     Cliente objetivo: Retail 12.1 (Interface 120100); TOC también admite 120007. ]]

local ADDON_NAME, ns = ...

--- Textos en el panel de teclas (Bindings.xml en la raíz; no incluir en el .toc).
--- El cuerpo de cada <Binding> se ejecuta como Lua: debe ser código válido (p. ej. solo comentarios «-- …»), no texto suelto ni un «0» suelto.
_G["BINDING_HEADER_CHUKIEUI_ACTIONBARS"] = "Chukie UI - Barras 1–4"
_G["BINDING_NAME_CLICK ChukieUi_MiniAct1:LeftButton"] =
  "Chukie UI - mini barra acción 1 (Action Bar 6 / slot 145)"
_G["BINDING_NAME_CLICK ChukieUi_MiniAct2:LeftButton"] =
  "Chukie UI - mini barra acción 2 (Action Bar 6 / slot 146)"
_G["BINDING_NAME_CLICK ChukieUi_MiniAct3:LeftButton"] =
  "Chukie UI - mini barra acción 3 (Action Bar 6 / slot 147)"
_G["BINDING_NAME_CLICK ChukieDynAct2:LeftButton"] =
  "Chukie UI - ranura dinámica 2 (extra / zona / misión)"
_G["BINDING_NAME_CLICK ChukieDynAct3:LeftButton"] =
  "Chukie UI - ranura dinámica 3 (extra / zona / misión)"
_G["BINDING_NAME_CLICK ChukieDynAct4:LeftButton"] =
  "Chukie UI - ranura dinámica 4 (extra / zona / misión)"

do
  local labels = {
    [1] = { "1", "2", "3", "4", "5" },
    [2] = { "Q", "W", "E", "R", "T" },
    [3] = { "A", "S", "D", "F", "G" },
    [4] = { "Z", "X", "C", "V" },
  }
  for barId = 1, 4 do
    for btn = 1, 6 do
      local keyHint = labels[barId] and labels[barId][btn]
      local suffix = keyHint and (" (def: " .. keyHint .. ")") or ""
      _G[string.format("BINDING_NAME_CLICK ChukieUi_AB%d_B%d:LeftButton", barId, btn)] =
        string.format("Chukie UI - barra %d botón %d%s", barId, btn, suffix)
    end
  end
end

local defaults = {
  enabled = true,
  panels = {
    rightPanel = {
      --- Escala global del cluster derecho: mapa + barras + ranuras debug (porcentaje único).
      panelScalePercent = 100,
      panelWidth = 300,
      panelHeight = 360,
      lockRightPanelInEditMode = true,
      offsetX = 0,
      offsetY = 0,
      rotateMinimap = false,
      playerArrowMode = 0,
      playerArrowCustom = "",
      minimapScalePercent = 100,
      minimapZoomPreference = 0,
      debugRightPanelBounds = false,
      debugLeftPanelBounds = false,
      leftPanelEnabled = true,
      leftPanelScalePercent = 100,
      leftPanelDebugOffsetX = 0,
      leftPanelDebugOffsetY = 0,
      leftPanelFeedFontFace = 0,
      leftPanelFeedFontSize = 0, -- 0 = automático.
      leftPanelFeedBgAlphaPercent = 45,
      leftPanelFeedHistoryMax = 300,
      leftPanelL1Subs = {
        loot = true,
        money = true,
        currency = true,
        tradeskills = true,
        system = true,
        combatMisc = true,
        skill = true,
        bgSystem = true,
        raidWarning = true,
        uiError = true,
        uiInfo = true,
        tradeChannel = true,
        blizzardGeneralMirror = true,
      },
      leftPanelGeneralFontFace = 0,
      leftPanelGeneralFontSize = 0, -- 0 = automático.
      leftPanelGeneralBgAlphaPercent = 35,
      leftPanelGeneralHistoryMax = 500,
      leftPanelGeneralMirrorFromBlizzard = true,
      leftPanelGeneralMirrorFrame = 1,
      leftPanelL3Subs = {
        say = true,
        yell = true,
        emote = true,
        guild = true,
        officer = true,
        party = true,
        raid = true,
        instance = true,
        whisper = true,
        whisperInform = true,
        bnWhisper = true,
        bnWhisperInform = true,
        channel = true,
        communities = true,
      },
      leftPanelGeneralInputFontFace = 0,
      leftPanelGeneralInputFontSize = 0, -- 0 = automático.
      leftPanelGeneralInputBgAlphaPercent = 55,
      leftPanelGeneralInputHeight = 24,
      leftPanelGeneralInputCleanStyle = true,
      leftPanelGeneralInputBorderAlphaPercent = 45,
      leftPanelGeneralInputBorderSize = 1,
      leftPanelGeneralInputHorizontalPad = 4,
      leftPanelGeneralInputOffsetX = 0,
      leftPanelGeneralInputOffsetY = 0,
      -- Sector amarillo (RightStrip): apariencia de grilla inferior.
      rightStripUseMasque = false,
      rightStripGridScalePercent = 100,
      rightStripFontFace = 0,
      rightStripFontSize = 0, -- 0 = automático.
    },
  },
  widgets = {
    minimapBar = {},
    rightPanelWidgets = {
      enabled = true,
      useMasque = true,
      gridCellSize = 46,
      gridGap = 4,
      sidePad = 8,
      topPad = 6,
      dateHeight = 24,
      dateBottomPad = 6,
      dateFontFace = 0,
      dateFontSize = 0,
      --- Teletransporte: 0 = automático; 1..N = índice en TeleportCatalog.GetList().
      teleportDefaultIndex = 0,
      --- Compatibilidad antigua (opcional); si no hay índice, se puede usar esta clave.
      teleportDefaultKey = nil,
      --- Por key del catálogo: false = no mostrar en grilla (clic derecho); nil/true = permitir si es válida.
      teleportGridVisibility = {},
      --- Ranuras 2–4 como barra de 3 acciones (slots 145–147 / Action Bar 6). Estilo Dominos.
      miniActionBarEnabled = true,
      --- Ranuras 2–4: acción extra / habilidad de zona / ítem de misión (solo si miniActionBarEnabled = false).
      dynamicActionSlotsEnabled = true,
      --- Si está activo, deshabilita detección dinámica y deja el panel derecho en modo estático liviano.
      staticSessionMode = true,
      --- Toggle de WoWCombatLog.txt en una de las tres celdas de acción.
      combatLogWidgetEnabled = true,
      combatLogWidgetSlot = 4,
      combatLogStopOnExit = true,
      combatLogAdvanced = true,
      combatLogTypes = {
        dungeonNormal = false,
        dungeonHeroic = false,
        dungeonMythic = false,
        dungeonMythicPlus = true,
        raidLfr = false,
        raidNormal = false,
        raidHeroic = false,
        raidMythic = true,
        timewalking = false,
        delve = false,
        pvp = false,
      },
      --- Vacío = todas las instancias cuyos tipos estén habilitados.
      combatLogInstances = {},
      combatLogInstanceNames = {},
    },
  },
  --- Barras de acción estilo Dominos (IDs 1–14 lineales × 12 slots).
  actionBars = {
    enabled = true,
    leftEnabled = true,
    --- Las barras 1–4 son una matriz fija de 6 × 4.
    --- Cada fila/columna puede tener su propia opacidad (10–100 %).
    leftButtonAlphaPercent = {},
    leftButtonSize = 36,
    leftSpacing = 2,
    leftBarSpacing = 4,
    --- Offsets desde el centro de la pantalla hasta el centro del bloque de barras 1–4.
    leftOffsetX = 0,
    leftOffsetY = 0,
    --- Skyriding: barras 1–4 → páginas 8–11 ([bonusbar:5]).
    skyridingPaging = true,
    --- Vehículo / override / possess: la barra 1 muestra esas acciones.
    vehiclePaging = true,
    --- Barras de bonus 1–4 (páginas 7–10): formas, sigilo y habilidades temporales de misión.
    bonusPaging = true,
    --- Botón de bajarse sobre la barra 1 (reemplaza el de Blizzard).
    vehicleExitButton = true,
    --- Asignar una vez las teclas por defecto (12345/qwert/asdfg/zxcv) si no hay binds.
    applyDefaultKeybinds = true,
    --- Masque: grupo «Chukie UI» → «ActionBars».
    useMasque = true,
    --- Ocultar arte/barras stock de Blizzard (MainActionBar, MultiBars, etc.).
    hideBlizzardArt = true,
    --- Hold-and-release / empower (Evoker): pressAndHoldAction + typerelease=actionrelease.
    pressAndHoldRelease = true,
    --- Guarda el contenido de las barras 1–4 por personaje y especialización
    --- (ChukieUiDB.actionLayouts, fuera de los perfiles de UI).
    saveLeftLayout = true,
    --- Al cambiar talentos / loadout / especialización, repone lo guardado en las barras 1–4.
    restoreLeftLayoutOnTalents = true,
    rightBar6Enabled = true,
    rightBar6NumButtons = 8,
    --- 2 columnas × 4 filas.
    rightBar6Cols = 2,
    rightBar6ButtonSize = 36,
    rightBar6Spacing = 2,
    rightBar6OffsetX = 8,
    rightBar6OffsetY = 8,
  },
  --- Brújula horizontal encima del minimapa (panel derecho).
  horizontalCompass = {
    enabled = true,
    height = 22,
    --- Grados visibles a lo ancho de la cinta.
    fovDegrees = 120,
    fontSize = 12,
    showDegreeTicks = true,
    showTarget = true,
    showWaypoint = true,
    showGroup = false,
    hideWhenNoFacing = false,
    --- Vertical desde el centro del minimapa (+ arriba / − abajo). 0 se ajusta solo la primera vez
    --- a «justo encima del mapa» según el tamaño real del minimapa.
    offsetY = 0,
  },
  minimapBar = {
    enabled = true,
    --- Segunda fila bajo la barra de addons: micromenú Blizzard configurable.
    minimenuBarEnabled = true,
    --- Fila del micromenú (px), independiente de la barra de addons.
    minimenuRowHeight = 42,
    --- Ancho objetivo de cada icono del micromenú tras escalar (px).
    minimenuIconWidth = 28,
    --- Espacio horizontal entre iconos del micromenú (px; puede ser negativo).
    minimenuSpacing = 2,
    --- Distancia vertical entre la barra de addons y la del micromenú (px), cuando ambas están activas.
    minimenuGapBelowAddonBar = 8,
    --- Desplazamiento horizontal de la barra de addons (px) respecto al centrado en el minimapa.
    addonBarOffsetX = 0,
    --- Desplazamiento horizontal del micromenú (px); independiente de la barra de addons.
    minimenuBarOffsetX = 0,
    --- Por botón: false = oculto; nil/true = visible (tabla dispersa).
    minimenuVisibility = {},
    stripBlizzardMinimap = true,
    --- Barra de addons (px); cellSize/pad se rellenan al migrar perfiles antiguos.
    addonBarIconWidth = 34,
    addonBarIconHeight = 34,
    addonBarSpacing = 4,
    cellSize = 34,
    pad = 4,
    lockLdb = true,
    useMasque = true,
    --- Masque en botones del micromenú embebido (grupo aparte en Masque: «MinimapBarMicroMenu»).
    useMasqueMicromenu = false,
    buttonPolicy = {},
    discoveredOrder = {},
  },
  minimapPosition = {
    panelScalePercent = 100,
    --- Marco global ChukieUi_RightPanel (px): el MinimapCluster rellena este rectángulo; reglas de posición repetibles.
    panelWidth = 300,
    panelHeight = 360,
    --- Con modo edición de Blizzard activo: si es true, el cluster no pasa a UIParent (no uses el editor nativo del minimapa; evita conflictos con el host).
    lockRightPanelInEditMode = true,
    offsetX = 0,
    offsetY = 0,
    --- CVar rotateMinimap: mapa gira con el PJ, flecha fija hacia arriba.
    rotateMinimap = false,
    --- 0 = textura Blizzard por defecto; 1 = flecha fina (vehículo); 2 = playerArrowCustom.
    playerArrowMode = 0,
    playerArrowCustom = "",
    --- Escala visual de todo el MinimapCluster (límite aplicado en RightPanel.lua / ns.RightPanel, p. ej. 20–300 %).
    minimapScalePercent = 100,
    --- 0 = no forzar; 1 = zoom mínimo (máximo alejado); 2 = zoom máximo permitido (máximo acercado). Límite fijo del cliente.
    minimapZoomPreference = 0,
    --- Dibuja un recuadro verde sobre los bordes del MinimapCluster (panel derecho).
    debugRightPanelBounds = false,
    --- Referencias del nuevo panel izquierdo (5 sectores rojos de la maqueta).
    debugLeftPanelBounds = false,
    leftPanelEnabled = true,
    leftPanelScalePercent = 100,
    leftPanelDebugOffsetX = 0,
    leftPanelDebugOffsetY = 0,
    leftPanelFeedFontFace = 0,
    leftPanelFeedFontSize = 0,
    leftPanelFeedBgAlphaPercent = 45,
    leftPanelFeedHistoryMax = 300,
    leftPanelL1Subs = {
      loot = true,
      money = true,
      currency = true,
      tradeskills = true,
      system = true,
      combatMisc = true,
      skill = true,
      bgSystem = true,
      raidWarning = true,
      uiError = true,
      uiInfo = true,
      tradeChannel = true,
      blizzardGeneralMirror = true,
    },
    leftPanelGeneralFontFace = 0,
    leftPanelGeneralFontSize = 0,
    leftPanelGeneralBgAlphaPercent = 35,
    leftPanelGeneralHistoryMax = 500,
    leftPanelGeneralMirrorFromBlizzard = true,
    leftPanelGeneralMirrorFrame = 1,
    leftPanelL3Subs = {
      say = true,
      yell = true,
      emote = true,
      guild = true,
      officer = true,
      party = true,
      raid = true,
      instance = true,
      whisper = true,
      whisperInform = true,
      bnWhisper = true,
      bnWhisperInform = true,
      channel = true,
      communities = true,
    },
    leftPanelGeneralInputFontFace = 0,
    leftPanelGeneralInputFontSize = 0,
    leftPanelGeneralInputBgAlphaPercent = 55,
    leftPanelGeneralInputHeight = 24,
    leftPanelGeneralInputCleanStyle = true,
    leftPanelGeneralInputBorderAlphaPercent = 45,
    leftPanelGeneralInputBorderSize = 1,
    leftPanelGeneralInputHorizontalPad = 4,
    leftPanelGeneralInputOffsetX = 0,
    leftPanelGeneralInputOffsetY = 0,
    -- Sector amarillo (RightStrip): apariencia de grilla inferior.
    rightStripUseMasque = false,
    rightStripGridScalePercent = 100,
    rightStripFontFace = 0,
    rightStripFontSize = 0,
  },
  cvars = {
    lootUnderMouse = "1",
  },
  --- Alertas: grupos con efectos y condiciones independientes (`rules` legacy es proyección).
  alerts = {
    enabled = false,
    nextId = 1,
    rules = {},
    groups = {},
  },
  --[[ Panel de auras: slots grandes en posición fija, uno por hechizo elegido.
       Cada slot es un AuraContainer del cliente, así que muestra también las auras
       que Blizzard oculta al addon, pero por eso mismo el hueco no se compacta. ]]
  auraPanel = {
    enabled = false,
    unlocked = false,
    point = { "CENTER", 0, -180 },
    size = 64,
    spacing = 8,
    perLine = 6,
    growth = "right",
    unit = "player",
    filter = "HELPFUL",
    auras = {},
  },
  --[[ Grilla de party: cada columna guarda un hechizo y cada celda lo lanza mediante
       una acción segura sobre la unidad fija de su fila. ]]
  partyGrid = {
    enabled = false,
    unlocked = false,
    --- Lado de la celda cuadrada: muestra el icono del hechizo de su columna.
    size = 34,
    spacing = 2,
    --- Celdas por jugador (una habilidad por columna) y hacia dónde crecen.
    columns = 1,
    columnSpells = {},
    --- Columnas que publican una acción /click y sus unidades, en orden de marcado.
    columnCycles = {},
    columnCycleUnits = {},
    columnSpacing = 2,
    growth = "RIGHT",
    --- Separación respecto a la grilla de Blizzard cuando está pegada.
    gap = 8,
    offsetX = 0,
    offsetY = 0,
    orientation = "vertical",
    side = "RIGHT",
    attachToBlizzard = true,
    --- Cada grupo de celdas sigue al marco Blizzard de su propia unidad.
    perUnitAnchor = true,
    includePlayer = true,
    showHealth = true,
    showRole = true,
    --- Grupo independiente «Chukie UI → PartyGrid» cuando Masque está instalado.
    useMasque = true,
    --- Opacidad de la grilla completa (10–100 %). Al moverla se fuerza opaca.
    alphaPercent = 100,
    --- Fuera de grupo la grilla se oculta salvo que se pida lo contrario.
    showSolo = false,
    --- Posición propia cuando no está pegada a la grilla de Blizzard.
    point = { "CENTER", -320, 0 },
  },
}

ns.defaults = defaults

--[[ Estado de cooldown/cargas con valores secretos (Retail 12.x).
     En combate Blizzard oculta tiempos y currentCharges; solo son NeverSecret
     isEnabled, isActive, isOnGCD y maxCharges. Con esos booleanos se distinguen
     tres estados (lleno / recargando / sin cargas), que en habilidades de 2 cargas
     equivalen al número exacto. Con 3 o más, los intermedios quedan indeterminados. ]]
do
  local CdInfo = {}
  ns.CdInfo = CdInfo

  local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
  end

  local function readBool(v)
    if v == nil or isSecret(v) then
      return nil
    end
    return v == true
  end

  --- st = { cdActive, onGcd, hasCharges, maxCharges, chargeActive, empty, count }.
  --- count es nil si no se puede deducir sin leer valores secretos.
  function CdInfo.Derive(cdInfo, chargeInfo)
    local st = {
      cdActive = false,
      onGcd = false,
      hasCharges = false,
      maxCharges = nil,
      chargeActive = false,
      empty = false,
      count = nil,
    }
    if type(cdInfo) == "table" then
      st.onGcd = readBool(cdInfo.isOnGCD) == true
      local active = readBool(cdInfo.isActive)
      st.cdActive = active == true and readBool(cdInfo.isEnabled) ~= false and not st.onGcd
    end
    if type(chargeInfo) == "table" and not isSecret(chargeInfo.maxCharges) then
      local maxCharges = tonumber(chargeInfo.maxCharges)
      if maxCharges and maxCharges > 1 then
        st.hasCharges = true
        st.maxCharges = math.floor(maxCharges)
        local current
        if not isSecret(chargeInfo.currentCharges) then
          current = tonumber(chargeInfo.currentCharges)
        end
        local active = readBool(chargeInfo.isActive)
        if active == nil and current then
          active = current < st.maxCharges
        end
        st.chargeActive = active == true
        st.empty = st.chargeActive and st.cdActive
        if current then
          st.count = math.floor(current)
          st.empty = st.count <= 0
        elseif not st.chargeActive then
          st.count = st.maxCharges
        elseif st.empty then
          st.count = 0
        elseif st.maxCharges == 2 then
          st.count = 1
        end
      end
    end
    if not st.hasCharges then
      st.empty = st.cdActive
    end
    return st
  end

  function CdInfo.GetActionState(action)
    action = tonumber(action) or 0
    if action <= 0 or not C_ActionBar then
      return CdInfo.Derive(nil, nil)
    end
    local cdInfo, chargeInfo
    if C_ActionBar.GetActionCooldown then
      local ok, info = pcall(C_ActionBar.GetActionCooldown, action)
      cdInfo = ok and info or nil
    end
    if C_ActionBar.GetActionCharges then
      local ok, info = pcall(C_ActionBar.GetActionCharges, action)
      chargeInfo = ok and info or nil
    end
    return CdInfo.Derive(cdInfo, chargeInfo)
  end
end

ChukieUiDB = ChukieUiDB or {}

local function copyDefaults(dest, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      dest[k] = dest[k] or {}
      copyDefaults(dest[k], v)
    elseif dest[k] == nil then
      dest[k] = v
    end
  end
end

function ns.CopyDefaultsIntoProfile(dest)
  copyDefaults(dest, defaults)
end

local function applyCvars()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or not p.enabled then
    return
  end
  local cvars = p.cvars
  if not cvars then
    return
  end
  for name, value in pairs(cvars) do
    if GetCVar(name) ~= nil then
      SetCVar(name, tostring(value))
    end
  end
end

function ns.OnProfileChanged()
  applyCvars()
  if ns.PanelCore and ns.PanelCore.RefreshRootBounds then
    ns.PanelCore:RefreshRootBounds()
  end
  if ns.RightPanel and ns.RightPanel.Apply then
    ns.RightPanel:Apply()
  end
  if ns.MinimapBar and ns.MinimapBar.Refresh then
    ns.MinimapBar:Refresh()
  end
  if ns.RightPanelWidgets and ns.RightPanelWidgets.Refresh then
    ns.RightPanelWidgets:Refresh()
  end
  if ns.CombatLog and ns.CombatLog.RefreshConfig then
    ns.CombatLog:RefreshConfig()
  end
  if ns.LeftPanel and ns.LeftPanel.Refresh then
    ns.LeftPanel:Refresh()
  end
  if ns.ActionBars and ns.ActionBars.Refresh then
    ns.ActionBars:Refresh()
  end
  if ns.HorizontalCompass and ns.HorizontalCompass.Refresh then
    ns.HorizontalCompass:Refresh()
  end
  if ns.Alerts and ns.Alerts.OnProfileChanged then
    ns.Alerts:OnProfileChanged()
  end
  if ns.AuraPanel and ns.AuraPanel.Refresh then
    ns.AuraPanel:Refresh()
  end
  if ns.PartyGrid and ns.PartyGrid.Refresh then
    ns.PartyGrid:Refresh()
  end
end

function ns.ApplyUiTweaks()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or not p.enabled then
    return
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon == ADDON_NAME then
    if ns.Profile and ns.Profile.Initialize then
      ns.Profile:Initialize()
    end
    if ns.RegisterConfigPanel then
      ns.RegisterConfigPanel()
    end
    if ns.PanelCore and ns.PanelCore.RefreshRootBounds then
      ns.PanelCore:RefreshRootBounds()
    end
    C_Timer.After(0, function()
      if ns.RightPanel and ns.RightPanel.Initialize then
        ns.RightPanel:Initialize()
      end
      if ns.LeftPanel and ns.LeftPanel.Initialize then
        ns.LeftPanel:Initialize()
      end
      if ns.ActionBars and ns.ActionBars.Refresh then
        ns.ActionBars:Refresh()
      end
    end)
    return
  end
  if event == "PLAYER_LOGIN" then
    applyCvars()
    if ns.Alerts and ns.Alerts.Refresh then
      ns.Alerts:Refresh()
    end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    ns.ApplyUiTweaks()
    if ns.ActionBars and ns.ActionBars.Refresh then
      ns.ActionBars:Refresh()
    end
    if ns.Alerts and ns.Alerts.Refresh then
      ns.Alerts:Refresh()
    end
  end
end)

SLASH_CHUKIEUI1 = "/chukieui"
SLASH_CHUKIEUI2 = "/chu"
SlashCmdList["CHUKIEUI"] = function(msg)
  local raw = strtrim(msg or "")
  local msg = strlower(raw)
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if msg == "" or msg == "config" or msg == "opciones" then
    if ns.OpenConfigPanel and ns.OpenConfigPanel() then
      return
    end
    print("|cffff9900Chukie UI|r: no se pudo abrir el panel de opciones.")
    return
  end
  if msg == "minimapa" or msg == "minimap" or msg == "panel" or msg == "panelderecho" then
    if ns.OpenMinimapConfigPanel and ns.OpenMinimapConfigPanel() then
      return
    end
    print("|cffff9900Chukie UI|r: apartado Panel derecho no disponible.")
    return
  end
  do
    local id = raw:match("^[Aa][Uu][Rr][Aa][Cc][Hh][Ee][Cc][Kk]%s+(%d+)")
      or raw:match("^[Aa][Uu][Rr][Aa]%s+(%d+)")
    if id and ns.Alerts and ns.Alerts.DebugAuraCheck then
      ns.Alerts:DebugAuraCheck(tonumber(id), "player")
      return
    end
    if msg == "auracheck" or msg == "aura" then
      print("|cffff9900Chukie UI|r: uso — /chukieui auracheck 436336")
      return
    end
  end
  if msg == "aurapanel" or msg == "panelauras" or msg == "auras" then
    if ns.AuraPanel and ns.AuraPanel.ToggleConfig then
      ns.AuraPanel:ToggleConfig()
    else
      print("|cffff9900Chukie UI|r: módulo Panel de auras no disponible.")
    end
    return
  end
  if msg == "party" or msg == "grilla" or msg == "partygrid" or strmatch(msg, "^party%s") then
    if not (ns.PartyGrid and ns.PartyGrid.ToggleConfig) then
      print("|cffff9900Chukie UI|r: módulo Grilla de party no disponible.")
      return
    end
    local what = strtrim(strsub(msg, 6))
    --- Interruptor sin abrir la ventana: útil para descartar el módulo tras un problema.
    if what == "on" then
      if ns.PartyGrid:SetEnabled(true) then
        print("|cff00ff00Chukie UI|r: grilla de party ON.")
      end
    elseif what == "off" then
      if ns.PartyGrid:SetEnabled(false) then
        print("|cff00ff00Chukie UI|r: grilla de party OFF.")
      end
    elseif what == "diag" then
      if ns.PartyGrid.PrintDiagnostics then
        ns.PartyGrid:PrintDiagnostics()
      end
    elseif not (ns.OpenFramesConfigPanel and ns.OpenFramesConfigPanel()) then
      --- Las opciones viven en el menú del addon (Marcos → Party); la ventana propia
      --- queda como respaldo y para arrastrar la grilla (/chukie-party).
      ns.PartyGrid:ToggleConfig()
    end
    return
  end
  if msg == "fix" or msg == "arreglar" then
    if not (ns.RightPanel and ns.RightPanel.Apply) then
      print("|cffff9900Chukie UI|r: panel derecho no disponible.")
    elseif InCombatLockdown and InCombatLockdown() then
      ns.RightPanel:RequestApplyAfterCombat()
      print("|cffff9900Chukie UI|r: en combate; el panel se rearma al terminar la pelea.")
    else
      ns.RightPanel:Apply()
      print("|cff00ff00Chukie UI|r: panel derecho rearmado.")
    end
    return
  end
  if msg == "diagbotones" or msg == "diag botones" then
    if ns.RightPanel and ns.RightPanel.PrintButtonDiagnostics then
      ns.RightPanel:PrintButtonDiagnostics()
    else
      print("|cffff9900Chukie UI|r: diagnóstico no disponible.")
    end
    return
  end
  if msg == "diag" or msg == "diagnostico" or msg == "diagnóstico" then
    if ns.RightPanel and ns.RightPanel.PrintDiagnostics then
      ns.RightPanel:PrintDiagnostics()
    else
      print("|cffff9900Chukie UI|r: diagnóstico no disponible.")
    end
    return
  end
  if msg == "auracontainer" or msg == "contenedor" then
    if ns.Alerts and ns.Alerts.DebugAuraContainers then
      ns.Alerts:DebugAuraContainers()
    else
      print("|cffff9900Chukie UI|r: módulo Alertas no disponible.")
    end
    return
  end
  do
    local id = raw:match("^[Cc][Dd][Cc][Hh][Ee][Cc][Kk]%s+(%d+)")
    if id and ns.Alerts and ns.Alerts.DebugCdCheck then
      ns.Alerts:DebugCdCheck(tonumber(id))
      return
    end
    if msg == "cdcheck" then
      print("|cffff9900Chukie UI|r: uso — /chukieui cdcheck 410089")
      return
    end
  end
  if msg == "alertas on" or msg == "alerts on" then
    if ns.Alerts and ns.Alerts.SetEnabled then
      ns.Alerts:SetEnabled(true)
      print("|cff00ff00Chukie UI|r: módulo Alertas ON.")
    end
    return
  end
  if msg == "alertas off" or msg == "alerts off" then
    if ns.Alerts and ns.Alerts.SetEnabled then
      ns.Alerts:SetEnabled(false)
      print("|cff00ff00Chukie UI|r: módulo Alertas OFF.")
    end
    return
  end
  if msg == "acciones" or strmatch(msg, "^acciones%s") then
    local abl = ns.ActionBarLayouts
    if not abl then
      print("|cffff9900Chukie UI|r: módulo de guardado de acciones no disponible.")
      return
    end
    local what = strtrim(strsub(msg, 9))
    if what == "guardar" then
      abl:SaveNow()
    elseif what == "restaurar" then
      abl:RestoreNow()
    elseif what == "borrar" then
      abl:ClearSaved()
    else
      print("|cff00ff00Chukie UI|r: barras 1–4 — " .. abl:GetStatusText())
      print("  Uso: /chukieui acciones guardar | restaurar | borrar")
    end
    return
  end
  if msg == "barras" or msg == "barras diag" then
    if ns.ActionBars and ns.ActionBars.PrintDiagnostics then
      ns.ActionBars:PrintDiagnostics()
    else
      print("|cffff9900Chukie UI|r: módulo de barras no disponible.")
    end
    return
  end
  if msg == "botones" then
    if ns.OpenMinimapButtonsPanel and ns.OpenMinimapButtonsPanel() then
      return
    end
    print("|cffff9900Chukie UI|r: apartado Botones no disponible.")
    return
  end
  if msg == "mmpos" or strmatch(msg, "^mmpos%s") then
    local rest = strtrim(strsub(msg, 6))
    if rest ~= "" and ns.RightPanel and ns.RightPanel.SetOffsets then
      local sx, sy = rest:match("^(-?%d+)%s+(-?%d+)$")
      if sx and sy then
        ns.RightPanel:SetOffsets(tonumber(sx), tonumber(sy))
        local db = ns.RightPanel:DB()
        print(
          string.format(
            "|cff00ff00Chukie UI|r: panel derecho → X=%d Y=%d (ancla esquina inferior derecha)",
            db.offsetX or 0,
            db.offsetY or 0
          )
        )
        return
      end
    end
    if rest == "" and ns.RightPanel and ns.RightPanel.DB then
      local db = ns.RightPanel:DB()
      print(
        string.format(
          "|cff00ff00Chukie UI|r: panel derecho actual → X=%d Y=%d. Uso: /chukieui mmpos <x> <y>",
          db.offsetX or 0,
          db.offsetY or 0
        )
      )
      return
    end
    print("|cffff9900Chukie UI|r: uso — /chukieui mmpos <x> <y>  (números enteros, p. ej. mmpos 120 -40)")
    return
  end
  do
    local head, tail = strmatch(raw, "^(%S+)%s*(.*)$")
    if head and strlower(head) == "mmarrow" then
      local tl = strtrim(tail)
      local first = strlower(strmatch(tl, "^(%S+)") or "")
      local pathRest = strtrim(strmatch(tl, "^%S+%s+(.+)$") or "")
      local db = ns.RightPanel and ns.RightPanel.DB and ns.RightPanel:DB()
      if not db then
        return
      end
      if tl == "" or first == "help" or first == "?" then
        print(
          "|cff00ff00Chukie UI|r mmarrow — default | thin | custom <ruta> | reset  (la ruta conserva mayúsculas; usa \\ o \\\\ según copies desde el juego)"
        )
        return
      end
      if first == "thin" or first == "fina" then
        db.playerArrowMode = 1
        ns.RightPanel:Apply()
        print("|cff00ff00Chukie UI|r: flecha del minimapa → fina (textura vehículo Blizzard).")
        return
      end
      if first == "default" or first == "defecto" or first == "reset" then
        db.playerArrowMode = 0
        db.playerArrowCustom = ""
        ns.RightPanel:Apply()
        print("|cff00ff00Chukie UI|r: flecha del minimapa → defecto Blizzard.")
        return
      end
      if first == "custom" and pathRest ~= "" then
        db.playerArrowMode = 2
        db.playerArrowCustom = pathRest
        ns.RightPanel:Apply()
        print("|cff00ff00Chukie UI|r: flecha → personalizada: " .. pathRest)
        return
      end
      if tl ~= "" and (tl:find("\\", 1, true) or strmatch(tl, "^[Ii]nterface")) then
        db.playerArrowMode = 2
        db.playerArrowCustom = tl
        ns.RightPanel:Apply()
        print("|cff00ff00Chukie UI|r: flecha → personalizada: " .. tl)
        return
      end
      print("|cffff9900Chukie UI|r: mmarrow — default | thin | custom <ruta> | reset")
      return
    end
  end
  print("|cff00ff00Chukie UI|r — /chukieui config | panel | minimapa | botones | acciones | mmpos <x> <y> | mmarrow …")
  print(
    "|cff00ff00Chukie UI|r — alertas: /chukie-aura | /chukieui alertas on | /chukieui auracheck <id> | /chukieui cdcheck <id> | /chukieui auracontainer"
  )
  print("|cff00ff00Chukie UI|r — panel de auras: /chukie-auras (o /chukieui aurapanel)")
  print("|cff00ff00Chukie UI|r — grilla de party clickeable: /chukieui party (menú: Marcos) | /chukie-party (ventana) | /chukieui party on | off | diag")
  print("|cff00ff00Chukie UI|r — panel derecho: /chukieui diag | /chukieui diagbotones | /chukieui fix")
  print("|cff00ff00Chukie UI|r — barras de acción: /chukieui barras (situación, paginado y quién muestra la barra del evento)")
  print("|cff00ff00Chukie UI|r — Combat Log: Esc → AddOns → Chukie UI → Panel izquierdo")
  if p then
    print("  Perfil: " .. tostring(ns.Profile:GetCurrentName()) .. " — " .. (p.enabled and "activado" or "desactivado"))
  end
  if ns.Alerts then
    local backend = ns.Alerts.GetAuraDisplayBackend and ns.Alerts:GetAuraDisplayBackend() or "legacy"
    print("  Alertas módulo: " .. (ns.Alerts:IsEnabled() and "ON" or "OFF") .. " | auras: " .. backend)
  end
end

-- Alias de alertas (también registrado en AlertsManager; aquí junto al help de /chukieui).
SLASH_CHUKIEAURA1 = "/chukie-aura"
SLASH_CHUKIEAURA2 = "/chukieaura"
SlashCmdList["CHUKIEAURA"] = function()
  if ns.AlertsManager and ns.AlertsManager.Show then
    ns.AlertsManager:Show()
  else
    print("|cffff9900Chukie UI|r: gestor de alertas no disponible.")
  end
end

SLASH_CHUKIEAURAPANEL1 = "/chukie-auras"
SLASH_CHUKIEAURAPANEL2 = "/chukieauras"
SlashCmdList["CHUKIEAURAPANEL"] = function()
  if ns.AuraPanel and ns.AuraPanel.ToggleConfig then
    ns.AuraPanel:ToggleConfig()
  else
    print("|cffff9900Chukie UI|r: panel de auras no disponible.")
  end
end

SLASH_CHUKIEPARTYGRID1 = "/chukie-party"
SLASH_CHUKIEPARTYGRID2 = "/chukieparty"
SlashCmdList["CHUKIEPARTYGRID"] = function()
  if ns.PartyGrid and ns.PartyGrid.ToggleConfig then
    ns.PartyGrid:ToggleConfig()
  else
    print("|cffff9900Chukie UI|r: grilla de party no disponible.")
  end
end
