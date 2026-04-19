--[[ Panel derecho del addon: marco global ChukieUi_RightPanel (panelWidth × panelHeight), BOTTOMRIGHT en UIParent + offsets.
     MinimapCluster es hijo del panel y SetAllPoints: mismo rectálogo que el marco Chukie (barras + minimapa dentro).
     Se reafirma si Blizzard intenta SetSize/SetWidth/SetHeight sobre el cluster. lockRightPanelInEditMode evita soltar el cluster a UIParent en modo edición Blizzard.
     Árbol de referencia (debug, solo líneas): (1) Cluster panel derecho = ChukieUi_RightPanel + MinimapCluster.
     (2) Bloque central verde = minimapa + barra addons + micromenú. (3) Bloque izq azul. (4) Bloque der amarillo. ]]

local ADDON_NAME, ns = ...

local MP = {}
ns.RightPanel = MP

--- Textura por defecto del jugador en el minimapa (Blizzard).
local PLAYER_ARROW_DEFAULT = "Interface\\Minimap\\MinimapArrow"
--- Flecha fina del propio addon (recorte de la hoja en Media/); alternativa Blizzard: Vehicle-SilvershardMines-Arrow.
local PLAYER_ARROW_THIN = "Interface\\AddOns\\Chukie_Ui\\Media\\ChukieUi_PlayerArrow_Thin128.png"

local DEBUG_OUTLINE_THICK = 2
--- Insets del recuadro verde (target = panel o cluster). Y negativo en TOPLEFT/BOTTOMRIGHT baja la esquina en pantalla.
--- Superior (tal cual); inferior: BR_Y muy negativo para pasar ~2 filas de micromenú bajo el cluster.
--- Izquierda sin tocar; BR_X solo a la derecha (positivo = más ancho). ~|TL_X| para mismo «aire» que a la izq.
local DEBUG_OUTLINE_TL_X = -10
local DEBUG_OUTLINE_TL_Y = -40
local DEBUG_OUTLINE_BR_X = 40
local DEBUG_OUTLINE_BR_Y = -108
--- Hueco entre el recuadro verde (mapa+micromenú) y las franjas laterales de referencia (⅓ del ancho del verde).
local DEBUG_RIGHTCLICK_STRIP_GAP = 2
--- Franja izquierda (azul): mitad de alto del verde, borde inferior alineado con el verde.
local DEBUG_RIGHTCLICK_STRIP_LEFT_HEIGHT_FRAC = 0.5
local RIGHT_PANEL_CORE_ID = "rightPanel"
--- Minimap en la zona superior del bloque central: casi al borde, dejando 2 ranuras abajo.
local MINIMAP_TOP_PAD = 9
local MINIMAP_SIDE_PAD = 24
local MINIMAP_BOTTOM_EXTRA_PAD = 12

local function isDebugBoundsEnabled(db)
  if not db then
    return false
  end
  local v = db.debugRightPanelBounds
  return v == true or v == 1
end

local function forceHideMinimapRingFrame(frame)
  if not frame then
    return
  end
  if frame.SetAlpha then
    frame:SetAlpha(0)
  end
  if frame.Hide then
    frame:Hide()
  end
  if frame._chukieForceHideHooked or not hooksecurefunc then
    return
  end
  frame._chukieForceHideHooked = true
  hooksecurefunc(frame, "Show", function(f)
    if f.SetAlpha then
      f:SetAlpha(0)
    end
    if f.Hide then
      f:Hide()
    end
  end)
  hooksecurefunc(frame, "SetShown", function(f, show)
    if show then
      if f.SetAlpha then
        f:SetAlpha(0)
      end
      if f.Hide then
        f:Hide()
      end
    end
  end)
end

