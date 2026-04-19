--[[ Perfiles: varios conjuntos de opciones; «Default» contiene valores válidos por defecto. ]]

local _, ns = ...

local DEFAULT_NAME = "Default"

ns.Profile = ns.Profile or {}

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

local function cloneProfileData(src)
  local t = {
    enabled = src.enabled,
    minimapBar = {},
    minimapPosition = {},
    panels = { rightPanel = {} },
    widgets = { minimapBar = {}, rightPanelWidgets = {} },
    cvars = {},
  }
  for k, v in pairs(src.minimapPosition or {}) do
    t.minimapPosition[k] = v
    t.panels.rightPanel[k] = v
  end
  for k, v in pairs(src.minimapBar or {}) do
    if (k == "buttonPolicy" or k == "minimenuVisibility") and type(v) == "table" then
      local np = {}
      for pk, pv in pairs(v) do
        np[pk] = pv
      end
      t.minimapBar[k] = np
      t.widgets.minimapBar[k] = np
    elseif k == "discoveredOrder" and type(v) == "table" then
      local no = {}
      for i = 1, #v do
        no[i] = v[i]
      end
      t.minimapBar[k] = no
      t.widgets.minimapBar[k] = no
    else
      t.minimapBar[k] = v
      t.widgets.minimapBar[k] = v
    end
  end
  for k, v in pairs((((src.panels or {}).rightPanel) or {})) do
    t.panels.rightPanel[k] = v
    t.minimapPosition[k] = v
  end
  for k, v in pairs((((src.widgets or {}).minimapBar) or {})) do
    t.widgets.minimapBar[k] = v
    t.minimapBar[k] = v
  end
  for k, v in pairs((((src.widgets or {}).rightPanelWidgets) or {})) do
    t.widgets.rightPanelWidgets[k] = v
  end
  for k, v in pairs(src.cvars or {}) do
    t.cvars[k] = v
  end
  return t
end

local function ensurePanelWidgetSchema(p)
  p.panels = p.panels or {}
  p.widgets = p.widgets or {}
  local rightPanel = p.panels.rightPanel or p.minimapPosition or {}
  local minimapBar = p.widgets.minimapBar or p.minimapBar or {}
  local rightWidgets = p.widgets.rightPanelWidgets or {}
  p.panels.rightPanel = rightPanel
  p.widgets.minimapBar = minimapBar
  p.widgets.rightPanelWidgets = rightWidgets
  --- Compatibilidad: rutas legacy apuntan al mismo objeto.
  p.minimapPosition = rightPanel
  p.minimapBar = minimapBar
end

function ns.Profile:Migrate()
  if type(ChukieUiDB.profiles) == "table" and ChukieUiDB.profiles[DEFAULT_NAME] then
    ChukieUiDB.currentProfile = ChukieUiDB.currentProfile or DEFAULT_NAME
    return
  end
  ChukieUiDB.profiles = ChukieUiDB.profiles or {}
  local src = {
    enabled = ChukieUiDB.enabled,
    minimapBar = ChukieUiDB.minimapBar,
    cvars = ChukieUiDB.cvars,
  }
  ChukieUiDB.profiles[DEFAULT_NAME] = cloneProfileData(src)
  ChukieUiDB.currentProfile = DEFAULT_NAME
  ChukieUiDB.enabled = nil
  ChukieUiDB.minimapBar = nil
  ChukieUiDB.cvars = nil
end

function ns.Profile:GetActive()
  self:Migrate()
  local name = ChukieUiDB.currentProfile or DEFAULT_NAME
  local p = ChukieUiDB.profiles[name]
  if not p then
    ChukieUiDB.currentProfile = DEFAULT_NAME
    p = ChukieUiDB.profiles[DEFAULT_NAME]
  end
  ensurePanelWidgetSchema(p)
  p.cvars = p.cvars or {}
  return p
end

function ns.Profile:GetRightPanelModel()
  local p = self:GetActive()
  ensurePanelWidgetSchema(p)
  return p.panels.rightPanel
end

function ns.Profile:GetMinimapBarModel()
  local p = self:GetActive()
  ensurePanelWidgetSchema(p)
  return p.widgets.minimapBar
end

function ns.Profile:GetRightPanelWidgetsModel()
  local p = self:GetActive()
  ensurePanelWidgetSchema(p)
  return p.widgets.rightPanelWidgets
end

function ns.Profile:GetCurrentName()
  return ChukieUiDB.currentProfile or DEFAULT_NAME
end

