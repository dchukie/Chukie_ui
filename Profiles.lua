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
    cvars = {},
  }
  for k, v in pairs(src.minimapPosition or {}) do
    t.minimapPosition[k] = v
  end
  for k, v in pairs(src.minimapBar or {}) do
    if (k == "buttonPolicy" or k == "minimenuVisibility") and type(v) == "table" then
      local np = {}
      for pk, pv in pairs(v) do
        np[pk] = pv
      end
      t.minimapBar[k] = np
    elseif k == "discoveredOrder" and type(v) == "table" then
      local no = {}
      for i = 1, #v do
        no[i] = v[i]
      end
      t.minimapBar[k] = no
    else
      t.minimapBar[k] = v
    end
  end
  for k, v in pairs(src.cvars or {}) do
    t.cvars[k] = v
  end
  return t
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
  p.minimapBar = p.minimapBar or {}
  p.cvars = p.cvars or {}
  return p
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

function ns.Profile:Initialize()
  self:Migrate()
  if ns.CopyDefaultsIntoProfile then
    ns.CopyDefaultsIntoProfile(self:GetActive())
  end
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
  if ns.CopyDefaultsIntoProfile then
    ns.CopyDefaultsIntoProfile(ChukieUiDB.profiles[name])
  end
  self:NotifyChanged()
  return true
end