local function listRegions(frame)
  local out = {}
  if not frame or not frame.GetNumRegions then
    return out
  end
  local n = frame:GetNumRegions() or 0
  for i = 1, n do
    local r = select(i, frame:GetRegions())
    if r then
      out[#out + 1] = r
    end
  end
  return out
end

local function isCompassOrRingTexture(texObj)
  if not texObj or not texObj.GetObjectType or texObj:GetObjectType() ~= "Texture" then
    return false
  end
  local name = texObj.GetName and texObj:GetName()
  if type(name) == "string" then
    local lowName = name:lower()
    if lowName:find("compass", 1, true) or lowName:find("northtag", 1, true) then
      return true
    end
  end
  local atlas = texObj.GetAtlas and texObj:GetAtlas()
  if type(atlas) == "string" then
    local lowAtlas = atlas:lower()
    if lowAtlas:find("compass", 1, true) or lowAtlas:find("minimap", 1, true) and lowAtlas:find("ring", 1, true) then
      return true
    end
  end
  local tex = texObj.GetTexture and texObj:GetTexture()
  if type(tex) == "string" then
    local lowTex = tex:lower()
    if lowTex:find("minimap", 1, true) and (lowTex:find("compass", 1, true) or lowTex:find("ring", 1, true) or lowTex:find("border", 1, true)) then
      return true
    end
  end
  return false
end

local function forceHideMinimapCompassAndRing()
  for _, f in ipairs({ MinimapBorder, MinimapCompassTexture, MinimapNorthTag }) do
    forceHideMinimapRingFrame(f)
  end
  for _, host in ipairs({ Minimap, MinimapCluster }) do
    for _, r in ipairs(listRegions(host)) do
      if isCompassOrRingTexture(r) then
        forceHideMinimapRingFrame(r)
      end
    end
  end
end

--- Un solo marco en UIParent; se estira entre las esquinas del panel o del cluster (coords correctas, sin mezclar absolutos con offsets).
local function createRightPanelDebugOverlay()
  local f = CreateFrame("Frame", "ChukieUi_RightPanelDebugOutline", UIParent)
  f:EnableMouse(false)
  f:SetMouseClickEnabled(false)
  f:SetFrameStrata("TOOLTIP")
  f:SetFixedFrameStrata(true)
  --- El motor solo acepta 0–65535; valores mayores disparan error en SetFrameLevel.
  f:SetFrameLevel(65535)
  local r, g, b, a = 0.12, 0.95, 0.22, 0.92
  local t = DEBUG_OUTLINE_THICK
  local fill = f:CreateTexture(nil, "BACKGROUND")
  fill:SetDrawLayer("BACKGROUND", 0)
  fill:SetAllPoints()
  fill:SetColorTexture(r, g, b, 0.14)
  local top = f:CreateTexture(nil, "OVERLAY")
  top:SetDrawLayer("OVERLAY", 7)
  top:SetColorTexture(r, g, b, a)
  top:SetHeight(t)
  top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  local bot = f:CreateTexture(nil, "OVERLAY")
  bot:SetDrawLayer("OVERLAY", 7)
  bot:SetColorTexture(r, g, b, a)
  bot:SetHeight(t)
  bot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  bot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  local left = f:CreateTexture(nil, "OVERLAY")
  left:SetDrawLayer("OVERLAY", 7)
  left:SetColorTexture(r, g, b, a)
  left:SetWidth(t)
  left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  local right = f:CreateTexture(nil, "OVERLAY")
  right:SetDrawLayer("OVERLAY", 7)
  right:SetColorTexture(r, g, b, a)
  right:SetWidth(t)
  right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  return f
end

--- Franjas de referencia (debug): borde en color (r,g,b,a); relleno semitransparente.
local function buildRightClickBarsStripFrame(globalName, frameLevel, r, g, b, a)
  local f = CreateFrame("Frame", globalName, UIParent)
  f:EnableMouse(false)
  f:SetMouseClickEnabled(false)
  f:SetFrameStrata("TOOLTIP")
  f:SetFixedFrameStrata(true)
  f:SetFrameLevel(frameLevel)
  local t = DEBUG_OUTLINE_THICK
  local fill = f:CreateTexture(nil, "BACKGROUND")
  fill:SetDrawLayer("BACKGROUND", 0)
  fill:SetAllPoints()
  fill:SetColorTexture(r, g, b, 0.12)
  local top = f:CreateTexture(nil, "OVERLAY")
  top:SetDrawLayer("OVERLAY", 7)
  top:SetColorTexture(r, g, b, a)
  top:SetHeight(t)
  top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  local bot = f:CreateTexture(nil, "OVERLAY")
  bot:SetDrawLayer("OVERLAY", 7)
  bot:SetColorTexture(r, g, b, a)
  bot:SetHeight(t)
  bot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  bot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  local left = f:CreateTexture(nil, "OVERLAY")
  left:SetDrawLayer("OVERLAY", 7)
  left:SetColorTexture(r, g, b, a)
  left:SetWidth(t)
  left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  local right = f:CreateTexture(nil, "OVERLAY")
  right:SetDrawLayer("OVERLAY", 7)
  right:SetColorTexture(r, g, b, a)
  right:SetWidth(t)
  right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  return f
end

function MP:DB()
  local d
  if ns.Profile and ns.Profile.GetRightPanelModel then
    d = ns.Profile:GetRightPanelModel()
  else
    local p = ns.Profile:GetActive()
    p.minimapPosition = p.minimapPosition or {}
    d = p.minimapPosition
  end
  if d.lockRightPanelInEditMode == nil and d.lockMinimapClusterInEditMode ~= nil then
    d.lockRightPanelInEditMode = d.lockMinimapClusterInEditMode
  end
  if d.panelScalePercent == nil and d.minimapScalePercent ~= nil then
    d.panelScalePercent = d.minimapScalePercent
  end
  return d
end

function MP:GetRightPanelSize()
  local db = self:DB()
  local pct = tonumber(db.panelScalePercent) or 100
  pct = math.max(60, math.min(220, math.floor(pct + 0.5)))
  db.panelScalePercent = pct
  local scale = pct / 100
  local w = tonumber(db.panelWidth)
  local h = tonumber(db.panelHeight)
  if not w or w < 160 then
    w = 300
  end
  if not h or h < 180 then
    h = 360
  end
  w = w * scale
  h = h * scale
  return math.floor(math.min(900, math.max(160, w + 0.5))), math.floor(math.min(1100, math.max(180, h + 0.5)))
end

function MP:SyncRightPanelTreeLayout()
  local host = self._rightPanelFrame
  local pc = ns.PanelCore
  if not host or not pc or not pc.LayoutSlotByInsets or not pc.LayoutSlotByAttach then
    return
  end
  local center = pc:LayoutSlotByInsets(
    RIGHT_PANEL_CORE_ID,
    "center",
    DEBUG_OUTLINE_TL_X,
    DEBUG_OUTLINE_TL_Y,
    DEBUG_OUTLINE_BR_X,
    DEBUG_OUTLINE_BR_Y
  )
  if not center then
    return
  end
  local cw = center:GetWidth()
  local ch = center:GetHeight()
  if not cw or not ch or cw < 2 or ch < 2 then
    return
  end
  local sw = math.max(2, math.floor(cw / 3 + 0.5))
  local leftH = math.max(2, math.floor(ch * DEBUG_RIGHTCLICK_STRIP_LEFT_HEIGHT_FRAC + 0.5))
  local left = pc:LayoutSlotByAttach(RIGHT_PANEL_CORE_ID, "left", {
    relativeTo = center,
    point = "BOTTOMRIGHT",
    relativePoint = "BOTTOMLEFT",
    x = -DEBUG_RIGHTCLICK_STRIP_GAP,
    y = 0,
    width = sw,
    height = leftH,
  })
  local right = pc:LayoutSlotByAttach(RIGHT_PANEL_CORE_ID, "right", {
    relativeTo = center,
    point = "TOPLEFT",
    relativePoint = "TOPRIGHT",
    x = DEBUG_RIGHTCLICK_STRIP_GAP,
    y = 0,
    width = sw,
    height = ch,
  })
  self._panelTreeCenter = center
  self._panelTreeLeft = left
  self._panelTreeRight = right
end

local function getBarsReservedHeight()
  local MB = ns.MinimapBar
  local addonH = 38
  local miniH = 30
  local gap = 8
  if MB then
    if MB.GetAddonBarIconHeight then
      addonH = math.max(12, (tonumber(MB:GetAddonBarIconHeight()) or 34) + 4)
    end
    if MB.GetMiniMenuBarHeight then
      miniH = math.max(12, tonumber(MB:GetMiniMenuBarHeight()) or 30)
    end
    if MB.GetMinimenuGapBelowAddonBar then
      gap = math.max(0, tonumber(MB:GetMinimenuGapBelowAddonBar()) or 8)
    end
  end
  return addonH + miniH + gap + MINIMAP_BOTTOM_EXTRA_PAD
end

function MP:EnforceMinimapInCenterTopArea()
  local host = self._rightPanelFrame
  if not host or not MinimapCluster or MinimapCluster:GetParent() ~= host or not Minimap then
    return
  end
  self:SyncRightPanelTreeLayout()
  local center = self._panelTreeCenter
  if not center then
    return
  end
  local cw = center:GetWidth()
  local ch = center:GetHeight()
  if not cw or not ch or cw < 2 or ch < 2 then
    return
  end
  local maxW = cw - (MINIMAP_SIDE_PAD * 2)
  local maxH = ch - MINIMAP_TOP_PAD - getBarsReservedHeight()
  local s = math.floor(math.min(maxW, maxH) + 0.5)
  if not s or s < 120 then
    return
  end
  Minimap:ClearAllPoints()
  Minimap:SetSize(s, s)
  Minimap:SetPoint("TOP", center, "TOP", 0, -MINIMAP_TOP_PAD)
  --- Ocultar anillo cardinal y borde circular del minimapa, sin depender de opciones.
  forceHideMinimapCompassAndRing()
  if ns.MinimapBar then
    if ns.MinimapBar.PositionAddonBarCentered then
      ns.MinimapBar:PositionAddonBarCentered()
    end
    if ns.MinimapBar.PositionMicromenuCentered then
      ns.MinimapBar:PositionMicromenuCentered()
    end
  end
end

--- MinimapCluster debe coincidir con el host; Blizzard a vece cambia el tamaño del cluster aparte del padre.
function MP:EnforceMinimapClusterFillRightPanel()
  local host = self._rightPanelFrame
  if not host or not MinimapCluster or MinimapCluster:GetParent() ~= host then
    return
  end
  self._clusterLayoutMutating = true
  MinimapCluster:ClearAllPoints()
  MinimapCluster:SetAllPoints(host)
  MinimapCluster:SetClampedToScreen(false)
  self._clusterLayoutMutating = false
end

function MP:UpdateDebugRightPanelOutline()
  local function hideDebugFrames()
    if self._debugOutline then
      self._debugOutline:Hide()
    end
    if self._rightClickBarsRef then
      self._rightClickBarsRef:Hide()
    end
    if self._rightClickBarsRefRight then
      self._rightClickBarsRefRight:Hide()
    end
  end

  local on = isDebugBoundsEnabled(self:DB())
  if not on then
    hideDebugFrames()
    return
  end
  local host = self._rightPanelFrame
  local cluster = MinimapCluster
  self:SyncRightPanelTreeLayout()
  local centerSlot = self._panelTreeCenter
  local leftSlot = self._panelTreeLeft
  local rightSlot = self._panelTreeRight
  local target = nil
  if centerSlot and centerSlot:GetWidth() and centerSlot:GetHeight() and centerSlot:GetWidth() >= 2 and centerSlot:GetHeight() >= 2 then
    target = centerSlot
  elseif host and cluster and cluster:GetParent() == host then
    target = host
  elseif cluster and cluster:IsShown() and (cluster:GetWidth() or 0) >= 2 and (cluster:GetHeight() or 0) >= 2 then
    target = cluster
  elseif host then
    target = host
  end
  if not target then
    hideDebugFrames()
    return
  end
  local f = self._debugOutline
  if not f then
    f = createRightPanelDebugOverlay()
    self._debugOutline = f
  end
  if f:GetParent() ~= UIParent then
    f:SetParent(UIParent)
  end
  f:ClearAllPoints()
  if target == centerSlot then
    f:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    f:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
  else
    f:SetPoint("TOPLEFT", target, "TOPLEFT", DEBUG_OUTLINE_TL_X, DEBUG_OUTLINE_TL_Y)
    f:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", DEBUG_OUTLINE_BR_X, DEBUG_OUTLINE_BR_Y)
  end
  f:Show()

  local fw = math.floor((f:GetWidth() or 0) + 0.5)
  local fh = math.floor((f:GetHeight() or 0) + 0.5)
  local strip = self._rightClickBarsRef
  local stripR = self._rightClickBarsRefRight
  if leftSlot and rightSlot and fw >= 2 and fh >= 2 then
    if not strip then
      strip = buildRightClickBarsStripFrame("ChukieUi_RightClickBarsRef", 65534, 0.25, 0.72, 0.98, 0.88)
      self._rightClickBarsRef = strip
    end
    if strip:GetParent() ~= UIParent then
      strip:SetParent(UIParent)
    end
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", leftSlot, "TOPLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", leftSlot, "BOTTOMRIGHT", 0, 0)
    strip:Show()

    if stripR and stripR.GetName and stripR:GetName() ~= "ChukieUi_RightPanelDebugStripRight" then
      stripR:Hide()
      self._rightClickBarsRefRight = nil
      stripR = nil
    end
    if not stripR then
      stripR = buildRightClickBarsStripFrame("ChukieUi_RightPanelDebugStripRight", 65533, 0.96, 0.86, 0.18, 0.92)
      self._rightClickBarsRefRight = stripR
    end
    if stripR:GetParent() ~= UIParent then
      stripR:SetParent(UIParent)
    end
    stripR:ClearAllPoints()
    stripR:SetPoint("TOPLEFT", rightSlot, "TOPLEFT", 0, 0)
    stripR:SetPoint("BOTTOMRIGHT", rightSlot, "BOTTOMRIGHT", 0, 0)
    stripR:Show()
  elseif fw >= 2 and fh >= 2 then
    local sw = math.max(2, math.floor(fw / 3 + 0.5))
    if not strip then
      strip = buildRightClickBarsStripFrame("ChukieUi_RightClickBarsRef", 65534, 0.25, 0.72, 0.98, 0.88)
      self._rightClickBarsRef = strip
    end
    if strip:GetParent() ~= UIParent then
      strip:SetParent(UIParent)
    end
    strip:ClearAllPoints()
    local stripH = math.max(2, math.floor(fh * DEBUG_RIGHTCLICK_STRIP_LEFT_HEIGHT_FRAC + 0.5))
    strip:SetSize(sw, stripH)
    strip:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -DEBUG_RIGHTCLICK_STRIP_GAP, 0)
    strip:Show()

    if stripR and stripR.GetName and stripR:GetName() ~= "ChukieUi_RightPanelDebugStripRight" then
      stripR:Hide()
      self._rightClickBarsRefRight = nil
      stripR = nil
    end
    if not stripR then
      stripR = buildRightClickBarsStripFrame("ChukieUi_RightPanelDebugStripRight", 65533, 0.96, 0.86, 0.18, 0.92)
      self._rightClickBarsRefRight = stripR
    end
    if stripR:GetParent() ~= UIParent then
      stripR:SetParent(UIParent)
    end
    stripR:ClearAllPoints()
    stripR:SetSize(sw, fh)
    stripR:SetPoint("TOPLEFT", f, "TOPRIGHT", DEBUG_RIGHTCLICK_STRIP_GAP, 0)
    stripR:Show()
  else
    if strip then
      strip:Hide()
    end
    if stripR then
      stripR:Hide()
    end
  end
