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

local function isSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = deepCopy(v)
  end
  return out
end

--- Personaje-reino y spec actuales. Devuelven nil hasta que el cliente tiene datos.
function ns.Profile.CharKey()
  local name = UnitName and UnitName("player")
  if type(name) ~= "string" or name == "" or isSecret(name) then
    return nil
  end
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName())
    or (GetRealmName and GetRealmName())
    or ""
  if isSecret(realm) then
    return nil
  end
  return name .. "-" .. tostring(realm)
end

function ns.Profile.SpecId()
  if PlayerUtil and PlayerUtil.GetCurrentSpecID then
    local ok, id = pcall(PlayerUtil.GetCurrentSpecID)
    if ok and tonumber(id) then
      return math.floor(tonumber(id))
    end
  end
  local getIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
  local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
  if getIndex and getInfo then
    local okIdx, idx = pcall(getIndex)
    if okIdx and tonumber(idx) then
      local okInfo, id, specName = pcall(getInfo, idx)
      if okInfo and tonumber(id) then
        return math.floor(tonumber(id)), type(specName) == "string" and specName or nil
      end
    end
  end
  return 0
end

function ns.Profile.SpecName()
  local _, name = ns.Profile.SpecId()
  if type(name) == "string" and name ~= "" then
    return name
  end
  local getIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
  local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
  if getIndex and getInfo then
    local okIdx, idx = pcall(getIndex)
    if okIdx and tonumber(idx) then
      local okInfo, _, specName = pcall(getInfo, idx)
      if okInfo and type(specName) == "string" and specName ~= "" then
        return specName
      end
    end
  end
  return "Spec"
end

function ns.Profile.ContextLabel()
  local ck = ns.Profile.CharKey()
  local spec = ns.Profile.SpecName()
  local player = ck and ck:match("^(.-)%-") or ck or "?"
  return player .. " — " .. spec
end

local function cloneProfileData(src)
  src = src or {}
  local t = deepCopy(src)
  t.panels = t.panels or {}
  t.widgets = t.widgets or {}
  t.panels.rightPanel = t.panels.rightPanel or t.minimapPosition or {}
  t.widgets.minimapBar = t.widgets.minimapBar or t.minimapBar or {}
  t.widgets.rightPanelWidgets = t.widgets.rightPanelWidgets or {}
  t.minimapPosition = t.panels.rightPanel
  t.minimapBar = t.widgets.minimapBar
  t.actionBars = t.actionBars or {}
  t.alerts = t.alerts or { enabled = false, nextId = 1, rules = {}, groups = {} }
  t.horizontalCompass = t.horizontalCompass or {}
  t.auraPanel = t.auraPanel or { auras = {} }
  t.partyGrid = t.partyGrid or {}
  t.cvars = t.cvars or {}
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

function ns.Profile.CloneData(src)
  return cloneProfileData(src)
end

local function bindingsRoot()
  ChukieUiDB.profileBindings = type(ChukieUiDB.profileBindings) == "table" and ChukieUiDB.profileBindings or {}
  return ChukieUiDB.profileBindings
end

function ns.Profile:BindCurrentContext(name)
  local ck = self.CharKey()
  if not ck then
    return false
  end
  name = name or self:GetCurrentName()
  if type(name) ~= "string" or not ChukieUiDB.profiles[name] then
    return false
  end
  local root = bindingsRoot()
  root[ck] = type(root[ck]) == "table" and root[ck] or {}
  root[ck][tostring(self.SpecId())] = name
  return true
end

function ns.Profile:SuggestContextName()
  local base = self.ContextLabel()
  if not ChukieUiDB.profiles[base] then
    return base
  end
  local i = 2
  while ChukieUiDB.profiles[base .. " (" .. i .. ")"] do
    i = i + 1
  end
  return base .. " (" .. i .. ")"
end

local function anyProfileBinding(root)
  for _, perChar in pairs(root) do
    if type(perChar) == "table" then
      for _ in pairs(perChar) do
        return true
      end
    end
  end
  return false
end

