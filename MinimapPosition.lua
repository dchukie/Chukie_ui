--[[ Panel derecho: MinimapCluster anclado a BOTTOMRIGHT de UIParent (offsets desde esa esquina).
     La posición se ajusta con los deslizadores de opciones o /chukieui mmpos (sin arrastre con ratón). ]]

local ADDON_NAME, ns = ...

local MP = {}
ns.MinimapPosition = MP

--- Textura por defecto del jugador en el minimapa (Blizzard).
local PLAYER_ARROW_DEFAULT = "Interface\\Minimap\\MinimapArrow"
--- Flecha fina del propio addon (recorte de la hoja en Media/); alternativa Blizzard: Vehicle-SilvershardMines-Arrow.
local PLAYER_ARROW_THIN = "Interface\\AddOns\\Chukie_Ui\\Media\\ChukieUi_PlayerArrow_Thin128.png"

function MP:DB()
  local p = ns.Profile:GetActive()
  p.minimapPosition = p.minimapPosition or {}
  return p.minimapPosition
end

function MP:ClampOffsets(ox, oy)
  --- X negativo = hacia la izquierda desde la esquina derecha; Y positivo = hacia arriba desde el borde inferior.
  ox = math.max(-1200, math.min(120, math.floor((ox or 0) + 0.5)))
  oy = math.max(-120, math.min(900, math.floor((oy or 0) + 0.5)))
  return ox, oy
end

function MP:ApplyPlayerArrow()
  if not Minimap or not Minimap.SetPlayerTexture then
    return
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or p.enabled == false then
    pcall(Minimap.SetPlayerTexture, Minimap, PLAYER_ARROW_DEFAULT)
    return
  end
  local db = self:DB()
  local mode = tonumber(db.playerArrowMode) or 0
  local path = PLAYER_ARROW_DEFAULT
  if mode == 1 then
    path = PLAYER_ARROW_THIN
  elseif mode == 2 then
    local custom = strtrim(tostring(db.playerArrowCustom or ""))
    if custom ~= "" then
      path = custom
    end
  end
  pcall(Minimap.SetPlayerTexture, Minimap, path)
end

function MP:ApplyClusterScale()
  if not MinimapCluster then
    return
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or p.enabled == false then
    MinimapCluster:SetScale(1)
    return
  end
  local pct = tonumber(self:DB().minimapScalePercent) or 100
  pct = math.max(20, math.min(300, math.floor(pct + 0.5)))
  self:DB().minimapScalePercent = pct
  MinimapCluster:SetScale(pct / 100)
end

--- Solo índices permitidos por el motor (GetZoomLevels); no hay «más zoom» extra vía API.
function MP:ApplyPreferredZoom()
  if not Minimap or not Minimap.SetZoom or not Minimap.GetZoomLevels then
    return
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or p.enabled == false then
    return
  end
  local pref = tonumber(self:DB().minimapZoomPreference) or 0
  if pref == 0 then
    return
  end
  local levels = Minimap:GetZoomLevels()
  if not levels or levels < 1 then
    return
  end
  local maxIdx = levels - 1
  if pref == 1 then
    pcall(Minimap.SetZoom, Minimap, 0)
  elseif pref == 2 then
    pcall(Minimap.SetZoom, Minimap, maxIdx)
  end
end

function MP:ApplyRotateMinimapCvar()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or p.enabled == false then
    return
  end
  local db = self:DB()
  local on = db.rotateMinimap == true
  local v = on and "1" or "0"
  if C_CVar and C_CVar.SetCVar then
    C_CVar.SetCVar("rotateMinimap", v)
  elseif GetCVar and GetCVar("rotateMinimap") ~= nil then
    SetCVar("rotateMinimap", v)
  end
end

function MP:Apply()
  self:ApplyRotateMinimapCvar()
  self:ApplyPlayerArrow()
  if MinimapCluster and UIParent then
    local db = self:DB()
    if not db._brPanelAnchorMigrated then
      db._brPanelAnchorMigrated = true
      if (db.offsetX or 0) == 0 and (db.offsetY or 0) == 0 then
        db.offsetX = -28
        db.offsetY = 200
      end
    end
    local ox, oy = self:ClampOffsets(db.offsetX or 0, db.offsetY or 0)
    db.offsetX, db.offsetY = ox, oy
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", ox, oy)
    MinimapCluster:SetClampedToScreen(true)
    MinimapCluster:SetMovable(false)
  end
  if MinimapCluster then
    self:ApplyClusterScale()
  end
  self:ApplyPreferredZoom()
  if ns.MinimapBar and ns.MinimapBar.ApplyBlizzardStripOrRestore then
    ns.MinimapBar:ApplyBlizzardStripOrRestore()
  end
end

function MP:SetOffsets(ox, oy)
  local db = self:DB()
  db.offsetX, db.offsetY = self:ClampOffsets(ox, oy)
  self:Apply()
  if ns.MinimapBar and ns.MinimapBar.Refresh then
    ns.MinimapBar:Refresh()
  end
end

function MP:DestroyLegacyDragStrip()
  local f = _G.ChukieUi_MinimapDragStrip
  if not f then
    return
  end
  f:SetScript("OnDragStart", nil)
  f:SetScript("OnDragStop", nil)
  f:SetScript("OnEnter", nil)
  f:SetScript("OnLeave", nil)
  if f.RegisterForDrag then
    f:RegisterForDrag()
  end
  f:EnableMouse(false)
  f:Hide()
  f:SetParent(nil)
end

function MP:Initialize()
  if not MinimapCluster then
    return
  end
  self:DestroyLegacyDragStrip()
  self:Apply()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("MINIMAP_UPDATE_ZOOM")
ev:SetScript("OnEvent", function(_, event)
  if event == "MINIMAP_UPDATE_ZOOM" then
    if ns.MinimapPosition and ns.MinimapPosition.ApplyPreferredZoom then
      C_Timer.After(0, function()
        if ns.MinimapPosition and ns.MinimapPosition.ApplyPreferredZoom then
          ns.MinimapPosition:ApplyPreferredZoom()
        end
      end)
    end
    return
  end
  if ns.MinimapPosition and ns.MinimapPosition.Apply then
    ns.MinimapPosition:Apply()
  end
end)
