--[[ Respaldo textual recuperable: perfil completo, ranuras 1–180, macros y teclas.
     WoW no deja crear archivos arbitrarios: el usuario copia el texto a un .txt. ]]

local _, ns = ...

local B = {}
ns.Backup = B

local MAGIC = "CHUKIEUI-BACKUP-1"
local PREFIX = "|cff00ff00Chukie UI|r: "
local WARN = "|cffff9900Chukie UI|r: "

local MAX_ACCOUNT_MACROS = _G.MAX_ACCOUNT_MACROS or 120
local MAX_CHARACTER_MACROS = _G.MAX_CHARACTER_MACROS or 18

local function addonVersion()
  local toc = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Chukie_Ui", "Version")
  return toc or "0.5.5"
end

local function checksum(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 2147483647
  end
  return string.format("%08x", h)
end

local function encode(value)
  local t = type(value)
  if t == "boolean" then
    return value and "t" or "f"
  end
  if t == "number" then
    return "d" .. tostring(value)
  end
  if t == "string" then
    return "s" .. #value .. ":" .. value
  end
  if t ~= "table" then
    return "n"
  end
  local keys = {}
  for k in pairs(value) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
      return ta < tb
    end
    if ta == "number" then
      return a < b
    end
    return tostring(a) < tostring(b)
  end)
  local parts = {}
  for i = 1, #keys do
    local k = keys[i]
    parts[#parts + 1] = encode(k) .. "=" .. encode(value[k])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function decode(str, i)
  i = i or 1
  local c = str:sub(i, i)
  if c == "n" then
    return nil, i + 1
  end
  if c == "t" then
    return true, i + 1
  end
  if c == "f" then
    return false, i + 1
  end
  if c == "d" then
    local num, rest = str:match("^([%+%-]?%d+%.?%d*[eE]?[%+%-]?%d*)()", i + 1)
    return tonumber(num), rest
  end
  if c == "s" then
    local len, rest = str:match("^(%d+):()", i + 1)
    len = tonumber(len)
    if not len then
      return nil, i
    end
    local s = str:sub(rest, rest + len - 1)
    return s, rest + len
  end
  if c == "{" then
    local t = {}
    i = i + 1
    if str:sub(i, i) == "}" then
      return t, i + 1
    end
    while i <= #str do
      local k
      k, i = decode(str, i)
      if str:sub(i, i) ~= "=" then
        return t, i
      end
      local v
      v, i = decode(str, i + 1)
      t[k] = v
      local sep = str:sub(i, i)
      if sep == "}" then
        return t, i + 1
      end
      if sep ~= "," then
        return t, i
      end
      i = i + 1
    end
    return t, i
  end
  return nil, i
end

local function bindingCommands()
  local list = {}
  for i = 1, 12 do
    list[#list + 1] = "ACTIONBUTTON" .. i
  end
  for bar = 1, 7 do
    for i = 1, 12 do
      list[#list + 1] = "MULTIACTIONBAR" .. bar .. "BUTTON" .. i
    end
  end
  for barId = 1, 4 do
    for btn = 1, 6 do
      list[#list + 1] = string.format("CLICK ChukieUi_AB%d_B%d:LeftButton", barId, btn)
    end
  end
  for i = 1, 3 do
    list[#list + 1] = "CLICK ChukieUi_MiniAct" .. i .. ":LeftButton"
  end
  for i = 2, 4 do
    list[#list + 1] = "CLICK ChukieDynAct" .. i .. ":LeftButton"
  end
  return list
end

function B:CaptureBindings()
  local out = {}
  if not GetBindingKey then
    return out
  end
  local cmds = bindingCommands()
  for i = 1, #cmds do
    local cmd = cmds[i]
    local ok, k1, k2 = pcall(GetBindingKey, cmd)
    if ok then
      local keys = {}
      if type(k1) == "string" and k1 ~= "" then
        keys[#keys + 1] = k1
      end
      if type(k2) == "string" and k2 ~= "" then
        keys[#keys + 1] = k2
      end
      if #keys > 0 then
        out[cmd] = keys
      end
    end
  end
  return out
end

function B:ApplyBindings(map)
  if type(map) ~= "table" or InCombatLockdown() then
    return false, 0
  end
  local applied = 0
  for cmd, keys in pairs(map) do
    if type(cmd) == "string" and type(keys) == "table" then
      if GetBindingKey then
        local ok, a, b = pcall(GetBindingKey, cmd)
        if ok then
          if type(a) == "string" then
            pcall(SetBinding, a)
          end
          if type(b) == "string" then
            pcall(SetBinding, b)
          end
        end
      end
      for i = 1, #keys do
        local key = keys[i]
        if type(key) == "string" and key ~= "" and SetBinding then
          if pcall(SetBinding, key, cmd) then
            applied = applied + 1
          end
        end
      end
    end
  end
  if SaveBindings then
    local which = (GetCurrentBindingSet and GetCurrentBindingSet()) or 2
    pcall(SaveBindings, which)
  end
  return true, applied
end

local function macroInfo(index)
  if not GetMacroInfo then
    return nil
  end
  local ok, name, icon, body = pcall(GetMacroInfo, index)
  if not ok or type(name) ~= "string" or name == "" then
    return nil
  end
  return {
    name = name,
    icon = type(icon) == "string" and icon or "",
    body = type(body) == "string" and body or "",
  }
end

function B:CaptureMacros()
  local out = {}
  local globalCount, charCount = 0, 0
  if GetNumMacros then
    local ok, g, c = pcall(GetNumMacros)
    if ok then
      globalCount = tonumber(g) or 0
      charCount = tonumber(c) or 0
    end
  end
  for i = 1, globalCount do
    local m = macroInfo(i)
    if m then
      m.scope = "global"
      out[#out + 1] = m
    end
  end
  for i = 1, charCount do
    local m = macroInfo(MAX_ACCOUNT_MACROS + i)
    if m then
      m.scope = "char"
      out[#out + 1] = m
    end
  end
  return out
end

local function findMacroIndex(name, perChar)
  if not GetMacroIndexByName then
    return 0
  end
  local ok, index = pcall(GetMacroIndexByName, name)
  if not ok or not tonumber(index) or index <= 0 then
    return 0
  end
  index = math.floor(index)
  if perChar then
    if index > MAX_ACCOUNT_MACROS then
      return index
    end
    return 0
  end
  if index <= MAX_ACCOUNT_MACROS then
    return index
  end
  return 0
end

function B:ApplyMacros(list)
  if type(list) ~= "table" or InCombatLockdown() then
    return false, 0, 0
  end
  local created, updated, failed = 0, 0, 0
  for i = 1, #list do
    local m = list[i]
    if type(m) == "table" and type(m.name) == "string" and m.name ~= "" then
      local perChar = m.scope == "char"
      local icon = m.icon
      if type(icon) ~= "string" or icon == "" then
        icon = "INV_MISC_QUESTIONMARK"
      end
      local body = type(m.body) == "string" and m.body or ""
      local index = findMacroIndex(m.name, perChar)
      if index > 0 and EditMacro then
        if pcall(EditMacro, index, m.name, icon, body) then
          updated = updated + 1
        else
          failed = failed + 1
        end
      elseif CreateMacro then
        local ok = pcall(CreateMacro, m.name, icon, body, perChar)
        if ok then
          created = created + 1
        else
          failed = failed + 1
        end
      else
        failed = failed + 1
      end
    end
  end
  return true, created, updated, failed
end

function B:BuildPayload()
  local profileName = ns.Profile and ns.Profile.GetCurrentName and ns.Profile:GetCurrentName() or "Default"
  local profile = ns.Profile and ns.Profile.CloneData and ns.Profile.CloneData(ns.Profile:GetActive()) or {}
  local slots, filled = {}, 0
  if ns.ActionBarLayouts and ns.ActionBarLayouts.CaptureAllSlots then
    slots, filled = ns.ActionBarLayouts:CaptureAllSlots()
  end
  return {
    version = 1,
    addon = addonVersion(),
    char = ns.Profile and ns.Profile.CharKey and ns.Profile.CharKey() or "",
    spec = ns.Profile and ns.Profile.SpecId and ns.Profile.SpecId() or 0,
    specName = ns.Profile and ns.Profile.SpecName and ns.Profile.SpecName() or "",
    label = ns.Profile and ns.Profile.ContextLabel and ns.Profile.ContextLabel() or "",
    profileName = profileName,
    profile = profile,
    slots = slots,
    macros = self:CaptureMacros(),
    bindings = self:CaptureBindings(),
    filledSlots = filled,
  }
end

function B:Encode(payload)
  payload = payload or self:BuildPayload()
  local body = encode(payload)
  local lines = {
    MAGIC,
    "addon=" .. tostring(payload.addon or addonVersion()),
    "char=" .. tostring(payload.char or ""),
    "spec=" .. tostring(payload.spec or 0),
    "specName=" .. tostring(payload.specName or ""),
    "profile=" .. tostring(payload.profileName or ""),
    "created=" .. tostring(time()),
    "checksum=" .. checksum(body),
    "---",
    body,
  }
  return table.concat(lines, "\n"), payload
end

function B:Decode(text)
  if type(text) ~= "string" then
    return nil, "texto vacío"
  end
  text = text:gsub("^\239\187\191", ""):gsub("\r\n", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
  if text:sub(1, #MAGIC) ~= MAGIC then
    return nil, "cabecera inválida (¿no es un respaldo de Chukie UI?)"
  end
  local sep = text:find("\n---\n", 1, true)
  if not sep then
    return nil, "falta el cuerpo del respaldo"
  end
  local header = text:sub(1, sep - 1)
  local body = text:sub(sep + 5)
  local meta = {}
  for line in header:gmatch("[^\n]+") do
    local k, v = line:match("^(%w+)=(.*)$")
    if k then
      meta[k] = v
    end
  end
  if meta.checksum and meta.checksum ~= checksum(body) then
    return nil, "checksum no coincide: el texto está cortado o se modificó"
  end
  local payload = decode(body, 1)
  if type(payload) ~= "table" then
    return nil, "no se pudo leer el cuerpo"
  end
  payload._meta = meta
  return payload
end

function B:Preview(payload)
  if type(payload) ~= "table" then
    return "Respaldo inválido."
  end
  local macros = type(payload.macros) == "table" and #payload.macros or 0
  local binds = 0
  if type(payload.bindings) == "table" then
    for _ in pairs(payload.bindings) do
      binds = binds + 1
    end
  end
  local slots = 0
  if type(payload.slots) == "table" then
    for _, enc in pairs(payload.slots) do
      if type(enc) == "string" and enc ~= "" then
        slots = slots + 1
      end
    end
  end
  return table.concat({
    "Origen: " .. tostring(payload.label or payload.char or "?"),
    "Spec: " .. tostring(payload.specName or payload.spec or "?"),
    "Perfil: " .. tostring(payload.profileName or "?"),
    "Addon: " .. tostring(payload.addon or "?"),
    "Ranuras con acción: " .. slots,
    "Macros: " .. macros,
    "Comandos de tecla: " .. binds,
    "Al aplicar se reemplaza el perfil activo, las macros del paquete, las ranuras 1–180 y las teclas de barras/botones Chukie.",
  }, "\n")
end

local function snapshotForUndo()
  return B:BuildPayload()
end

function B:Apply(payload)
  if InCombatLockdown and InCombatLockdown() then
    return false, "en combate no se puede importar"
  end
  if type(payload) ~= "table" or type(payload.profile) ~= "table" then
    return false, "respaldo incompleto"
  end
  ChukieUiDB.backupUndo = snapshotForUndo()
  local name = ns.Profile:GetCurrentName()
  ChukieUiDB.profiles[name] = ns.Profile.CloneData(payload.profile)
  if ns.CopyDefaultsIntoProfile then
    ns.CopyDefaultsIntoProfile(ChukieUiDB.profiles[name])
  end
  ns.Profile:BindCurrentContext(name)
  local created, updated, macroFailed = 0, 0, 0
  if payload.macros then
    local okm
    okm, created, updated, macroFailed = self:ApplyMacros(payload.macros)
    if not okm then
      created, updated, macroFailed = 0, 0, 0
    end
  end
  local placed, failed, cleared = 0, 0, 0
  if ns.ActionBarLayouts and payload.slots then
    local ok, err
    ok, err, placed, failed, cleared = ns.ActionBarLayouts:ApplySlots(payload.slots, true)
    if not ok then
      return false, err or "no se pudieron colocar las acciones"
    end
  end
  local bindCount = 0
  if payload.bindings then
    local okb
    okb, bindCount = self:ApplyBindings(payload.bindings)
  end
  if ns.Profile.NotifyChanged then
    ns.Profile:NotifyChanged()
  end
  return true, nil, {
    placed = placed,
    failed = failed,
    cleared = cleared,
    macrosCreated = created,
    macrosUpdated = updated,
    macrosFailed = macroFailed,
    bindings = bindCount,
  }
end

function B:Undo()
  local snap = ChukieUiDB and ChukieUiDB.backupUndo
  if type(snap) ~= "table" then
    return false, "no hay un deshacer guardado"
  end
  ChukieUiDB.backupUndo = nil
  return self:Apply(snap)
end

--- CopyToClipboard es una función protegida: solo responde dentro del clic de un botón.
local function clipboardCopy(text)
  if type(text) ~= "string" or text == "" or type(CopyToClipboard) ~= "function" then
    return false
  end
  return pcall(CopyToClipboard, text)
end

--- Ctrl+V está asignado a las placas de nombre. Si la tecla sale del cuadro de texto el
--- atajo gana y no se pega nada, así que mientras el cuadro tiene el foco ningún atajo
--- debe recibir teclas.
local function holdKeyboard(edit, hold)
  if not edit.SetPropagateKeyboardInput then
    return
  end
  pcall(edit.SetPropagateKeyboardInput, edit, not hold)
end

function B:Show(text)
  if InCombatLockdown and InCombatLockdown() then
    print(WARN .. "el respaldo no se abre en combate.")
    return
  end
  local f = self._frame
  if not f then
    f = CreateFrame("Frame", "ChukieUi_BackupFrame", UIParent, "BackdropTemplate")
    f:SetSize(640, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
      f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
      })
    end
    tinsert(UISpecialFrames, f:GetName())
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Chukie UI — respaldo")
    f.title = title
    local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 20, -40)
    help:SetPoint("TOPRIGHT", -20, -40)
    help:SetJustifyH("LEFT")
    help:SetText("Exportar y Copiar dejan el respaldo en el portapapeles. Pegar prepara el cuadro para Ctrl+V.")
    f.help = help
    local scroll = CreateFrame("ScrollFrame", "ChukieUi_BackupScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -70)
    scroll:SetPoint("BOTTOMRIGHT", -40, 118)
    local edit = CreateFrame("EditBox", "ChukieUi_BackupEdit", scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(560)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusGained", function(self)
      holdKeyboard(self, true)
    end)
    edit:SetScript("OnEditFocusLost", function(self)
      holdKeyboard(self, false)
    end)
    edit:SetScript("OnKeyDown", function(self)
      holdKeyboard(self, self:HasFocus())
    end)
    scroll:SetScrollChild(edit)
    f.edit = edit
    local function addBtn(label, x, y, click)
      local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      b:SetSize(110, 24)
      b:SetPoint("BOTTOMLEFT", x, y)
      b:SetText(label)
      b:SetScript("OnClick", click)
      return b
    end
    addBtn("Exportar", 20, 48, function()
      local encoded = B:Encode()
      f.edit:SetText(encoded)
      f.edit:HighlightText()
      f.edit:SetFocus()
      print(PREFIX .. "respaldo generado. Pulsá Copiar para llevarlo al portapapeles.")
    end)
    addBtn("Copiar", 140, 48, function()
      local encoded = f.edit:GetText()
      if encoded == "" then
        encoded = B:Encode()
        f.edit:SetText(encoded)
      end
      if clipboardCopy(encoded) then
        print(PREFIX .. "respaldo copiado al portapapeles. Pegalo en un archivo .txt.")
        return
      end
      f.edit:SetFocus()
      f.edit:HighlightText()
      print(WARN .. "no se pudo usar el portapapeles: el texto quedó seleccionado, pulsá Ctrl+C.")
    end)
    addBtn("Pegar", 260, 48, function()
      f._pending = nil
      f.edit:SetText("")
      f.edit:SetFocus()
      holdKeyboard(f.edit, true)
      print(PREFIX .. "cuadro listo y con el foco: pulsá Ctrl+V y después Importar.")
    end)
    addBtn("Importar", 20, 20, function()
      local payload, err = B:Decode(f.edit:GetText())
      if not payload then
        print(WARN .. (err or "no se pudo leer"))
        return
      end
      f.help:SetText(B:Preview(payload) .. "\nPulsa Aplicar para confirmar.")
      f._pending = payload
    end)
    addBtn("Aplicar", 140, 20, function()
      local payload = f._pending
      if not payload then
        payload = select(1, B:Decode(f.edit:GetText()))
      end
      if not payload then
        print(WARN .. "primero Importar para validar el texto.")
        return
      end
      local ok, err, stats = B:Apply(payload)
      if not ok then
        print(WARN .. (err or "falló la importación"))
        return
      end
      f._pending = nil
      print(
        PREFIX
          .. string.format(
            "importado: %d ranuras, %d vaciadas, %d macros nuevas, %d actualizadas, %d teclas. /chukieui backup deshacer",
            stats.placed or 0,
            stats.cleared or 0,
            stats.macrosCreated or 0,
            stats.macrosUpdated or 0,
            stats.bindings or 0
          )
      )
    end)
    addBtn("Deshacer", 260, 20, function()
      local ok, err = B:Undo()
      if not ok then
        print(WARN .. (err or "no hay deshacer"))
        return
      end
      print(PREFIX .. "se restauró el estado anterior al último importar.")
    end)
    addBtn("Cerrar", 380, 20, function()
      f.edit:ClearFocus()
      f:Hide()
    end)
    f:SetScript("OnHide", function(self)
      self.edit:ClearFocus()
      holdKeyboard(self.edit, false)
    end)
    self._frame = f
  end
  if type(text) == "string" then
    f.edit:SetText(text)
  elseif not f:IsShown() then
    f.edit:SetText("")
  end
  f.help:SetText(
    (ns.Profile and ns.Profile.GetContextStatusText and ns.Profile:GetContextStatusText() or "")
      .. "\nExportar y Copiar dejan el respaldo en el portapapeles. Pegar prepara el cuadro para Ctrl+V."
  )
  f:Show()
end
