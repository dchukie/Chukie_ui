--[[ Guardado de acciones de las barras 1–4 (panel izquierdo).
     Blizzard guarda un juego de barras por loadout de talentos, así que al cambiar de build
     (o de especialización) las ranuras se pisan. Aquí se guarda qué hay en cada slot
     (hechizo / macro / ítem / flyout / montura / mascota / equipo) por personaje y
     especialización, y se vuelve a colocar cuando el juego lo cambia.
     Nunca vacía ranuras: solo repone lo que estaba guardado. Todo fuera de combate. ]]

local _, ns = ...

local ABL = {}
ns.ActionBarLayouts = ABL

local PREFIX = "|cff00ff00Chukie UI|r: "
local WARN_PREFIX = "|cffff9900Chukie UI|r: "

--- Reintentos tras un cambio de talentos: los datos de hechizo llegan con retraso.
local RESTORE_DELAYS = { 0.6, 2.5, 5 }
local SAVE_DEBOUNCE = 1.5
--- Ventana en la que no se guarda nada tras un cambio de talentos (evita guardar la barra pisada).
local SUPPRESS_SAVE_SECONDS = 10
local INITIAL_SAVE_DELAY = 6

local function isSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

local function opts()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  if not p then
    return {}
  end
  p.actionBars = p.actionBars or {}
  return p.actionBars
end

function ABL:IsSaveEnabled()
  return opts().saveLeftLayout ~= false
end

function ABL:IsRestoreEnabled()
  return opts().restoreLeftLayoutOnTalents ~= false
end

local function leftSlots()
  if ns.ActionBars and ns.ActionBars.GetLeftActionSlots then
    local slots = ns.ActionBars:GetLeftActionSlots()
    if type(slots) == "table" and #slots > 0 then
      return slots
    end
  end
  local fallback = {}
  for i = 1, 48 do
    fallback[i] = i
  end
  return fallback
end

local function leftSlotSet()
  local set = {}
  local slots = leftSlots()
  for i = 1, #slots do
    set[slots[i]] = true
  end
  return set
end

local function charKey()
  local name = UnitName and UnitName("player")
  if type(name) ~= "string" or name == "" or isSecret(name) then
    return nil
  end
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName())
    or (GetRealmName and GetRealmName())
    or ""
  return name .. "-" .. realm
end

local function currentSpecId()
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
      local okInfo, id = pcall(getInfo, idx)
      if okInfo and tonumber(id) then
        return math.floor(tonumber(id))
      end
    end
  end
  return 0
end

--- Las acciones son datos del personaje, no ajustes: viven fuera de los perfiles de UI
--- (`ChukieUiDB.actionLayouts[personaje-reino][specID]`) para no perderse al cambiar de perfil.
local function savedStore(create)
  if type(ChukieUiDB) ~= "table" then
    return nil
  end
  local ck = charKey()
  if not ck then
    return nil
  end
  local root = ChukieUiDB.actionLayouts
  if not root then
    if not create then
      return nil
    end
    root = {}
    ChukieUiDB.actionLayouts = root
  end
  local perChar = root[ck]
  if not perChar then
    if not create then
      return nil
    end
    perChar = {}
    root[ck] = perChar
  end
  local specKey = tostring(currentSpecId())
  local entry = perChar[specKey]
  if not entry then
    if not create then
      return nil
    end
    entry = { slots = {} }
    perChar[specKey] = entry
  end
  entry.slots = entry.slots or {}
  return entry
end

local function actionInfo(slot)
  local get = GetActionInfo or (C_ActionBar and C_ActionBar.GetActionInfo)
  if not get then
    return nil
  end
  local ok, a, b, c = pcall(get, slot)
  if not ok then
    return nil
  end
  if type(a) == "table" then
    a, b, c = a.actionType or a.type, a.id, a.subType
  end
  if isSecret(a) or isSecret(b) or isSecret(c) then
    return nil
  end
  return a, b, c
end

local function slotHasAction(slot)
  local has = HasAction and HasAction(slot)
  if isSecret(has) then
    return false
  end
  return has and true or false
end

local function macroName(index)
  if not GetMacroInfo or not index or index <= 0 then
    return ""
  end
  local ok, name = pcall(GetMacroInfo, index)
  if ok and type(name) == "string" then
    return name
  end
  return ""
end