end

--- Franja azul izquierda del verde (⅓ ancho); nil si debug apagado o no creada.
function MP:GetRightClickBarsRefFrame()
  return self._rightClickBarsRef
end

--- Franja amarilla derecha del verde (alto = recuadro verde; ancho ⅓ del verde); nil si debug apagado o no creada.
function MP:GetRightClickBarsRefRightFrame()
  return self._rightClickBarsRefRight
end

function MP:GetPanelTreeFrames()
  return self._panelTreeLeft, self._panelTreeCenter, self._panelTreeRight
end

function MP:ClampOffsets(ox, oy)
  --- X negativo = hacia la izquierda desde la esquina derecha; Y positivo = hacia arriba desde el borde inferior.
  --- Y negativo grande baja el panel hacia el borde inferior de la pantalla (resoluciones altas / UI grande).
  ox = math.max(-1200, math.min(120, math.floor((ox or 0) + 0.5)))
  oy = math.max(-1200, math.min(900, math.floor((oy or 0) + 0.5)))
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
  local db = self:DB()
  local pct = tonumber(db.panelScalePercent) or tonumber(db.minimapScalePercent) or 100
  pct = math.max(60, math.min(220, math.floor(pct + 0.5)))
  db.panelScalePercent = pct
  db.minimapScalePercent = pct
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

