--[[ Brújula horizontal encima del minimapa (panel derecho).
     Cinta de rumbo que se desplaza; marcador central fijo = hacia dónde mirás.
     Marcadores opcionales (target / waypoint / grupo): si no hay dato o es secreto, se omiten. ]]

local _, ns = ...

local HC = {}
ns.HorizontalCompass = HC

local TWO_PI = math.pi * 2
local DEG = 180 / math.pi
local RAD = math.pi / 180

local CARDINALS = {
  { deg = 0, label = "N" },
  { deg = 45, label = "NE" },
  { deg = 90, label = "E" },
  { deg = 135, label = "SE" },
  { deg = 180, label = "S" },
  { deg = 225, label = "SO" },
  { deg = 270, label = "O" },
  { deg = 315, label = "NO" },
}

local TICK_STEP = 15
local MAX_GROUP_MARKERS = 8
local UPDATE_INTERVAL = 0.04
--- Offset Y respecto al centro vertical del minimapa: alcanza de encima del mapa a debajo.
local OFFSET_Y_LIMIT = 160
--- Separación al borde del minimapa cuando se calcula la posición «justo encima».
local ABOVE_MINIMAP_GAP = 4

local function isSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

local function clamp(n, lo, hi)
  n = tonumber(n)
  if not n then
    return lo
  end
  if n < lo then
    return lo
  end
  if n > hi then
    return hi
  end
  return n
end

local function normAngle(a)
  a = tonumber(a)
  if not a or isSecret(a) then
    return nil
  end
  while a < 0 do
    a = a + TWO_PI
  end
  while a >= TWO_PI do
    a = a - TWO_PI
  end
  return a
end

--- Diferencia angular más corta en [-π, π].
local function angleDelta(fromFacing, toBearing)
  local d = normAngle(toBearing) - normAngle(fromFacing)
  if not d then
    return nil
  end
  if d > math.pi then
    d = d - TWO_PI
  elseif d < -math.pi then
    d = d + TWO_PI
  end
  return d
end

function HC:DB()
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

function HC:IsEnabled()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or not p.enabled then
    return false
  end
  return self:DB().enabled ~= false
end

--- Altura reservada para el layout del minimapa (px).
function HC:GetReservedHeight()
  if not self:IsEnabled() then
    return 0
  end
  local db = self:DB()
  return clamp(db.height, 14, 48)
end

local function rotateMinimapOn()
  if ns.RightPanel and ns.RightPanel.DB then
    local ok, db = pcall(ns.RightPanel.DB, ns.RightPanel)
    if ok and type(db) == "table" and db.rotateMinimap == true then
      return true
    end
  end
  if GetCVar then
    local ok, v = pcall(GetCVar, "rotateMinimap")
    if ok and tostring(v) == "1" then
      return true
    end
  end
  return false
end

--- Fallback en instancias: TexCoord del anillo de brújula del minimapa (sigue girando aunque esté oculto).
local function facingFromCompassTexture()
  if not rotateMinimapOn() then
    return nil
  end
  local tex = _G.MinimapCompassTexture
  if not tex or not tex.GetTexCoord then
    return nil
  end
  local ok, fx, fy, bx, by = pcall(tex.GetTexCoord, tex)
  if not ok then
    return nil
  end
  fx, fy, bx, by = tonumber(fx), tonumber(fy), tonumber(bx), tonumber(by)
  if not fx or not fy or not bx or not by then
    return nil
  end
  if isSecret(fx) or isSecret(fy) or isSecret(bx) or isSecret(by) then
    return nil
  end
  local dx, dy = -(fx - bx), (by - fy)
  if dy == 0 then
    return dx < 0 and math.pi or 0
  end
  return normAngle(math.atan(dx / dy) + (dy < 0 and math.pi or 0))
end

function HC:GetFacing()
  if GetPlayerFacing then
    local ok, facing = pcall(GetPlayerFacing)
    if ok then
      facing = normAngle(facing)
      if facing then
        self._lastFacing = facing
        return facing, false
      end
    end
  end
  local fromTex = facingFromCompassTexture()
  if fromTex then
    self._lastFacing = fromTex
    return fromTex, false
  end
  if self._lastFacing then
    return self._lastFacing, true
  end
  return 0, true
end

local function mapPos(unit)
  if not unit or not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
    return nil
  end
  local okMap, mapId = pcall(C_Map.GetBestMapForUnit, unit)
  if not okMap or not mapId or isSecret(mapId) then
    return nil
  end
  local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapId, unit)
  if not okPos or not pos then
    return nil
  end
  local x, y
  if pos.GetXY then
    local okXY, px, py = pcall(pos.GetXY, pos)
    if okXY then
      x, y = px, py
    end
  else
    x, y = pos.x, pos.y
  end
  x, y = tonumber(x), tonumber(y)
  if not x or not y or isSecret(x) or isSecret(y) then
    return nil
  end
  return x, y, mapId