--- Formato compacto: "spell:123", "macro:4:Nombre", "item:6948", "flyout:11",
--- "mount:0", "pet:BattlePet-…", "eqset:Nombre". El nombre siempre va al final.
local function encodeAction(slot)
  local kind, id = actionInfo(slot)
  if type(kind) ~= "string" or kind == "" then
    return nil
  end
  if kind == "spell" then
    local n = tonumber(id)
    if not n or n <= 0 then
      return nil
    end
    return "spell:" .. n
  end
  if kind == "item" then
    local n = tonumber(id)
    if not n or n <= 0 then
      return nil
    end
    return "item:" .. n
  end
  if kind == "flyout" then
    local n = tonumber(id)
    if not n or n <= 0 then
      return nil
    end
    return "flyout:" .. n
  end
  if kind == "macro" then
    local n = math.floor(tonumber(id) or 0)
    return "macro:" .. n .. ":" .. macroName(n)
  end
  if kind == "summonmount" then
    local n = tonumber(id)
    if not n then
      return nil
    end
    return "mount:" .. math.floor(n)
  end
  if kind == "summonpet" then
    if type(id) ~= "string" or id == "" then
      return nil
    end
    return "pet:" .. id
  end
  if kind == "equipmentset" then
    if type(id) ~= "string" or id == "" then
      return nil
    end
    return "eqset:" .. id
  end
  return nil
end

local function decodeAction(enc)
  if type(enc) ~= "string" then
    return nil
  end
  local kind, rest = enc:match("^(%w+):(.*)$")
  if not kind then
    return nil
  end
  if kind == "macro" then
    local index, name = rest:match("^(%d*):?(.*)$")
    return { kind = kind, index = tonumber(index) or 0, name = name or "" }
  end
  if kind == "pet" or kind == "eqset" then
    if rest == "" then
      return nil
    end
    return { kind = kind, name = rest }
  end
  local n = tonumber(rest)
  if not n then
    return nil
  end
  return { kind = kind, id = n }
end

local function sameAction(encA, encB)
  local a, b = decodeAction(encA), decodeAction(encB)
  if not a or not b or a.kind ~= b.kind then
    return false
  end
  if a.kind == "macro" then
    if a.name ~= "" and b.name ~= "" then
      return a.name == b.name
    end
    return a.index == b.index
  end
  if a.kind == "pet" or a.kind == "eqset" then
    return a.name == b.name
  end
  return a.id == b.id
end

local function clearCursor()
  if ClearCursor then
    pcall(ClearCursor)
  end
end

local function cursorHoldsSomething()
  if not GetCursorInfo then
    return false
  end
  local ok, kind = pcall(GetCursorInfo)
  if not ok then
    return false
  end
  return kind ~= nil and kind ~= false
end

local function pickupSpell(spellId)
  local pick = (C_Spell and C_Spell.PickupSpell) or PickupSpell
  if not pick or not spellId then
    return false
  end
  return pcall(pick, spellId)
end

local function pickupItem(itemId)
  local pick = (C_Item and C_Item.PickupItem) or PickupItem
  if not pick then
    return false
  end
  return pcall(pick, itemId)
end

local function pickupMacro(entry)
  if not PickupMacro then
    return false
  end
  local index = entry.index or 0
  if entry.name ~= "" and GetMacroIndexByName then
    local ok, byName = pcall(GetMacroIndexByName, entry.name)
    if ok and tonumber(byName) and byName > 0 then
      index = byName
    end
  end
  if index <= 0 then
    return false
  end
  return pcall(PickupMacro, index)
end

--- Los flyout (portales, venenos, invocaciones) no tienen «pickup» propio: hay que
--- localizarlos en el libro de hechizos.
local function pickupFlyout(flyoutId)
  if not (C_SpellBook and C_SpellBook.GetSpellBookItemInfo and C_SpellBook.PickupSpellBookItem) then
    return false
  end
  local bank = (Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
  local flyoutType = Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
  local numLines = C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines() or 0
  for line = 1, numLines do
    local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookSkillLineInfo(line)
    if type(lineInfo) == "table" then
      local first = (lineInfo.itemIndexOffset or 0) + 1
      local last = (lineInfo.itemIndexOffset or 0) + (lineInfo.numSpellBookItems or 0)
      for index = first, last do
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, bank)
        if ok and type(info) == "table" and info.itemType == flyoutType and tonumber(info.actionID) == flyoutId then
          if pcall(C_SpellBook.PickupSpellBookItem, index, bank) then
            return true
          end
        end
      end
    end
  end
  return false
end

--- Monturas: se coloca el hechizo de la montura (equivale a arrastrarla del compendio).
local function pickupMount(mountId)
  if mountId == 0 then
    if C_MountJournal and C_MountJournal.Pickup then
      return pcall(C_MountJournal.Pickup, 0)
    end
    return false
  end
  if C_MountJournal and C_MountJournal.GetMountInfoByID then
    local ok, _, spellId = pcall(C_MountJournal.GetMountInfoByID, mountId)
    if ok and tonumber(spellId) then
      return pickupSpell(spellId)
    end
  end
  return false