--- Durante cinemática / película el viewport y el layout de Blizzard suelen cambiar; anclar aquí hace que el mismo offset
--- quede «mal» al volver al modo normal o tras /reload.
--- DialogueUI (YUI-Dialogue) en Midnight (12.x) usa UIParent:SetShown(false) al ocultar la UI en diálogo; anclar con el padre
--- oculto desincroniza el cluster hasta el siguiente /reload si no se vuelve a aplicar al mostrarse.
function MP:ShouldDeferClusterLayout()
  if UIParent and UIParent.IsShown and not UIParent:IsShown() then
    return true
  end
  if CinematicFrame and CinematicFrame.IsShown and CinematicFrame:IsShown() then
    return true
  end
  if MovieFrame and MovieFrame.IsShown and MovieFrame:IsShown() then
    return true
  end
  return false
end

function MP:CancelLayoutRetryTicker()
  local t = self._layoutRetryTicker
  if t then
    if t.Cancel then
      t:Cancel()
    end
    self._layoutRetryTicker = nil
  end
end

--- Reintenta Apply cuando ya no haya cinemática/película (o tras un tope de intentos).
function MP:RequestLayoutWhenStable()
  if self._layoutRetryTicker then
    return
  end
  local tries = 0
  self._layoutRetryTicker = C_Timer.NewTicker(0.25, function()
    tries = tries + 1
    if (not MP:ShouldDeferClusterLayout()) or tries > 120 then
      MP:CancelLayoutRetryTicker()
      if ns.RightPanel and ns.RightPanel.RequestApply then
        ns.RightPanel:RequestApply(0)
      end
    end
  end)
