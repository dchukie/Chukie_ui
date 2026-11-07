--[[ Grilla de party con una habilidad segura por columna (Retail 12.1).

     Capa segura: cada celda es un SecureActionButton directo. El clic izquierdo lanza
     el hechizo de su columna sobre la unidad fija de su fila. En columnas de ciclo, el
     derecho agrega o quita esa unidad de la secuencia, siempre fuera de combate.
     No se registra en ClickCastFrames ni usa ClickCastUnitTemplate para impedir que
     C_ClickBindings o Clique intercepten la acción propia.

     Capa visual: celdas cuadradas con aspecto de botón de acción. Los
     valores de vida se pasan tal cual al StatusBar: en 12.1 pueden ser secretos, así
     que no se comparan, ni se suman, ni deciden nada.

     Todo lo que toca el frame seguro (tamaño, punto, atributos, visibilidad) se hace
     fuera de combate. Toda configuración solicitada en combate se rechaza sin escribir
     SavedVariables y la UI se resincroniza al salir. ]]

local _, ns = ...

local PG = {}
ns.PartyGrid = PG

local UNITS = { "player", "party1", "party2", "party3", "party4" }

--- Celda cuadrada: un solo lado, porque la celda lleva el icono de una habilidad.
local SIZE_MIN, SIZE_MAX = 16, 100
local SPACING_MAX = 20
--- Distancia a la grilla de Blizzard y ajuste fino. El rango es amplio a propósito: la
--- grilla puede tener que cruzar media pantalla para quedar donde se la quiere, y el
--- negativo grande permite meterla por encima del propio marco.
local GAP_MIN, GAP_MAX = -600, 600
local OFFSET_MAX = 600

--[[ Columnas: cada unidad tiene una fila de celdas, una por columna, todas con la misma
     unidad detrás (una habilidad distinta por columna). El techo es bajo a
     propósito: son botones seguros, y crearlos en combate no está permitido, así que
     conviene que la cuenta total sea previsible. ]]
local COLUMNS_MIN, COLUMNS_MAX = 1, 8
local COLUMN_SPACING_MAX = 20

--- Opacidad de la grilla completa. El piso no es 0 a propósito: una grilla invisible no se
--- distingue de una que falla, y este módulo ya tiene bastante historia de «desapareció».
local ALPHA_MIN, ALPHA_MAX = 10, 100

local SIDES = { "RIGHT", "LEFT", "TOP", "BOTTOM" }
local SIDE_LABELS = { RIGHT = "Derecha", LEFT = "Izquierda", TOP = "Arriba", BOTTOM = "Abajo" }
local ORIENTATIONS = { "vertical", "horizontal" }
local ORIENTATION_LABELS = { vertical = "Vertical", horizontal = "Horizontal" }
--- Hacia dónde crecen las columnas a partir de la celda anclada a cada unidad.
local GROWTHS = { "RIGHT", "LEFT", "DOWN", "UP" }
local GROWTH_LABELS = {
  RIGHT = "Hacia la derecha",
  LEFT = "Hacia la izquierda",
  DOWN = "Hacia abajo",
  UP = "Hacia arriba",
}

--[[ Rangos y etiquetas publicados para que el panel de opciones del addon
     (ConfigPanel.lua) no duplique los límites ni los nombres de las listas: las dos
     ventanas de ajustes tocan las mismas claves del perfil. ]]
PG.LIMITS = {
  size = { SIZE_MIN, SIZE_MAX },
  spacing = { 0, SPACING_MAX },
  gap = { GAP_MIN, GAP_MAX },
  offset = { -OFFSET_MAX, OFFSET_MAX },
  columns = { COLUMNS_MIN, COLUMNS_MAX },
  columnSpacing = { 0, COLUMN_SPACING_MAX },
  alphaPercent = { ALPHA_MIN, ALPHA_MAX },
}
PG.SIDES, PG.SIDE_LABELS = SIDES, SIDE_LABELS
PG.ORIENTATIONS, PG.ORIENTATION_LABELS = ORIENTATIONS, ORIENTATION_LABELS
PG.GROWTHS, PG.GROWTH_LABELS = GROWTHS, GROWTH_LABELS

--- Grilla de party de Blizzard: el marco real depende del modo activo (party
--- estilo raid, contenedor de raid o los marcos individuales de party).
local HOST_CANDIDATES = { "CompactPartyFrame", "CompactRaidFrameContainer", "PartyFrame" }

local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION" }
local SPELL_EVENTS = {
  "SPELL_UPDATE_COOLDOWN",
  "SPELL_UPDATE_CHARGES",
  "SPELL_UPDATE_USABLE",
  "ACTIONBAR_UPDATE_USABLE",
  "SPELLS_CHANGED",
}

local ROLE_ATLAS = {
  TANK = "roleicon-tiny-tank",
  HEALER = "roleicon-tiny-healer",
  DAMAGER = "roleicon-tiny-dps",
}

--- Respaldo si el cliente no conoce los atlas de rol: hoja clásica de LFG.
local ROLE_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = {
  TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
  HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
  DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

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

local function inCombat()
  return InCombatLockdown and InCombatLockdown() or false
end

local function isSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

--[[ Lectura de marcos ajenos. Desde 12.0 un marco al que el cliente u otro addon le pasó un
     valor secreto queda marcado y sus getters devuelven secretos: compararlos desde código
     con taint aborta la ejecución. Las barras de vida de la grilla compacta entran en esa
     categoría y cuelgan justo de los marcos que recorremos para anclar celda a celda.
     Un dato ilegible se trata como desconocido: perder una referencia degrada el anclaje,
     mientras que el error corta el layout entero. ]]
local function frameNumber(frame, method)
  local fn = frame and frame[method]
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, frame)
  if not ok or type(value) ~= "number" or isSecret(value) then
    return nil
  end
  return value
end

local function frameFlag(frame, method)
  local fn = frame and frame[method]
  if type(fn) ~= "function" then
    return false
  end
  local ok, value = pcall(fn, frame)
  if not ok or isSecret(value) then
    return false
  end
  return value == true
end

--[[ Hijos de un marco ajeno. La llamada puede fallar entera: si alguno de los hijos es un objeto
     prohibido —de los que el cliente se reserva— armar la lista desde código con taint aborta la
     ejecución («Attempt to access forbidden object from code tainted by an AddOn»). Una rama
     ilegible se descarta: perderla degrada el anclaje, mientras que el error cortaba el layout y
     terminaba apagando el módulo. ]]
local function frameChildren(frame)
  if not frame then
    return nil
  end
  local ok, children = pcall(function()
    if type(frame.GetChildren) ~= "function" then
      return nil
    end
    return { frame:GetChildren() }
  end)
  if not ok or type(children) ~= "table" then
    return nil
  end
  return children
end

--- En mapas restringidos UnitIsUnit puede devolver un booleano secreto, que no se puede testear.
local function sameUnit(a, b)
  if a == b then
    return true
  end
  if not UnitIsUnit then
    return false
  end
  local ok, same = pcall(UnitIsUnit, a, b)
  if not ok or isSecret(same) then
    return false
  end
  return same == true
end

local function spellInfo(spellId)
  spellId = tonumber(spellId)
  if not spellId or spellId <= 0 then
    return nil
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
    if ok and type(info) == "table" then
      return info
    end
  end
  if GetSpellInfo then
    local ok, name, _, icon = pcall(GetSpellInfo, spellId)
    if ok and name then
      return { name = name, iconID = icon, spellID = spellId }
    end
  end
  return nil
end

local function spellInfoByIdentifier(identifier)
  if type(identifier) == "string" then
    identifier = identifier:match("^%s*(.-)%s*$")
  end
  if identifier == nil or identifier == "" then
    return nil
  end
  local numeric = tonumber(identifier)
  if numeric then
    return spellInfo(numeric)
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, identifier)
    if ok and type(info) == "table" and tonumber(info.spellID) then
      return info
    end
  end
  if GetSpellInfo then
    local ok, name, _, icon, _, _, spellId = pcall(GetSpellInfo, identifier)
    if ok and name and tonumber(spellId) then
      return { name = name, iconID = icon, spellID = spellId }
    end
  end
  return nil
end

--- Nombre global que se invoca desde una macro: `/click ch-cl-NombreDelHechizo`.
--- Solo se quitan caracteres que separan argumentos o tienen significado en macros;
--- las letras localizadas se conservan.
local function cycleActionToken(name)
  name = tostring(name or ""):gsub("%s+", "")
  name = name:gsub("[\"'`;/%[%]<>|]", "")
  return name ~= "" and ("ch-cl-" .. name) or nil
end

-- ---------------------------------------------------------------------------
-- Modelo
-- ---------------------------------------------------------------------------

function PG:DB()
  if ns.Profile and ns.Profile.GetPartyGridModel then
    return ns.Profile:GetPartyGridModel()
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return {}
  end
  if type(p.partyGrid) ~= "table" then
    if inCombat() then
      return {}
    end
    p.partyGrid = {}
  end
  if type(p.partyGrid.columnSpells) ~= "table" then
    if inCombat() then
      return p.partyGrid
    end
    p.partyGrid.columnSpells = {}
  end
  if type(p.partyGrid.columnCycles) ~= "table" then
    if inCombat() then
      return p.partyGrid
    end
    p.partyGrid.columnCycles = {}
  end
  if type(p.partyGrid.columnCycleUnits) ~= "table" then
    if inCombat() then
      return p.partyGrid
    end
    p.partyGrid.columnCycleUnits = {}
  end
  return p.partyGrid
end

function PG:CanConfigure(quiet)
  if not inCombat() then
    return true
  end
  if not quiet and (not self._lastCombatWarning or GetTime() - self._lastCombatWarning > 1) then
    self._lastCombatWarning = GetTime()
    print("|cffff9900Chukie UI|r: PartyGrid no se puede configurar en combate; el cambio fue rechazado.")
  end
  if self._configFrame then
    self:SyncConfig()
  end
  self:RefreshSettings()
  return false
end

--[[ Los controles de la ventana de Ajustes de Blizzard no se pueden deshabilitar en
     caliente, así que cuando un cambio se rechaza hay que devolverles el valor real del
     perfil. `_syncingSettings` marca ese rebote para que el setter del control no lo
     tome como una edición del usuario y vuelva a entrar. ]]