end

--- Rumbo hacia un punto del mapa (misma convención que GetPlayerFacing).
local function bearingToMapPoint(px, py, tx, ty)
  local dx = tx - px -- este +
  local dy = py - ty -- norte + (y del mapa crece al sur)
  if dx == 0 and dy == 0 then
    return nil
  end
  return normAngle(math.atan2(-dx, dy))
end

local function bearingToUnit(unit)
  if not UnitExists or not UnitExists(unit) then
    return nil
  end
  local px, py, mapId = mapPos("player")
  if not px then
    return nil
  end
  local tx, ty, tMap = mapPos(unit)
  if not tx or (tMap and mapId and tMap ~= mapId) then
    return nil
  end
  return bearingToMapPoint(px, py, tx, ty)
end

local function bearingToWaypoint()
  local px, py, mapId = mapPos("player")
  if not px or not mapId then
    return nil
  end

  --- Waypoint de usuario (tomtom-style / pin del mapa).
  if C_Map and C_Map.GetUserWaypoint then
    local okWp, wp = pcall(C_Map.GetUserWaypoint)
    if okWp and type(wp) == "table" then
      local wMap = wp.uiMapID or wp.mapID
      local pos = wp.position
      local x, y
      if pos then
        if pos.GetXY then
          local okXY, gx, gy = pcall(pos.GetXY, pos)
          if okXY then
            x, y = gx, gy
          end
        else
          x, y = pos.x, pos.y
        end
      end
      x, y = tonumber(x), tonumber(y)
      if wMap == mapId and x and y and not isSecret(x) and not isSecret(y) then
        return bearingToMapPoint(px, py, x, y)
      end
    end
  end

  --- Quest super-trackeada → siguiente waypoint en el mapa actual.
  local questId
  if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
    local okQ, qid = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    if okQ then
      questId = tonumber(qid)
    end
  end
  if questId and questId > 0 and C_QuestLog and C_QuestLog.GetNextWaypoint then
    local okN, wpMap, x, y = pcall(C_QuestLog.GetNextWaypoint, questId)
    if okN then
      x, y = tonumber(x), tonumber(y)
      if (not wpMap or wpMap == mapId) and x and y and not isSecret(x) and not isSecret(y) then
        return bearingToMapPoint(px, py, x, y)
      end
    end
  end

  --- Algunos builds exponen GetNextWaypointForMap (puede no existir en 12.1).
  if C_SuperTrack and C_SuperTrack.GetNextWaypointForMap then
    local okM, x, y = pcall(C_SuperTrack.GetNextWaypointForMap, mapId)
    if okM then
      x, y = tonumber(x), tonumber(y)
      if x and y and not isSecret(x) and not isSecret(y) then
        return bearingToMapPoint(px, py, x, y)
      end
    end
  end

  return nil
end

local function ensureLabel(parent, name, layer)
  local fs = parent[name]
  if fs then
    return fs
  end
  fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontNormalSmall")
  fs:SetJustifyH("CENTER")
  fs:Hide()
  parent[name] = fs
  return fs
end

local function ensureTex(parent, name, layer)
  local t = parent[name]
  if t then
    return t
  end
  t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:Hide()
  parent[name] = t
  return t
end

function HC:Ensure()
  if self._host then
    return self._host
  end
  local host = CreateFrame("Frame", "ChukieUi_HorizontalCompass", UIParent)
  host:SetFrameStrata("MEDIUM")
  host:SetFrameLevel(60)
  host:EnableMouse(false)
  host:Hide()

  local clip = CreateFrame("Frame", nil, host)
  clip:SetAllPoints(host)
  clip:EnableMouse(false)
  host._clip = clip

  local line = host:CreateTexture(nil, "BACKGROUND")
  line:SetColorTexture(1, 1, 1, 0.12)
  line:SetPoint("LEFT", host, "LEFT", 0, 0)
  line:SetPoint("RIGHT", host, "RIGHT", 0, 0)
  line:SetHeight(1)
  host._baseLine = line

  local center = host:CreateTexture(nil, "OVERLAY")
  center:SetColorTexture(1, 0.85, 0.2, 0.95)
  center:SetSize(2, 14)
  center:SetPoint("CENTER", host, "CENTER", 0, 0)
  host._centerMark = center

  local tip = host:CreateTexture(nil, "OVERLAY")
  tip:SetColorTexture(1, 0.85, 0.2, 0.95)
  tip:SetSize(8, 2)
  tip:SetPoint("BOTTOM", center, "TOP", 0, 0)
  host._centerTip = tip

  self._host = host
  self._cardinals = {}
  self._ticks = {}
  self._markers = {
    target = ensureTex(host, "_markTarget", "OVERLAY"),
    waypoint = ensureTex(host, "_markWaypoint", "OVERLAY"),
    group = {},
  }
  self._markers.target:SetColorTexture(1, 0.25, 0.2, 0.95)
  self._markers.target:SetSize(3, 10)
  self._markers.waypoint:SetColorTexture(0.35, 0.85, 1, 0.95)
  self._markers.waypoint:SetSize(3, 10)
  for i = 1, MAX_GROUP_MARKERS do
    local g = ensureTex(host, "_markGroup" .. i, "OVERLAY")
    g:SetColorTexture(0.4, 1, 0.45, 0.85)
    g:SetSize(2, 8)
    self._markers.group[i] = g
  end

  return host