end

function MP:WantsRightPanel()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  return p and p.enabled ~= false
end

function MP:IsEditModeLayoutActive()
  return EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
end

function MP:EnsureRightPanel()
  if self._rightPanelFrame then
    return self._rightPanelFrame
  end
  if ns.PanelCore and ns.PanelCore.EnsurePanel then
    local h = ns.PanelCore:EnsurePanel(RIGHT_PANEL_CORE_ID)
    if h then
      self._rightPanelFrame = h
      return h
    end
  end
  if not UIParent then
    return nil
  end
  local h = CreateFrame("Frame", "ChukieUi_RightPanel", UIParent)
  h:SetSize(1, 1)
  h:EnableMouse(false)
  h:SetFrameStrata("BACKGROUND")
  h:SetFixedFrameStrata(true)
  h:SetFrameLevel(0)
  self._rightPanelFrame = h
  return h
end

function MP:CancelRightPanelReassertTimer()
  local t = self._rightPanelReassertTimer
  if t then
    if t.Cancel then
      t:Cancel()
    end
    self._rightPanelReassertTimer = nil
  end
end

function MP:CancelScheduledApply()
  local t = self._scheduledApplyTimer
  if t then
    if t.Cancel then
      t:Cancel()
    end
    self._scheduledApplyTimer = nil
  end
  self._scheduledApplyDue = nil
end

function MP:RequestApply(delay)
  delay = math.max(0, tonumber(delay) or 0)
  local due = GetTime() + delay
  if self._scheduledApplyTimer and self._scheduledApplyDue and self._scheduledApplyDue <= due then
    return
  end
  self:CancelScheduledApply()
  self._scheduledApplyDue = due
  self._scheduledApplyTimer = C_Timer.NewTimer(delay, function()
    self._scheduledApplyTimer = nil
    self._scheduledApplyDue = nil
    if ns.RightPanel and ns.RightPanel.Apply then
      ns.RightPanel:Apply()
    end
  end)
end

function MP:ScheduleReassertMinimapToRightPanel()
  if not self:WantsRightPanel() or self:IsEditModeLayoutActive() then
    return
  end
  self:CancelRightPanelReassertTimer()
  self._rightPanelReassertTimer = C_Timer.NewTimer(0.03, function()
    self._rightPanelReassertTimer = nil
    if ns.RightPanel and ns.RightPanel.RequestApply then
      ns.RightPanel:RequestApply(0)
    end
  end)
end

--- MinimapCluster bajo el host; el host tiene tamaño fijo (perfil); el cluster rellena el host.
function MP:ApplyMinimapClusterInRightPanel(ox, oy)
  if not MinimapCluster or not UIParent then
    return
  end
  local host = self:EnsureRightPanel()
  if not host then
    return
  end
  local w, h = self:GetRightPanelSize()
  self._clusterLayoutMutating = true
  if ns.PanelCore and ns.PanelCore.SetPanelBottomRight then
    host = ns.PanelCore:SetPanelBottomRight(RIGHT_PANEL_CORE_ID, w, h, ox, oy) or host
    self._rightPanelFrame = host
  else
    host:SetSize(w, h)
    host:ClearAllPoints()
    host:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", ox, oy)
  end
  MinimapCluster:SetParent(host)
  MinimapCluster:ClearAllPoints()
  MinimapCluster:SetAllPoints(host)
  MinimapCluster:SetClampedToScreen(false)
  MinimapCluster:SetMovable(false)
  self._clusterLayoutMutating = false
  self:SyncRightPanelTreeLayout()
  self:EnforceMinimapInCenterTopArea()
  self:EnableRightPanelWatch()
end

function MP:DisableRightPanelWatch()
  local host = self._rightPanelFrame
  if host then
    host:SetScript("OnUpdate", nil)
    host._chukieRightPanelWatchAcc = nil
  end
end