--- Primera vez que se ve esta combinación personaje+spec: o se hereda el perfil
--- actual (migración) o se clona uno propio.
function ns.Profile:EnsureContextBinding()
  local ck = self.CharKey()
  if not ck or type(ChukieUiDB.profiles) ~= "table" then
    return nil
  end
  local specKey = tostring(self.SpecId())
  local root = bindingsRoot()
  root[ck] = type(root[ck]) == "table" and root[ck] or {}
  local bound = root[ck][specKey]
  if type(bound) == "string" and ChukieUiDB.profiles[bound] then
    return bound
  end
  if not anyProfileBinding(root) then
    local current = self:GetCurrentName()
    root[ck][specKey] = current
    return current
  end
  local name = self:SuggestContextName()
  ChukieUiDB.profiles[name] = cloneProfileData(self:GetActive())
  if ns.CopyDefaultsIntoProfile then
    ns.CopyDefaultsIntoProfile(ChukieUiDB.profiles[name])
  end
  root[ck][specKey] = name
  return name
end

function ns.Profile:ApplyContext()
  if not self.CharKey() then
    self._pendingContext = true
    return false
  end
  if (self.SpecId() or 0) == 0 then
    self._pendingContext = true
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    self._pendingContext = true
    return false
  end
  local bound = self:EnsureContextBinding()
  if not bound then
    return false
  end
  if self:GetCurrentName() == bound then
    return true
  end
  return self:SetCurrent(bound)
end

function ns.Profile:OnRegenEnabled()
  if self._pendingContext then
    self._pendingContext = nil
    self:ApplyContext()
  end
end

function ns.Profile:GetContextStatusText()
  local ck = self.CharKey() or "?"
  local bound = nil
  local root = ChukieUiDB and ChukieUiDB.profileBindings
  if type(root) == "table" and type(root[ck]) == "table" then
    bound = root[ck][tostring(self.SpecId())]
  end
  return string.format(
    "Contexto %s → perfil «%s»",
    self.ContextLabel(),
    tostring(bound or self:GetCurrentName())
  )
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

function ns.Profile:CommittedName()
  return self._committedName or self:GetCurrentName()
end

function ns.Profile:SetCurrent(name)
  if type(name) ~= "string" or not ChukieUiDB.profiles[name] then
    return false
  end
  local same = self:CommittedName() == name
  if not same then
    self._pendingSwitch = nil
    if StaticPopup_Hide then
      pcall(StaticPopup_Hide, "CHUKIEUI_SWITCH_PROFILE")
    end
  end
  ChukieUiDB.currentProfile = name
  self._committedName = name
  self:BindCurrentContext(name)
  if same then
    return true
  end
  self:MigrateActionBarsLeftCenterAnchor()
  self:NotifyChanged()
  return true
end