function PG:RegisterSetting(setting, get)
  if not setting or type(get) ~= "function" then
    return setting
  end
  self._settings = self._settings or {}
  self._settings[#self._settings + 1] = { setting = setting, get = get }
  return setting
end

function PG:SettingsLocked()
  return self._syncingSettings == true
end

local function pushSetting(entry)
  entry.setting:SetValue(entry.get())
end

function PG:RefreshSettings()
  if self._syncingSettings or not self._settings then
    return
  end
  self._syncingSettings = true
  for i = 1, #self._settings do
    pcall(pushSetting, self._settings[i])
  end
  self._syncingSettings = false
end

--- Única ruta de escritura de configuración. `apply` puede ser "layout" o "refresh";
--- nunca escribe SavedVariables en combate.
function PG:SetOption(key, value, apply)
  if not self:CanConfigure() then
    return false
  end
  self:DB()[key] = value
  if apply == "layout" then
    self:Layout()
  else
    self:Refresh()
  end
  return true
end

function PG:SetOptions(changes, apply)
  if not self:CanConfigure() then
    return false
  end
  local db = self:DB()
  for key, value in pairs(changes or {}) do
    db[key] = value
  end
  if apply == "layout" then
    self:Layout()
  else
    self:Refresh()
  end
  return true
end

function PG:ColumnSpell(column)
  local spells = self:DB().columnSpells
  return tonumber(type(spells) == "table" and spells[column]) or nil
end

function PG:IsCycleColumn(column)
  local cycles = self:DB().columnCycles
  return type(cycles) == "table" and cycles[column] == true
end

function PG:CycleUnits(column)
  local all = self:DB().columnCycleUnits
  local units = type(all) == "table" and all[column] or nil
  return type(units) == "table" and units or {}
end

function PG:IsCycleUnit(column, unit)
  local units = self:CycleUnits(column)
  for i = 1, #units do
    if units[i] == unit then
      return true
    end
  end
  return false
end

function PG:CycleActionName(column)
  if not self:IsCycleColumn(column) then
    return nil
  end
  local info = spellInfo(self:ColumnSpell(column))
  return info and cycleActionToken(info.name) or nil
end

function PG:CycleUnitSummary(column)
  local units = self:CycleUnits(column)
  return #units > 0 and table.concat(units, ", ") or "(ninguno)"
end

function PG:FindCycleActionConflict(column, spellId)
  local info = spellInfo(spellId)
  local action = info and cycleActionToken(info.name) or nil
  if not action then
    return nil
  end
  for other = COLUMNS_MIN, COLUMNS_MAX do
    if other ~= column and self:IsCycleColumn(other) and self:CycleActionName(other) == action then
      return other
    end
  end
  return nil
end

--- Solo se llama tras pasar por CanConfigure, así que crear la tabla acá nunca escribe
--- el perfil en combate: un perfil viejo puede llegar sin ella.
function PG:ColumnSpellTable()
  local db = self:DB()
  if type(db.columnSpells) ~= "table" then
    db.columnSpells = {}
  end
  return db.columnSpells
end

function PG:SetColumnSpell(column, spellId)
  column = math.floor(tonumber(column) or 0)
  spellId = tonumber(spellId)
  if column < COLUMNS_MIN or column > COLUMNS_MAX then
    return false
  end
  if spellId and (spellId <= 0 or not spellInfo(spellId)) then
    print("|cffff9900Chukie UI|r: solo se aceptan hechizos válidos.")
    return false
  end
  local conflict = spellId and self:IsCycleColumn(column) and self:FindCycleActionConflict(column, spellId)
  if conflict then
    print("|cffff9900Chukie UI|r: ese hechizo ya corresponde al ciclo de la columna " .. conflict .. ".")
    return false
  end
  if not self:CanConfigure() then
    return false
  end
  local spells = self:ColumnSpellTable()
  spells[column] = spellId
  self:ApplySecureAttributes()
  self:UpdateAll()
  if self._configFrame then
    self:SyncConfig()
  end
  self:RefreshSettings()
  return true
end

function PG:SetColumnSpellInput(column, identifier)
  local text = tostring(identifier or ""):match("^%s*(.-)%s*$")
  if text == "" then
    return self:SetColumnSpell(column, nil)
  end
  local info = spellInfoByIdentifier(text)
  if not info or not tonumber(info.spellID) then
    print("|cffff9900Chukie UI|r: no se encontró ese hechizo; escribí el nombre exacto o su ID.")
    self:RefreshSettings()
    if self._configFrame then
      self:SyncConfig()
    end
    return false
  end
  return self:SetColumnSpell(column, info.spellID)
end

function PG:ColumnCycleTable()
  local db = self:DB()
  if type(db.columnCycles) ~= "table" then
    db.columnCycles = {}
  end
  return db.columnCycles
end

function PG:ColumnCycleUnitTable()
  local db = self:DB()
  if type(db.columnCycleUnits) ~= "table" then
    db.columnCycleUnits = {}
  end
  return db.columnCycleUnits
end

function PG:SetColumnCycle(column, enabled)
  column = math.floor(tonumber(column) or 0)
  if column < COLUMNS_MIN or column > COLUMNS_MAX then
    return false
  end
  enabled = enabled == true or enabled == 1
  local spellId = self:ColumnSpell(column)
  local conflict = enabled and spellId and self:FindCycleActionConflict(column, spellId)
  if conflict then
    print("|cffff9900Chukie UI|r: ese hechizo ya corresponde al ciclo de la columna " .. conflict .. ".")
    self:RefreshSettings()
    return false
  end
  if not self:CanConfigure() then
    return false
  end
  self:ColumnCycleTable()[column] = enabled or nil
  self:ApplySecureAttributes()
  self:UpdateAll()
  if self._configFrame then
    self:SyncConfig()
  end
  self:RefreshSettings()
  return true
end

function PG:ToggleCycleUnit(column, unit)
  if not self:IsCycleColumn(column) then
    return false
  end
  local valid
  for i = 1, #UNITS do
    if UNITS[i] == unit then
      valid = true
      break
    end
  end
  if not valid or not self:CanConfigure() then
    return false
  end
  local all = self:ColumnCycleUnitTable()
  local units = all[column]
  if type(units) ~= "table" then
    units = {}
    all[column] = units
  end
  for i = 1, #units do
    if units[i] == unit then
      table.remove(units, i)
      self:ApplySecureAttributes()
      self:UpdateAll()
      if self._configFrame then
        self:SyncConfig()
      end
      self:RefreshSettings()
      return true
    end
  end
  units[#units + 1] = unit
  self:ApplySecureAttributes()
  self:UpdateAll()
  if self._configFrame then
    self:SyncConfig()
  end
  self:RefreshSettings()
  return true
end

function PG:MoveColumnSpell(source, destination, spellId)
  source = math.floor(tonumber(source) or 0)
  destination = math.floor(tonumber(destination) or 0)
  spellId = tonumber(spellId)
  if source < COLUMNS_MIN or source > COLUMNS_MAX or destination < COLUMNS_MIN or destination > COLUMNS_MAX then
    return false
  end
  if not spellId or not spellInfo(spellId) or not self:CanConfigure() then
    return false
  end
  local conflict = self:IsCycleColumn(destination) and self:FindCycleActionConflict(destination, spellId)
  if conflict then
    print("|cffff9900Chukie UI|r: ese hechizo ya corresponde al ciclo de la columna " .. conflict .. ".")
    return false
  end
  local spells = self:ColumnSpellTable()
  spells[destination] = spellId
  if source ~= destination then
    spells[source] = nil
  end
  self:ApplySecureAttributes()
  self:UpdateAll()
  if self._configFrame then
    self:SyncConfig()
  end
  self:RefreshSettings()
  return true
end

function PG:IsEnabled()
  --- Un fallo apaga la grilla solo para esta sesión: el perfil no se toca, así que
  --- /reload la devuelve tal como estaba configurada.
  if self._killed then
    return false
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p or not p.enabled then
    return false
  end
  return self:DB().enabled == true
end

--- Lado de la celda. `height` es la clave vieja (celda rectangular con nombre): se usa
--- como valor de partida para que un perfil anterior no salte a otro tamaño.
function PG:CellSize()
  local db = self:DB()
  return math.floor(clamp(db.size or db.height, SIZE_MIN, SIZE_MAX))
end

function PG:Spacing()
  return math.floor(clamp(self:DB().spacing, 0, SPACING_MAX))
end

--- Celdas por unidad.
function PG:Columns()
  return math.floor(clamp(self:DB().columns or COLUMNS_MIN, COLUMNS_MIN, COLUMNS_MAX))
end

function PG:ColumnSpacing()
  return math.floor(clamp(self:DB().columnSpacing, 0, COLUMN_SPACING_MAX))
end

function PG:Growth()
  local g = self:DB().growth
  return GROWTH_LABELS[g] and g or "RIGHT"
end

--- Opacidad en porcentaje (lo que se guarda y se muestra en los controles).
function PG:AlphaPercent()
  return math.floor(clamp(self:DB().alphaPercent or ALPHA_MAX, ALPHA_MIN, ALPHA_MAX))
end

function PG:Gap()
  return math.floor(clamp(self:DB().gap, GAP_MIN, GAP_MAX))
end

function PG:Offsets()
  local db = self:DB()
  return math.floor(clamp(db.offsetX, -OFFSET_MAX, OFFSET_MAX)), math.floor(clamp(db.offsetY, -OFFSET_MAX, OFFSET_MAX))
end

function PG:Orientation()
  local o = self:DB().orientation
  return ORIENTATION_LABELS[o] and o or "vertical"
end

function PG:Side()
  local s = self:DB().side
  return SIDE_LABELS[s] and s or "RIGHT"
end

--- Unidades que participan de la grilla, en orden fijo.
function PG:UnitList()
  local db = self:DB()
  local list = {}
  if db.includePlayer ~= false then
    list[#list + 1] = "player"
  end
  for i = 1, 4 do
    list[#list + 1] = "party" .. i
  end
  return list
end

-- ---------------------------------------------------------------------------
-- Capa visual
-- ---------------------------------------------------------------------------

local function edgeBorder(parent, level)
  local edges = {}
  for i = 1, 4 do
    local t = parent:CreateTexture(nil, "OVERLAY", nil, level or 0)
    t:SetColorTexture(1, 0.82, 0, 0.9)
    t:Hide()
    edges[i] = t
  end
  return edges
end

local function layoutBorder(edges, thickness)
  local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
  top:ClearAllPoints()
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(thickness)
  bottom:ClearAllPoints()
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(thickness)
  left:ClearAllPoints()
  left:SetPoint("TOPLEFT")
  left:SetPoint("BOTTOMLEFT")
  left:SetWidth(thickness)
  right:ClearAllPoints()
  right:SetPoint("TOPRIGHT")
  right:SetPoint("BOTTOMRIGHT")
  right:SetWidth(thickness)
end

local function showBorder(edges, on)
  for i = 1, #edges do
    if on then
      edges[i]:Show()
    else
      edges[i]:Hide()
    end
  end
end

local function classColor(unit)
  local class = UnitClassBase and UnitClassBase(unit) or select(2, UnitClass(unit))
  local colors = RAID_CLASS_COLORS or CUSTOM_CLASS_COLORS
  local c = class and colors and colors[class]
  if c then
    return c.r, c.g, c.b
  end
  return 0.6, 0.6, 0.65
end

--- Los números de vida van directos al widget: si el cliente los entrega como
--- secretos el StatusBar igual los dibuja, pero el addon no puede leerlos.
local function updateHealth(btn)
  local bar = btn.health
  if not bar then
    return
  end
  if not UnitExists(btn.unit) then
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return
  end
  pcall(bar.SetMinMaxValues, bar, 0, UnitHealthMax(btn.unit))
  pcall(bar.SetValue, bar, UnitHealth(btn.unit))
end

local function clearCooldown(cd)
  if cd and cd.Clear then
    pcall(cd.Clear, cd)
  end
end

--- Un valor secreto no se compara ni se convierte a booleano: se descarta antes.
local function knownBool(call, ...)
  if not call then
    return nil
  end
  local ok, value = pcall(call, ...)
  if not ok or isSecret(value) or value == nil then
    return nil
  end
  return value == true or value == 1
end

--[[ Estado por columna: hechizo, icono, cooldown, cargas y usabilidad son idénticos en
     las cinco celdas de una columna, así que se calculan una vez por pase y no cuarenta.
     El rango queda fuera a propósito: ese sí depende de la unidad de cada fila. ]]
function PG:BuildColumnStates()
  local states = {}
  --- Solo las columnas que hoy se dibujan: las demás no tienen celdas que actualizar.
  for column = COLUMNS_MIN, self:Columns() do
    local spellId = self:ColumnSpell(column)
    local info = spellId and spellInfo(spellId) or nil
    if info then
      local cdInfo, chargeInfo
      if C_Spell and C_Spell.GetSpellCooldown then
        local ok, value = pcall(C_Spell.GetSpellCooldown, spellId)
        cdInfo = ok and value or nil
      end
      if C_Spell and C_Spell.GetSpellCharges then
        local ok, value = pcall(C_Spell.GetSpellCharges, spellId)
        chargeInfo = ok and value or nil
      end
      local st = (ns.CdInfo and ns.CdInfo.Derive and ns.CdInfo.Derive(cdInfo, chargeInfo)) or {}
      st.spellId = spellId
      st.icon = info.iconID or info.icon
      st.usable = knownBool(C_Spell and C_Spell.IsSpellUsable, spellId)
      --- Firma de lo que dibuja el Cooldown: sin ella habría que reasignar el duration
      --- object en cada pase, y reasignarlo sin cambio de estado no aporta nada.
      st.signature = table.concat({
        tostring(spellId),
        tostring(st.onGcd == true),
        tostring(st.cdActive == true),
        tostring(st.hasCharges == true),
        tostring(st.chargeActive == true),
      }, ":")
      states[column] = st
    end
  end
  self._columnStates = states
  return states
end

function PG:ColumnStates()
  return self._columnStates or self:BuildColumnStates()
end

--[[ Swipe del cooldown real, nunca el del GCD: se descarta si `isOnGCD`, y además el
     duration object se pide con `ignoreGCD = true`, así el barrido global tampoco entra
     por la vía del widget. Con cargas se dibuja la recarga de la próxima. ]]
local function applyCooldown(btn, st)
  local cd = btn.cooldown
  if not cd then
    return
  end
  local signature = st and st.signature or nil
  if btn._cdSignature == signature then
    return
  end
  btn._cdSignature = signature
  clearCooldown(cd)
  cd:Hide()
  if not st or st.onGcd or not (st.cdActive or (st.hasCharges and st.chargeActive)) then
    return
  end
  if not cd.SetCooldownFromDurationObject or not C_Spell then
    return
  end
  local ok, duration
  if st.hasCharges and st.chargeActive and C_Spell.GetSpellChargeDuration then
    ok, duration = pcall(C_Spell.GetSpellChargeDuration, st.spellId)
  elseif C_Spell.GetSpellCooldownDuration then
    ok, duration = pcall(C_Spell.GetSpellCooldownDuration, st.spellId, true)
  end
  if ok and duration and pcall(cd.SetCooldownFromDurationObject, cd, duration) then
    cd:Show()
  end
end

--- Rango: lo único del botón de acción que cambia de una fila a otra.
function PG:UpdateRange(btn, st)
  st = st or (self._columnStates and self._columnStates[btn.column])
  local cycleOff = self:IsCycleColumn(btn.column) and not self:IsCycleUnit(btn.column, btn.unit)
  if btn.icon.SetDesaturated then
    btn.icon:SetDesaturated(cycleOff)
  end
  if cycleOff then
    btn.icon:SetVertexColor(0.28, 0.28, 0.28)
    return
  end
  if not st then
    btn.icon:SetVertexColor(1, 1, 1)
    return
  end
  local inRange = knownBool(C_Spell and C_Spell.IsSpellInRange, st.spellId, btn.unit)
  if inRange == false then
    btn.icon:SetVertexColor(1, 0.35, 0.35)
  elseif st.usable == false then
    btn.icon:SetVertexColor(0.45, 0.45, 0.45)
  else
    --- Secreto o desconocido es neutral: no degrada el icono ni decide nada.
    btn.icon:SetVertexColor(1, 1, 1)
  end
end

function PG:UpdateAction(btn, st)
  if st == nil then
    st = self:ColumnStates()[btn.column]
  end
  btn.spellId = st and st.spellId or nil
  if not st then
    if btn._icon ~= false then
      btn._icon = false
      btn.icon:SetColorTexture(0.12, 0.12, 0.15, 0.75)
    end
    btn.icon:SetVertexColor(1, 1, 1)
    btn.charges:SetText("")
    applyCooldown(btn, nil)
    return
  end
  if btn._icon ~= st.icon then
    btn._icon = st.icon
    btn.icon:SetTexture(st.icon)
    --- SetColorTexture (columna vacía) descarta los texcoords. Sin Masque se reponen;
    --- con Masque manda la skin (pisarlos acá rompería su recorte/máscara).
    if not btn._masqued then
      btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
  end
  applyCooldown(btn, st)
  btn.charges:SetText((st.hasCharges and st.count ~= nil) and tostring(st.count) or "")
  self:UpdateRange(btn, st)
end

function PG:UpdateButton(btn, st)
  local db = self:DB()
  local unit = btn.unit
  local exists = UnitExists(unit)
  local r, g, b = classColor(unit)

  if db.showHealth ~= false then
    btn.health:SetStatusBarColor(r * 0.9, g * 0.9, b * 0.9)
    btn.health:Show()
    updateHealth(btn)
  else
    btn.health:Hide()
  end

  local role = exists and UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or nil
  --- El rol es de la unidad, no de la columna: se dibuja solo en la primera celda de
  --- la fila para no repetirlo tantas veces como columnas haya.
  if db.showRole ~= false and btn.column == 1 and ROLE_COORDS[role or ""] then
    -- Si el cliente no conoce el atlas (o lo rechaza), queda la hoja clásica.
    pcall(btn.role.SetAtlas, btn.role, ROLE_ATLAS[role])
    if not btn.role:GetAtlas() then
      local c = ROLE_COORDS[role]
      btn.role:SetTexture(ROLE_TEXTURE)
      btn.role:SetTexCoord(c[1], c[2], c[3], c[4])
    end
    btn.role:Show()
  else
    btn.role:Hide()
  end

  local connected = not exists or UnitIsConnected(unit) ~= false
  btn.bg:SetAlpha(connected and 0.85 or 0.45)

  showBorder(btn.target, exists and UnitIsUnit("target", unit) == true)
  self:UpdateAction(btn, st)
end

--- Las columnas de más están ocultas: recalcularlas sería trabajo tirado.
function PG:UpdateAll()
  if not self._buttons then
    return
  end
  local states = self:BuildColumnStates()
  local columns = self:Columns()
  for i = 1, #self._buttons do
    local btn = self._buttons[i]
    if (btn.column or 1) <= columns then
      self:UpdateButton(btn, states[btn.column])
    end
  end
end

--- Eventos de hechizo: cambia la capa de acción, no la vida ni el rol ni el objetivo.
function PG:UpdateActions()
  if not self._buttons then
    return
  end
  local states = self:BuildColumnStates()
  local columns = self:Columns()
  for i = 1, #self._buttons do
    local btn = self._buttons[i]
    if (btn.column or 1) <= columns then
      self:UpdateAction(btn, states[btn.column])
    end
  end
end

function PG:UpdateUnit(unit)
  local row = self._cells and self._cells[unit]
  if not row then
    return
  end
  --- Vida, rol y objetivo cambian por unidad; el estado del hechizo no, así que se
  --- reutiliza el que ya está calculado por columna.
  local states = self:ColumnStates()
  local columns = math.min(#row, self:Columns())
  for i = 1, columns do
    self:UpdateButton(row[i], states[i])
  end
end

--[[ Pulso corto: solo rango. Todo lo demás (cooldown, cargas, usabilidad, icono) llega
     por evento, así que el tick no vuelve a consultar el estado de cada hechizo. ]]
function PG:TickRange()
  --- `IsVisible` y no `IsShown`: pegada a la grilla de Blizzard, el host puede estar
  --- marcado como visible y aun así no dibujarse porque su padre está oculto.
  if not self._buttons or not self._host or not self._host:IsVisible() then
    return
  end
  local states = self:ColumnStates()
  local columns = self:Columns()
  for i = 1, #self._buttons do
    local btn = self._buttons[i]
    if (btn.column or 1) <= columns and btn.spellId and btn:IsShown() then
      self:UpdateRange(btn, states[btn.column])
    end
  end
end

--[[ Red de seguridad de visibilidad. La grilla vive colgada de un marco de Blizzard y
     Blizzard no avisa cuando cambia cuál de sus contenedores usa (modo edición, estilo
     raid, morir y reaparecer, un dungeon con seguidores). Si nos quedamos colgados del
     que ya no se dibuja, la grilla desaparece sin error y sin evento que la traiga de
     vuelta. Comparar el padre esperado una vez por segundo cuesta nada y cierra ese
     agujero; el relayout solo ocurre cuando de verdad cambió. ]]
function PG:CheckHost()
  local host = self._host
  if not host or inCombat() or not self:IsEnabled() then
    return
  end
  local db = self:DB()
  local expected = UIParent
  if db.attachToBlizzard ~= false and db.unlocked ~= true then
    expected = self:BlizzardContainer() or UIParent
  end
  if host:GetParent() ~= expected then
    self:Layout()
    self:UpdateAll()
  end
end

--- Volcado de estado para cuando la grilla no está donde debería: dice si la apagó un
--- fallo, de qué marco de Blizzard cuelga y si ese marco se está dibujando.
function PG:PrintDiagnostics()
  local function frameName(f)
    if not f then
      return "nil"
    end
    return (f.GetName and f:GetName()) or "sin nombre"
  end
  local function tag(f)
    if not f then
      return "nil"
    end
    return string.format("%s (mostrado=%s visible=%s)", frameName(f),
      tostring(f.IsShown and f:IsShown()), tostring(f.IsVisible and f:IsVisible()))
  end
  print("|cff00ff00Chukie UI|r grilla de party:")
  print("  perfil=" .. tostring(self:DB().enabled) .. " activa=" .. tostring(self:IsEnabled())
    .. " cortada=" .. tostring(self._killed == true) .. " errores=" .. tostring(self._errorCount or 0)
    .. " combate=" .. tostring(inCombat()))
  local host = self._host
  if host then
    print(string.format("  host=%s tam=%.0fx%.0f celdas=%d columnas=%d opacidad=%d%% pendiente=%s",
      tag(host), frameNumber(host, "GetWidth") or 0, frameNumber(host, "GetHeight") or 0,
      #(self._buttons or {}), self:Columns(), math.floor((host:GetAlpha() or 1) * 100 + 0.5),
      tostring(self._pending == true)))
    print("  padre=" .. tag(host:GetParent()) .. " esperado=" .. frameName(self:BlizzardContainer()))
    print("  anclada a=" .. tag(self:BlizzardHost()) .. " condicion=" .. tostring(self._visibilityCond))
    local container = self:BlizzardContainer()
    local matched = 0
    if container then
      for _ in pairs(self:BlizzardUnitFrames(container)) do
        matched = matched + 1
      end
    end
    print("  anclajePorJugador=" .. tostring(self:DB().perUnitAnchor ~= false)
      .. " lado=" .. self:Side() .. " crecimiento=" .. self:Growth()
      .. " marcosPorUnidad=" .. matched)
  else
    print("  host todavía no creado (fallo=" .. tostring(self._failed == true) .. ")")
  end
  for i = 1, #HOST_CANDIDATES do
    print("  " .. HOST_CANDIDATES[i] .. ": " .. tag(_G[HOST_CANDIDATES[i]]))
  end
  local masque = _G.LibStub and _G.LibStub("Masque", true)
  local skinned = 0
  for i = 1, #(self._buttons or {}) do
    if self._buttons[i]._masqued then
      skinned = skinned + 1
    end
  end
  print("  Masque: opcion=" .. tostring(self:DB().useMasque ~= false)
    .. " disponible=" .. tostring(masque ~= nil) .. " grupo=PartyGrid botones=" .. skinned)
  --- Fase del clic: quién ejecuta la acción lo decide este CVar salvo que el botón lo pise.
  local keyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
  print("  clic: ActionButtonUseKeyDown=" .. tostring(keyDown) .. " useOnKeyDown(botón)=false")
  for column = COLUMNS_MIN, COLUMNS_MAX do
    local action = self:CycleActionName(column)
    if action then
      local button = (self._cycleButtons or {})[action]
      print(string.format("  ciclo col=%d /click %s unidades=%s existe=%s indice=%s actual=%s",
        column, action, self:CycleUnitSummary(column), tostring(button ~= nil),
        button and tostring(button:GetAttribute("cycleIndex")) or "nil",
        button and tostring(button:GetAttribute("unit")) or "nil"))
    end
  end
  local click = self._lastClick
  if click then
    print(string.format("  último clic: %s col=%d hechizo=%s fase=%s hace %.1fs",
      tostring(click.unit), click.column or 0, tostring(click.spellId),
      click.down and "pulsación" or "release", GetTime() - (click.time or 0)))
  else
    print("  último clic: ninguno recibido todavía")
  end
  if self._lastError then
    print("  último error (" .. tostring(self._lastErrorSource) .. "): " .. self._lastError)
  end
end

-- ---------------------------------------------------------------------------
-- Capa segura
-- ---------------------------------------------------------------------------

--[[ `GetCursorInfo()` devuelve para hechizos: "spell", índice del libro, banco, spellID.
     El ID útil es el cuarto valor; el segundo es un índice de libro y usarlo como ID
     apuntaría a otro hechizo cualquiera. Solo se aceptan hechizos: ítems, macros y
     flyouts quedan fuera en esta versión. ]]
local function cursorSpellId()
  local kind, bookIndex, bank, spellId = GetCursorInfo()
  if kind ~= "spell" then
    return nil
  end
  spellId = tonumber(spellId)
  if not spellId and C_SpellBook and C_SpellBook.GetSpellBookItemInfo and tonumber(bookIndex) then
    --- Clientes con el payload viejo: el banco llegaba como texto ("spell"/"pet") y la
    --- API nueva espera el enum.
    local spellBank = bank
    if type(spellBank) ~= "number" and Enum and Enum.SpellBookSpellBank then
      spellBank = (bank == "pet") and Enum.SpellBookSpellBank.Pet or Enum.SpellBookSpellBank.Player
    end
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, bookIndex, spellBank)
    if ok and type(info) == "table" then
      spellId = tonumber(info.spellID)
    end
  end
  return (spellId and spellInfo(spellId)) and spellId or nil
end

function PG:CreateButton(index, unit, column)
  local suffix = index .. "c" .. column
  local ok, btn = pcall(CreateFrame, "Button", "ChukieUi_PartyGridUnit" .. suffix, self._host, "SecureActionButtonTemplate")
  if not ok or not btn then
    return nil
  end

  local size = self:CellSize()
  --- Marca de propiedad: BlizzardUnitFrames salta lo nuestro al buscar marcos de party.
  btn._chukieGrid = true
  btn.unit = unit
  btn.column = column
  btn:SetSize(size, size)
  -- Sin puntos todavía: los coloca Layout y luego los muestra RegisterUnitWatch.
  btn:Hide()

  btn.bg = btn:CreateTexture(nil, "BACKGROUND")
  btn.bg:SetAllPoints(btn)
  btn.bg:SetColorTexture(0.05, 0.05, 0.07, 0.85)

  local level = btn:GetFrameLevel()

  btn.health = CreateFrame("StatusBar", nil, btn)
  btn.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  btn.health:SetPoint("TOPLEFT", 1, -1)
  btn.health:SetPoint("BOTTOMRIGHT", -1, 1)
  btn.health:SetFrameLevel(level + 1)
  btn.health:EnableMouse(false)
  btn.health:SetMinMaxValues(0, 1)
  btn.health:SetValue(0)
  btn.health:SetAlpha(0.3)

  -- Rol y bordes por encima de la barra: la barra es un frame hijo, así que las capas
  -- del propio botón quedarían debajo.
  btn.overlay = CreateFrame("Frame", nil, btn)
  btn.overlay:SetAllPoints(btn)
  btn.overlay:SetFrameLevel(level + 2)
  btn.overlay:EnableMouse(false)

  btn.icon = btn.overlay:CreateTexture(nil, "ARTWORK")
  btn.icon:SetAllPoints(btn.overlay)
  btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
  btn.cooldown:SetAllPoints(btn)
  btn.cooldown:SetFrameLevel(level + 3)
  btn.cooldown:SetDrawEdge(true)
  btn.cooldown:SetDrawBling(false)
  if btn.cooldown.SetHideCountdownNumbers then
    btn.cooldown:SetHideCountdownNumbers(false)
  end
  btn.cooldown:Hide()

  --- Por encima del swipe: cargas, rol, borde de objetivo y resaltado tienen que
  --- seguir leyéndose mientras el cooldown está girando.
  btn.top = CreateFrame("Frame", nil, btn)
  btn.top:SetAllPoints(btn)
  btn.top:SetFrameLevel(level + 4)
  btn.top:EnableMouse(false)

  btn.charges = btn.top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  btn.charges:SetPoint("BOTTOMRIGHT", -2, 2)
  btn.charges:SetJustifyH("RIGHT")

  btn.role = btn.top:CreateTexture(nil, "ARTWORK")
  btn.role:SetPoint("BOTTOMLEFT", 2, 2)
  btn.role:SetSize(12, 12)
  btn.role:Hide()

  btn.highlight = btn.top:CreateTexture(nil, "OVERLAY")
  btn.highlight:SetAllPoints(btn.top)
  btn.highlight:SetColorTexture(1, 1, 1, 0.12)
  btn.highlight:Hide()

  btn.target = edgeBorder(btn.top, 1)
  layoutBorder(btn.target, 1)

  --- Región exclusiva para el borde de Masque. Vive en el frame superior para que el
  --- borde de la skin no quede tapado por icono/cooldown, pero no recibe mouse.
  btn.masqueNormal = btn.top:CreateTexture(nil, "BORDER")
  btn.masqueNormal:SetAllPoints(btn.top)
  btn.masqueNormal:SetColorTexture(1, 1, 1, 0)

  btn:SetAttribute("unit", unit)
  --[[ Solo el botón izquierdo llega a una acción segura. El derecho queda registrado
       para editar fuera de combate la lista de una columna ciclo, pero no tiene `type2`.

       Las **dos fases** del clic sí se registran, y no es un detalle: quién ejecuta la
       acción lo decide el CVar `ActionButtonUseKeyDown` (o este atributo por botón). Con
       solo el release registrado, un cliente configurado para actuar en la pulsación no
       recibe nunca la fase que espera y el clic no castea nada, sin error ni aviso.
       `useOnKeyDown = false` fija la ejecución en el release, que además es lo que necesita
       el arrastre: la celda es también el asa para asignar hechizos, y no queremos lanzar
       nada al empezar a arrastrar. ]]
  btn:SetAttribute("useOnKeyDown", false)
  btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")

  --- Registro del último clic recibido: si algún día no castea, esto dice si el clic llegó
  --- al botón seguro (y en qué fase) o si nunca lo alcanzó. Lo imprime `party diag`.
  btn:SetScript("PostClick", function(f, mouseButton, down)
    if mouseButton == "RightButton" and not down then
      PG:ToggleCycleUnit(f.column, f.unit)
      return
    end
    PG._lastClick = {
      unit = f.unit,
      column = f.column,
      spellId = f.spellId,
      button = mouseButton,
      down = down and true or false,
      time = GetTime(),
    }
  end)

  btn:HookScript("OnEnter", function(f)
    f.highlight:Show()
    if not f.spellId then
      return
    end
    GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(f.spellId)
    if PG:IsCycleColumn(f.column) then
      if PG:IsCycleUnit(f.column, f.unit) then
        GameTooltip:AddLine("Ciclo: incluido (derecho para quitar)", 0.3, 1, 0.3)
      else
        GameTooltip:AddLine("Ciclo: apagado (derecho para incluir)", 0.65, 0.65, 0.65)
      end
    end
    GameTooltip:Show()
  end)
  btn:HookScript("OnLeave", function(f)
    f.highlight:Hide()
    GameTooltip:Hide()
  end)

  btn:SetScript("OnDragStart", function(f)
    if not f.spellId or not PG:CanConfigure() then
      return
    end
    PG._drag = { column = f.column, spellId = f.spellId }
    if C_Spell and C_Spell.PickupSpell then
      pcall(C_Spell.PickupSpell, f.spellId)
    elseif PickupSpell then
      pcall(PickupSpell, f.spellId)
    end
  end)
  btn:SetScript("OnReceiveDrag", function(f)
    local spellId = cursorSpellId()
    if not spellId or not PG:CanConfigure() then
      return
    end
    --[[ Solo cuenta como movimiento si el hechizo del cursor es el mismo que salió de
         una celda: con eso un `_drag` viejo nunca puede vaciar una columna ajena. ]]
    local drag = PG._drag
    local source = (drag and drag.spellId == spellId) and drag.column or nil
    local changed
    if source then
      changed = PG:MoveColumnSpell(source, f.column, spellId)
    else
      changed = PG:SetColumnSpell(f.column, spellId)
    end
    if changed then
      ClearCursor()
    end
    PG._drag = nil
  end)
  btn:SetScript("OnDragStop", function()
    --[[ El origen no se vacía acá: si se cancela el arrastre o se suelta fuera de la
         grilla, la asignación original queda intacta (fuera es copia segura). El
         descarte va diferido porque OnDragStop puede llegar antes que el
         OnReceiveDrag del destino. ]]
    local drag = PG._drag
    C_Timer.After(0, function()
      if PG._drag == drag then
        PG._drag = nil
      end
    end)
  end)

  return btn
end

-- ---------------------------------------------------------------------------
-- Masque
-- ---------------------------------------------------------------------------

function PG:GetMasqueGroup()
  if self:DB().useMasque == false then
    return nil
  end
  local stub = _G.LibStub
  if not stub then
    return nil
  end
  local masque = stub("Masque", true)
  if not masque or type(masque.Group) ~= "function" then
    return nil
  end
  if not self._masqueGroup then
    --- Grupo separado de ActionBars y RightStrip para poder elegir otra skin.
    self._masqueGroup = masque:Group("Chukie UI", "PartyGrid")
  end
  return self._masqueGroup
end

function PG:RemoveMasque()
  if inCombat() then
    self._pendingMasque = true
    return
  end
  local group = self._masqueGroup
  if not group or type(group.RemoveButton) ~= "function" then
    return
  end
  for i = 1, #(self._buttons or {}) do
    local btn = self._buttons[i]
    if btn._masqued then
      pcall(group.RemoveButton, group, btn)
      btn._masqued = nil
    end
  end
end

function PG:ApplyMasque()
  if inCombat() then
    self._pendingMasque = true
    return
  end
  self._pendingMasque = nil
  local group = self:GetMasqueGroup()
  if not group then
    self:RemoveMasque()
    return
  end
  local added = false
  for i = 1, #(self._buttons or {}) do
    local btn = self._buttons[i]
    if not btn._masqued and type(group.AddButton) == "function" then
      local ok = pcall(group.AddButton, group, btn, {
        Backdrop = btn.bg,
        Icon = btn.icon,
        Cooldown = btn.cooldown,
        Count = btn.charges,
        Normal = btn.masqueNormal,
        Pushed = false,
        Flash = false,
        Checked = false,
        Border = false,
        IconBorder = false,
        DebuffBorder = false,
        EnchantBorder = false,
        Highlight = false,
      }, "Action")
      if ok then
        btn._masqued = true
        added = true
      end
    end
  end
  if added and type(group.ReSkin) == "function" then
    pcall(group.ReSkin, group)
  end
end

function PG:EnsureCycleButton(actionName)
  self._cycleButtons = self._cycleButtons or {}
  local button = self._cycleButtons[actionName]
  if button then
    return button
  end
  local existing = _G[actionName]
  if existing then
    print("|cffff9900Chukie UI|r: la acción " .. actionName .. " ya fue publicada por otro addon.")
    return nil
  end
  local ok
  ok, button = pcall(CreateFrame, "Button", actionName, UIParent, "SecureActionButtonTemplate")
  if not ok or not button then
    return nil
  end
  button._chukiePartyCycle = true
  button._chukiePartyCycleOwner = "Chukie_Ui"
  button:SetSize(1, 1)
  button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -10)
  button:SetAlpha(0)
  button:SetAttribute("useOnKeyDown", false)
  --- Retail moderno necesita declarar también la fase de release para que `/click`
  --- dispare botones de hechizo cuando ActionButtonUseKeyDown está activo.
  button:SetAttribute("pressAndHoldAction", true)
  button:SetAttribute("typerelease", "spell")
  button:RegisterForClicks("AnyDown", "AnyUp")
  --[[ La lista va en `cycleUnitN` y no en `unitN`: los nombres terminados en 1..5 son
       atributos modificados del botón (la unidad de cada botón del mouse), así que
       `unit1` gana siempre sobre el `unit` que elige este ciclo. ]]
  SecureHandlerWrapScript(button, "PreClick", button, [[
    if not down then
      local count = self:GetAttribute("unitCount") or 0
      local index = self:GetAttribute("cycleIndex") or 0
      for i = 1, count do
        index = (index % count) + 1
        local unit = self:GetAttribute("cycleUnit" .. index)
        if unit and UnitExists(unit) then
          self:SetAttribute("unit", unit)
          self:SetAttribute("cycleIndex", index)
          break
        end
      end
    end
  ]])
  self._cycleButtons[actionName] = button
  return button
end

function PG:ApplyCycleAttributes()
  if inCombat() then
    self._pending = true
    return false
  end
  for _, button in pairs(self._cycleButtons or {}) do
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("unitCount", 0)
    button:SetAttribute("cycleIndex", 0)
    for i = 1, #UNITS do
      button:SetAttribute("cycleUnit" .. i, nil)
      --- Versiones previas guardaban la lista acá y esos valores pisan el ciclo.
      button:SetAttribute("unit" .. i, nil)
    end
  end
  for column = COLUMNS_MIN, COLUMNS_MAX do
    local spellId = self:ColumnSpell(column)
    local actionName = self:CycleActionName(column)
    local units = self:CycleUnits(column)
    if self:IsEnabled() and spellId and actionName and #units > 0 then
      local button = self:EnsureCycleButton(actionName)
      if button then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", spellId)
        button:SetAttribute("unit", units[1])
        button:SetAttribute("unitCount", #units)
        button:SetAttribute("cycleIndex", 0)
        for i = 1, #units do
          button:SetAttribute("cycleUnit" .. i, units[i])
        end
      end
    end
  end
  return true
end

function PG:ApplySecureAttributes()
  if not self._buttons then
    return false
  end
  if inCombat() then
    self._pending = true
    return false
  end
  for i = 1, #self._buttons do
    local btn = self._buttons[i]
    local spellId = self:ColumnSpell(btn.column)
    btn:SetAttribute("unit", btn.unit)
    if spellId then
      btn:SetAttribute("type1", "spell")
      btn:SetAttribute("spell1", spellId)
    else
      btn:SetAttribute("type1", nil)
      btn:SetAttribute("spell1", nil)
    end
    btn:SetAttribute("type2", nil)
    btn:SetAttribute("spell2", nil)
  end
  self:ApplyCycleAttributes()
  return true
end

function PG:EnsureFrames()
  if self._buttons then
    return true
  end
  if inCombat() then
    self._pending = true
    return false
  end

  local host = CreateFrame("Frame", "ChukieUi_PartyGrid", UIParent)
  host._chukieGrid = true
  host:SetFrameStrata("MEDIUM")
  host:SetClampedToScreen(true)
  host:SetMovable(true)
  host:EnableMouse(false)
  host:RegisterForDrag("LeftButton")
  host:SetSize(100, 100)
  host:SetPoint("CENTER")
  host.bg = host:CreateTexture(nil, "BACKGROUND")
  host.bg:SetAllPoints(host)
  host.bg:SetColorTexture(0, 0.7, 1, 0.12)
  host.bg:Hide()
  host.hint = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  host.hint:SetPoint("BOTTOM", host, "TOP", 0, 4)
  host.hint:SetText("Grilla clickeable: arrastrá para mover")
  host.hint:Hide()
  host:SetScript("OnDragStart", function(f)
    if inCombat() then
      return
    end
    f:StartMoving()
  end)
  host:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local cx, cy = f:GetCenter()
    local px, py = UIParent:GetCenter()
    if cx and cy and px and py and not (isSecret(cx) or isSecret(cy) or isSecret(px) or isSecret(py)) then
      -- Arrastrar implica posición propia: si seguía pegada a Blizzard, se suelta.
      PG:SetOptions({
        attachToBlizzard = false,
        point = { "CENTER", math.floor(cx - px + 0.5), math.floor(cy - py + 0.5) },
      }, "layout")
      return
    end
    PG:Layout()
    if PG._configFrame and PG._configFrame:IsShown() then
      PG:SyncConfig()
    end
  end)
  self._host = host

  self._buttons, self._cells = {}, {}
  for i = 1, #UNITS do
    self._cells[UNITS[i]] = {}
  end
  self:EnsureColumns(self:Columns())
  if #self._buttons == 0 then
    self._failed = true
    return false
  end
  return true
end

--[[ El pool se completa por columna y luego por unidad. Así una columna solo cuenta
     como disponible cuando existen sus cinco celdas; nunca se activa una grilla con
     filas de longitudes distintas. ]]
function PG:EnsureColumns(count)
  if not self._cells then
    return 0
  end
  count = math.floor(clamp(count, COLUMNS_MIN, COLUMNS_MAX))
  if inCombat() then
    local available = COLUMNS_MAX
    for i = 1, #UNITS do
      available = math.min(available, #self._cells[UNITS[i]])
    end
    --- Solo queda pendiente si de verdad faltan celdas por crear.
    if count > available then
      self._pending = true
    end
    return math.min(count, available)
  end
  for col = 1, count do
    for i = 1, #UNITS do
      local unit = UNITS[i]
      local row = self._cells[unit]
      if not row[col] then
        local btn = self:CreateButton(i, unit, col)
        if not btn then
          self._failed = true
          return col - 1
        end
        row[col] = btn
        self._buttons[#self._buttons + 1] = btn
        --- Si aumenta el número de columnas, la celda nueva necesita dibujarse ahora:
        --- no debe esperar a que llegue un evento de hechizo o unidad.
        self._newCells = true
      end
    end
  end
  return count
end

-- ---------------------------------------------------------------------------
-- Posición y visibilidad
-- ---------------------------------------------------------------------------

--- Marco de party de Blizzard visible al que pegarse, o nil si hay que usar
--- la posición propia guardada.
function PG:BlizzardHost()
  if self:DB().attachToBlizzard == false then
    return nil
  end
  for i = 1, #HOST_CANDIDATES do
    local f = _G[HOST_CANDIDATES[i]]
    if f and frameFlag(f, "IsVisible") then
      local width = frameNumber(f, "GetWidth")
      --- Ancho ilegible (marco con secretos): alcanza con que esté visible.
      if width == nil or width > 1 then
        return f
      end
    end
  end
  return nil
end

--[[ Contenedor de party de Blizzard, exista o no visible. Colgar nuestro host de él es
     lo que ata la visibilidad sin una línea de Lua: si el juego oculta su grilla (o la
     muestra), la nuestra corre la misma suerte, también en combate, donde no podríamos
     ocultarla por código.

     Los tres candidatos existen a la vez en Retail: el que manda es el del modo activo y
     los otros quedan creados pero ocultos para siempre. Tomar el primero que exista deja
     la grilla colgada de un marco que nunca se muestra —invisible aunque la de Blizzard
     esté a la vista, y sin arreglo con /reload—, así que primero se busca el que se está
     dibujando y solo al final se cae en el orden de la lista. ]]
function PG:BlizzardContainer()
  local shown
  for i = 1, #HOST_CANDIDATES do
    local f = _G[HOST_CANDIDATES[i]]
    if f and f.GetParent then
      if f.IsVisible and f:IsVisible() then
        return f
      end
      --- Mostrado pero con un padre oculto (fuera de grupo, por ejemplo) sigue siendo el
      --- marco del modo activo: es mejor candidato que uno apagado de raíz.
      if not shown and f.IsShown and f:IsShown() then
        shown = f
      end
    end
  end
  if shown then
    return shown
  end
  --- Sin grupo no hay nada visible: el modo de marcos lo dice el gestor de modo edición.
  local mgr = EditModeManagerFrame
  if mgr and mgr.UseRaidStylePartyFrames then
    local ok, raidStyle = pcall(mgr.UseRaidStylePartyFrames, mgr)
    if ok then
      local name = raidStyle and "CompactPartyFrame" or "PartyFrame"
      local f = _G[name]
      if f and f.GetParent then
        return f
      end
    end
  end
  for i = 1, #HOST_CANDIDATES do
    local f = _G[HOST_CANDIDATES[i]]
    if f and f.GetParent then
      return f
    end
  end
  return nil
end

--- Marcos de miembro de Blizzard indexados por unidad. Se recorre el árbol porque según
--- el estilo (party o raid) cuelgan a distinta profundidad, y se compara con UnitIsUnit
--- para que un "raid3" case con nuestro "party2".
function PG:BlizzardUnitFrames(container)
  local map = {}
  if not container then
    return map
  end
  --[[ Un hijo se examina completo o no se examina: cualquier acceso a un objeto prohibido
       aborta la ejecución, y ni siquiera se puede preguntar si lo es sin tocarlo. Devuelve si
       conviene seguir bajando por esa rama. La grilla queda fuera del recorrido, y no es un
       detalle: nuestras celdas también llevan un campo `unit` y, pegadas a Blizzard, son hijas
       de su contenedor. Sin ese filtro el mapa puede devolver una celda nuestra como marco de
       la unidad, y anclarla a sí misma aborta el layout ("Cannot anchor to itself"). Pasa justo
       fuera de grupo: los marcos de Blizzard no se dibujan y los nuestros sí. ]]
  local function inspect(child)
    if isSecret(child) or child._chukieGrid then
      return false
    end
    if child.IsForbidden and child:IsForbidden() then
      return false
    end
    local unit = type(child.unit) == "string" and child.unit or nil
    if not unit and child.GetAttribute then
      local ok, attr = pcall(child.GetAttribute, child, "unit")
      unit = ok and type(attr) == "string" and attr or nil
    end
    if unit and frameFlag(child, "IsVisible") then
      local width = frameNumber(child, "GetWidth")
      if width == nil or width > 1 then
        for _, ours in ipairs(UNITS) do
          if not map[ours] and sameUnit(unit, ours) then
            map[ours] = child
            break
          end
        end
      end
    end
    --[[ Un marco marcado con secretos devuelve medidas e hijos ilegibles, así que no se baja
         por su rama: las barras de vida entran en esa categoría y no contienen marcos de
         unidad, con lo que el mapa no pierde nada. ]]
    return not frameFlag(child, "HasSecretValues")
  end

  local function scan(frame, depth)
    if depth > 8 then
      return
    end
    local children = frameChildren(frame)
    if not children then
      return
    end
    for i = 1, #children do
      local child = children[i]
      local ok, deeper = pcall(inspect, child)
      if ok and deeper then
        scan(child, depth + 1)
      end
    end
  end
  scan(container, 1)
  return map
end

local function anchorToHost(host, target, side, gap, ox, oy)
  host:ClearAllPoints()
  if side == "LEFT" then
    host:SetPoint("TOPRIGHT", target, "TOPLEFT", -gap + ox, oy)
  elseif side == "TOP" then
    host:SetPoint("BOTTOMLEFT", target, "TOPLEFT", ox, gap + oy)
  elseif side == "BOTTOM" then
    host:SetPoint("TOPLEFT", target, "BOTTOMLEFT", ox, -gap + oy)
  else
    host:SetPoint("TOPLEFT", target, "TOPRIGHT", gap + ox, oy)
  end
end

function PG:Layout()
  if not self._buttons then
    return
  end
  if inCombat() then
    -- Mover o redimensionar frames seguros en combate no está permitido.
    self._pending = true
    return
  end

  local host = self._host
  local db = self:DB()
  local size = self:CellSize()
  local spacing = self:Spacing()
  local vertical = self:Orientation() == "vertical"
  local unlocked = db.unlocked == true
  --- Al mover se muestran las 5 celdas, haya grupo o no.
  local forceAll = unlocked

  local attached = db.attachToBlizzard ~= false
  local container = attached and self:BlizzardContainer() or nil
  --- Al mover colgamos de UIParent: si no, con la grilla de Blizzard oculta la nuestra
  --- tampoco se vería y no habría nada que arrastrar.
  local newParent = (container and not unlocked) and container or UIParent
  if host:GetParent() ~= newParent then
    host:SetParent(newParent)
  end
  --[[ Correspondencia celda a celda. BlizzardUnitFrames solo devuelve marcos visibles,
       así que con su grilla oculta el mapa queda vacío y caemos en la fila propia. ]]
  local rows = (container and not unlocked) and self:BlizzardUnitFrames(container) or nil

  -- Orden: primero las unidades presentes (grilla compacta), después las vacías,
  -- así una incorporación en combate aparece al final sin recolocar nada.
  local order, tail = {}, {}
  for _, unit in ipairs(self:UnitList()) do
    if unit == "player" or UnitExists(unit) or forceAll then
      order[#order + 1] = unit
    else
      tail[#tail + 1] = unit
    end
  end
  local visible = #order
  for i = 1, #tail do
    order[#order + 1] = tail[i]
  end

  --[[ Mismo orden que Blizzard: la clave sale de la posición real de cada marco suyo
       (más arriba primero; a igual altura, más a la izquierda), así respetamos su
       ordenamiento por rol o por grupo sin tener que replicar sus reglas. Se ordena por
       clave numérica y no con un comparador de posiciones para que la comparación sea
       siempre consistente: un comparador contradictorio aborta table.sort. ]]
  if rows then
    local key = {}
    for i, unit in ipairs(order) do
      local ref = rows[unit]
      local top = ref and frameNumber(ref, "GetTop")
      local left = ref and frameNumber(ref, "GetLeft")
      if top and left then
        key[unit] = -math.floor(top * 10) * 10000 + math.floor(left * 10)
      else
        key[unit] = 1e12 + i
      end
    end
    table.sort(order, function(a, b)
      if key[a] == key[b] then
        return false
      end
      return key[a] < key[b]
    end)
  end

  --- Columnas realmente disponibles: en combate puede haber menos creadas que pedidas.
  local columns = self:EnsureColumns(self:Columns())
  self:ApplySecureAttributes()
  local colSpacing = self:ColumnSpacing()
  local growth = self:Growth()
  local growHorizontal = (growth == "RIGHT" or growth == "LEFT")

  --- Caja del host: el largo del eje de unidades más lo que ocupan las columnas. Solo
  --- importa para arrastrar y para las celdas que se colocan respecto del host.
  local slots = math.max(visible, 1)
  local unitPx = slots * size + (slots - 1) * spacing
  local colPx = columns * size + (columns - 1) * colSpacing
  if vertical then
    host:SetSize(growHorizontal and colPx or size, growHorizontal and unitPx or (unitPx + colPx - size))
  else
    host:SetSize(growHorizontal and (unitPx + colPx - size) or unitPx, growHorizontal and size or colPx)
  end

  local target = self:BlizzardHost()
  local ox, oy = self:Offsets()
  if target then
    anchorToHost(host, target, self:Side(), self:Gap(), ox, oy)
  else
    local p = type(db.point) == "table" and db.point or { "CENTER", -320, 0 }
    host:ClearAllPoints()
    host:SetPoint("CENTER", UIParent, "CENTER", tonumber(p[2]) or -320, tonumber(p[3]) or 0)
  end

  local step = size + spacing
  local side = self:Side()
  --- Cada grupo de celdas puede seguir al marco de su unidad en cualquiera de los lados.
  --- Esto también cubre los party frames Blizzard dispuestos en horizontal.
  local perCell = rows and db.perUnitAnchor ~= false
  local gap = self:Gap()
  --- Creciendo a la izquierda o hacia arriba las columnas van hacia el borde contrario
  --- de la caja: la primera celda arranca corrida para que el bloque entre igual.
  local colBack = colPx - size
  local firstX = (growth == "LEFT") and colBack or 0
  local firstY = (growth == "UP") and colBack or 0
  local seq, prev = 0, nil
  for i = 1, #order do
    local unit = order[i]
    local row = self._cells[unit]
    local btn = row and row[1]
    if btn then
      btn:SetSize(size, size)
      btn:ClearAllPoints()
      local ref = perCell and rows[unit] or nil
      --- Anclarse a sí misma aborta el layout entero: la celda queda sin punto y la grilla
      --- a medio armar. Barato de descartar, caro de dejar pasar.
      if ref == btn then
        ref = nil
      end
      if ref then
        local cx, cy = 0, 0
        if side == "TOP" or side == "BOTTOM" then
          if growth == "RIGHT" then
            cx = -colBack / 2
          elseif growth == "LEFT" then
            cx = colBack / 2
          end
        elseif growth == "DOWN" then
          cy = colBack / 2
        elseif growth == "UP" then
          cy = -colBack / 2
        end
        if side == "LEFT" then
          btn:SetPoint("RIGHT", ref, "LEFT", -gap + ox, cy + oy)
        elseif side == "TOP" then
          btn:SetPoint("BOTTOM", ref, "TOP", cx + ox, gap + oy)
        elseif side == "BOTTOM" then
          btn:SetPoint("TOP", ref, "BOTTOM", cx + ox, -gap + oy)
        else
          btn:SetPoint("LEFT", ref, "RIGHT", gap + ox, cy + oy)
        end
        prev = btn
      elseif prev then
        --- Sin marco propio (todavía no existe para Blizzard): en cadena tras la anterior.
        if vertical then
          btn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing)
        else
          btn:SetPoint("TOPLEFT", prev, "TOPRIGHT", spacing, 0)
        end
        prev = btn
      elseif vertical then
        btn:SetPoint("TOPLEFT", host, "TOPLEFT", firstX, -(firstY + seq * step))
        seq = seq + 1
      else
        btn:SetPoint("TOPLEFT", host, "TOPLEFT", firstX + seq * step, -firstY)
        seq = seq + 1
      end

      --- Resto de la fila: cada columna cuelga de la anterior en la dirección elegida,
      --- así la fila entera sigue a la celda anclada a la unidad.
      local prevCol = btn
      for col = 2, columns do
        local cell = row[col]
        if cell then
          cell:SetSize(size, size)
          cell:ClearAllPoints()
          if growth == "LEFT" then
            cell:SetPoint("TOPRIGHT", prevCol, "TOPLEFT", -colSpacing, 0)
          elseif growth == "UP" then
            cell:SetPoint("BOTTOMLEFT", prevCol, "TOPLEFT", 0, colSpacing)
          elseif growth == "DOWN" then
            cell:SetPoint("TOPLEFT", prevCol, "BOTTOMLEFT", 0, -colSpacing)
          else
            cell:SetPoint("TOPLEFT", prevCol, "TOPRIGHT", colSpacing, 0)
          end
          prevCol = cell
        end
      end
    end
  end

  -- Fuera quedan las columnas de más y, si no se lo incluye, la fila del jugador.
  local includePlayer = db.includePlayer ~= false
  for i = 1, #self._buttons do
    local btn = self._buttons[i]
    if (btn.column or 1) > columns or (btn.unit == "player" and not includePlayer) then
      if btn._watched then
        UnregisterUnitWatch(btn)
        btn._watched = nil
      end
      btn:Hide()
    elseif forceAll then
      if btn._watched then
        UnregisterUnitWatch(btn)
        btn._watched = nil
      end
      btn:Show()
    else
      if not btn._watched then
        RegisterUnitWatch(btn)
        btn._watched = true
      end
    end
  end

  -- Se registra en cada layout: así el driver reevalúa el estado en el momento
  -- (y no queda visible una grilla que debía ocultarse).
  local cond = (db.showSolo == true) and "[petbattle] hide; show"
    or "[petbattle] hide; [group:party][group:raid] show; hide"
  if unlocked then
    cond = "show"
  end
  RegisterStateDriver(host, "visibility", cond)
  self._visibilityCond = cond

  --[[ Opacidad de la grilla completa: va en el host y las celdas la heredan, así que un
       solo valor cubre iconos, vida, cooldown, rol y bordes sin tocar cada región. Al
       mover se fuerza opaca: con la grilla translúcida y la pantalla despejada, arrastrar
       a ciegas no tiene sentido. ]]
  host:SetAlpha(unlocked and 1 or (self:AlphaPercent() / 100))

  if unlocked then
    host.bg:Show()
    host.hint:Show()
    host:EnableMouse(true)
  else
    host.bg:Hide()
    host.hint:Hide()
    host:EnableMouse(false)
  end
  self._pending = false
  --- Las mismas claves se editan desde el menú del addon: si la ventana propia está
  --- abierta, que no quede mostrando los valores anteriores.
  if self._configFrame and self._configFrame:IsShown() then
    self:SyncConfig()
  end
  self:ApplyMasque()
  --- Después de Masque: UpdateAction no repone texcoords sobre una skin ya aplicada.
  if self._newCells then
    self._newCells = nil
    self:UpdateAll()
  end
end

function PG:Refresh()
  if not self:IsEnabled() then
    self:SetUnitEventsActive(false)
    self:RemoveMasque()
    if self._buttons and not inCombat() then
      --- Un cambio de perfil también actualiza las acciones ocultas; así nunca quedan
      --- atributos del perfil anterior esperando a que se vuelva a activar la grilla.
      self:ApplySecureAttributes()
    end
    if self._host then
      if inCombat() then
        self._pending = true
      else
        if self._visibilityCond then
          UnregisterStateDriver(self._host, "visibility")
          self._visibilityCond = nil
        end
        for i = 1, #(self._buttons or {}) do
          local btn = self._buttons[i]
          if btn._watched then
            UnregisterUnitWatch(btn)
            btn._watched = nil
          end
          btn:Hide()
        end
        self._host:Hide()
      end
    end
    if self._configFrame and self._configFrame:IsShown() then
      self:SyncConfig()
    end
    self:RefreshSettings()
    return
  end

  if not self:EnsureFrames() then
    if self._configFrame and self._configFrame:IsShown() then
      self:SyncConfig()
    end
    return
  end
  self:SetUnitEventsActive(true)
  self:ApplySecureAttributes()
  -- La visibilidad del host la decide el state driver que registra Layout.
  self:Layout()
  self:UpdateAll()
  if self._configFrame and self._configFrame:IsShown() then
    self:SyncConfig()
  end
  self:RefreshSettings()
end

local function errTraceback(e)
  return tostring(e) .. "\n" .. debugstack(2, 6, 0)
end

--[[ Contabilidad de fallos del módulo, común al pulso y a los eventos. El corte es de
     sesión y no escribe el perfil: apagar la opción guardada dejaba la grilla muerta
     también después de un /reload, sin nada a la vista que lo explicara. El error se
     reenvía al manejador del juego para que un capturador (BugSack) guarde la traza. ]]
function PG:ReportError(err, source)
  self._lastError = tostring(err)
  self._lastErrorSource = source
  self._errorCount = (self._errorCount or 0) + 1
  if self._errorCount <= 3 then
    print("|cffff9900Chukie UI|r grilla de party, error en " .. tostring(source) .. ":")
    print("|cffff9900Chukie UI|r " .. tostring(err))
    pcall(geterrorhandler(), err)
  end
  --- Un fallo aislado (una carga de zona a medias, por ejemplo) no justifica perder la
  --- grilla: se corta cuando se vuelve repetido.
  if self._errorCount == 3 then
    self._killed = true
    print("|cffff9900Chukie UI|r: grilla de party apagada por esta sesión. /reload la restaura; /chukieui party on la reintenta ya. Estado: /chukieui party diag")
    pcall(self.Refresh, self)
  end
end

local rangeElapsed, hostElapsed = 0, 0
local doHost, doRange = false, false
local function tickWork()
  if doHost then
    PG:CheckHost()
  end
  if doRange then
    PG:TickRange()
  end
end

local function rangeTick(_, elapsed)
  hostElapsed = hostElapsed + elapsed
  rangeElapsed = rangeElapsed + elapsed
  doHost = hostElapsed >= 1
  doRange = rangeElapsed >= 0.2
  if not (doHost or doRange) then
    return
  end
  if doHost then
    hostElapsed = 0
  end
  if doRange then
    rangeElapsed = 0
  end
  --- Sin red, un fallo acá se repetiría cinco veces por segundo.
  local ok, err = xpcall(tickWork, errTraceback)
  if not ok then
    PG:ReportError(err, "pulso")
  end
end

--- Los eventos de unidad y de hechizo llegan sin filtro, y el pulso de rango cuesta
--- aunque no haya nada que dibujar: los tres se apagan con la grilla.
function PG:SetUnitEventsActive(on)
  local ev = self._ev
  if not ev or self._unitEventsOn == on then
    return
  end
  self._unitEventsOn = on
  for i = 1, #UNIT_EVENTS do
    if on then
      ev:RegisterEvent(UNIT_EVENTS[i])
    else
      ev:UnregisterEvent(UNIT_EVENTS[i])
    end
  end
  for i = 1, #SPELL_EVENTS do
    if on then
      pcall(ev.RegisterEvent, ev, SPELL_EVENTS[i])
    else
      pcall(ev.UnregisterEvent, ev, SPELL_EVENTS[i])
    end
  end
  ev:SetScript("OnUpdate", on and rangeTick or nil)
end

function PG:SetEnabled(on)
  --- Encenderla a mano también levanta el corte de sesión: es la forma de reintentar
  --- después de un fallo sin salir del juego.
  if on then
    self._killed = nil
    self._errorCount = 0
    self._failed = nil
  end
  return self:SetOption("enabled", on and true or false, "refresh")
end

function PG:SetUnlocked(on)
  return self:SetOption("unlocked", on and true or false, "refresh")
end

-- ---------------------------------------------------------------------------
-- Ventana de configuración
-- ---------------------------------------------------------------------------

local function makeButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 100, h or 22)
  b:SetText(text or "")
  return b
end

local function makeCheck(parent, label, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
  c.text:SetText(label)
  c:SetScript("OnClick", function(cb)
    onClick(cb:GetChecked() and true or false)
  end)
  return c
end

local function makeSlider(parent, key, label, lo, hi, step)
  local s = CreateFrame("Slider", "ChukieUi_PartyGrid" .. key, parent, "OptionsSliderTemplate")
  s:SetWidth(180)
  s:SetMinMaxValues(lo, hi)
  s:SetValueStep(step or 1)
  s:SetObeyStepOnDrag(true)
  --[[ Con rangos anchos (la distancia y los ajustes llegan a ±600 sobre 180 px de barra) el
       arrastre no sirve para el ajuste fino: la rueda mueve exactamente un paso. ]]
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(slider, delta)
    if slider.IsEnabled and not slider:IsEnabled() then
      return
    end
    slider:SetValue(slider:GetValue() + delta * (slider:GetValueStep() or 1))
  end)
  local name = s:GetName()
  _G[name .. "Low"]:SetText(tostring(lo))
  _G[name .. "High"]:SetText(tostring(hi))
  s.labelText = _G[name .. "Text"]
  s.labelBase = label
  return s
end

local function setEnabled(widget, on)
  if widget.SetEnabled then
    widget:SetEnabled(on and true or false)
  elseif on and widget.Enable then
    widget:Enable()
  elseif widget.Disable then
    widget:Disable()
  end
end

local function cycle(list, current)
  for i = 1, #list do
    if list[i] == current then
      return list[(i % #list) + 1]
    end
  end
  return list[1]
end

function PG:EnsureConfig()
  if self._configFrame then
    return self._configFrame
  end
  local f = CreateFrame("Frame", "ChukieUi_PartyGridConfig", UIParent, "BackdropTemplate")
  f:SetSize(540, math.min(860, math.floor((frameNumber(UIParent, "GetHeight") or 800) * 0.92)))
  f:SetPoint("CENTER", UIParent, "CENTER", ((frameNumber(UIParent, "GetWidth") or 1024) / 4), 0)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(200)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  tinsert(UISpecialFrames, "ChukieUi_PartyGridConfig")
  f:SetScript("OnHide", function()
    if PG:DB().unlocked ~= true then
      return
    end
    --- Cerrar la ventana en combate no puede fijar la grilla (sería escribir el perfil):
    --- queda anotado y se aplica en PLAYER_REGEN_ENABLED, sin avisos de rechazo.
    if inCombat() then
      PG._wantLock = true
      return
    end
    PG:SetUnlocked(false)
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("Chukie UI — Grilla de party clickeable")

  CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -4, -4)

  local scroll = CreateFrame("ScrollFrame", "ChukieUi_PartyGridConfigScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -40)
  scroll:SetPoint("BOTTOMRIGHT", -34, 14)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange() or 0
    local value = (self:GetVerticalScroll() or 0) - delta * 40
    self:SetVerticalScroll(math.max(0, math.min(range, value)))
  end)

  local body = CreateFrame("Frame", nil, scroll)
  body:SetSize(470, 1120)
  scroll:SetScrollChild(body)
  f.scroll = scroll
  f.body = body

  f.enabledCheck = makeCheck(body, "Grilla activa", function(v)
    PG:SetEnabled(v)
  end)
  f.enabledCheck:SetPoint("TOPLEFT", 0, 0)

  f.moveBtn = makeButton(body, "Mover", 90, 22)
  f.moveBtn:SetPoint("TOPRIGHT", 0, -2)
  f.moveBtn:SetScript("OnClick", function()
    PG:SetUnlocked(PG:DB().unlocked ~= true)
  end)

  local function onSlider(slider, key, value, suffix)
    slider.labelText:SetText(slider.labelBase .. ": " .. tostring(value) .. (suffix or ""))
    PG:SetOption(key, value, "layout")
  end

  f.sizeSlider = makeSlider(body, "Size", "Tamaño de celda", SIZE_MIN, SIZE_MAX, 1)
  f.sizeSlider:SetPoint("TOPLEFT", 8, -40)
  f.sizeSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onSlider(s, "size", math.floor(v + 0.5), " px")
  end)

  f.spacingSlider = makeSlider(body, "Spacing", "Separación", 0, SPACING_MAX, 1)
  f.spacingSlider:SetPoint("TOPLEFT", 8, -88)
  f.spacingSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onSlider(s, "spacing", math.floor(v + 0.5), " px")
  end)

  f.columnsSlider = makeSlider(body, "Columns", "Columnas por jugador", COLUMNS_MIN, COLUMNS_MAX, 1)
  f.columnsSlider:SetPoint("TOPLEFT", 8, -136)
  f.columnsSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onSlider(s, "columns", math.floor(v + 0.5))
  end)

  f.colSpacingSlider = makeSlider(body, "ColSpacing", "Separación de columnas", 0, COLUMN_SPACING_MAX, 1)
  f.colSpacingSlider:SetPoint("TOPLEFT", 8, -184)
  f.colSpacingSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onSlider(s, "columnSpacing", math.floor(v + 0.5), " px")
  end)

  f.gapSlider = makeSlider(body, "Gap", "Distancia a la grilla", GAP_MIN, GAP_MAX, 2)
  f.gapSlider:SetPoint("TOPLEFT", 228, -40)
  f.gapSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onSlider(s, "gap", math.floor(v + 0.5), " px")
  end)

  f.offsetXSlider = makeSlider(body, "OffsetX", "Ajuste X", -OFFSET_MAX, OFFSET_MAX, 2)
  f.offsetXSlider:SetPoint("TOPLEFT", 228, -88)
  f.offsetXSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onSlider(s, "offsetX", math.floor(v + 0.5), " px")
  end)

  f.offsetYSlider = makeSlider(body, "OffsetY", "Ajuste Y", -OFFSET_MAX, OFFSET_MAX, 2)
  f.offsetYSlider:SetPoint("TOPLEFT", 228, -136)
  f.offsetYSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onSlider(s, "offsetY", math.floor(v + 0.5), " px")
  end)

  f.alphaSlider = makeSlider(body, "Alpha", "Opacidad", ALPHA_MIN, ALPHA_MAX, 5)
  f.alphaSlider:SetPoint("TOPLEFT", 8, -352)
  f.alphaSlider:SetScript("OnValueChanged", function(s, v)
    if s._syncing then
      return
    end
    onSlider(s, "alphaPercent", math.floor(v + 0.5), "%")
  end)

  f.growthBtn = makeButton(body, "Crecen: Hacia la derecha", 200, 22)
  f.growthBtn:SetPoint("TOPLEFT", 224, -186)
  f.growthBtn:SetScript("OnClick", function()
    PG:SetOption("growth", cycle(GROWTHS, PG:Growth()), "layout")
  end)

  f.orientationBtn = makeButton(body, "Orientación: Vertical", 170, 22)
  f.orientationBtn:SetPoint("TOPLEFT", 0, -226)
  f.orientationBtn:SetScript("OnClick", function()
    PG:SetOption("orientation", cycle(ORIENTATIONS, PG:Orientation()), "layout")
  end)

  f.sideBtn = makeButton(body, "Lado: Derecha", 170, 22)
  f.sideBtn:SetPoint("TOPLEFT", 0, -252)
  f.sideBtn:SetScript("OnClick", function()
    PG:SetOption("side", cycle(SIDES, PG:Side()), "layout")
  end)

  f.attachCheck = makeCheck(body, "Pegada a la grilla de Blizzard", function(v)
    PG:SetOption("attachToBlizzard", v, "layout")
  end)
  f.attachCheck:SetPoint("TOPLEFT", 224, -224)

  f.soloCheck = makeCheck(body, "Mostrar en solitario", function(v)
    PG:SetOption("showSolo", v, "layout")
  end)
  f.soloCheck:SetPoint("TOPLEFT", 224, -248)

  f.playerCheck = makeCheck(body, "Incluir al jugador", function(v)
    PG:SetOption("includePlayer", v, "refresh")
  end)
  f.playerCheck:SetPoint("TOPLEFT", 0, -284)

  f.healthCheck = makeCheck(body, "Barra de vida", function(v)
    PG:SetOption("showHealth", v, "refresh")
  end)
  f.healthCheck:SetPoint("TOPLEFT", 224, -284)

  f.roleCheck = makeCheck(body, "Icono de rol", function(v)
    PG:SetOption("showRole", v, "refresh")
  end)
  f.roleCheck:SetPoint("TOPLEFT", 0, -308)

  f.masqueCheck = makeCheck(body, "Usar Masque (grupo PartyGrid)", function(v)
    PG:SetOption("useMasque", v, "refresh")
  end)
  f.masqueCheck:SetPoint("TOPLEFT", 224, -308)

  f.perUnitCheck = makeCheck(body, "Anclar cada grupo a su jugador", function(v)
    PG:SetOption("perUnitAnchor", v, "layout")
  end)
  f.perUnitCheck:SetPoint("TOPLEFT", 224, -334)

  f.columnsHeader = body:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.columnsHeader:SetPoint("TOPLEFT", 0, -374)
  f.columnsHeader:SetText("Habilidades por columna")

  f.columnsHint = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.columnsHint:SetPoint("TOPLEFT", 0, -398)
  f.columnsHint:SetPoint("RIGHT", body, "RIGHT", 0, 0)
  f.columnsHint:SetJustifyH("LEFT")
  f.columnsHint:SetTextColor(0.72, 0.72, 0.78)
  f.columnsHint:SetText("Escribí el nombre exacto o el ID y dale Enter. Vacío limpia la columna.")

  f.columnLabels, f.columnEdits = {}, {}
  f.columnCycleButtons, f.columnClearButtons = {}, {}
  f.columnMacroEdits, f.columnCycleInfo = {}, {}
  for column = 1, COLUMNS_MAX do
    local columnIndex = column
    local y = -424 - (column - 1) * 48

    local label = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, y - 5)
    label:SetWidth(48)
    label:SetJustifyH("LEFT")
    f.columnLabels[column] = label

    local edit = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    edit:SetSize(190, 22)
    edit:SetPoint("TOPLEFT", 56, y)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(96)
    edit:SetScript("OnEditFocusLost", function(self)
      if not self._syncing then
        PG:SetColumnSpellInput(columnIndex, self:GetText())
      end
    end)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
    edit:SetScript("OnEscapePressed", function(self)
      self._syncing = true
      self:ClearFocus()
      self._syncing = false
      PG:SyncConfig()
    end)
    f.columnEdits[column] = edit

    local cycleButton = makeButton(body, "Normal", 62, 20)
    cycleButton:SetPoint("TOPLEFT", 252, y - 1)
    cycleButton:SetScript("OnClick", function()
      PG:SetColumnCycle(columnIndex, not PG:IsCycleColumn(columnIndex))
    end)
    f.columnCycleButtons[column] = cycleButton

    local clear = makeButton(body, "Limpiar", 62, 20)
    clear:SetPoint("TOPLEFT", 320, y - 1)
    clear:SetScript("OnClick", function()
      PG:SetColumnSpell(columnIndex, nil)
    end)
    f.columnClearButtons[column] = clear

    local macro = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    macro:SetSize(190, 20)
    macro:SetPoint("TOPLEFT", 56, y - 24)
    macro:SetAutoFocus(false)
    macro:SetMaxLetters(96)
    macro:SetTextColor(0.7, 0.85, 1)
    macro:SetScript("OnEditFocusGained", function(self)
      self:HighlightText()
    end)
    macro:SetScript("OnEnterPressed", macro.ClearFocus)
    macro:SetScript("OnEscapePressed", macro.ClearFocus)
    macro:SetScript("OnEditFocusLost", function()
      PG:SyncConfig()
    end)
    f.columnMacroEdits[column] = macro

    local info = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", 252, y - 28)
    info:SetPoint("RIGHT", body, "RIGHT", 0, 0)
    info:SetJustifyH("LEFT")
    f.columnCycleInfo[column] = info
  end

  f.help = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.help:SetPoint("TOPLEFT", 0, -824)
  f.help:SetPoint("RIGHT", body, "RIGHT", 0, 0)
  f.help:SetJustifyH("LEFT")
  f.help:SetJustifyV("TOP")
  f.help:SetTextColor(0.72, 0.72, 0.78)

  self._configFrame = f
  return f