--- DialogueUI suele usar SetUIVisibility (no siempre UIParent:SetShown); si el cluster vuelve a UIParent sin Lua SetParent, esto lo corrige.
function MP:EnableRightPanelWatch()
  local host = self._rightPanelFrame
  if not host then
    return
  end
  if not self:WantsRightPanel() or self:IsEditModeLayoutActive() then
    self:DisableRightPanelWatch()
    return
  end
  host:SetScript("OnUpdate", function(hframe, el)
    hframe._chukieRightPanelWatchAcc = (hframe._chukieRightPanelWatchAcc or 0) + el
    if hframe._chukieRightPanelWatchAcc < 0.1 then
      return
    end
    hframe._chukieRightPanelWatchAcc = 0
    local MP2 = ns.RightPanel
    if not MP2 or not MP2:WantsRightPanel() or MP2:IsEditModeLayoutActive() then
      hframe:SetScript("OnUpdate", nil)
      return
    end
    if MP2._clusterLayoutMutating then
      return
    end
    if not MinimapCluster then
      return
    end
    if MinimapCluster:GetParent() ~= MP2._rightPanelFrame then
      MP2:RequestApply(0)
      return
    end
    local hst = MP2._rightPanelFrame
    if hst and not MP2:ShouldDeferClusterLayout() then
      local hw, hh = hst:GetWidth(), hst:GetHeight()
      local cw, ch = MinimapCluster:GetWidth(), MinimapCluster:GetHeight()
      if hw and hh and cw and ch and (math.abs(cw - hw) > 0.5 or math.abs(ch - hh) > 0.5) then
        MP2:EnforceMinimapClusterFillRightPanel()
      end
    end
  end)
end

--- Addon desactivado o salida del modo host: vuelve a anclar el cluster directamente a UIParent (mismos offsets).
function MP:ReleaseMinimapClusterFromRightPanel(ox, oy)
  if not MinimapCluster or not UIParent then
    return
  end
  self:DisableRightPanelWatch()
  self._clusterLayoutMutating = true
  MinimapCluster:SetParent(UIParent)
  MinimapCluster:ClearAllPoints()
  MinimapCluster:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", ox, oy)
  MinimapCluster:SetClampedToScreen(false)
  MinimapCluster:SetMovable(false)
  self._clusterLayoutMutating = false
end

function MP:InstallMinimapClusterSecureHooks()
  if self._minimapClusterSecureHooks or not MinimapCluster or not hooksecurefunc then
    return
  end
  self._minimapClusterSecureHooks = true
  pcall(function()
    hooksecurefunc(MinimapCluster, "SetParent", function(frame, parent)
      if frame ~= MinimapCluster then
        return
      end
      if MP._clusterLayoutMutating then
        return
      end
      if not MP:WantsRightPanel() or MP:IsEditModeLayoutActive() then
        return
      end
      local host = MP._rightPanelFrame
      if host and parent ~= host then
        MP:ScheduleReassertMinimapToRightPanel()
      end
    end)
  end)
  pcall(function()
    hooksecurefunc(MinimapCluster, "SetPoint", function(frame, p, r, ...)
      if frame ~= MinimapCluster then
        return
      end
      if MP._clusterLayoutMutating then
        return
      end
      if not MP:WantsRightPanel() or MP:IsEditModeLayoutActive() then
        return
      end
      if MinimapCluster:GetParent() ~= MP._rightPanelFrame then
        MP:ScheduleReassertMinimapToRightPanel()
        return
      end
      if r == UIParent then
        MP:ScheduleReassertMinimapToRightPanel()
      end
    end)
  end)
  local function onClusterSizeTamper(frame)
    if frame ~= MinimapCluster then
      return
    end
    if MP._clusterLayoutMutating then
      return
    end
    if not MP:WantsRightPanel() or MP:IsEditModeLayoutActive() then
      return
    end
    local host = MP._rightPanelFrame
    if not host or not MinimapCluster or MinimapCluster:GetParent() ~= host then
      return
    end
    local hw, hh = host:GetWidth(), host:GetHeight()
    local cw, ch = MinimapCluster:GetWidth(), MinimapCluster:GetHeight()
    if hw and hh and cw and ch and (math.abs(cw - hw) > 0.25 or math.abs(ch - hh) > 0.25) then
      MP:EnforceMinimapClusterFillRightPanel()
    end
  end
  pcall(function()
    hooksecurefunc(MinimapCluster, "SetSize", onClusterSizeTamper)
  end)
  pcall(function()
    hooksecurefunc(MinimapCluster, "SetWidth", onClusterSizeTamper)
  end)
  pcall(function()
    hooksecurefunc(MinimapCluster, "SetHeight", onClusterSizeTamper)
  end)
end

function MP:Apply()
  if ns.PanelCore and ns.PanelCore.RefreshRootBounds then
    ns.PanelCore:RefreshRootBounds()
  end
  self:ApplyRotateMinimapCvar()
  self:ApplyPlayerArrow()
  --- Escala antes de mover el marco: coherente con el ancla final.
  if MinimapCluster then
    self:ApplyClusterScale()
  end
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
    local useRightPanel = self:WantsRightPanel()
    if useRightPanel and self:ShouldDeferClusterLayout() then
      self:RequestLayoutWhenStable()
    elseif useRightPanel and self:IsEditModeLayoutActive() then
      self:CancelLayoutRetryTicker()
      local db = self:DB()
      if db.lockRightPanelInEditMode then
        --- Mantener panel Chukie (host fijo); no usar el arrastre/editor de Blizzard sobre el cluster.
        self:ApplyMinimapClusterInRightPanel(ox, oy)
      else
        self:DisableRightPanelWatch()
        if self._rightPanelFrame and MinimapCluster:GetParent() == self._rightPanelFrame then
          self:ReleaseMinimapClusterFromRightPanel(ox, oy)
        end
      end
    elseif useRightPanel then
      self:CancelLayoutRetryTicker()
      self:ApplyMinimapClusterInRightPanel(ox, oy)
    else
      self:CancelLayoutRetryTicker()
      self:DisableRightPanelWatch()
      if self._rightPanelFrame and MinimapCluster:GetParent() == self._rightPanelFrame then
        self:ReleaseMinimapClusterFromRightPanel(ox, oy)
      else
        self._clusterLayoutMutating = true
        MinimapCluster:ClearAllPoints()
        MinimapCluster:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", ox, oy)
        MinimapCluster:SetClampedToScreen(false)
        MinimapCluster:SetMovable(false)
        self._clusterLayoutMutating = false
      end
    end
  end
  self:ApplyPreferredZoom()
  if ns.MinimapBar and ns.MinimapBar.ApplyBlizzardStripOrRestore then
    ns.MinimapBar:ApplyBlizzardStripOrRestore()
  end
  if self:WantsRightPanel()
    and self._rightPanelFrame
    and MinimapCluster
    and MinimapCluster:GetParent() == self._rightPanelFrame
    and (not self:IsEditModeLayoutActive() or self:DB().lockRightPanelInEditMode)
    and not self:ShouldDeferClusterLayout()
  then
    self:EnforceMinimapClusterFillRightPanel()
  end
  if self:WantsRightPanel() and self._rightPanelFrame then
    self:SyncRightPanelTreeLayout()
    self:EnforceMinimapInCenterTopArea()
  end
  self:UpdateDebugRightPanelOutline()
  if isDebugBoundsEnabled(self:DB()) then
    C_Timer.After(0, function()
      if ns.RightPanel and ns.RightPanel.UpdateDebugRightPanelOutline then
        ns.RightPanel:UpdateDebugRightPanelOutline()
      end
    end)
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

