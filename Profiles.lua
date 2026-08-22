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
    alerts = { enabled = false, nextId = 1, rules = {}, groups = {}, tickInterval = 0.15 },
    actionBars = {},
    horizontalCompass = {},
    auraPanel = { auras = {} },
    partyGrid = {},
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
    if
      (k == "teleportGridVisibility"
        or k == "combatLogTypes"
        or k == "combatLogInstances"
        or k == "combatLogInstanceNames")
      and type(v) == "table"
    then
      local np = {}
      for pk, pv in pairs(v) do
        np[pk] = pv
      end
      t.widgets.rightPanelWidgets[k] = np
    else
      t.widgets.rightPanelWidgets[k] = v
    end
  end
  for k, v in pairs(src.cvars or {}) do
    t.cvars[k] = v
  end
  if type(src.alerts) == "table" then
    t.alerts.enabled = src.alerts.enabled == true
    t.alerts.nextId = math.floor(tonumber(src.alerts.nextId) or 1)
    t.alerts.tickInterval = tonumber(src.alerts.tickInterval) or 0.15
    if t.alerts.nextId < 1 then
      t.alerts.nextId = 1
    end
    t.alerts.rules = {}
    if type(src.alerts.rules) == "table" then
      for i = 1, #src.alerts.rules do
        local r = src.alerts.rules[i]
        if type(r) == "table" then
          local nr = {}
          for rk, rv in pairs(r) do
            if rk == "point" and type(rv) == "table" then
              nr.point = { rv[1], rv[2], rv[3] }
            elseif rk == "color" and type(rv) == "table" then
              nr.color = { tonumber(rv[1]) or 1, tonumber(rv[2]) or 1, tonumber(rv[3]) or 1 }
            elseif rk == "overlayFx" and type(rv) == "table" then
              nr.overlayFx = {
                pulse = rv.pulse == true,
                color = rv.color == true,
                shake = rv.shake == true,
                glow = rv.glow == true,
              }
            elseif rk == "chargeFilter" and type(rv) == "table" then
              nr.chargeFilter = {
                enabled = rv.enabled == true,
                op = rv.op or "gte",
                value = math.floor(tonumber(rv.value) or 1),
              }
            elseif type(rv) ~= "table" then
              nr[rk] = rv
            end
          end
          t.alerts.rules[#t.alerts.rules + 1] = nr
        end
      end
    end
    t.alerts.groups = {}
    if type(src.alerts.groups) == "table" then
      for i = 1, #src.alerts.groups do
        local g = src.alerts.groups[i]
        if type(g) == "table" then
          local ng = {
            id = g.id,
            name = g.name,
            enabled = g.enabled ~= false,
            ruleLogic = g.ruleLogic == "or" and "or" or "and",
            overlayFx = nil,
            rules = {},
            effects = {},
          }
          if type(g.overlayFx) == "table" then
            ng.overlayFx = {
              pulse = g.overlayFx.pulse == true,
              color = g.overlayFx.color == true,
              shake = g.overlayFx.shake == true,
              glow = g.overlayFx.glow == true,
            }
          end
          if type(g.rules) == "table" then
            for ri = 1, #g.rules do
              local r = g.rules[ri]
              if type(r) == "table" then
                local nr = {}
                for rk, rv in pairs(r) do
                  if type(rv) ~= "table" then
                    nr[rk] = rv
                  end
                end
                ng.rules[#ng.rules + 1] = nr
              end
            end
          end
          if type(g.effects) == "table" then
            for ei = 1, #g.effects do
              local e = g.effects[ei]
              if type(e) == "table" then
                local ne = {}
                for ek, ev in pairs(e) do
                  if ek == "point" and type(ev) == "table" then
                    ne.point = { ev[1], ev[2], ev[3] }
                  elseif ek == "color" and type(ev) == "table" then
                    ne.color = { tonumber(ev[1]) or 1, tonumber(ev[2]) or 1, tonumber(ev[3]) or 1 }
                  elseif type(ev) ~= "table" then
                    ne[ek] = ev
                  end
                end
                ng.effects[#ng.effects + 1] = ne
              end
            end
          end
          t.alerts.groups[#t.alerts.groups + 1] = ng
        end
      end
    end
    -- Preserve legacy cd/proc so EnsureSchema can migrate after clone.
    if type(src.alerts.cd) == "table" then
      t.alerts.cd = {}
      for rk, rv in pairs(src.alerts.cd) do
        if rk == "point" and type(rv) == "table" then
          t.alerts.cd.point = { rv[1], rv[2], rv[3] }
        elseif type(rv) ~= "table" then
          t.alerts.cd[rk] = rv
        end
      end
    end
    if type(src.alerts.proc) == "table" then
      t.alerts.proc = {}
      for rk, rv in pairs(src.alerts.proc) do
        if rk == "point" and type(rv) == "table" then
          t.alerts.proc.point = { rv[1], rv[2], rv[3] }
        elseif type(rv) ~= "table" then
          t.alerts.proc[rk] = rv
        end
      end
    end
  end
  if type(src.actionBars) == "table" then
    for k, v in pairs(src.actionBars) do
      if k == "leftButtonAlphaPercent" and type(v) == "table" then
        t.actionBars.leftButtonAlphaPercent = {}
        for barId = 1, 4 do
          local sourceRow = v[barId]
          if type(sourceRow) == "table" then
            local targetRow = {}
            t.actionBars.leftButtonAlphaPercent[barId] = targetRow
            for buttonIndex = 1, 6 do
              targetRow[buttonIndex] = sourceRow[buttonIndex]
            end
          end
        end
      elseif type(v) ~= "table" then
        t.actionBars[k] = v
      end
    end
  end
  if type(src.horizontalCompass) == "table" then
    for k, v in pairs(src.horizontalCompass) do
      if type(v) ~= "table" then
        t.horizontalCompass[k] = v
      end
    end
  end
  if type(src.auraPanel) == "table" then
    for k, v in pairs(src.auraPanel) do
      if k == "point" and type(v) == "table" then
        t.auraPanel.point = { v[1], v[2], v[3] }
      elseif k == "auras" and type(v) == "table" then
        for i = 1, #v do
          local a = v[i]
          if type(a) == "table" then
            t.auraPanel.auras[#t.auraPanel.auras + 1] = {
              spellId = a.spellId,
              enabled = a.enabled,
              unit = a.unit,
              filter = a.filter,
            }
          end
        end
      elseif type(v) ~= "table" then
        t.auraPanel[k] = v
      end
    end
  end
  if type(src.partyGrid) == "table" then
    for k, v in pairs(src.partyGrid) do
      if k == "point" and type(v) == "table" then
        t.partyGrid.point = { v[1], v[2], v[3] }
      elseif k == "columnSpells" and type(v) == "table" then
        t.partyGrid.columnSpells = {}
        for column, spellId in pairs(v) do
          t.partyGrid.columnSpells[column] = spellId
        end
      elseif k == "columnCycles" and type(v) == "table" then
        t.partyGrid.columnCycles = {}
        for column, enabled in pairs(v) do
          t.partyGrid.columnCycles[column] = enabled
        end
      elseif k == "columnCycleUnits" and type(v) == "table" then
        t.partyGrid.columnCycleUnits = {}
        for column, units in pairs(v) do
          if type(units) == "table" then
            t.partyGrid.columnCycleUnits[column] = {}
            for i = 1, #units do
              t.partyGrid.columnCycleUnits[column][i] = units[i]
            end
          end
        end
      elseif type(v) ~= "table" then
        t.partyGrid[k] = v
      end
    end
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
  p.actionBars = p.actionBars or {}
  --- Las barras izquierdas ya no tienen cantidad configurable: siempre son 6 × 4.
  p.actionBars.leftNumButtons = nil
  p.actionBars.leftNumButtonsPerBar = nil
  p.actionBars.leftButtonAlphaPercent =
    type(p.actionBars.leftButtonAlphaPercent) == "table" and p.actionBars.leftButtonAlphaPercent or {}
  p.horizontalCompass = p.horizontalCompass or {}
  p.auraPanel = p.auraPanel or {}
  p.auraPanel.auras = p.auraPanel.auras or {}
  --- PartyGrid prohíbe incluso reparaciones de esquema durante combate: un perfil
  --- antiguo se completa al cargar o en PLAYER_REGEN_ENABLED, nunca al consultarlo.
  local combat = InCombatLockdown and InCombatLockdown()
  if not combat then
    if type(p.partyGrid) ~= "table" then
      p.partyGrid = {}
    end
    if type(p.partyGrid.columnSpells) ~= "table" then
      p.partyGrid.columnSpells = {}
    end
    if type(p.partyGrid.columnCycles) ~= "table" then
      p.partyGrid.columnCycles = {}
    end
    if type(p.partyGrid.columnCycleUnits) ~= "table" then
      p.partyGrid.columnCycleUnits = {}
    end
  end
  p.alerts = p.alerts or { enabled = false, nextId = 1, rules = {}, groups = {} }
  p.alerts.rules = p.alerts.rules or {}
  p.alerts.groups = p.alerts.groups or {}
  if ns.Alerts and ns.Alerts.EnsureSchema then
    ns.Alerts:EnsureSchema(p.alerts)
  end
end

function ns.Profile:GetAlertsModel()
  local p = self:GetActive()
  ensurePanelWidgetSchema(p)
  return p.alerts
end

function ns.Profile:GetAuraPanelModel()
  local p = self:GetActive()
  ensurePanelWidgetSchema(p)
  return p.auraPanel
end

function ns.Profile:GetPartyGridModel()
  local p = self:GetActive()
  ensurePanelWidgetSchema(p)
  return type(p.partyGrid) == "table" and p.partyGrid or {}
end

function ns.Profile:GetHorizontalCompassModel()
  local p = self:GetActive()
  ensurePanelWidgetSchema(p)
  return p.horizontalCompass
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
  self:MigrateActionBarsLeftCenterAnchor()
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

--- Las barras 1–4 son fijas en 6 botones. Las claves configurables anteriores se eliminan
--- incluso en perfiles ya migrados para que no parezca que todavía gobiernan el layout.
function ns.Profile:MigrateActionBarsLeftButtons()
  local a = self:GetActive().actionBars
  if not a then
    return
  end
  a._leftBars6Applied = true
  a.leftNumButtons = nil
  a.leftNumButtonsPerBar = nil
  a.leftButtonAlphaPercent =
    type(a.leftButtonAlphaPercent) == "table" and a.leftButtonAlphaPercent or {}
end

--- El bloque de barras 1–4 pasó de anclarse en la esquina del panel izquierdo al centro
--- de la pantalla: los offsets viejos apuntaban a otro origen, así que se reinician una vez.
function ns.Profile:MigrateActionBarsLeftCenterAnchor()
  local a = self:GetActive().actionBars
  if not a or a._leftCenterAnchorApplied then
    return
  end
  a._leftCenterAnchorApplied = true
  a.leftOffsetX = 0
  a.leftOffsetY = 0
end

function ns.Profile:Initialize()
  self:Migrate()
  self:MigrateMinimapBarPixelOptions()
  if ns.CopyDefaultsIntoProfile then
    ns.CopyDefaultsIntoProfile(self:GetActive())
  end
  self:MigrateMinimapBarPixelOptions()
  self:MigrateActionBarsLeftButtons()
  self:MigrateActionBarsLeftCenterAnchor()
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