end

function PG:SyncConfig()
  local f = self:EnsureConfig()
  local db = self:DB()
  f.enabledCheck:SetChecked(db.enabled == true)
  f.moveBtn:SetText(db.unlocked == true and "Fijar" or "Mover")

  local function setSlider(s, value, suffix)
    s._syncing = true
    s:SetValue(value)
    s._syncing = false
    s.labelText:SetText(s.labelBase .. ": " .. tostring(value) .. (suffix or ""))
  end
  local ox, oy = self:Offsets()
  setSlider(f.sizeSlider, self:CellSize(), " px")
  setSlider(f.spacingSlider, self:Spacing(), " px")
  setSlider(f.columnsSlider, self:Columns())
  setSlider(f.colSpacingSlider, self:ColumnSpacing(), " px")
  setSlider(f.gapSlider, self:Gap(), " px")
  setSlider(f.offsetXSlider, ox, " px")
  setSlider(f.offsetYSlider, oy, " px")
  setSlider(f.alphaSlider, self:AlphaPercent(), "%")

  f.growthBtn:SetText("Crecen: " .. (GROWTH_LABELS[self:Growth()] or "Hacia la derecha"))
  f.orientationBtn:SetText("Orientación: " .. (ORIENTATION_LABELS[self:Orientation()] or "Vertical"))
  f.sideBtn:SetText("Lado: " .. (SIDE_LABELS[self:Side()] or "Derecha"))
  f.attachCheck:SetChecked(db.attachToBlizzard ~= false)
  f.perUnitCheck:SetChecked(db.perUnitAnchor ~= false)
  f.soloCheck:SetChecked(db.showSolo == true)
  f.playerCheck:SetChecked(db.includePlayer ~= false)
  f.healthCheck:SetChecked(db.showHealth ~= false)
  f.roleCheck:SetChecked(db.showRole ~= false)
  f.masqueCheck:SetChecked(db.useMasque ~= false)
  local activeColumns = self:Columns()
  for column = 1, COLUMNS_MAX do
    local spellId = self:ColumnSpell(column)
    local info = spellId and spellInfo(spellId) or nil
    local isCycle = self:IsCycleColumn(column)
    f.columnLabels[column]:SetText("Col. " .. column)
    --- Apagada la etiqueta de una columna que hoy no se dibuja: su hechizo sigue
    --- guardado, pero no hay celdas donde lanzarlo.
    if column <= activeColumns then
      f.columnLabels[column]:SetTextColor(1, 0.82, 0)
    else
      f.columnLabels[column]:SetTextColor(0.55, 0.55, 0.55)
    end

    local edit = f.columnEdits[column]
    if not edit:HasFocus() then
      edit._syncing = true
      edit:SetText(info and (info.name or tostring(spellId)) or "")
      edit:SetCursorPosition(0)
      edit._syncing = false
    end

    f.columnCycleButtons[column]:SetText(isCycle and "Ciclo" or "Normal")

    local macro = f.columnMacroEdits[column]
    local action = self:CycleActionName(column)
    macro._syncing = true
    macro:SetText(action and ("/click " .. action) or "(sin ciclo)")
    macro:SetCursorPosition(0)
    macro._syncing = false

    local unitInfo = f.columnCycleInfo[column]
    if isCycle then
      unitInfo:SetText("Ciclo: " .. self:CycleUnitSummary(column))
      unitInfo:SetTextColor(0.55, 0.85, 1)
    elseif spellId then
      unitInfo:SetText("Normal: lanza sobre la fila.")
      unitInfo:SetTextColor(0.6, 0.6, 0.66)
    else
      unitInfo:SetText("Vacía.")
      unitInfo:SetTextColor(0.6, 0.6, 0.66)
    end

    setEnabled(edit, not inCombat())
    setEnabled(f.columnCycleButtons[column], not inCombat())
    setEnabled(f.columnClearButtons[column], not inCombat() and spellId ~= nil)
    setEnabled(macro, action ~= nil)
  end

  local baseControls = {
    f.enabledCheck,
    f.moveBtn,
    f.sizeSlider,
    f.spacingSlider,
    f.columnsSlider,
    f.gapSlider,
    f.offsetXSlider,
    f.offsetYSlider,
    f.alphaSlider,
    f.orientationBtn,
    f.attachCheck,
    f.perUnitCheck,
    f.playerCheck,
    f.healthCheck,
    f.roleCheck,
    f.masqueCheck,
  }
  for i = 1, #baseControls do
    setEnabled(baseControls[i], true)
  end

  local attached = self:BlizzardHost() ~= nil
  setEnabled(f.sideBtn, attached)
  setEnabled(f.gapSlider, attached)
  setEnabled(f.perUnitCheck, db.attachToBlizzard ~= false)
  --- Con una sola columna no hay nada que separar ni hacia dónde crecer.
  local multi = self:Columns() > 1
  setEnabled(f.colSpacingSlider, multi)
  setEnabled(f.growthBtn, multi)
  --- Pegada a Blizzard, la visibilidad la decide su grilla: la casilla de solitario no
  --- puede cambiar nada.
  setEnabled(f.soloCheck, db.attachToBlizzard == false)

  local configurable = not inCombat()
  local controls = {
    f.enabledCheck,
    f.moveBtn,
    f.sizeSlider,
    f.spacingSlider,
    f.columnsSlider,
    f.colSpacingSlider,
    f.gapSlider,
    f.offsetXSlider,
    f.offsetYSlider,
    f.alphaSlider,
    f.growthBtn,
    f.orientationBtn,
    f.sideBtn,
    f.attachCheck,
    f.perUnitCheck,
    f.soloCheck,
    f.playerCheck,
    f.healthCheck,
    f.roleCheck,
    f.masqueCheck,
  }
  if not configurable then
    for i = 1, #controls do
      setEnabled(controls[i], false)
    end
  end

  local lines = {}
  if self._failed then
    lines[#lines + 1] = "|cffff6666Este cliente rechazó las plantillas seguras|r: la grilla no se puede crear."
  elseif inCombat() then
    lines[#lines + 1] = "|cffffcc66Configuración bloqueada durante el combate|r: los cambios se rechazan y no se guardan."
  end
  if db.attachToBlizzard ~= false then
    lines[#lines + 1] = "Pegada a la grilla de Blizzard: cuelga de su marco, así que |cffffffffaparece y desaparece con ella|r"
      .. " y cada celda se ancla enfrente de la fila de su unidad, respetando el orden que use Blizzard."
    if not attached then
      lines[#lines + 1] = "Ahora su grilla no está visible, así que la nuestra tampoco. Para probar estando solo, armá"
        .. " un grupo de |cffffffffseguidores|r por la cola de LFG: aparecen las dos grillas con miembros reales."
    end
  end
  lines[#lines + 1] = "Arrastrá un hechizo del libro sobre cualquier celda para asignarlo a toda su columna. Arrastrá desde una celda a otra columna para moverlo; soltar fuera o cancelar conserva el origen."
  if multi then
    lines[#lines + 1] = "Cada jugador lleva |cffffffff" .. self:Columns() .. " celdas|r en fila, todas sobre su misma unidad:"
      .. " cada columna lanza una habilidad distinta sobre la unidad de esa fila."
  end
  lines[#lines + 1] = "Clic izquierdo: lanza el hechizo de la columna sobre la fila de esa celda. Una columna vacía no ejecuta nada."
  lines[#lines + 1] = "Una columna en |cffffffffCiclo|r publica /click ch-cl-Hechizo: cada pulsación avanza por los jugadores incluidos."
    .. " Fuera de combate, clic derecho incluye o excluye; los excluidos se ven apagados."
  lines[#lines + 1] = "Si alguien entra al grupo en combate, su celda aparece al final hasta que la pelea termine: recolocar marcos seguros en combate no está permitido."
  f.help:SetText(table.concat(lines, "\n\n"))
end

function PG:ShowConfig()
  local f = self:EnsureConfig()
  self:SyncConfig()
  f:Show()
end

function PG:ToggleConfig()
  local f = self:EnsureConfig()
  if f:IsShown() then
    f:Hide()
  else
    self:ShowConfig()
  end
end

-- ---------------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------------

do
  local ev = CreateFrame("Frame")
  PG._ev = ev
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("ADDON_LOADED")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:RegisterEvent("PLAYER_REGEN_DISABLED")
  ev:RegisterEvent("GROUP_ROSTER_UPDATE")
  ev:RegisterEvent("PLAYER_TARGET_CHANGED")
  ev:RegisterEvent("PLAYER_ROLES_ASSIGNED")
  --- Morir, liberar el espíritu y volver rearma los marcos de party de Blizzard: si no
  --- recalculamos, las celdas quedan ancladas a marcos que ya no se dibujan.
  ev:RegisterEvent("PLAYER_DEAD")
  ev:RegisterEvent("PLAYER_ALIVE")
  ev:RegisterEvent("PLAYER_UNGHOST")
  --- Cambiar el tamaño o el estilo de la grilla de party en modo edición mueve sus
  --- marcos: hay que recalcular a qué fila corresponde cada celda nuestra.
  pcall(ev.RegisterEvent, ev, "EDIT_MODE_LAYOUTS_UPDATED")
  --- Los eventos de hechizo y el pulso de rango los enciende SetUnitEventsActive junto
  --- con la grilla; apagada, este marco solo escucha lo imprescindible.

  --- Entrar o salir del modo edición muestra, mueve u oculta la grilla de Blizzard, y
  --- ahí cambia a qué fila corresponde cada celda. El retraso deja que Blizzard termine
  --- de armar sus marcos antes de leerles la posición. Si el cliente no publica estos
  --- callbacks, el registro simplemente nunca se dispara.
  if EventRegistry and EventRegistry.RegisterCallback then
    local function relayout()
      if not PG:IsEnabled() then
        return
      end
      C_Timer.After(0.1, function()
        if PG:IsEnabled() then
          PG:Layout()
          PG:UpdateAll()
        end
      end)
    end
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Enter", relayout, PG)
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", relayout, PG)
  end

  local function handle(event, unit)
    if event == "ADDON_LOADED" then
      if unit == "Masque" and PG:IsEnabled() then
        PG:ApplyMasque()
      end
      return
    end
    if event == "PLAYER_REGEN_DISABLED" then
      if PG._configFrame then
        PG:SyncConfig()
      end
      return
    end
    if event == "PLAYER_REGEN_ENABLED" then
      --- La ventana se cerró en combate con la grilla suelta: recién ahora se puede
      --- fijar sin escribir el perfil durante la pelea.
      if PG._wantLock then
        PG._wantLock = nil
        if PG._configFrame and not PG._configFrame:IsShown() then
          PG:SetUnlocked(false)
        end
      end
      PG:Refresh()
      if PG._configFrame then
        PG:SyncConfig()
      end
      return
    end
    if not PG:IsEnabled() then
      return
    end
    if event == "PLAYER_ENTERING_WORLD" then
      PG:Refresh()
      --- Blizzard crea sus marcos de miembro con retraso: un segundo pase toma el orden
      --- definitivo si al entrar todavía no estaban.
      C_Timer.After(1, function()
        if PG:IsEnabled() then
          PG:Layout()
          PG:UpdateAll()
        end
      end)
      return
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "EDIT_MODE_LAYOUTS_UPDATED"
      or event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
      PG:Layout()
      PG:UpdateAll()
      return
    end
    if event == "PLAYER_TARGET_CHANGED" then
      PG:UpdateAll()
      return
    end
    for i = 1, #SPELL_EVENTS do
      if event == SPELL_EVENTS[i] then
        PG:UpdateActions()
        return
      end
    end
    if unit then
      PG:UpdateUnit(unit)
    end
  end

  --- Aislado a propósito: un fallo de este módulo no debe arrastrar al resto del addon.
  --- Los argumentos viajan por upvalue: xpcall recibe una función sin parámetros, que es
  --- la forma que funciona igual en cualquier versión del intérprete.
  local pendingEvent, pendingUnit
  local function run()
    return handle(pendingEvent, pendingUnit)
  end
  ev:SetScript("OnEvent", function(_, event, unit)
    pendingEvent, pendingUnit = event, unit
    local ok, err = xpcall(run, errTraceback)
    if not ok then
      PG:ReportError(err, event)
    end
  end)
end