function MP:CancelDeferredUIParentShowTimers()
  local arr = self._uiparentShowTimers
  if not arr then
    return
  end
  for i = 1, #arr do
    local h = arr[i]
    if h and h.Cancel then
      h:Cancel()
    end
    arr[i] = nil
  end
end

--- Tras mostrar UIParent (p. ej. fin de diálogo DialogueUI), Blizzard puede reposicionar el cluster unos fotogramas después.
function MP:ScheduleLayoutAfterUIParentReshown()
  self:CancelDeferredUIParentShowTimers()
  self._uiparentShowTimers = {}
  --- Coalescing por RequestApply: pocos hitos bastan y evitan ráfagas.
  local delays = { 0, 0.12, 0.45, 1.1, 2.2 }
  for i = 1, #delays do
    local d = delays[i]
    self._uiparentShowTimers[i] = C_Timer.NewTimer(d, function()
      if ns.RightPanel and ns.RightPanel.RequestApply then
        ns.RightPanel:RequestApply(0)
      end
    end)
  end
end

--- DialogueUI (tmp/DialogueUI/Code/CallbackRegistry.lua) detecta UIParent con un frame HIJO cuyo OnShow/OnHide dispara;
--- en Midnight Camera.lua usan UIParent:SetShown(), que no siempre dispara el mismo ciclo que HookScript("OnShow") del padre.
function MP:InstallUIParentLayoutHooks()
  if self._uiparentLayoutHooksInstalled then
    return
  end
  self._uiparentLayoutHooksInstalled = true
  if not UIParent then
    return
  end
  if not self._UIParentVisibilityProbe then
    local probe = CreateFrame("Frame", "ChukieUi_UIParentVisibilityProbe", UIParent)
    probe:SetSize(1, 1)
    probe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    probe:SetFrameStrata("BACKGROUND")
    probe:SetFrameLevel(0)
    probe:EnableMouse(false)
    probe:SetScript("OnShow", function()
      if ns.RightPanel and ns.RightPanel.ScheduleLayoutAfterUIParentReshown then
        ns.RightPanel:ScheduleLayoutAfterUIParentReshown()
      end
    end)
    self._UIParentVisibilityProbe = probe
  end
  if hooksecurefunc then
    pcall(function()
      hooksecurefunc(UIParent, "SetShown", function(frame, state)
        if frame ~= UIParent then
          return
        end
        if state and ns.RightPanel and ns.RightPanel.ScheduleLayoutAfterUIParentReshown then
          ns.RightPanel:ScheduleLayoutAfterUIParentReshown()
        end
      end)
    end)
    pcall(function()
      hooksecurefunc(UIParent, "Show", function(frame)
        if frame ~= UIParent then
          return
        end
        if ns.RightPanel and ns.RightPanel.ScheduleLayoutAfterUIParentReshown then
          ns.RightPanel:ScheduleLayoutAfterUIParentReshown()
        end
      end)
    end)
    pcall(function()
      if not SetUIVisibility then
        return
      end
      hooksecurefunc("SetUIVisibility", function(isVisible)
        if not ns.RightPanel then
          return
        end
        if isVisible then
          if ns.RightPanel.ScheduleLayoutAfterUIParentReshown then
            ns.RightPanel:ScheduleLayoutAfterUIParentReshown()
          end
        else
          if ns.RightPanel and ns.RightPanel.RequestApply then
            ns.RightPanel:RequestApply(0)
            ns.RightPanel:RequestApply(0.08)
          end
        end
      end)
    end)
    pcall(function()
      local lastAlpha = (UIParent.GetAlpha and UIParent:GetAlpha()) or 1
      hooksecurefunc(UIParent, "SetAlpha", function(fr, a)
        if fr ~= UIParent then
          return
        end
        a = tonumber(a) or 1
        if lastAlpha < 0.08 and a > 0.55 and ns.RightPanel and ns.RightPanel.ScheduleLayoutAfterUIParentReshown then
          ns.RightPanel:ScheduleLayoutAfterUIParentReshown()
        end
        lastAlpha = a
      end)
    end)
  end
