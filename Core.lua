--[[ Chukie UI — núcleo del addon. Aquí se fusionan opciones por defecto,
     se aplican CVars y puedes ir añadiendo hooks a marcos de la UI.
     Documentación / cliente objetivo: Retail 12.0.1 (Interface 120001 en Chukie_Ui.toc). ]]

local ADDON_NAME, ns = ...

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
    },
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
  },
  cvars = {
    lootUnderMouse = "1",
  },
}

ns.defaults = defaults

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
    end)
    return
  end
  if event == "PLAYER_LOGIN" then
    applyCvars()
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    ns.ApplyUiTweaks()
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
  print("|cff00ff00Chukie UI|r — /chukieui config | panel | minimapa | botones | mmpos <x> <y> | mmarrow …")
  if p then
    print("  Perfil: " .. tostring(ns.Profile:GetCurrentName()) .. " — " .. (p.enabled and "activado" or "desactivado"))
  end
end
