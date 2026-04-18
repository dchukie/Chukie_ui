--[[ Chukie UI — núcleo del addon. Aquí se fusionan opciones por defecto,
     se aplican CVars y puedes ir añadiendo hooks a marcos de la UI.
     Documentación / cliente objetivo: Retail 12.0.1 (Interface 120001 en Chukie_Ui.toc). ]]

local ADDON_NAME, ns = ...

local defaults = {
  enabled = true,
  minimapBar = {
    enabled = true,
    --- Segunda fila bajo la barra de addons: micromenú Blizzard configurable.
    minimenuBarEnabled = true,
    --- Escala extra de los botones del micromenú (%) respecto al ajuste automático a la fila.
    minimenuButtonScalePercent = 100,
    --- Espacio horizontal extra entre botones del micromenú (px; puede ser negativo para apretar).
    minimenuSpacing = 2,
    --- Por botón: false = oculto; nil/true = visible (tabla dispersa).
    minimenuVisibility = {},
    stripBlizzardMinimap = true,
    cellSize = 34,
    pad = 4,
    lockLdb = true,
    useMasque = true,
    buttonPolicy = {},
    discoveredOrder = {},
  },
  minimapPosition = {
    offsetX = 0,
    offsetY = 0,
    locked = false,
    --- CVar rotateMinimap: mapa gira con el PJ, flecha fija hacia arriba.
    rotateMinimap = false,
    --- 0 = textura Blizzard por defecto; 1 = flecha fina (vehículo); 2 = playerArrowCustom.
    playerArrowMode = 0,
    playerArrowCustom = "",
    --- Escala visual de todo el MinimapCluster (70–150 %).
    minimapScalePercent = 100,
    --- 0 = no forzar; 1 = zoom mínimo (máximo alejado); 2 = zoom máximo permitido (máximo acercado). Límite fijo del cliente.
    minimapZoomPreference = 0,
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
  if ns.MinimapPosition and ns.MinimapPosition.Apply then
    ns.MinimapPosition:Apply()
  end
  if ns.MinimapBar and ns.MinimapBar.Refresh then
    ns.MinimapBar:Refresh()
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
    C_Timer.After(0, function()
      if ns.MinimapPosition and ns.MinimapPosition.Initialize then
        ns.MinimapPosition:Initialize()
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
    if rest ~= "" and ns.MinimapPosition and ns.MinimapPosition.SetOffsets then
      local sx, sy = rest:match("^(-?%d+)%s+(-?%d+)$")
      if sx and sy then
        ns.MinimapPosition:SetOffsets(tonumber(sx), tonumber(sy))
        local db = ns.MinimapPosition:DB()
        print(
          string.format(
            "|cff00ff00Chukie UI|r: panel derecho → X=%d Y=%d (ancla esquina inferior derecha)%s",
            db.offsetX or 0,
            db.offsetY or 0,
            (db.locked == true) and " [Lock]" or ""
          )
        )
        return
      end
    end
    if rest == "" and ns.MinimapPosition and ns.MinimapPosition.DB then
      local db = ns.MinimapPosition:DB()
      print(
        string.format(
          "|cff00ff00Chukie UI|r: panel derecho actual → X=%d Y=%d%s. Uso: /chukieui mmpos <x> <y>",
          db.offsetX or 0,
          db.offsetY or 0,
          (db.locked == true) and " [Lock]" or ""
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
      local db = ns.MinimapPosition and ns.MinimapPosition.DB and ns.MinimapPosition:DB()
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
        ns.MinimapPosition:Apply()
        print("|cff00ff00Chukie UI|r: flecha del minimapa → fina (textura vehículo Blizzard).")
        return
      end
      if first == "default" or first == "defecto" or first == "reset" then
        db.playerArrowMode = 0
        db.playerArrowCustom = ""
        ns.MinimapPosition:Apply()
        print("|cff00ff00Chukie UI|r: flecha del minimapa → defecto Blizzard.")
        return
      end
      if first == "custom" and pathRest ~= "" then
        db.playerArrowMode = 2
        db.playerArrowCustom = pathRest
        ns.MinimapPosition:Apply()
        print("|cff00ff00Chukie UI|r: flecha → personalizada: " .. pathRest)
        return
      end
      if tl ~= "" and (tl:find("\\", 1, true) or strmatch(tl, "^[Ii]nterface")) then
        db.playerArrowMode = 2
        db.playerArrowCustom = tl
        ns.MinimapPosition:Apply()
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