function ns.Profile:ListSorted()
  local t = {}
  for n in pairs(ChukieUiDB.profiles) do
    t[#t + 1] = n
  end
  table.sort(t, function(a, b)
    if a == DEFAULT_NAME then
      return true
    end
    if b == DEFAULT_NAME then
      return false
    end
    return strlower(a) < strlower(b)
  end)
  return t
end

function ns.Profile:SetCurrent(name)
  if type(name) ~= "string" or not ChukieUiDB.profiles[name] then
    return false
  end
  ChukieUiDB.currentProfile = name
  self:NotifyChanged()
  return true
end

function ns.Profile:NotifyChanged()
  if ns.OnProfileChanged then
    ns.OnProfileChanged()
  end
end

function ns.Profile:MigrateMinimapBarPixelOptions()
  local m = self:GetActive().minimapBar
  if not m then
    return
  end
  --- Una vez: si existía `cellSize`/`pad` de versiones antiguas, copiar a las claves en px (antes de que `CopyDefaultsIntoProfile` rellene solo el defecto).
  if not m._chukieCellToAddonPxDone then
    local cs = tonumber(m.cellSize)
    if cs then
      m.addonBarIconWidth = cs
      m.addonBarIconHeight = tonumber(m.addonBarIconHeight) or cs
      local pd = tonumber(m.pad)
      if pd then
        m.addonBarSpacing = pd
      end
    end
    m._chukieCellToAddonPxDone = true
  end
  if m.addonBarIconWidth == nil then
    m.addonBarIconWidth = tonumber(m.cellSize) or 34
  end
  if m.addonBarIconHeight == nil then
    m.addonBarIconHeight = tonumber(m.addonBarIconWidth) or 34
  end
  if m.addonBarSpacing == nil then
    m.addonBarSpacing = tonumber(m.pad) or 4
  end
  if m.minimenuRowHeight == nil then
    m.minimenuRowHeight = 42
  end
  if m.minimenuIconWidth == nil then
    m.minimenuIconWidth = 28
  end
  if m.minimenuGapBelowAddonBar == nil then
    m.minimenuGapBelowAddonBar = 8
  end
  if m.useMasqueMicromenu == nil then
    m.useMasqueMicromenu = false
  end
  --- Antigua clave única `minimapBarsOffsetX`: misma posición en ambas barras que antes.
  if m.minimapBarsOffsetX ~= nil then
    local leg = tonumber(m.minimapBarsOffsetX) or 0
    leg = math.max(-200, math.min(200, math.floor(leg + 0.5)))
    m.addonBarOffsetX = leg
    m.minimenuBarOffsetX = leg
    m.minimapBarsOffsetX = nil
  end
  if m.addonBarOffsetX == nil then
    m.addonBarOffsetX = 0
  end
  if m.minimenuBarOffsetX == nil then
    m.minimenuBarOffsetX = 0
  end
end

function ns.Profile:Initialize()
  self:Migrate()
  self:MigrateMinimapBarPixelOptions()
  if ns.CopyDefaultsIntoProfile then
    ns.CopyDefaultsIntoProfile(self:GetActive())
  end
  self:MigrateMinimapBarPixelOptions()
end

function ns.Profile:SuggestDuplicateName()
  local base = self:GetCurrentName()
  local n = base .. " (copia)"
  local i = 2
  while ChukieUiDB.profiles[n] do
    n = base .. " (copia " .. i .. ")"
    i = i + 1
  end
  return n
end

function ns.Profile:DuplicateCurrent()
  local name = self:SuggestDuplicateName()
  ChukieUiDB.profiles[name] = cloneProfileData(self:GetActive())
  if ns.CopyDefaultsIntoProfile then
    ns.CopyDefaultsIntoProfile(ChukieUiDB.profiles[name])
  end
  ChukieUiDB.currentProfile = name
  self:MigrateMinimapBarPixelOptions()
  self:NotifyChanged()
  return name
end

function ns.Profile:DeleteCurrent()
  local name = self:GetCurrentName()
  if name == DEFAULT_NAME then
    return false, "No se puede eliminar el perfil «Default»."
  end
  local count = 0
  for _ in pairs(ChukieUiDB.profiles) do
    count = count + 1
  end
  if count <= 1 then
    return false, "Debe existir al menos un perfil."
  end
  ChukieUiDB.profiles[name] = nil
  ChukieUiDB.currentProfile = DEFAULT_NAME
  self:NotifyChanged()
  return true
end

function ns.Profile:ResetCurrentToTemplate()
  local name = self:GetCurrentName()
  ChukieUiDB.profiles[name] = {}
  self:MigrateMinimapBarPixelOptions()
  if ns.CopyDefaultsIntoProfile then
    ns.CopyDefaultsIntoProfile(ChukieUiDB.profiles[name])
  end
  self:MigrateMinimapBarPixelOptions()
  self:NotifyChanged()
  return true
end
