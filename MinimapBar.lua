--[[ Panel derecho (Retail 12.0.1, ## Interface: 120001 en el .toc).
     - «Solo mapa»: STRIP_FRAMES + descendientes nombrados + marcos del cluster (TrackingFrame, ZoomIn/Out del mapa, InstanceDifficulty, IndicatorFrame…).
     - Addons: barra + política por botón (Defecto / Barra / Oculto) en minimapBar.buttonPolicy + discoveredOrder.
     - Barra de addons: el botón real (LibDBIcon, Zygor, etc.) permanece en el mapa pero oculto; la barra usa proxies
       (icono copiado + clic/tooltip reenviados) para que Masque funcione sin tocar el marco LibDBIcon.
     - Segunda fila: miniMenuBar — botones del micromenú Blizzard (`MICRO_BUTTONS` o fallback), reparent bajo el mapa. ]]

local _, ns = ...

local MB = {}
ns.MinimapBar = MB

local NAME_BLACKLIST = {
  AddonCompartmentFrame = true,
  MinimapBackdrop = true,
}

--- Globales Blizzard a retirar del minimapa cuando stripBlizzardMinimap está activo (nil/true).
local STRIP_FRAMES = {
  MiniMapWorldMapButton = true,
  MiniMapMailFrame = true,
  MiniMapBattlefieldFrame = true,
  MiniMapTracking = true,
  MiniMapTrackingButton = true,
  GameTimeFrame = true,
  TimeManagerClockButton = true,
  QueueStatusMinimapButton = true,
  QueueStatusButton = true,
  ExpansionLandingPageMinimapButton = true,
  GuildInstanceDifficulty = true,
  MiniMapInstanceDifficulty = true,
  MinimapZoomIn = true,
  MinimapZoomOut = true,
  MinimapZoneText = true,
  MinimapZoneTextButton = true,
  AddonCompartmentFrame = true,
  MinimapNorthTag = true,
  MiniMapChallengeMode = true,
  GarrisonMinimapMission = true,
  MinimapToggleButton = true,
  MinimapCompassTexture = true,
  --- Franja decorativa encima del mapa (a menudo el «bloque» vacío); en Retail suele ser MinimapCluster.BorderTop.
  MinimapBorderTop = true,
}

--- Marcos que en Retail viven como hijos de MinimapCluster / Minimap (no siempre coinciden con _G de STRIP_FRAMES).
local STRIP_RES_PREFIX = "ChukieUiStripRes_"

local function collectStripResolverFrames()
  local out, seen = {}, {}
  local function add(getter)
    local f = getter()
    if f and type(f) == "table" and f.GetObjectType and not seen[f] then
      seen[f] = true
      out[#out + 1] = f
    end
  end
  if MinimapCluster then
    --- TitleContainer (DF+): agrupa zona + reloj; BorderTop: fondo pastilla; ZoneTextButton abre el mapa al clic.
    add(function()
      return MinimapCluster.TitleContainer
    end)
    add(function()
      return MinimapCluster.BorderTop
    end)
    add(function()
      return MinimapCluster.ZoneTextButton
    end)
    add(function()
      return MinimapCluster.ZoneTextFrame
    end)
    add(function()
      return MinimapCluster.TrackingFrame or MinimapCluster.Tracking
    end)
    add(function()
      local TF = MinimapCluster.TrackingFrame or MinimapCluster.Tracking
      return TF and TF.Button
    end)
    add(function()
      return MinimapCluster.InstanceDifficulty
    end)
    if MinimapCluster.IndicatorFrame then
      add(function()
        return MinimapCluster.IndicatorFrame.MailFrame
      end)
      add(function()
        return MinimapCluster.IndicatorFrame.CraftingOrderFrame
      end)
    end
  end
  if Minimap then
    add(function()
      return Minimap.ZoomIn
    end)
    add(function()
      return Minimap.ZoomOut
    end)
  end
  return out
end

local function prof()
  return ns.Profile:GetActive()
end

local function barOpts()
  local m
  if ns.Profile and ns.Profile.GetMinimapBarModel then
    m = ns.Profile:GetMinimapBarModel()
  else
    m = prof().minimapBar
  end
  m = m or {}
  m.buttonPolicy = m.buttonPolicy or {}
  m.discoveredOrder = m.discoveredOrder or {}
  return m
end

local function getRightPanelTreeCenter()
  if not ns.RightPanel or not ns.RightPanel.GetPanelTreeFrames then
    return nil
  end
  local _, center = ns.RightPanel:GetPanelTreeFrames()
  if not center then
    return nil
  end
  local w, h = center:GetWidth(), center:GetHeight()
  if not w or not h or w < 2 or h < 2 then
    return nil
  end
  return center
end

local function getRightPanelBaseFrame()
  local center = getRightPanelTreeCenter()
  if center then
    return center
  end
  if ns.PanelCore and ns.PanelCore.GetPanelFrame then
    local p = ns.PanelCore:GetPanelFrame("rightPanel")
    if p then
      return p
    end
  end
  if ns.PanelCore and ns.PanelCore.EnsureRoot then
    return ns.PanelCore:EnsureRoot()
  end
  return UIParent
end

local function getPanelScalePct()
  if ns.RightPanel and ns.RightPanel.DB then
    local db = ns.RightPanel:DB()
    local pct = tonumber(db and db.panelScalePercent)
    if pct then
      return math.max(60, math.min(220, math.floor(pct + 0.5)))
    end
  end
  return 100
end

local function isMicroMenuDebugEnabled()
  if not ns.RightPanel or not ns.RightPanel.DB then
    return false
  end
  local db = ns.RightPanel:DB()
  local v = db and db.debugRightPanelBounds
  return v == true or v == 1
end

local function microMenuDebugPrint(fmt, ...)
  if not isMicroMenuDebugEnabled() then
    return
  end
  local ok, msg = pcall(string.format, fmt, ...)
  if not ok then
    msg = tostring(fmt)
  end
  print("|cff33ff99ChukieUi|r " .. msg)
end

local function absNum(v)
  v = tonumber(v) or 0
  if v < 0 then
    return -v
  end
  return v
end

local ADDON_BAR_GAP_BELOW_MINIMAP = 1
local MINIMENU_EXTRA_HEIGHT = 3
local MINIMENU_TOP_RAISE = 3

--- Orden típico del micromenú Retail (fallback si no existe la global `MICRO_BUTTONS`).
local MICRO_BUTTON_FALLBACK_NAMES = {
  "CharacterMicroButton",
  "PlayerSpellsMicroButton",
  "SpellbookMicroButton",
  "ProfessionMicroButton",
  "TalentMicroButton",
  "AchievementMicroButton",
  "QuestLogMicroButton",
  "GuildMicroButton",
  "LFDMicroButton",
  "CollectionsMicroButton",
  "EJMicroButton",
  "StoreMicroButton",
  "PromotionFrameMicroButton",
  "WhatsNewMicroButton",
  "MainMenuMicroButton",
}

--- Botones del micromenú de Blizzard (sufijo «MicroButton»). No deben tratarse como iconos LibDBIcon del minimapa.
local function isBlizzardMicroMenuButtonName(name)
  if type(name) ~= "string" or name == "" then
    return false
  end
  if name:find("^LibDBIcon10_", 1, true) then
    return false
  end
  return name:match("MicroButton$") ~= nil
end

function MB:GetMicroMenuButtonFrames()
  local out, seen = {}, {}
  local function pushFrame(f)
    if not f or type(f) ~= "table" or not f.GetObjectType or seen[f] then
      return
    end
    local ot = f:GetObjectType()
    if ot ~= "Button" and ot ~= "CheckButton" then
      return
    end
    seen[f] = true
    out[#out + 1] = f
  end
  if type(MICRO_BUTTONS) == "table" then
    for i = 1, #MICRO_BUTTONS do
      local v = MICRO_BUTTONS[i]
      if type(v) == "string" then
        pushFrame(_G[v])
      elseif type(v) == "table" and v.GetObjectType then
        pushFrame(v)
      end
    end
  end
  if #out == 0 then
    local hasPlayerSpells = _G.PlayerSpellsMicroButton
    for _, name in ipairs(MICRO_BUTTON_FALLBACK_NAMES) do
      if name == "SpellbookMicroButton" and hasPlayerSpells then
        --- Retail: hechizos y profesiones suelen ir en PlayerSpellsMicroButton.
      else
        pushFrame(_G[name])
      end
    end
  end
  return out
end

function MB:RestoreMicroMenuButtonsFromChukieBar()
  self:MasqueStripMicromenu()
  local list = self.microMenuDetached
  if not list then
    return
  end
  for _, btn in ipairs(list) do
    if btn and type(btn) == "table" then
      local p = btn.chukieMicroSavedParent
      if p and type(p) == "table" and p.SetFrameStrata then
        btn:SetParent(p)
      elseif MicroButtonAndBagsBar then
        btn:SetParent(MicroButtonAndBagsBar)
      elseif MainMenuBar then
        btn:SetParent(MainMenuBar)
      end
      if btn.chukieMicroSavedScale then
        btn:SetScale(btn.chukieMicroSavedScale)
      else
        btn:SetScale(1)
      end
      btn.chukieMicroChukieOwned = nil
      btn.chukieMicroSavedParent = nil
      btn.chukieMicroSavedScale = nil
      if btn.Show then
        btn:Show()
      end
    end
  end
  wipe(list)
  self.microMenuDetached = nil
end

function MB:EnsureMicroMenuHooks()
  if self.microMenuHooks then
    return
  end
  self.microMenuHooks = true
  hooksecurefunc("UpdateMicroButtons", function()
    if not MB.miniMenuBar or not MB.miniMenuBar:IsShown() then
      return
    end
    if barOpts().minimenuBarEnabled == false then
      return
    end
    if InCombatLockdown() then
      MB.microMenuRelayoutAfterCombat = true
      return
    end
    MB:LayoutMicroMenuEmbedded()
  end)
  if not MB.microMenuCombatEv then
    local ev = CreateFrame("Frame")
    MB.microMenuCombatEv = ev
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function()
      if MB.microMenuRelayoutAfterCombat then
        MB.microMenuRelayoutAfterCombat = false
        if MB.LayoutMicroMenuEmbedded then
          MB:LayoutMicroMenuEmbedded()
        end
      end
    end)
  end
end

function MB:LayoutMicroMenuEmbedded()
  if not self.miniMenuBar or barOpts().minimenuBarEnabled == false then
    return
  end
  if InCombatLockdown() then
    self.microMenuRelayoutAfterCombat = true
    return
  end
  local mm = self.miniMenuBar
  local rowH = self:GetMiniMenuBarHeight()
  mm:SetHeight(rowH)
  local innerH = math.max(14, rowH - 4)
  local gap = math.max(0, tonumber(self:GetMiniMenuSpacing()) or 0)
  local targetW = self:GetMiniMenuIconWidth()
  local x = 0
  self.microMenuDetached = self.microMenuDetached or {}
  local known = {}
  local visibleButtons = {}
  for _, b in ipairs(self.microMenuDetached) do
    known[b] = true
  end
  for _, btn in ipairs(self:GetMicroMenuButtonFrames()) do
    if not known[btn] then
      self.microMenuDetached[#self.microMenuDetached + 1] = btn
      known[btn] = true
    end
    if not btn.chukieMicroSavedParent then
      btn.chukieMicroSavedParent = btn:GetParent()
    end
    if not btn.chukieMicroSavedScale then
      btn.chukieMicroSavedScale = btn:GetScale() > 0 and btn:GetScale() or 1
    end
    btn:SetParent(mm)
    btn.chukieMicroChukieOwned = true
    local n = btn:GetName() or ""
    if not self:IsMinimenuButtonVisible(n) then
      btn:SetScale(btn.chukieMicroSavedScale or 1)
      btn:ClearAllPoints()
      btn:Hide()
    else
      btn:Show()
      btn:SetScale(1)
      btn:ClearAllPoints()
      visibleButtons[#visibleButtons + 1] = btn
    end
  end
  local visibleCount = #visibleButtons
  local commonScale = 1
  local baseL, baseR = 0, 0
  if visibleCount > 0 then
    local refBtn = visibleButtons[1]
    local w0 = refBtn:GetWidth() or 28
    local h0 = refBtn:GetHeight() or 58
    local l, r = refBtn:GetHitRectInsets()
    baseL = tonumber(l) or 0
    baseR = tonumber(r) or 0
    local base = refBtn.chukieMicroSavedScale or 1
    local sW = targetW / math.max((w0 - (baseL + baseR)), 1)
    local sH = innerH / math.max(h0, 1)
    local fit = math.min(sW, sH, 2.35)
    fit = math.max(0.18, fit)
    commonScale = math.min(2.8, math.max(0.15, fit * base))
  end
  local totalContentWidth = 0
  if visibleCount > 0 then
    totalContentWidth = (visibleCount * targetW) + ((visibleCount - 1) * gap)
  end
  for i, btn in ipairs(visibleButtons) do
    btn:SetScale(commonScale)
    btn:ClearAllPoints()
    local cx = (-totalContentWidth / 2) + (targetW / 2) + ((i - 1) * (targetW + gap))
    btn:SetPoint("CENTER", mm, "CENTER", cx, 0)
  end
  local width = 48
  if visibleCount > 0 then
    width = totalContentWidth + 2
  end
  mm:SetWidth(math.max(width, 48))
  self._microMenuDebug = {
    visibleCount = visibleCount,
    targetW = targetW,
    gap = gap,
    commonScale = commonScale,
    baseL = baseL,
    baseR = baseR,
    width = mm:GetWidth() or width,
  }
  microMenuDebugPrint(
    "MicroLayout visible=%d targetW=%.2f gap=%.2f scale=%.3f insets(L=%.2f,R=%.2f) calcWidth=%.2f finalWidth=%.2f",
    visibleCount,
    targetW,
    gap,
    commonScale,
    baseL,
    baseR,
    width,
    mm:GetWidth() or width
  )
  self:PositionMicromenuCentered()
  self:MasqueApplyMicromenu()
end

function MB:GetMicroMenuVisualCenterDelta()
  if not self.miniMenuBar then
    return 0
  end
  local mm = self.miniMenuBar
  local mmLeft = mm:GetLeft()
  local mmW = mm:GetWidth() or 0
  if not mmLeft or mmW <= 0 then
    return 0
  end
  local minL, maxR = nil, nil
  for _, btn in ipairs(self:GetMicroMenuButtonFrames()) do
    if btn and btn:GetParent() == mm and btn:IsShown() then
      local l = btn:GetLeft()
      local r = btn:GetRight()
      if l and r then
        if not minL or l < minL then
          minL = l
        end
        if not maxR or r > maxR then
          maxR = r
        end
      end
    end
  end
  if not minL or not maxR then
    return 0
  end
  local visualCenter = (minL + maxR) / 2
  local containerCenter = mmLeft + (mmW / 2)
  return visualCenter - containerCenter
end

--- Layout unificado: barras siempre centradas (sin offset manual separado).
function MB:GetAddonBarOffsetX()
  return 0
end

--- Layout unificado: micromenú siempre centrado (sin offset manual separado).
function MB:GetMinimenuBarOffsetX()
  return 0
end

--- Barra de addons: centrada bajo el minimapa (si existe), o en la base del panel.
function MB:PositionAddonBarCentered()
  if not self.bar or barOpts().enabled == false then
    return
  end
  self.bar:ClearAllPoints()
  local ref = getRightPanelBaseFrame()
  if Minimap and Minimap:IsShown() and ref then
    local refTop = ref:GetTop()
    local mapBottom = Minimap:GetBottom()
    if refTop and mapBottom then
      --- Centrado en el bloque central (ref), usando la altura real del minimapa para ubicar la barra abajo.
      self.bar:SetPoint("TOP", ref, "TOP", 0, (mapBottom - refTop) + ADDON_BAR_GAP_BELOW_MINIMAP)
      return
    end
  end
  if Minimap and Minimap:IsShown() then
    self.bar:SetPoint("TOP", Minimap, "BOTTOM", 0, ADDON_BAR_GAP_BELOW_MINIMAP)
    return
  end
  if not ref then
    return
  end
  self.bar:SetPoint("BOTTOM", ref, "BOTTOM", 0, 2)
end

function MB:PositionMicromenuCentered()
  if not self.miniMenuBar or barOpts().minimenuBarEnabled == false then
    return
  end
  local mm = self.miniMenuBar
  mm:ClearAllPoints()
  if self.bar and self.bar:IsShown() and barOpts().enabled ~= false then
    local ref = getRightPanelBaseFrame()
    if ref then
      local refTop = ref:GetTop()
      local refW = ref:GetWidth() or 0
      local barBottom = self.bar:GetBottom()
      local mmW = mm:GetWidth() or 0
      if refTop and barBottom and refW > 0 and mmW > 0 then
        local yOff = (barBottom - refTop) - self:GetMinimenuGapBelowAddonBar() + MINIMENU_TOP_RAISE
        --- Centrado absoluto por eje X contra el bloque central.
        mm:SetPoint("TOP", ref, "TOP", 0, yOff)
        local refLeft = ref:GetLeft()
        local mmLeft = mm:GetLeft()
        local centerDelta = nil
        if refLeft and mmLeft then
          centerDelta = ((mmLeft + (mmW / 2)) - (refLeft + (refW / 2)))
        end
        microMenuDebugPrint(
          "MicroPos TOP refW=%.2f mmW=%.2f yOff=%.2f centerDelta=%s",
          refW,
          mmW,
          yOff,
          centerDelta and string.format("%.2f", centerDelta) or "n/a"
        )
        return
      end
    end
    --- Fallback: mantener debajo de la barra.
    mm:SetPoint("TOP", self.bar, "BOTTOM", 0, -self:GetMinimenuGapBelowAddonBar() + MINIMENU_TOP_RAISE)
    microMenuDebugPrint("MicroPos fallback TOP self.bar")
  else
    local ref = getRightPanelBaseFrame()
    if not ref then
      return
    end
    local refW = ref:GetWidth() or 0
    local mmW = mm:GetWidth() or 0
    if refW > 0 and mmW > 0 then
      mm:SetPoint("BOTTOM", ref, "BOTTOM", 0, 2)
      microMenuDebugPrint("MicroPos BOTTOM refW=%.2f mmW=%.2f", refW, mmW)
      return
    end
    mm:SetPoint("BOTTOM", ref, "BOTTOM", 0, 2)
    microMenuDebugPrint("MicroPos fallback BOTTOM center")
  end
end

function MB:ProfileRotateMinimap()
  if not prof().enabled then
    return false
  end
  local m = prof().minimapPosition or {}
  return m.rotateMinimap == true
end

--- Con «Solo mapa» + rotación en perfil: no stripar norte/brújula como el resto; alinear con el CVar.
function MB:ApplyNorthCompassAfterStrip()
  if not self:ShouldStripBlizzardChrome() then
    return
  end
  local north = MinimapNorthTag
  local comp = MinimapCompassTexture
  for _, f in ipairs({ north, comp }) do
    if f then
      f.chukieStripChrome = nil
    end
  end
  --- Forzar oculto del anillo/cardinales: evita que Blizzard o el flujo de rotación los vuelva a mostrar.
  if north then
    north:Hide()
    if north.SetAlpha then
      north:SetAlpha(0)
    end
  end
  if comp then
    comp:Hide()
    if comp.SetAlpha then
      comp:SetAlpha(0)
    end
    if comp.SetTexture then
      comp:SetTexture(nil)
    end
  end
  if not self._compassHideEnforced then
    self._compassHideEnforced = true
    if north and north.HookScript then
      north:HookScript("OnShow", function(frame)
        frame:Hide()
        if frame.SetAlpha then
          frame:SetAlpha(0)
        end
      end)
    end
    if comp and comp.HookScript then
      comp:HookScript("OnShow", function(frame)
        frame:Hide()
        if frame.SetAlpha then
          frame:SetAlpha(0)
        end
      end)
    end
  end
  if self._isApplyingNorthCompassAfterStrip then
    return
  end
  self._isApplyingNorthCompassAfterStrip = true
  if Minimap_UpdateRotationSetting then
    pcall(Minimap_UpdateRotationSetting)
  end
  self._isApplyingNorthCompassAfterStrip = false
end

function MB:GetFramePolicy(frameName)
  if not frameName or frameName == "" then
    return "bar"
  end
  local pol = barOpts().buttonPolicy
  local v = pol[frameName]
  if v == "default" or v == 0 then
    return "default"
  end
  if v == "hidden" or v == 2 then
    return "hidden"
  end
  if v == "bar" or v == 1 or v == nil then
    return "bar"
  end
  return "bar"
end

function MB:IsAddonPolicyName(n)
  if not n or n == "" or STRIP_FRAMES[n] or NAME_BLACKLIST[n] or n:find("^ChukieUi_", 1, true) then
    return false
  end
  if isBlizzardMicroMenuButtonName(n) then
    return false
  end
  if n:match("^LibDBIcon10_") then
    return true
  end
  if n == "ZygorGuidesViewerMapIcon" then
    return true
  end
  if barOpts().buttonPolicy[n] ~= nil then
    return true
  end
  for _, id in ipairs(barOpts().discoveredOrder or {}) do
    if id == n then
      return true
    end
  end
  return false
end

function MB:ShouldStripBlizzardChrome()
  if not prof().enabled then
    return false
  end
  return barOpts().stripBlizzardMinimap ~= false
end

--- Ancho de iconos en la barra de addons (px). Perfiles antiguos: `cellSize`.
function MB:GetAddonBarIconWidth()
  local m = barOpts()
  local base = tonumber(m.addonBarIconWidth) or tonumber(m.cellSize) or 34
  local v = base * (getPanelScalePct() / 100)
  return math.max(8, math.min(128, math.floor(v + 0.5)))
end

--- Alto de iconos en la barra de addons (px). Por defecto igual al ancho.
function MB:GetAddonBarIconHeight()
  local m = barOpts()
  local base = tonumber(m.addonBarIconHeight) or tonumber(m.addonBarIconWidth) or tonumber(m.cellSize) or 34
  local v = base * (getPanelScalePct() / 100)
  return math.max(8, math.min(128, math.floor(v + 0.5)))
end

--- Espacio horizontal entre iconos de addons (px). Antiguo: `pad`.
function MB:GetAddonBarSpacing()
  local m = barOpts()
  local base = tonumber(m.addonBarSpacing) or tonumber(m.pad) or 4
  local v = base * (getPanelScalePct() / 100)
  return math.max(0, math.min(64, math.floor(v + 0.5)))
end

--- Alto de la fila del micromenú (px), independiente de la barra de addons.
function MB:GetMiniMenuBarHeight()
  local base = tonumber(barOpts().minimenuRowHeight) or 42
  local v = base * (getPanelScalePct() / 100)
  return math.max(20, math.min(80, math.floor(v + 0.5))) + MINIMENU_EXTRA_HEIGHT
end

--- Ancho objetivo de cada icono del micromenú tras escalar (px).
function MB:GetMiniMenuIconWidth()
  local base = tonumber(barOpts().minimenuIconWidth) or 28
  local v = base * (getPanelScalePct() / 100)
  return math.max(12, math.min(56, math.floor(v + 0.5)))
end

function MB:GetMiniMenuSpacing()
  local base = tonumber(barOpts().minimenuSpacing)
  if not base then
    base = 2
  end
  local v = base * (getPanelScalePct() / 100)
  if not v then
    return 2
  end
  return math.max(-32, math.min(32, math.floor(v + 0.5)))
end

--- Separación entre el borde inferior de la barra de addons y el superior del micromenú (px; negativo = solapar).
function MB:GetMinimenuGapBelowAddonBar()
  local base = tonumber(barOpts().minimenuGapBelowAddonBar)
  if not base then
    base = 8
  end
  local v = base * (getPanelScalePct() / 100)
  if not v then
    return 8
  end
  return math.max(-32, math.min(48, math.floor(v + 0.5)))
end

function MB:IsMinimenuButtonVisible(frameName)
  if not frameName or frameName == "" then
    return true
  end
  local t = barOpts().minimenuVisibility
  if not t then
    return true
  end
  return t[frameName] ~= false
end

--- Nombres únicos del micromenú (orden del cliente: `MICRO_BUTTONS` si existe).
function MB:GetMinimenuButtonNameList()
  local seen, ordered = {}, {}
  local function add(n)
    if not n or n == "" or seen[n] or not isBlizzardMicroMenuButtonName(n) then
      return
    end
    seen[n] = true
    ordered[#ordered + 1] = n
  end
  if type(MICRO_BUTTONS) == "table" then
    for i = 1, #MICRO_BUTTONS do
      local v = MICRO_BUTTONS[i]
      local n = type(v) == "string" and v or (type(v) == "table" and v.GetName and v:GetName())
      if n then
        add(n)
      end
    end
  end
  for _, n in ipairs(MICRO_BUTTON_FALLBACK_NAMES) do
    if _G[n] then
      add(n)
    end
  end
  for _, btn in ipairs(self:GetMicroMenuButtonFrames()) do
    add(btn:GetName())
  end
  return ordered
end

local function packPoints(f)
  local t = {}
  for i = 1, f:GetNumPoints() do
    local a, b, c, d, e = f:GetPoint(i)
    t[i] = { a, b, c, d, e }
  end
  return t
end

local function restorePoints(f, points)
  if not points then
    return
  end
  f:ClearAllPoints()
  for i = 1, #points do
    local p = points[i]
    f:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
end

--- `GetChildren()` devuelve varargs; empaquetar con `{ ... }` puede omitir hijos en el cliente.
local function listFrameChildren(frame)
  if not frame or not frame.GetChildren then
    return {}
  end
  local t = {}
  local i = 1
  while true do
    local c = select(i, frame:GetChildren())
    if not c then
      break
    end
    t[#t + 1] = c
    i = i + 1
  end
  return t
end

--- Igual que GetChildren: GetRegions() es varargs; `{ ... }` + ipairs puede dejar texturas sin recorrer.
local function listFrameRegions(frame)
  if not frame or not frame.GetRegions then
    return {}
  end
  local t = {}
  local i = 1
  while true do
    local r = select(i, frame:GetRegions())
    if not r then
      break
    end
    t[#t + 1] = r
    i = i + 1
  end
  return t
end

local function isUnderMinimapClusterOrMap(f)
  local p = f and f:GetParent()
  while p do
    if p == Minimap or p == MinimapCluster then
      return true
    end
    p = p:GetParent()
  end
  return false
end

function MB:ShouldNeverCapture(f)
  if not f or f == self.bar or f == self.miniMenuBar then
    return true
  end
  local n = f:GetName() or ""
  if isBlizzardMicroMenuButtonName(n) then
    return true
  end
  if NAME_BLACKLIST[n] or n:find("^ChukieUi_", 1, true) then
    return true
  end
  if n:find("^ChukieUi_mmproxy_", 1, true) then
    return true
  end
  if f.isZygorWaypoint then
    return true
  end
  if STRIP_FRAMES[n] then
    return true
  end
  local w = f:GetWidth()
  if w and w > 140 then
    return true
  end
  return false
end

--- Solo addons / botones genéricos en el minimapa (no marcos Blizzard de STRIP_FRAMES).
function MB:IsManagedCandidate(f)
  if self:ShouldNeverCapture(f) then
    return false
  end
  local n = f:GetName() or ""
  if n:find("^ChukieUi_mmproxy_", 1, true) then
    return false
  end
  if n:match("^LibDBIcon10_") then
    return true
  end
  if n == "ZygorGuidesViewerMapIcon" then
    return true
  end
  if not isUnderMinimapClusterOrMap(f) then
    return false
  end
  local ot = f:GetObjectType()
  if ot ~= "Button" and ot ~= "CheckButton" then
    return false
  end
  local w, h = f:GetSize()
  if not w or not h or w < 12 or h < 12 or w > 76 or h > 76 then
    return false
  end
  if n ~= "" then
    return true
  end
  return f:HasScript("OnClick") or f:GetScript("OnClick")
end

function MB:ShouldPlaceOnBar(f)
  if not self:IsManagedCandidate(f) then
    return false
  end
  return self:GetFramePolicy(f:GetName()) == "bar"
end

function MB:UpdateDiscoveredOrder()
  local order = barOpts().discoveredOrder
  local pol = barOpts().buttonPolicy
  for i = #order, 1, -1 do
    if isBlizzardMicroMenuButtonName(order[i]) then
      pol[order[i]] = nil
      table.remove(order, i)
    end
  end
  local polStrip = {}
  for k in pairs(pol) do
    if isBlizzardMicroMenuButtonName(k) then
      polStrip[#polStrip + 1] = k
    end
  end
  for _, k in ipairs(polStrip) do
    pol[k] = nil
  end
  local seen = {}
  for _, id in ipairs(order) do
    seen[id] = true
  end
  self:ForEachMinimapDescendant(function(f, n)
    if not f or self:ShouldNeverCapture(f) then
      return
    end
    if not n or n == "" or STRIP_FRAMES[n] then
      return
    end
    if not self:IsManagedCandidate(f) then
      return
    end
    if not seen[n] then
      order[#order + 1] = n
      seen[n] = true
    end
  end)
  table.sort(order)
end

function MB:EnsureAddonPolicyHook(f, frameName)
  if not f or f.chukieAddonPolicyHook then
    return
  end
  f.chukieAddonPolicyHook = true
  hooksecurefunc(f, "Show", function()
    if MB:GetFramePolicy(frameName) == "hidden" then
      f:Hide()
    end
  end)
  hooksecurefunc(f, "SetShown", function(frame, show)
    if show and MB:GetFramePolicy(frameName) == "hidden" then
      frame:Hide()
    end
  end)
end

function MB:ShouldKeepOriginalHiddenForBar(frameName)
  if not prof().enabled then
    return false
  end
  if barOpts().enabled == false then
    return false
  end
  return self:GetFramePolicy(frameName) == "bar"
end

--- Con política «bar» y barra activa, el botón real del minimapa debe permanecer oculto (el usuario usa el proxy).
function MB:EnsureBarOriginalHiddenHook(f, frameName)
  if not f or f.chukieBarOriginalHiddenHook then
    return
  end
  f.chukieBarOriginalHiddenHook = true
  hooksecurefunc(f, "Show", function()
    if MB:ShouldKeepOriginalHiddenForBar(frameName) then
      f:Hide()
    end
  end)
  hooksecurefunc(f, "SetShown", function(frame, showVal)
    if showVal and MB:ShouldKeepOriginalHiddenForBar(frameName) then
      frame:Hide()
    end
  end)
end

function MB:ApplyAddonButtonPolicies()
  self:ForEachMinimapDescendant(function(f, n)
    if not self:IsAddonPolicyName(n) then
      return
    end
    local pol = self:GetFramePolicy(n)
    if pol == "hidden" then
      f:Hide()
      self:EnsureAddonPolicyHook(f, n)
    elseif pol == "default" then
      f:Show()
    else
      if barOpts().enabled ~= false and prof().enabled then
        f:Hide()
        self:EnsureBarOriginalHiddenHook(f, n)
      else
        f:Show()
      end
    end
  end)
  for _, name in ipairs(barOpts().discoveredOrder or {}) do
    local g = _G[name]
    if g and type(g) == "table" and g.GetObjectType and g:GetName() == name and self:IsAddonPolicyName(name) then
      local pol = self:GetFramePolicy(name)
      if pol == "hidden" then
        g:Hide()
        self:EnsureAddonPolicyHook(g, name)
      elseif pol == "default" then
        g:Show()
      else
        if barOpts().enabled ~= false and prof().enabled then
          g:Hide()
          self:EnsureBarOriginalHiddenHook(g, name)
        else
          g:Show()
        end
      end
    end
  end
end

function MB:ForEachMinimapDescendant(callback)
  local seen = {}
  local function walk(f)
    if not f or seen[f] then
      return
    end
    seen[f] = true
    local n = f:GetName()
    if n and n ~= "" then
      callback(f, n)
    end
    for _, c in ipairs(listFrameChildren(f)) do
      walk(c)
    end
  end
  if MinimapCluster then
    walk(MinimapCluster)
  end
  if Minimap and not seen[Minimap] then
    walk(Minimap)
  end
end

function MB:EnsureStripShowHook(f)
  if not f or f.chukieStripShowHook then
    return
  end
  f.chukieStripShowHook = true
  hooksecurefunc(f, "Show", function()
    if MB:ShouldStripBlizzardChrome() and f.chukieStripChrome then
      f:Hide()
    end
  end)
  hooksecurefunc(f, "SetShown", function(frame, show)
    if show and MB:ShouldStripBlizzardChrome() and frame.chukieStripChrome then
      frame:Hide()
    end
  end)
end

function MB:HideStrippableFrame(f, frameName)
  if not f or not frameName then
    return
  end
  local allowed = STRIP_FRAMES[frameName]
  if not allowed then
    allowed = type(frameName) == "string" and strsub(frameName, 1, #STRIP_RES_PREFIX) == STRIP_RES_PREFIX
  end
  if not allowed then
    return
  end
  if (frameName == "MinimapNorthTag" or frameName == "MinimapCompassTexture") and self:ProfileRotateMinimap() then
    return
  end
  f.chukieStripChrome = true
  f:Hide()
  self:EnsureStripShowHook(f)
end

function MB:ApplyBlizzardStripOrRestore()
  if self:ShouldStripBlizzardChrome() then
    self:ForEachMinimapDescendant(function(f, n)
      if STRIP_FRAMES[n] then
        self:HideStrippableFrame(f, n)
      end
    end)
    for name in pairs(STRIP_FRAMES) do
      local g = _G[name]
      if g and type(g) == "table" and g.GetObjectType and g:GetName() == name then
        self:HideStrippableFrame(g, name)
      end
    end
    for i, fr in ipairs(collectStripResolverFrames()) do
      self:HideStrippableFrame(fr, STRIP_RES_PREFIX .. i)
    end
    self:ApplyNorthCompassAfterStrip()
  else
    for name in pairs(STRIP_FRAMES) do
      local g = _G[name]
      if g and type(g) == "table" then
        g.chukieStripChrome = nil
        if g.Show then
          g:Show()
        end
      end
    end
    self:ForEachMinimapDescendant(function(f, n)
      if STRIP_FRAMES[n] then
        f.chukieStripChrome = nil
        if f.Show then
          f:Show()
        end
      end
    end)
    for _, fr in ipairs(collectStripResolverFrames()) do
      if fr then
        fr.chukieStripChrome = nil
        if fr.Show then
          fr:Show()
        end
      end
    end
  end
end

function MB:EnumerateManagedCandidates()
  local out, seen = {}, {}
  self:ForEachMinimapDescendant(function(f, n)
    if seen[f] or not self:IsManagedCandidate(f) then
      return
    end
    seen[f] = true
    out[#out + 1] = f
  end)
  table.sort(out, function(a, b)
    return (a:GetName() or "") < (b:GetName() or "")
  end)
  return out
end

function MB:CollectFrames()
  local out = {}
  for _, f in ipairs(self:EnumerateManagedCandidates()) do
    if self:ShouldPlaceOnBar(f) then
      out[#out + 1] = f
    end
  end
  return out
end

function MB:LdbNameFromButton(f)
  local n = f:GetName()
  if n and n:match("^LibDBIcon10_") then
    return n:match("^LibDBIcon10_(.+)$")
  end
  local LDBI = LibStub("LibDBIcon-1.0", true)
  if not LDBI or not LDBI.objects then
    return nil
  end
  for name, btn in pairs(LDBI.objects) do
    if btn == f then
      return name
    end
  end
  return nil
end

function MB:FixLdbButton(f)
  local LDBI = LibStub("LibDBIcon-1.0", true)
  if not LDBI then
    return
  end
  local ldbName = self:LdbNameFromButton(f)
  if not ldbName then
    return
  end
  --- En la barra, LibDBIcon sigue registrado en el minimapa: el fundido global al salir del mapa
  --- afecta a todos los botones con showOnMouseover. Forzar siempre visibles aquí.
  if LDBI.ShowOnEnter then
    LDBI:ShowOnEnter(ldbName, false)
  end
  f:SetAlpha(1)
  if barOpts().lockLdb ~= false then
    if LDBI.Lock then
      LDBI:Lock(ldbName)
    end
    if f.SetMovable then
      f:SetMovable(false)
    end
    if f.RegisterForDrag then
      f:RegisterForDrag()
    end
  else
    if LDBI.Unlock then
      LDBI:Unlock(ldbName)
    end
    if f.RegisterForDrag then
      f:RegisterForDrag("LeftButton")
    end
  end
  self.capturedLDB[ldbName] = true
end

local function getOriginIconTexture(orig)
  if not orig then
    return nil
  end
  local t = orig.icon
  if t and t.GetObjectType and t:GetObjectType() == "Texture" then
    return t
  end
  if orig.IconTexture and orig.IconTexture.GetObjectType and orig.IconTexture:GetObjectType() == "Texture" then
    return orig.IconTexture
  end
  t = orig.Icon
  if t and t.GetObjectType and t:GetObjectType() == "Texture" then
    return t
  end
  return nil
end

function MB:SyncProxyFromOrigin(proxy, orig)
  if not proxy or not proxy.icon or not orig then
    return
  end
  local oIcon = getOriginIconTexture(orig)
  if not oIcon then
    return
  end
  if oIcon.GetTexture then
    local tex = oIcon:GetTexture()
    if tex then
      proxy.icon:SetTexture(tex)
    end
  end
  if oIcon.GetMaskTexture and proxy.icon.SetMaskTexture then
    local ok, mask = pcall(function()
      return oIcon:GetMaskTexture()
    end)
    if ok and mask then
      pcall(function()
        proxy.icon:SetMaskTexture(mask)
      end)
    end
  end
  if oIcon.GetTexCoord then
    local a, b, c, d, e, fcoord, g, h = oIcon:GetTexCoord()
    if h then
      proxy.icon:SetTexCoord(a, b, c, d, e, fcoord, g, h)
    elseif d then
      proxy.icon:SetTexCoord(a, b, c, d)
    end
  end
  if oIcon.GetVertexColor then
    local r, g, b, a = oIcon:GetVertexColor()
    proxy.icon:SetVertexColor(r, g, b, a)
  end
end

function MB:EnsureProxyIconHooks(orig)
  if not orig or orig.chukieProxyIconHooked then
    return
  end
  local oIcon = getOriginIconTexture(orig)
  if not oIcon then
    return
  end
  orig.chukieProxyIconHooked = true
  hooksecurefunc(oIcon, "SetTexture", function()
    local p = orig.chukieActiveProxy
    if p and p.chukieIsMinimapProxy then
      MB:SyncProxyFromOrigin(p, orig)
    end
  end)
  hooksecurefunc(oIcon, "SetTexCoord", function()
    local p = orig.chukieActiveProxy
    if p and p.chukieIsMinimapProxy then
      MB:SyncProxyFromOrigin(p, orig)
    end
  end)
end

function MB:WireProxy(proxy, orig)
  proxy.chukieSource = orig
  orig.chukieActiveProxy = proxy
  proxy:RegisterForClicks("AnyUp", "AnyDown")
  proxy:SetScript("OnMouseDown", function(self, button)
    local o = self.chukieSource
    if not o then
      return
    end
    local h = o:GetScript("OnMouseDown")
    if h then
      h(o, button)
    end
  end)
  proxy:SetScript("OnMouseUp", function(self, button)
    local o = self.chukieSource
    if not o then
      return
    end
    local h = o:GetScript("OnMouseUp")
    if h then
      h(o, button)
    end
  end)
  proxy:SetScript("OnClick", function(self, button)
    local o = self.chukieSource
    if not o then
      return
    end
    local h = o:GetScript("OnClick")
    if h then
      h(o, button)
    end
  end)
  proxy:SetScript("OnEnter", function(self)
    local o = self.chukieSource
    if not o then
      return
    end
    local h = o:GetScript("OnEnter")
    if h then
      h(o)
    end
  end)
  proxy:SetScript("OnLeave", function(self)
    local o = self.chukieSource
    if not o then
      return
    end
    local h = o:GetScript("OnLeave")
    if h then
      h(o)
    end
  end)
  self:EnsureProxyIconHooks(orig)
end

function MB:ProxySanitizeName(n)
  return (n:gsub("[^%w_]", "_"):sub(1, 50))
end

function MB:GetOrCreateProxy(sourceFrameName, orig)
  local safe = self:ProxySanitizeName(sourceFrameName)
  local pname = "ChukieUi_mmproxy_" .. safe
  local p = _G[pname]
  if not p then
    p = CreateFrame("Button", pname, self.bar)
    p:SetFrameStrata("MEDIUM")
    local tex = p:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    p.icon = tex
    p.chukieIsMinimapProxy = true
  else
    p:SetParent(self.bar)
    if not p.icon then
      local tex = p:CreateTexture(nil, "ARTWORK")
      tex:SetAllPoints()
      p.icon = tex
    end
    p.chukieIsMinimapProxy = true
  end
  p:SetSize(self:GetAddonBarIconWidth(), self:GetAddonBarIconHeight())
  p:Show()
  return p
end

--- Botón real oculto en el minimapa; hijos de la barra = proxies con icono y scripts reenviados.
function MB:InstallBarProxies(list)
  if not self.bar then
    return
  end
  for _, orig in ipairs(list) do
    if orig and orig ~= self.bar then
      local n = orig:GetName()
      if n and n ~= "" then
        self:FixLdbButton(orig)
        self:EnsureBarOriginalHiddenHook(orig, n)
        orig.chukieBarHiddenActive = true
        orig:Hide()
        if orig.EnableMouse then
          orig:EnableMouse(false)
        end
        local proxy = self:GetOrCreateProxy(n, orig)
        self:WireProxy(proxy, orig)
        self:SyncProxyFromOrigin(proxy, orig)
      end
    end
  end
end

--- LibDBIcon (Retail): anillo y fondo del minimapa; Masque no los toma y quedan encima del skin.
local TEX_MINIMAP_RING = 136430
local TEX_MINIMAP_BG = 136467
local TEX_MINIMAP_HIGHLIGHT = 136477

local function textureIsBlizzardMinimapRingOrBg(r, iconTex)
  if not r or r == iconTex or not r.GetObjectType or r:GetObjectType() ~= "Texture" then
    return false
  end
  local tex = r.GetTexture and r:GetTexture()
  if tex == TEX_MINIMAP_RING or tex == TEX_MINIMAP_BG then
    return true
  end
  if type(tex) == "string" then
    if tex:find("MiniMap%-TrackingBorder", 1, true) or tex:find("UI%-Minimap%-Background", 1, true) then
      return true
    end
  end
  local at = r.GetAtlas and r:GetAtlas()
  if type(at) == "string" then
    local low = at:lower()
    if low == "ui-minimap-trackingborder" or low == "minimap-trackingborder" then
      return true
    end
    if low == "ui-minimap-background" then
      return true
    end
    if low:find("trackingborder", 1, true) or low:find("minimap%-tracking", 1, true) then
      return true
    end
    if low:find("minimap", 1, true) and low:find("background", 1, true) then
      return true
    end
  end
  return false
end

function MB:StripMinimapStyleChrome(btn)
  if not btn then
    return
  end
  local isLdb = (btn:GetName() or ""):match("^LibDBIcon10_") or (self:LdbNameFromButton(btn) ~= nil)
  if isLdb then
    if btn.border and btn.border.Hide then
      btn.border:Hide()
    end
    if btn.background and btn.background.Hide then
      btn.background:Hide()
    end
  end
  for _, r in ipairs(listFrameRegions(btn)) do
    if textureIsBlizzardMinimapRingOrBg(r, btn.icon) then
      r:Hide()
    end
  end
  if isLdb and btn.SetHighlightTexture then
    btn:SetHighlightTexture(nil)
  end
end

function MB:RestoreMinimapStyleChrome(btn)
  if not btn then
    return
  end
  local isLdb = (btn:GetName() or ""):match("^LibDBIcon10_") or (self:LdbNameFromButton(btn) ~= nil)
  if isLdb then
    if btn.border and btn.border.Show then
      btn.border:Show()
    end
    if btn.background and btn.background.Show then
      btn.background:Show()
    end
  end
  for _, r in ipairs(listFrameRegions(btn)) do
    if textureIsBlizzardMinimapRingOrBg(r, btn.icon) then
      r:Show()
    end
  end
  local stub = _G.LibStub
  local LDBI = stub and stub("LibDBIcon-1.0", true)
  local ldbName = self:LdbNameFromButton(btn)
  if LDBI and ldbName and LDBI.ResetButtonHighlightTexture then
    LDBI:ResetButtonHighlightTexture(ldbName)
  else
    local n = btn:GetName()
    if n and n:match("^LibDBIcon10_") and btn.SetHighlightTexture then
      btn:SetHighlightTexture(TEX_MINIMAP_HIGHLIGHT)
    end
  end
end

function MB:IsLibDbMinimapBarButton(f)
  if not f then
    return false
  end
  local n = f:GetName() or ""
  if n:match("^LibDBIcon10_") then
    return true
  end
  return self:LdbNameFromButton(f) ~= nil
end

function MB:GetMasqueGroup()
  if barOpts().useMasque == false then
    return nil
  end
  local stub = _G.LibStub
  if not stub then
    return nil
  end
  local msq = stub("Masque", true)
  if not msq or type(msq.Group) ~= "function" then
    return nil
  end
  if not self._masqueGroup then
    --- ID de perfil Masque: «Chukie UI_MinimapBar» (addon + subgrupo).
    self._masqueGroup = msq:Group("Chukie UI", "MinimapBar")
  end
  return self._masqueGroup
end

--- Grupo Masque solo para botones del micromenú (independiente de `useMasque` de la barra de addons).
function MB:GetMasqueMicroGroup()
  if barOpts().useMasqueMicromenu == false then
    return nil
  end
  local stub = _G.LibStub
  if not stub then
    return nil
  end
  local msq = stub("Masque", true)
  if not msq or type(msq.Group) ~= "function" then
    return nil
  end
  if not self._masqueMicroGroup then
    self._masqueMicroGroup = msq:Group("Chukie UI", "MinimapBarMicroMenu")
  end
  return self._masqueMicroGroup
end

local function masqueRegionsMicroButton(btn)
  if not btn then
    return nil
  end
  local icon = btn.icon or btn.Icon or btn.Portrait or btn.portrait
  if icon and icon.GetObjectType and icon:GetObjectType() == "Texture" then
    return {
      Icon = icon,
      Normal = false,
      Disabled = false,
      Pushed = false,
      Flash = false,
      Checked = false,
      Border = false,
      IconBorder = false,
      DebuffBorder = false,
      EnchantBorder = false,
      Highlight = false,
    }
  end
  local nt = btn.GetNormalTexture and btn:GetNormalTexture()
  if nt and nt.GetObjectType and nt:GetObjectType() == "Texture" then
    return {
      Icon = nt,
      Normal = false,
      Disabled = false,
      Pushed = false,
      Flash = false,
      Checked = false,
      Border = false,
      IconBorder = false,
      DebuffBorder = false,
      EnchantBorder = false,
      Highlight = false,
    }
  end
  return nil
end

function MB:MasqueStripMicromenu()
  local grp = self._masqueMicroGroup
  if not grp or type(grp.RemoveButton) ~= "function" then
    return
  end
  for _, btn in ipairs(self:GetMicroMenuButtonFrames()) do
    grp:RemoveButton(btn)
  end
end

function MB:MasqueApplyMicromenu()
  if barOpts().useMasqueMicromenu == false or not self.miniMenuBar then
    self:MasqueStripMicromenu()
    return
  end
  local grp = self:GetMasqueMicroGroup()
  if not grp then
    return
  end
  for _, btn in ipairs(self:GetMicroMenuButtonFrames()) do
    grp:RemoveButton(btn)
  end
  for _, btn in ipairs(self:GetMicroMenuButtonFrames()) do
    if btn and btn:GetParent() == self.miniMenuBar and btn:IsShown() then
      local ot = btn.GetObjectType and btn:GetObjectType()
      if ot == "Button" or ot == "CheckButton" then
        local reg = masqueRegionsMicroButton(btn)
        if reg and grp.AddButton then
          grp:AddButton(btn, reg, "Legacy")
        end
      end
    end
  end
  if grp.ReSkin then
    grp:ReSkin()
  end
end

function MB:MasqueStripBar()
  local grp = self._masqueGroup
  if not grp or not self.bar then
    return
  end
  for _, f in ipairs(listFrameChildren(self.bar)) do
    grp:RemoveButton(f)
    if not f.chukieIsMinimapProxy then
      self:RestoreMinimapStyleChrome(f)
    end
  end
end

--- Quita cromado LibDBIcon en todos los botones de la barra (tras Masque y tras Show de políticas).
function MB:MasqueRestripBarChrome()
  if barOpts().useMasque == false or not self.bar then
    return
  end
  for _, f in ipairs(listFrameChildren(self.bar)) do
    local ot = f.GetObjectType and f:GetObjectType()
    if ot == "Button" or ot == "CheckButton" then
      self:StripMinimapStyleChrome(f)
    end
  end
end

--- Regiones para LDB/minimapa: el `Button` por defecto trae NormalTexture (hueco negro) que no es de LibDBIcon;
--- Masque la pintaba como marco de acción. Forzar capas a false (API Masque: Normal ~= false → no skin).
local function masqueRegionsMinimapLauncher(btn)
  if not btn or not btn.icon then
    return nil
  end
  return {
    Icon = btn.icon,
    Normal = false,
    Disabled = false,
    Pushed = false,
    Flash = false,
    Checked = false,
    Border = false,
    IconBorder = false,
    DebuffBorder = false,
    EnchantBorder = false,
    Highlight = false,
  }
end

--- Registra botones de la barra con Masque (tipo Legacy: icon, border, normal… como LibDBIcon).
function MB:MasqueApplyBar()
  if barOpts().useMasque == false then
    self:MasqueStripBar()
    return
  end
  local grp = self:GetMasqueGroup()
  if not grp or not self.bar then
    return
  end
  for _, f in ipairs(listFrameChildren(self.bar)) do
    local ot = f.GetObjectType and f:GetObjectType()
    if ot == "Button" or ot == "CheckButton" then
      local reg = masqueRegionsMinimapLauncher(f)
      grp:AddButton(f, reg, "Legacy")
    end
  end
  self:MasqueRestripBarChrome()
  if grp.ReSkin then
    grp:ReSkin()
  end
end

function MB:ReleaseAll()
  self.capturedLDB = self.capturedLDB or {}
  if not self.bar then
    wipe(self.capturedLDB)
    return
  end
  self:MasqueStripBar()
  local LDBI = LibStub("LibDBIcon-1.0", true)
  local kids = listFrameChildren(self.bar)
  for _, f in ipairs(kids) do
    if f.chukieIsMinimapProxy then
      local orig = f.chukieSource
      f.chukieSource = nil
      if orig then
        orig.chukieActiveProxy = nil
        orig.chukieBarHiddenActive = nil
        if orig.EnableMouse then
          orig:EnableMouse(true)
        end
        local ldbName = self:LdbNameFromButton(orig)
        if LDBI and ldbName then
          if LDBI.ShowOnEnter then
            LDBI:ShowOnEnter(ldbName, true)
          end
          if LDBI.Unlock then
            LDBI:Unlock(ldbName)
          end
          if orig.RegisterForDrag then
            orig:RegisterForDrag("LeftButton")
          end
          if LDBI.Show then
            LDBI:Show(ldbName)
          end
        end
      end
      f:SetScript("OnMouseDown", nil)
      f:SetScript("OnMouseUp", nil)
      f:SetScript("OnClick", nil)
      f:SetScript("OnEnter", nil)
      f:SetScript("OnLeave", nil)
      f:SetParent(nil)
      f:Hide()
    else
      local orig = f.chukieOrigParent or Minimap
      f:SetParent(orig)
      restorePoints(f, f.chukieSavedPoints)
      f.chukieSavedPoints = nil
      f.chukieOrigParent = nil
      local ldbName = self:LdbNameFromButton(f)
      if LDBI and ldbName then
        if LDBI.ShowOnEnter then
          LDBI:ShowOnEnter(ldbName, true)
        end
        if LDBI.Unlock then
          LDBI:Unlock(ldbName)
        end
        if f.RegisterForDrag then
          f:RegisterForDrag("LeftButton")
        end
        if LDBI.Show then
          LDBI:Show(ldbName)
        end
      end
    end
  end
  self.bar:Hide()
  wipe(self.capturedLDB)
end

function MB:LayoutMiniMenuBar()
  local mm = self.miniMenuBar
  if not mm then
    return
  end
  mm:SetHeight(self:GetMiniMenuBarHeight())
  --- La posición horizontal/vertical la fija PositionMicromenuCentered tras el layout de botones.
end

function MB:Layout()
  if not self.bar then
    return
  end
  local iw, ih, sp = self:GetAddonBarIconWidth(), self:GetAddonBarIconHeight(), self:GetAddonBarSpacing()
  local x = sp
  local kids = listFrameChildren(self.bar)
  for _, f in ipairs(kids) do
    f:ClearAllPoints()
    f:SetPoint("LEFT", self.bar, "LEFT", x, 0)
    f:SetSize(iw, ih)
    x = x + iw + sp
  end
  self.bar:SetWidth(math.max(x, 48))
  self.bar:SetHeight(ih + 4)
  self:PositionAddonBarCentered()
end

function MB:EnsureBar()
  local parent = getRightPanelBaseFrame()
  if self.bar then
    if parent and self.bar:GetParent() ~= parent then
      self.bar:SetParent(parent)
    end
    return
  end
  self.capturedLDB = {}
  local bar = CreateFrame("Frame", "ChukieUi_MinimapButtonBar", parent)
  bar:SetFrameStrata("MEDIUM")
  bar:SetFixedFrameStrata(true)
  bar:SetFrameLevel(((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 3) + 3)
  bar:SetHeight(self:GetAddonBarIconHeight() + 4)
  self.bar = bar
  self:PositionAddonBarCentered()
end

function MB:EnsureMiniMenuBar()
  local parent = getRightPanelBaseFrame()
  if self.miniMenuBar then
    if parent and self.miniMenuBar:GetParent() ~= parent then
      self.miniMenuBar:SetParent(parent)
    end
    return
  end
  local mm = CreateFrame("Frame", "ChukieUi_MiniMenuButtonBar", parent)
  mm:SetFrameStrata("MEDIUM")
  mm:SetFixedFrameStrata(true)
  mm:SetFrameLevel(((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 3) + 2)
  mm:SetHeight(self:GetMiniMenuBarHeight())
  self.miniMenuBar = mm
end

function MB:EnsureLdbHooks()
  if self.ldbHooks then
    return
  end
  local parent = getRightPanelBaseFrame()
  if not self.ldbHookHolder then
    self.ldbHookHolder = CreateFrame("Frame", "ChukieUi_LdbHookHolder", parent)
    self.ldbHookHolder:Hide()
  elseif parent and self.ldbHookHolder:GetParent() ~= parent then
    self.ldbHookHolder:SetParent(parent)
  end
  local LDBI = LibStub("LibDBIcon-1.0", true)
  if not LDBI or type(LDBI.RegisterCallback) ~= "function" then
    return
  end
  self.ldbHooks = true
  LDBI.RegisterCallback(self.ldbHookHolder, "LibDBIcon_IconCreated", function(eventName, button, name)
    if eventName == "LibDBIcon_IconCreated" and barOpts().enabled ~= false then
      self:ScheduleRefresh()
    end
  end)
  hooksecurefunc(LDBI, "Show", function(lib, name)
    if not name then
      return
    end
    local btn = lib:GetMinimapButton(name)
    if btn then
      local nn = btn:GetName()
      if nn and MB:GetFramePolicy(nn) == "hidden" then
        btn:Hide()
        MB:EnsureAddonPolicyHook(btn, nn)
      end
    end
    if barOpts().enabled ~= false and btn then
      local nn = btn:GetName()
      if nn and MB:ShouldPlaceOnBar(btn) then
        self:ScheduleRefresh()
      end
    end
  end)
  hooksecurefunc(LDBI, "Refresh", function(lib, name)
    if barOpts().enabled ~= false and name then
      local btn = lib:GetMinimapButton(name)
      if btn then
        local nn = btn:GetName()
        if nn and MB:ShouldPlaceOnBar(btn) then
          self:ScheduleRefresh()
        end
      end
    end
  end)
end

function MB:ScheduleRefresh()
  if self.refreshPending then
    return
  end
  self.refreshPending = true
  C_Timer.After(0.05, function()
    self.refreshPending = false
    self:Refresh()
  end)
end

function MB:Refresh()
  if ns.RightPanel and ns.RightPanel.SyncRightPanelTreeLayout then
    ns.RightPanel:SyncRightPanelTreeLayout()
  end
  self:MasqueStripMicromenu()
  self:ReleaseAll()
  self:UpdateDiscoveredOrder()
  if ns.AppendMinimapDiscoveryPolicyRows then
    ns.AppendMinimapDiscoveryPolicyRows()
  end
  if ns.AppendMinimenuVisibilityRows then
    ns.AppendMinimenuVisibilityRows()
  end
  self:ApplyBlizzardStripOrRestore()
  self:ApplyAddonButtonPolicies()
  if not prof().enabled then
    self:RestoreMicroMenuButtonsFromChukieBar()
    return
  end
  if not Minimap then
    self:RestoreMicroMenuButtonsFromChukieBar()
    return
  end
  self:EnsureLdbHooks()
  local showAddonBar = barOpts().enabled ~= false
  local showMiniMenu = barOpts().minimenuBarEnabled ~= false

  if showAddonBar then
    self:EnsureBar()
    self.bar:Show()
    local list = self:CollectFrames()
    self:InstallBarProxies(list)
    self:Layout()
    self:MasqueApplyBar()
  else
    if self.bar then
      self.bar:Hide()
    end
  end

  if showMiniMenu then
    self:EnsureMiniMenuBar()
    self:EnsureMicroMenuHooks()
    self:LayoutMiniMenuBar()
    self:LayoutMicroMenuEmbedded()
    self.miniMenuBar:Show()
  else
    self:RestoreMicroMenuButtonsFromChukieBar()
    if self.miniMenuBar then
      self.miniMenuBar:Hide()
    end
  end

  self:ApplyBlizzardStripOrRestore()
  self:ApplyAddonButtonPolicies()
  if ns.RightPanel and ns.RightPanel.UpdateDebugRightPanelOutline then
    ns.RightPanel:UpdateDebugRightPanelOutline()
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "Masque" then
    MB:ScheduleRefresh()
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    MB:Refresh()
    C_Timer.After(0.5, function()
      MB:Refresh()
    end)
    C_Timer.After(2, function()
      MB:Refresh()
    end)
  end
end)

do
  local zoomEv = CreateFrame("Frame")
  local zoomDeb
  zoomEv:RegisterEvent("MINIMAP_UPDATE_ZOOM")
  zoomEv:SetScript("OnEvent", function()
    if zoomDeb then
      return
    end
    zoomDeb = true
    C_Timer.After(0, function()
      zoomDeb = false
      if MB.ApplyBlizzardStripOrRestore then
        MB:ApplyBlizzardStripOrRestore()
      end
    end)
  end)
end
