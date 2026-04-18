--[[ Minimapa — Retail 12.0.1 (## Interface: 120001 en el .toc).
     - «Solo mapa»: STRIP_FRAMES + descendientes nombrados + marcos del cluster (TrackingFrame, ZoomIn/Out del mapa, InstanceDifficulty, IndicatorFrame…).
     - Addons: barra + política por botón (Defecto / Barra / Oculto) en minimapBar.buttonPolicy + discoveredOrder.
     - Barra «Bar»: el botón real (LibDBIcon, Zygor, etc.) permanece en el minimapa pero oculto; la barra usa botones proxy
       (icono copiado + clic/tooltip reenviados) para que Masque funcione sin tocar el marco LibDBIcon. ]]

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
  local m = prof().minimapBar
  m.buttonPolicy = m.buttonPolicy or {}
  m.discoveredOrder = m.discoveredOrder or {}
  return m
end

function MB:ProfileRotateMinimap()
  if not prof().enabled then
    return false
  end
  local m = prof().minimapPosition or {}
  return m.rotateMinimap == true
end

local function getRotateMinimapCvarBool()
  if C_CVar and C_CVar.GetCVarBool then
    return C_CVar.GetCVarBool("rotateMinimap")
  end
  local s = GetCVar and GetCVar("rotateMinimap")
  return s == "1"
end

--- Con «Solo mapa» + rotación en perfil: no stripar norte/brújula como el resto; alinear con el CVar.
function MB:ApplyNorthCompassAfterStrip()
  if not self:ShouldStripBlizzardChrome() or not self:ProfileRotateMinimap() then
    return
  end
  local north = MinimapNorthTag
  local comp = MinimapCompassTexture
  for _, f in ipairs({ north, comp }) do
    if f then
      f.chukieStripChrome = nil
    end
  end
  if getRotateMinimapCvarBool() then
    if north then
      north:Hide()
    end
    if comp then
      comp:Show()
    end
  else
    if north then
      north:Hide()
    end
    if comp then
      comp:Hide()
    end
  end
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

function MB:GetCell()
  local v = barOpts() and tonumber(barOpts().cellSize)
  v = v or 34
  return math.max(22, math.min(48, math.floor(v + 0.5)))
end

function MB:GetPad()
  local v = barOpts() and tonumber(barOpts().pad)
  v = v or 4
  return math.max(0, math.min(16, math.floor(v + 0.5)))
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
  if not f or f == self.bar then
    return true
  end
  local n = f:GetName() or ""
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
    p:SetSize(self:GetCell(), self:GetCell())
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

function MB:Layout()
  if not self.bar then
    return
  end
  local cell, pad = self:GetCell(), self:GetPad()
  local x = pad
  local kids = listFrameChildren(self.bar)
  for _, f in ipairs(kids) do
    f:ClearAllPoints()
    f:SetPoint("LEFT", self.bar, "LEFT", x, 0)
    f:SetSize(cell, cell)
    x = x + cell + pad
  end
  self.bar:SetWidth(math.max(x, 48))
  self.bar:SetHeight(self:GetCell() + self:GetPad() * 2)
end

function MB:EnsureBar()
  if self.bar then
    return
  end
  self.capturedLDB = {}
  local parent = MinimapCluster or UIParent
  local bar = CreateFrame("Frame", "ChukieUi_MinimapButtonBar", parent)
  bar:SetFrameStrata("MEDIUM")
  bar:SetFixedFrameStrata(true)
  bar:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 3) + 3)
  bar:SetHeight(self:GetCell() + self:GetPad() * 2)
  if Minimap then
    bar:SetPoint("TOP", Minimap, "BOTTOM", 0, -4)
  else
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -80, -80)
  end
  self.bar = bar
end

function MB:EnsureLdbHooks()
  if self.ldbHooks or not self.bar then
    return
  end
  local LDBI = LibStub("LibDBIcon-1.0", true)
  if not LDBI or type(LDBI.RegisterCallback) ~= "function" then
    return
  end
  self.ldbHooks = true
  LDBI.RegisterCallback(self.bar, "LibDBIcon_IconCreated", function(eventName, button, name)
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
    if barOpts().enabled ~= false and btn and self.bar then
      local nn = btn:GetName()
      if nn and MB:ShouldPlaceOnBar(btn) then
        self:ScheduleRefresh()
      end
    end
  end)
  hooksecurefunc(LDBI, "Refresh", function(lib, name)
    if barOpts().enabled ~= false and name then
      local btn = lib:GetMinimapButton(name)
      if btn and self.bar then
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
  self:ReleaseAll()
  self:UpdateDiscoveredOrder()
  if ns.AppendMinimapDiscoveryPolicyRows then
    ns.AppendMinimapDiscoveryPolicyRows()
  end
  self:ApplyBlizzardStripOrRestore()
  self:ApplyAddonButtonPolicies()
  if not prof().enabled then
    return
  end
  if barOpts().enabled == false then
    return
  end
  if not Minimap then
    return
  end
  self:EnsureBar()
  self:EnsureLdbHooks()
  self.bar:Show()
  local list = self:CollectFrames()
  self:InstallBarProxies(list)
  self:Layout()
  self:ApplyBlizzardStripOrRestore()
  self:ApplyAddonButtonPolicies()
  self:MasqueApplyBar()
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