end

local function pickupPet(guid)
  if C_PetJournal and C_PetJournal.PickupPet then
    return pcall(C_PetJournal.PickupPet, guid, false)
  end
  return false
end

local function pickupEquipmentSet(name)
  if not (C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet and C_EquipmentSet.GetEquipmentSetIDs) then
    return false
  end
  local okIds, ids = pcall(C_EquipmentSet.GetEquipmentSetIDs)
  if not okIds or type(ids) ~= "table" then
    return false
  end
  for i = 1, #ids do
    local okInfo, setName = pcall(C_EquipmentSet.GetEquipmentSetInfo, ids[i])
    if okInfo and setName == name then
      return pcall(C_EquipmentSet.PickupEquipmentSet, ids[i])
    end
  end
  return false
end

local function pickupSaved(entry)
  if entry.kind == "spell" then
    return pickupSpell(entry.id)
  end
  if entry.kind == "item" then
    return pickupItem(entry.id)
  end
  if entry.kind == "macro" then
    return pickupMacro(entry)
  end
  if entry.kind == "flyout" then
    return pickupFlyout(entry.id)
  end
  if entry.kind == "mount" then
    return pickupMount(entry.id)
  end
  if entry.kind == "pet" then
    return pickupPet(entry.name)
  end
  if entry.kind == "eqset" then
    return pickupEquipmentSet(entry.name)
  end
  return false
end

--- PlaceAction devuelve al cursor lo que hubiera en la ranura; se descarta con ClearCursor.
local function placeSaved(slot, enc)
  local entry = decodeAction(enc)
  if not entry or not PlaceAction then
    return false
  end
  clearCursor()
  pickupSaved(entry)
  if not cursorHoldsSomething() then
    clearCursor()
    return false
  end
  local placed = pcall(PlaceAction, slot)
  clearCursor()
  if not placed then
    return false
  end
  return sameAction(encodeAction(slot), enc)
end

function ABL:SuppressSaves(seconds)
  local until_ = GetTime() + (seconds or SUPPRESS_SAVE_SECONDS)
  if until_ > (self._suppressUntil or 0) then
    self._suppressUntil = until_
  end
  if self._saveTimer then
    self._saveTimer:Cancel()
    self._saveTimer = nil
  end
end

local function savedCount(store)
  local n = 0
  if store and type(store.slots) == "table" then
    for _ in pairs(store.slots) do
      n = n + 1
    end
  end
  return n
end

--- `force` permite guardar barras vacías a mano (el guardado automático nunca lo hace).
function ABL:Save(force)
  local store = savedStore(true)
  if not store then
    return false, "no se pudo identificar al personaje"
  end
  local slots = leftSlots()
  local data, count, skipped = {}, 0, 0
  for i = 1, #slots do
    local slot = slots[i]
    local enc = encodeAction(slot)
    if enc then
      data[slot] = enc
      count = count + 1
    elseif slotHasAction(slot) then
      skipped = skipped + 1
    end
  end
  if count == 0 and not force and savedCount(store) > 0 then
    return false, "las barras aún no están cargadas; se conserva lo guardado"
  end
  store.slots = data
  store.savedAt = time()
  return true, nil, count, skipped
end

function ABL:Restore(attempt)
  attempt = attempt or 1
  if InCombatLockdown() then
    self._pendingRestore = attempt
    return false, "en combate: se restaurará al salir"
  end
  local store = savedStore(false)
  local total = savedCount(store)
  if total == 0 then
    return false, "no hay acciones guardadas para esta especialización"
  end
  if cursorHoldsSomething() then
    --- Con algo en el cursor, colocar acciones lo perdería: esperar a que lo suelte.
    local waits = (self._cursorWaits or 0) + 1
    self._cursorWaits = waits
    if waits <= 10 then
      self:ScheduleRestore(1, attempt)
    end
    return false, "hay algo en el cursor; se reintenta al soltarlo"
  end
  self._cursorWaits = 0

  self._restoring = true
  self:SuppressSaves()
  local placed, failed = 0, 0
  for slot, enc in pairs(store.slots) do
    if not sameAction(encodeAction(slot), enc) then
      if placeSaved(slot, enc) then
        placed = placed + 1
      else
        failed = failed + 1
      end
    end
  end
  clearCursor()
  self._restoring = false

  if ns.ActionBars and ns.ActionBars.UpdateAllVisuals then
    ns.ActionBars:UpdateAllVisuals()
  end
  if failed > 0 and attempt < #RESTORE_DELAYS then
    self:ScheduleRestore(RESTORE_DELAYS[attempt + 1], attempt + 1)
  end
  return true, nil, placed, failed
end