end

function MP:Initialize()
  self:InstallUIParentLayoutHooks()
  if not MinimapCluster then
    return
  end
  self:InstallMinimapClusterSecureHooks()
  self:DestroyLegacyDragStrip()
  self:Apply()
end

local ev = CreateFrame("Frame")
local debounceApplyTimer
local interactionLayoutTimer
local interactionLayoutBurstId = 0

--- DialogueUI cierra con GOSSIP_CLOSED / MERCHANT_CLOSED / etc.; el layout de Blizzard puede mover MinimapCluster después.
local POST_INTERACTION_DELAYS = { 0.3, 0.55, 0.9, 1.35 }

local function CancelInteractionLayoutTimer()
  if interactionLayoutTimer then
    interactionLayoutTimer:Cancel()
    interactionLayoutTimer = nil
  end
end

local function SchedulePostInteractionLayout()
  CancelInteractionLayoutTimer()
  interactionLayoutBurstId = interactionLayoutBurstId + 1
  local burstId = interactionLayoutBurstId
  interactionLayoutTimer = C_Timer.NewTimer(0.1, function()
    interactionLayoutTimer = nil
    if burstId ~= interactionLayoutBurstId then
      return
    end
    if ns.RightPanel and ns.RightPanel.RequestApply then
      ns.RightPanel:RequestApply(0)
    end
    for i = 1, #POST_INTERACTION_DELAYS do
      local d = POST_INTERACTION_DELAYS[i]
      C_Timer.After(d, function()
        if burstId ~= interactionLayoutBurstId then
          return
        end
        if ns.RightPanel and ns.RightPanel.RequestApply then
          ns.RightPanel:RequestApply(0)
        end
      end)
    end
  end)
end

local function CancelDebouncedApply()
  if debounceApplyTimer then
    debounceApplyTimer:Cancel()
    debounceApplyTimer = nil
  end
end

--- UI_SCALE_CHANGED / DISPLAY_SIZE_CHANGED suelen dispararse en ráfaga; esperar estabiliza respecto al layout final.
local function ScheduleDebouncedApply()
  CancelDebouncedApply()
  debounceApplyTimer = C_Timer.NewTimer(0.2, function()
    debounceApplyTimer = nil
    if ns.RightPanel and ns.RightPanel.RequestApply then
      ns.RightPanel:RequestApply(0)
    end
  end)
end

ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("CINEMATIC_STOP")
ev:RegisterEvent("MINIMAP_UPDATE_ZOOM")
pcall(function()
  ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
end)
pcall(function()
  ev:RegisterEvent("GOSSIP_SHOW")
end)
pcall(function()
  ev:RegisterEvent("MERCHANT_SHOW")
end)
ev:RegisterEvent("GOSSIP_CLOSED")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:RegisterEvent("TRAINER_CLOSED")
ev:RegisterEvent("BANKFRAME_CLOSED")
ev:RegisterEvent("MAIL_CLOSED")
ev:RegisterEvent("QUEST_FINISHED")
ev:SetScript("OnEvent", function(_, event)
  if event == "MINIMAP_UPDATE_ZOOM" then
    if ns.RightPanel and ns.RightPanel.ApplyPreferredZoom then
      C_Timer.After(0, function()
        if ns.RightPanel and ns.RightPanel.ApplyPreferredZoom then
          ns.RightPanel:ApplyPreferredZoom()
        end
      end)
    end
    return
  end
  if event == "GOSSIP_SHOW" or event == "MERCHANT_SHOW" then
    SchedulePostInteractionLayout()
    return
  end
  if event == "GOSSIP_CLOSED"
    or event == "MERCHANT_CLOSED"
    or event == "TRAINER_CLOSED"
    or event == "BANKFRAME_CLOSED"
    or event == "MAIL_CLOSED"
    or event == "QUEST_FINISHED"
  then
    SchedulePostInteractionLayout()
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    CancelDebouncedApply()
    CancelInteractionLayoutTimer()
    interactionLayoutBurstId = interactionLayoutBurstId + 1
    if ns.RightPanel and ns.RightPanel.CancelRightPanelReassertTimer then
      ns.RightPanel:CancelRightPanelReassertTimer()
    end
    if ns.RightPanel and ns.RightPanel.CancelDeferredUIParentShowTimers then
      ns.RightPanel:CancelDeferredUIParentShowTimers()
    end
    if ns.RightPanel and ns.RightPanel.CancelLayoutRetryTicker then
      ns.RightPanel:CancelLayoutRetryTicker()
    end
    if ns.RightPanel and ns.RightPanel.RequestApply then
      ns.RightPanel:RequestApply(0)
      ns.RightPanel:RequestApply(0.35)
    end
    return
  end
  if event == "CINEMATIC_STOP" then
    CancelDebouncedApply()
    if ns.RightPanel and ns.RightPanel.CancelRightPanelReassertTimer then
      ns.RightPanel:CancelRightPanelReassertTimer()
    end
    if ns.RightPanel and ns.RightPanel.CancelLayoutRetryTicker then
      ns.RightPanel:CancelLayoutRetryTicker()
    end
    if ns.RightPanel and ns.RightPanel.RequestApply then
      ns.RightPanel:RequestApply(0)
    end
    return
  end
  if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
    ScheduleDebouncedApply()
    return
  end
  if ns.RightPanel and ns.RightPanel.RequestApply then
    ns.RightPanel:RequestApply(0)
  end
end)

ns.MinimapPosition = ns.RightPanel