local function trimName(name)
  if type(name) ~= "string" then
    return ""
  end
  return (name:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function popupSafe(text)
  return tostring(text or ""):gsub("%%", "%%%%")
end

function ns.Profile:RenameCurrent(newName)
  local old = self:GetCurrentName()
  newName = trimName(newName)
  if old == DEFAULT_NAME then
    return false, "No se puede renombrar «Default» (es la plantilla)."
  end
  if newName == "" then
    return false, "El nombre no puede estar vacío."
  end
  if newName == DEFAULT_NAME then
    return false, "«Default» está reservado para la plantilla."
  end
  if #newName > 40 then
    return false, "El nombre es demasiado largo (máximo 40)."
  end
  if newName == old then
    return true
  end
  if type(ChukieUiDB.profiles) ~= "table" or not ChukieUiDB.profiles[old] then
    return false, "No hay un perfil activo para renombrar."
  end
  if ChukieUiDB.profiles[newName] then
    return false, "Ya existe un perfil llamado «" .. newName .. "»."
  end
  ChukieUiDB.profiles[newName] = ChukieUiDB.profiles[old]
  ChukieUiDB.profiles[old] = nil
  ChukieUiDB.currentProfile = newName
  self._committedName = newName
  local root = bindingsRoot()
  for _, perChar in pairs(root) do
    if type(perChar) == "table" then
      for specKey, bound in pairs(perChar) do
        if bound == old then
          perChar[specKey] = newName
        end
      end
    end
  end
  if self.SyncSetting then
    self.SyncSetting(newName)
  end
  self:NotifyChanged()
  return true
end

local function popupEditBox(frame)
  if not frame then
    return nil
  end
  if frame.GetEditBox then
    local ok, box = pcall(frame.GetEditBox, frame)
    if ok and box then
      return box
    end
  end
  return frame.editBox or frame.EditBox
end

function ns.Profile:EnsureDialogs()
  if StaticPopupDialogs.CHUKIEUI_SWITCH_PROFILE then
    return
  end
  StaticPopupDialogs.CHUKIEUI_SWITCH_PROFILE = {
    text = "¿Cambiar del perfil «%s» al perfil «%s»?\nLayout, transparencias y opciones de UI cambian. Las barras de acciones de esta spec no se tocan.",
    button1 = "Cambiar",
    button2 = "Cancelar",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
      local pending = ns.Profile._pendingSwitch
      ns.Profile._pendingSwitch = nil
      if type(pending) == "string" then
        ns.Profile:SetCurrent(pending)
        if ns.Profile.SyncSetting then
          ns.Profile.SyncSetting(pending)
        end
      end
    end,
    OnCancel = function()
      ns.Profile._pendingSwitch = nil
      local current = ns.Profile:CommittedName()
      if ns.Profile.SyncSetting then
        ns.Profile.SyncSetting(current)
      end
    end,
    OnHide = function()
      if ns.Profile._pendingSwitch then
        ns.Profile._pendingSwitch = nil
        local current = ns.Profile:CommittedName()
        if ns.Profile.SyncSetting then
          ns.Profile.SyncSetting(current)
        end
      end
    end,
  }
  StaticPopupDialogs.CHUKIEUI_RENAME_PROFILE = {
    text = "Nuevo nombre para el perfil «%s»:",
    button1 = "Renombrar",
    button2 = "Cancelar",
    hasEditBox = true,
    maxLetters = 40,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
      local box = popupEditBox(self)
      if box then
        box:SetText(ns.Profile:GetCurrentName())
        box:HighlightText()
        box:SetFocus()
      end
    end,
    OnAccept = function(self)
      local box = popupEditBox(self)
      local text = box and box.GetText and box:GetText() or ""
      local ok, err = ns.Profile:RenameCurrent(text)
      if not ok then
        print("|cffff9900Chukie UI|r: " .. (err or "no se pudo renombrar"))
        return
      end
      print("|cff00ff00Chukie UI|r: perfil renombrado a «" .. ns.Profile:GetCurrentName() .. "».")
    end,
    EditBoxOnEnterPressed = function(self)
      local dialog = self:GetParent()
      if dialog and not dialog.button1 and dialog.GetParent then
        dialog = dialog:GetParent()
      end
      if dialog and dialog.button1 then
        dialog.button1:Click()
      end
    end,
  }
end

function ns.Profile:PromptSwitch(newName)
  self:EnsureDialogs()
  if type(newName) ~= "string" or not ChukieUiDB.profiles[newName] then
    return false
  end
  local current = self:CommittedName()
  if newName == current then
    return self:SetCurrent(newName)
  end
  if InCombatLockdown and InCombatLockdown() then
    print("|cffff9900Chukie UI|r: no se cambia de perfil en combate.")
    if self.SyncSetting then
      self.SyncSetting(current)
    end
    return false
  end
  if StaticPopup_Hide then
    self._pendingSwitch = nil
    pcall(StaticPopup_Hide, "CHUKIEUI_SWITCH_PROFILE")
  end
  self._pendingSwitch = newName
  StaticPopup_Show("CHUKIEUI_SWITCH_PROFILE", popupSafe(current), popupSafe(newName))
  if self.SyncSetting then
    self.SyncSetting(current)
  end
  return true
end

function ns.Profile:PromptRename()
  self:EnsureDialogs()
  if self:GetCurrentName() == DEFAULT_NAME then
    print("|cffff9900Chukie UI|r: no se puede renombrar «Default». Duplicá y renombrá la copia.")
    return false
  end
  StaticPopup_Show("CHUKIEUI_RENAME_PROFILE", popupSafe(self:GetCurrentName()))
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
  self._committedName = self:GetCurrentName()
  self:EnsureDialogs()
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
  self._committedName = name
  self:BindCurrentContext(name)
  self:MigrateMinimapBarPixelOptions()
  if self.SyncSetting then
    self.SyncSetting(name)
  end
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
  self._committedName = DEFAULT_NAME
  self:BindCurrentContext(DEFAULT_NAME)
  if self.SyncSetting then
    self.SyncSetting(DEFAULT_NAME)
  end
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