function ABL:ScheduleRestore(delay, attempt)
  if self._restoreTimer then
    self._restoreTimer:Cancel()
  end
  self._restoreTimer = C_Timer.NewTimer(delay or RESTORE_DELAYS[1], function()
    ABL._restoreTimer = nil
    ABL:Restore(attempt)
  end)
end

function ABL:ScheduleSave()
  if self._saveTimer then
    self._saveTimer:Cancel()
  end
  self._saveTimer = C_Timer.NewTimer(SAVE_DEBOUNCE, function()
    ABL._saveTimer = nil
    if not ABL:IsSaveEnabled() then
      return
    end
    if InCombatLockdown() then
      ABL._pendingSave = true
      return
    end
    ABL:Save(false)
  end)
end

function ABL:OnSlotChanged(slot)
  if not self:IsSaveEnabled() or self._restoring then
    return
  end
  if GetTime() < (self._suppressUntil or 0) then
    return
  end
  slot = tonumber(slot)
  --- 0 / nil = «cambiaron todas»: es lo que manda el juego al pisar barras, no se guarda.
  if not slot or slot <= 0 or not leftSlotSet()[slot] then
    return
  end
  self:ScheduleSave()
end

function ABL:OnTalentsChanged()
  --- Al entrar al mundo llegan varios eventos de talentos con datos a medio cargar.
  if not self._ready or not self:IsRestoreEnabled() then
    return
  end
  if savedCount(savedStore(false)) == 0 then
    --- Nada guardado todavía para esta especialización: no hay qué reponer.
    if self:IsSaveEnabled() then
      self:ScheduleSave()
    end
    return
  end
  self:SuppressSaves()
  self:ScheduleRestore(RESTORE_DELAYS[1], 1)
end

function ABL:OnEnteringWorld()
  local firstEntry = savedCount(savedStore(false)) == 0
  C_Timer.After(INITIAL_SAVE_DELAY, function()
    ABL._ready = true
    if firstEntry and ABL:IsSaveEnabled() and not InCombatLockdown() then
      ABL:Save(false)
    end
  end)
end

function ABL:SaveNow()
  local ok, err, count, skipped = self:Save(true)
  if not ok then
    print(WARN_PREFIX .. "no se guardaron las acciones (" .. (err or "error") .. ").")
    return false
  end
  local msg = PREFIX .. "acciones de las barras 1–4 guardadas (" .. count .. " ranuras)."
  if skipped and skipped > 0 then
    msg = msg .. " " .. skipped .. " ranura(s) de un tipo no soportado se omitieron."
  end
  print(msg)
  return true
end

function ABL:RestoreNow()
  local ok, err, placed, failed = self:Restore(1)
  if not ok then
    print(WARN_PREFIX .. "no se restauraron las acciones (" .. (err or "error") .. ").")
    return false
  end
  local msg = PREFIX .. "acciones restauradas: " .. placed .. " ranura(s) repuesta(s)."
  if failed and failed > 0 then
    msg = msg .. " " .. failed .. " sin reponer (se reintenta en unos segundos)."
  end
  print(msg)
  return true
end

function ABL:ClearSaved()
  local store = savedStore(false)
  if not store then
    print(WARN_PREFIX .. "no había acciones guardadas para esta especialización.")
    return false
  end
  store.slots = {}
  store.savedAt = nil
  print(PREFIX .. "guardado de acciones borrado para esta especialización.")
  return true
end

function ABL:GetStatusText()
  local store = savedStore(false)
  local count = savedCount(store)
  if count == 0 then
    return "Sin acciones guardadas para esta especialización."
  end
  local when = store.savedAt and date("%d/%m %H:%M", store.savedAt) or "?"
  return count .. " ranura(s) guardada(s) el " .. when .. "."
end

local TALENT_EVENTS = {
  "TRAIT_CONFIG_UPDATED",
  "ACTIVE_COMBAT_CONFIG_CHANGED",
  "PLAYER_TALENT_UPDATE",
  "ACTIVE_TALENT_GROUP_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
}

local ev = CreateFrame("Frame")
ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
for i = 1, #TALENT_EVENTS do
  pcall(ev.RegisterEvent, ev, TALENT_EVENTS[i])
end
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ACTIONBAR_SLOT_CHANGED" then
    ABL:OnSlotChanged(arg1)
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    ABL:OnEnteringWorld()
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    if ABL._pendingRestore then
      local attempt = ABL._pendingRestore
      ABL._pendingRestore = nil
      ABL:ScheduleRestore(RESTORE_DELAYS[1], attempt)
    elseif ABL._pendingSave then
      ABL._pendingSave = nil
      ABL:ScheduleSave()
    end
    return
  end
  if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 and arg1 ~= "player" then
    return
  end
  ABL:OnTalentsChanged()
end)
