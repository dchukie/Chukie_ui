--[[ Sonda de API para WoW Forever.
     Se usa con /chukieui forever. No deja marcos en pantalla. ]]

local _, ns = ...

local function flag(ok)
  if ok then
    return "sí"
  end
  return "no"
end

--- Misma prueba que AlertsAuraContainer: el tipo de marco existe y expone
--- SetUnit más AddAuraGroup o AddAuraSlot. En combate no se crea el marco.
local function auraContainerAvailable()
  if InCombatLockdown and InCombatLockdown() then
    return nil, "no comprobado (en combate)"
  end
  local templates = { "CustomAuraContainerTemplate", "ManagedAuraContainerTemplate", nil }
  for i = 1, #templates do
    local ok, frame
    if templates[i] then
      ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, templates[i])
    else
      ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent)
    end
    if ok and frame then
      local usable = type(frame.SetUnit) == "function"
        and (type(frame.AddAuraGroup) == "function" or type(frame.AddAuraSlot) == "function")
      frame:Hide()
      pcall(frame.SetParent, frame, nil)
      if usable then
        return true
      end
    end
  end
  return false
end

local function frameFlag(name)
  return _G[name] ~= nil
end

local function microButtonNote()
  if type(MICRO_BUTTONS) ~= "table" then
    return "no"
  end
  return "sí (" .. tostring(#MICRO_BUTTONS) .. ")"
end

--- La ranura 145 es la primera de la barra 6. «sí, vacía» quiere decir que la función existe.
local function hasAction145Note()
  local fn = (C_ActionBar and C_ActionBar.HasAction) or HasAction
  if type(fn) ~= "function" then
    return "no"
  end
  local ok, has = pcall(fn, 145)
  if not ok or (issecretvalue and issecretvalue(has)) then
    return "no"
  end
  if has then
    return "sí, con acción"
  end
  return "sí, vacía"
end

function ns.PrintForeverProbe()
  print("|cff00ff00Chukie UI|r — sonda Forever")
  if type(GetBuildInfo) == "function" then
    local version, build, date, interface, locale, buildType = GetBuildInfo()
    print(string.format(
      "  GetBuildInfo: %s | build %s | %s | interface %s | %s | %s",
      tostring(version),
      tostring(build),
      tostring(date),
      tostring(interface),
      tostring(locale),
      tostring(buildType)
    ))
  else
    print("  GetBuildInfo: no")
  end
  print("  WOW_PROJECT_ID: " .. tostring(WOW_PROJECT_ID))

  local auraOk, auraNote = auraContainerAvailable()
  local rows = {
    { "C_UnitAuras", C_UnitAuras ~= nil },
    { "AuraContainer", auraOk, auraNote },
    { "issecretvalue", type(issecretvalue) == "function" },
    { "Settings", type(Settings) == "table" },
    { "EditModeManagerFrame", EditModeManagerFrame ~= nil },
    { "C_ChallengeMode", type(C_ChallengeMode) == "table" },
    { "C_ClassTalents", type(C_ClassTalents) == "table" },
    { "GetSpecialization", type(GetSpecialization) == "function" },
    { "C_GamePad", type(C_GamePad) == "table" },
    { "C_GamePad.SetConfig", type(C_GamePad) == "table" and type(C_GamePad.SetConfig) == "function" },
    { "MinimapCluster", frameFlag("MinimapCluster") },
    { "Minimap", frameFlag("Minimap") },
    { "MicroMenu", frameFlag("MicroMenu") },
    { "MicroMenuContainer", frameFlag("MicroMenuContainer") },
    { "MICRO_BUTTONS", type(MICRO_BUTTONS) == "table", microButtonNote() },
    { "ExpansionLandingPageMinimapButton", frameFlag("ExpansionLandingPageMinimapButton") },
    { "AddonCompartmentFrame", frameFlag("AddonCompartmentFrame") },
    { "GameTimeFrame", frameFlag("GameTimeFrame") },
    { "ChatFrame1EditBox", frameFlag("ChatFrame1EditBox") },
    { "MultiBar5", frameFlag("MultiBar5") },
    { "HasAction(145)", type((C_ActionBar and C_ActionBar.HasAction) or HasAction) == "function", hasAction145Note() },
    { "ExtraActionButton1", frameFlag("ExtraActionButton1") },
    { "PVEFrame", frameFlag("PVEFrame") },
    { "LFDParentFrame", frameFlag("LFDParentFrame") },
    { "LFGParentFrame", frameFlag("LFGParentFrame") },
  }
  for i = 1, #rows do
    local name, ok, note = rows[i][1], rows[i][2], rows[i][3]
    print("  " .. name .. ": " .. (note or flag(ok)))
  end
end