end

local function getCenterSlot()
  if ns.RightPanel and ns.RightPanel.GetPanelTreeFrames then
    local left, center = ns.RightPanel:GetPanelTreeFrames()
    if center and center.GetWidth and (center:GetWidth() or 0) >= 2 then
      return center
    end
  end
  if ns.PanelCore and ns.PanelCore.GetSlotFrame then
    return ns.PanelCore:GetSlotFrame("rightPanel", "center")
  end
  return nil
end

local STRATA_ORDER = {
  "BACKGROUND",
  "LOW",
  "MEDIUM",
  "HIGH",
  "DIALOG",
}

local function strataIndex(frame)
  if not frame or not frame.GetFrameStrata then
    return 0
  end
  local s = frame:GetFrameStrata()
  for i = 1, #STRATA_ORDER do
    if STRATA_ORDER[i] == s then
      return i
    end
  end
  return 0
end

--[[ El minimapa vive en el mismo slot y se dibuja encima: al reparentar el host,
     el cliente recalcula su nivel respecto al nuevo padre y la cinta queda tapada.
     Se recoloca un plano por arriba del mapa (y del cluster, que trae bordes y
     botones propios) cada vez que se hace el layout. ]]
local function raiseAboveMinimap(host)
  local map, cluster = _G.Minimap, _G.MinimapCluster
  -- Sin contar el propio host: si no, subiría un plano en cada layout.
  local idx = math.max(strataIndex(map), strataIndex(cluster), 2)
  local strata = STRATA_ORDER[math.min(idx + 1, #STRATA_ORDER)] or "HIGH"
  local level = 0
  if map and map.GetFrameLevel then
    level = math.max(level, tonumber(map:GetFrameLevel()) or 0)
  end
  if cluster and cluster.GetFrameLevel then
    level = math.max(level, tonumber(cluster:GetFrameLevel()) or 0)
  end
  host:SetFrameStrata(strata)
  host:SetFrameLevel(level + 20)
end

function HC:Layout()
  local host = self:Ensure()
  if not self:IsEnabled() then
    host:Hide()
    host:SetScript("OnUpdate", nil)
    return
  end

  local center = getCenterSlot()
  if not center then
    host:Hide()
    host:SetScript("OnUpdate", nil)
    return
  end

  local db = self:DB()
  local h = clamp(db.height, 14, 48)
  local fontSize = clamp(db.fontSize, 8, 24)

  --- Referencia vertical: centro del minimapa (ya dimensionado por RightPanel antes de llamarnos).
  local anchor = _G.Minimap
  local anchorValid = anchor and anchor.GetHeight and (tonumber(anchor:GetHeight()) or 0) > 8
  if not anchorValid then
    anchor = center
  end

  --- Migración única: el ancla pasó del borde superior del slot al centro del minimapa.
  --- Se recalcula el offset guardado para que la brújula no salte de sitio al actualizar.
  if anchorValid and not db._minimapCenterAnchorApplied then
    db._minimapCenterAnchorApplied = true
    if (tonumber(db.offsetY) or 0) == 0 then
      local above = (anchor:GetHeight() * 0.5) + (h * 0.5) + ABOVE_MINIMAP_GAP
      db.offsetY = clamp(math.floor(above + 0.5), -OFFSET_Y_LIMIT, OFFSET_Y_LIMIT)
    end
  end
  local offY = clamp(tonumber(db.offsetY) or 0, -OFFSET_Y_LIMIT, OFFSET_Y_LIMIT)

  local width = math.max(40, math.floor((tonumber(center:GetWidth()) or 0) + 0.5))
  if host:GetParent() ~= center then
    host:SetParent(center)
  end
  host:ClearAllPoints()
  --- +Y sube (encima del mapa), −Y baja (hasta quedar debajo del minimapa).
  host:SetPoint("CENTER", anchor, "CENTER", 0, offY)
  host:SetSize(width, h)
  raiseAboveMinimap(host)
  host:Show()

  local path, _, flags = GameFontNormalSmall:GetFont()
  for i = 1, #CARDINALS do
    local fs = self._cardinals[i]
    if not fs then
      fs = ensureLabel(host, "_card" .. i, "OVERLAY")
      self._cardinals[i] = fs
    end
    fs:SetFont(path, fontSize, flags or "")
    fs:SetText(CARDINALS[i].label)
    fs:SetTextColor(0.92, 0.92, 0.95, 0.95)
  end

  local tickCount = math.floor(360 / TICK_STEP)
  for i = 1, tickCount do
    local t = self._ticks[i]
    if not t then
      t = ensureTex(host, "_tick" .. i, "ARTWORK")
      self._ticks[i] = t
    end
    local deg = (i - 1) * TICK_STEP
    local major = (deg % 45) == 0
    t:SetColorTexture(1, 1, 1, major and 0.35 or 0.18)
    t:SetSize(1, major and (h * 0.55) or (h * 0.3))
  end

  host._centerMark:SetHeight(math.max(8, h - 6))
  self._elapsed = 0
  host:SetScript("OnUpdate", function(_, elapsed)
    HC:OnUpdate(elapsed)
  end)
  self:Paint()
end

local function placeOnRibbon(host, widget, facing, bearing, fovRad, halfW)
  if not widget then
    return false
  end
  local d = angleDelta(facing, bearing)
  if not d then
    widget:Hide()
    return false
  end
  local halfFov = fovRad * 0.5
  if d < -halfFov or d > halfFov then
    widget:Hide()
    return false
  end
  local x = (d / halfFov) * halfW
  widget:ClearAllPoints()
  widget:SetPoint("CENTER", host, "CENTER", x, 0)
  widget:Show()
  return true
end

function HC:Paint()
  local host = self._host
  if not host or not host:IsShown() then
    return
  end
  local db = self:DB()
  local facing, frozen = self:GetFacing()
  if frozen and db.hideWhenNoFacing then
    host:SetAlpha(0)
    return
  end
  host:SetAlpha(1)

  local w = host:GetWidth() or 0
  if w < 4 then
    return
  end
  local halfW = w * 0.5
  local fovDeg = clamp(db.fovDegrees, 60, 180)
  local fovRad = fovDeg * RAD
  local showTicks = db.showDegreeTicks ~= false

  for i = 1, #CARDINALS do
    local c = CARDINALS[i]
    local fs = self._cardinals[i]
    if fs then
      placeOnRibbon(host, fs, facing, c.deg * RAD, fovRad, halfW)
    end
  end

  local tickCount = #self._ticks
  for i = 1, tickCount do
    local t = self._ticks[i]
    if t then
      if showTicks then
        local deg = (i - 1) * TICK_STEP
        if (deg % 45) ~= 0 then
          placeOnRibbon(host, t, facing, deg * RAD, fovRad, halfW)
        else
          t:Hide()
        end
      else
        t:Hide()
      end
    end
  end

  --- Marcadores opcionales.
  local mark = self._markers
  if db.showTarget ~= false then
    local b = bearingToUnit("target")
    if b then
      placeOnRibbon(host, mark.target, facing, b, fovRad, halfW)
    else
      mark.target:Hide()
    end
  else
    mark.target:Hide()
  end

  if db.showWaypoint ~= false then
    local b = bearingToWaypoint()
    if b then
      placeOnRibbon(host, mark.waypoint, facing, b, fovRad, halfW)
    else
      mark.waypoint:Hide()
    end
  else
    mark.waypoint:Hide()
  end

  local gi = 0
  if db.showGroup == true and IsInGroup and IsInGroup() then
    local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
    local n = prefix == "raid" and (GetNumGroupMembers and GetNumGroupMembers() or 0)
      or (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0)
    for i = 1, n do
      if gi >= MAX_GROUP_MARKERS then
        break
      end
      local unit = prefix .. i
      if UnitExists and UnitExists(unit) and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
        local b = bearingToUnit(unit)
        if b then
          gi = gi + 1
          placeOnRibbon(host, mark.group[gi], facing, b, fovRad, halfW)
        end
      end
    end
  end
  for i = gi + 1, MAX_GROUP_MARKERS do
    mark.group[i]:Hide()
  end
end

function HC:OnUpdate(elapsed)
  self._elapsed = (self._elapsed or 0) + (elapsed or 0)
  if self._elapsed < UPDATE_INTERVAL then
    return
  end
  self._elapsed = 0
  local ok = pcall(function()
    self:Paint()
  end)
  if not ok then
    -- Silencio: un fallo puntual de paint no debe romper el UI.
  end
end

function HC:Refresh()
  local ok = pcall(function()
    self:Layout()
  end)
  if not ok then
    if self._host then
      self._host:Hide()
      self._host:SetScript("OnUpdate", nil)
    end
  end
end

function HC:Hide()
  if self._host then
    self._host:Hide()
    self._host:SetScript("OnUpdate", nil)
  end
end
