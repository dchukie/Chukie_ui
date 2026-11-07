--[[ Catálogo de media para alertas CD/procs (arte de ThisWeeksAuras). ]]

local ADDON_NAME, ns = ...

local ROOT = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Alerts\\"

local function path(sub, file)
  return ROOT .. sub .. "\\" .. file
end

local M = {
  root = ROOT,
  texturesAll = {},
  shapes = {},
  rings = {},
  borders = {},
  statusbars = {},
  fonts = {},
  sounds = {},
  powerAuras = {},
  powerAurasSounds = {},
}

do
  local all = {
    "add.tga",
    "arrows_target.tga",
    "Border_DropShadow.blp",
    "browse.tga",
    "bug_report.tga",
    "bullet1.tga",
    "bullet2.tga",
    "bullet3.tga",
    "cancel-icon.tga",
    "cancel-mark.tga",
    "Circle_AlphaGradient_In.tga",
    "Circle_AlphaGradient_Out.tga",
    "circle_border5.tga",
    "Circle_Smooth_Border.tga",
    "Circle_Smooth.tga",
    "Circle_Smooth2.tga",
    "Circle_Squirrel_Border.tga",
    "Circle_Squirrel.tga",
    "Circle_White_Border.tga",
    "Circle_White.tga",
    "collapse.tga",
    "delete.tga",
    "discord.tga",
    "downleft.tga",
    "downright.tga",
    "duplicate.tga",
    "edge-example.tga",
    "edit.tga",
    "editdown.tga",
    "emoji.tga",
    "exclamation-mark.tga",
    "expand.tga",
    "eyes.tga",
    "gear.tga",
    "geardown.tga",
    "GitHub.tga",
    "icon.blp",
    "importsmall.tga",
    "info.tga",
    "interrupt.tga",
    "loaded.tga",
    "lockPosition.tga",
    "logo_256_round.tga",
    "logo_256.tga",
    "logo_64_nobg.tga",
    "logo_64.tga",
    "magnetic.tga",
    "movedown.tga",
    "moveup.tga",
    "newaura.tga",
    "offscreen.tga",
    "ok-icon.tga",
    "PRDFrame.tga",
    "PRDFrameKui.tga",
    "rainbowbar.tga",
    "reset.tga",
    "Ring_10px.tga",
    "Ring_20px.tga",
    "Ring_30px.tga",
    "Ring_40px.tga",
    "ring_glow3.tga",
    "sidebar.tga",
    "spinboxleft.tga",
    "spinboxlefth.tga",
    "spinboxleftp.tga",
    "spinboxoverlay.tga",
    "spinboxright.tga",
    "spinboxrighth.tga",
    "spinboxrightp.tga",
    "Square_AlphaGradient.tga",
    "square_border_10px.tga",
    "square_border_1px.tga",
    "square_border_5px.tga",
    "Square_FullWhite.tga",
    "square_mini.tga",
    "Square_Smooth_Border.tga",
    "Square_Smooth_Border2.tga",
    "Square_Smooth.tga",
    "Square_Squirrel_Border.tga",
    "Square_Squirrel.tga",
    "Square_White_Border.tga",
    "Square_White.tga",
    "standby.tga",
    "Statusbar_Clean.blp",
    "Statusbar_Stripes_Thick.blp",
    "Statusbar_Stripes_Thin.blp",
    "Statusbar_Stripes.blp",
    "stopmotion.blp",
    "stripe-bar.tga",
    "stripe-rainbow-bar.tga",
    "StripedTexture.tga",
    "swipe-example.tga",
    "target_indicator_glow.tga",
    "target_indicator.tga",
    "targeting-mark.tga",
    "template.tga",
    "Trapezoid.tga",
    "triangle-border.tga",
    "triangle.tga",
    "Triangle45.tga",
    "unloaded.tga",
    "upleft.tga",
    "upright.tga",
    "wago.tga",
    "wagoupdate_logo.tga",
    "wagoupdate_refresh.tga",
    "waheart.tga",
  }
  for i = 1, #all do
    M.texturesAll[i] = path("Textures", all[i])
  end
end

do
  local shapes = {
    "Circle_Smooth.tga",
    "Circle_Smooth_Border.tga",
    "Circle_Smooth2.tga",
    "Circle_Squirrel.tga",
    "Circle_Squirrel_Border.tga",
    "Circle_White.tga",
    "Circle_White_Border.tga",
    "Circle_AlphaGradient_In.tga",
    "Circle_AlphaGradient_Out.tga",
    "circle_border5.tga",
    "ring_glow3.tga",
    "Ring_10px.tga",
    "Ring_20px.tga",
    "Ring_30px.tga",
    "Ring_40px.tga",
    "Square_Smooth.tga",
    "Square_Smooth_Border.tga",
    "Square_Smooth_Border2.tga",
    "Square_Squirrel.tga",
    "Square_Squirrel_Border.tga",
    "Square_White.tga",
    "Square_White_Border.tga",
    "Square_FullWhite.tga",
    "Square_AlphaGradient.tga",
    "square_mini.tga",
    "square_border_1px.tga",
    "square_border_5px.tga",
    "square_border_10px.tga",
    "Trapezoid.tga",
    "triangle.tga",
    "triangle-border.tga",
    "Triangle45.tga",
    "target_indicator.tga",
    "target_indicator_glow.tga",
    "arrows_target.tga",
    "Statusbar_Clean.blp",
    "Statusbar_Stripes.blp",
    "rainbowbar.tga",
    "StripedTexture.tga",
    "stripe-bar.tga",
    "stripe-rainbow-bar.tga",
    "Border_DropShadow.blp",
    "edge-example.tga",
    "swipe-example.tga",
    "stopmotion.blp",
  }
  for i = 1, #shapes do
    M.shapes[i] = path("Textures", shapes[i])
  end
end

do
  local rings = { "Ring_10px.tga", "Ring_20px.tga", "Ring_30px.tga", "Ring_40px.tga", "ring_glow3.tga" }
  for i = 1, #rings do
    M.rings[i] = path("Textures", rings[i])
  end
end

do
  local borders = { "square_border_1px.tga", "square_border_5px.tga", "square_border_10px.tga", "Border_DropShadow.blp", "circle_border5.tga" }
  for i = 1, #borders do
    M.borders[i] = path("Textures", borders[i])
  end
end

do
  local bars = {}
  for _, f in ipairs({
    "rainbowbar.tga",
    "Statusbar_Clean.blp",
    "Statusbar_Stripes_Thick.blp",
    "Statusbar_Stripes_Thin.blp",
    "Statusbar_Stripes.blp",
    "stripe-bar.tga",
    "stripe-rainbow-bar.tga",
    "StripedTexture.tga",
  }) do
    bars[#bars + 1] = f
  end
  for i = 1, #bars do
    M.statusbars[i] = path("Textures", bars[i])
  end
end

do
  local fonts = {
    "FiraMono-Medium.ttf",
    "FiraSans-Heavy.ttf",
    "FiraSans-Medium.ttf",
    "FiraSansCondensed-Heavy.ttf",
    "FiraSansCondensed-Medium.ttf",
    "PTSansNarrow-Bold.ttf",
    "PTSansNarrow-Regular.ttf",
  }
  for i = 1, #fonts do
    M.fonts[i] = path("Fonts", fonts[i])
  end
end

do
  local sounds = {
    "AcousticGuitar.ogg",
    "Adds.ogg",
    "AirHorn.ogg",
    "Applause.ogg",
    "BananaPeelSlip.ogg",
    "BatmanPunch.ogg",
    "BikeHorn.ogg",
    "Blast.ogg",
    "Bleat.ogg",
    "Boss.ogg",
    "BoxingArenaSound.ogg",
    "Brass.mp3",
    "CartoonVoiceBaritone.ogg",
    "CartoonWalking.ogg",
    "CatMeow2.ogg",
    "ChickenAlarm.ogg",
    "Circle.ogg",
    "CowMooing.ogg",
    "Cross.ogg",
    "Diamond.ogg",
    "DontRelease.ogg",
    "DoubleWhoosh.ogg",
    "Drums.ogg",
    "Empowered.ogg",
    "ErrorBeep.ogg",
    "Focus.ogg",
    "Glass.mp3",
    "GoatBleating.ogg",
    "HeartbeatSingle.ogg",
    "Idiot.ogg",
    "KittenMeow.ogg",
    "Left.ogg",
    "Moon.ogg",
    "Next.ogg",
    "OhNo.ogg",
    "Portal.ogg",
    "Protected.ogg",
    "Release.ogg",
    "Right.ogg",
    "RingingPhone.ogg",
    "RoaringLion.ogg",
    "RobotBlip.ogg",
    "RoosterChickenCalls.ogg",
    "RunAway.ogg",
    "SharpPunch.ogg",
    "SheepBleat.ogg",
    "Shotgun.ogg",
    "Skull.ogg",
    "Spread.ogg",
    "Square.ogg",
    "SqueakyToyShort.ogg",
    "SquishFart.ogg",
    "Stack.ogg",
    "Star.ogg",
    "Switch.ogg",
    "SynthChord.ogg",
    "TadaFanfare.ogg",
    "Taunt.ogg",
    "TempleBellHuge.ogg",
    "Torch.ogg",
    "Triangle.ogg",
    "WarningSiren.ogg",
    "WaterDrop.ogg",
    "Xylophone.ogg",
  }
  for i = 1, #sounds do
    M.sounds[i] = path("Sounds", sounds[i])
  end
end

do
  local pa = {
    "Aura1.tga",
    "Aura10.tga",
    "Aura100.tga",
    "Aura101.tga",
    "Aura102.tga",
    "Aura103.tga",
    "Aura104.tga",
    "Aura105.tga",
    "Aura106.tga",
    "Aura107.tga",
    "Aura108.tga",
    "Aura109.tga",
    "Aura11.tga",
    "Aura110.tga",
    "Aura111.tga",
    "Aura112.tga",
    "Aura113.tga",
    "Aura114.tga",
    "Aura115.tga",
    "Aura116.tga",
    "Aura117.tga",
    "Aura118.tga",
    "Aura119.tga",
    "Aura12.tga",
    "Aura120.tga",
    "Aura121.tga",
    "Aura122.tga",
    "Aura123.tga",
    "Aura124.tga",
    "Aura125.tga",
    "Aura126.tga",
    "Aura127.tga",
    "Aura128.tga",
    "Aura129.tga",
    "Aura13.tga",
    "Aura130.tga",
    "Aura131.tga",
    "Aura132.tga",
    "Aura133.tga",
    "Aura134.tga",
    "Aura135.tga",
    "Aura136.tga",
    "Aura137.tga",
    "Aura138.tga",
    "Aura139.tga",
    "Aura14.tga",
    "Aura140.tga",
    "Aura141.tga",
    "Aura142.tga",
    "Aura143.tga",
    "Aura144.tga",
    "Aura145.tga",
    "Aura15.tga",
    "Aura16.tga",
    "Aura17.tga",
    "Aura18.tga",
    "Aura19.tga",
    "Aura2.tga",
    "Aura20.tga",
    "Aura21.tga",
    "Aura22.tga",
    "Aura23.tga",
    "Aura24.tga",
    "Aura25.tga",
    "Aura26.tga",
    "Aura27.tga",
    "Aura28.tga",
    "Aura29.tga",
    "Aura3.tga",
    "Aura30.tga",
    "Aura31.tga",
    "Aura32.tga",
    "Aura33.tga",
    "Aura34.tga",
    "Aura35.tga",
    "Aura36.tga",
    "Aura37.tga",
    "Aura38.tga",
    "Aura39.tga",
    "Aura4.tga",
    "Aura40.tga",
    "Aura41.tga",
    "Aura42.tga",
    "Aura43.tga",
    "Aura44.tga",
    "Aura45.tga",
    "Aura46.tga",
    "Aura47.tga",
    "Aura48.tga",
    "Aura49.tga",
    "Aura5.tga",
    "Aura50.tga",
    "Aura51.tga",
    "Aura52.tga",
    "Aura53.tga",
    "Aura54.tga",
    "Aura55.tga",
    "Aura56.tga",
    "Aura57.tga",
    "Aura58.tga",
    "Aura59.tga",
    "Aura6.tga",
    "Aura60.tga",
    "Aura61.tga",
    "Aura62.tga",
    "Aura63.tga",
    "Aura64.tga",
    "Aura65.tga",
    "Aura66.tga",
    "Aura67.tga",
    "Aura68.tga",
    "Aura69.tga",
    "Aura7.tga",
    "Aura70.tga",
    "Aura71.tga",
    "Aura72.tga",
    "Aura73.tga",
    "Aura74.tga",
    "Aura75.tga",
    "Aura76.tga",
    "Aura77.tga",
    "Aura78.tga",
    "Aura79.tga",
    "Aura8.tga",
    "Aura80.tga",
    "Aura81.tga",
    "Aura82.tga",
    "Aura83.tga",
    "Aura84.tga",
    "Aura85.tga",
    "Aura86.tga",
    "Aura87.tga",
    "Aura88.tga",
    "Aura89.tga",
    "Aura9.tga",
    "Aura90.tga",
    "Aura91.tga",
    "Aura92.tga",
    "Aura93.tga",
    "Aura94.tga",
    "Aura95.tga",
    "Aura96.tga",
    "Aura97.tga",
    "Aura98.tga",
    "Aura99.tga",
  }
  for i = 1, #pa do
    M.powerAuras[i] = path("PowerAuras", pa[i])
  end
end

do
  local pas = {
    "aggro.ogg",
    "Arrow_Swoosh.ogg",
    "bam.ogg",
    "bear_polar.ogg",
    "bigkiss.ogg",
    "BITE.ogg",
    "burp4.ogg",
    "cat2.ogg",
    "chant2.ogg",
    "chant4.ogg",
    "chimes.ogg",
    "cookie.ogg",
    "ESPARK1.ogg",
    "Fireball.ogg",
    "Gasp.ogg",
    "heartbeat.ogg",
    "hic3.ogg",
    "huh_1.ogg",
    "hurricane.ogg",
    "hyena.ogg",
    "kaching.ogg",
    "moan.ogg",
    "panther1.ogg",
    "phone.ogg",
    "PUNCH.ogg",
    "rainroof.ogg",
    "rocket.ogg",
    "shipswhistle.ogg",
    "shot.ogg",
    "snakeatt.ogg",
    "sneeze.ogg",
    "sonar.ogg",
    "splash.ogg",
    "Squeakypig.ogg",
    "swordecho.ogg",
    "throwknife.ogg",
    "thunder.ogg",
    "wickedmalelaugh1.ogg",
    "wilhelm.ogg",
    "wlaugh.ogg",
    "wolf5.ogg",
    "yeehaw.ogg",
  }
  for i = 1, #pas do
    M.powerAurasSounds[i] = path("PowerAurasSounds", pas[i])
  end
end

function M.Counts()
  local lsmN = 0
  local lsm = M.GetLSM and M.GetLSM()
  if lsm then
    for _, mt in ipairs({ "background", "statusbar", "border", "font", "sound" }) do
      local list = lsm:List(mt)
      if list then
        lsmN = lsmN + #list
      end
    end
  end
  return {
    textures = #M.texturesAll,
    shapes = #M.shapes,
    rings = #M.rings,
    borders = #M.borders,
    statusbars = #M.statusbars,
    fonts = #M.fonts,
    sounds = #M.sounds,
    powerAuras = #M.powerAuras,
    powerAurasSounds = #M.powerAurasSounds,
    user = #(M.userTextures or {}),
    lsm = lsmN,
  }
end

function M.GetLSM()
  if not LibStub then
    return nil
  end
  return LibStub("LibSharedMedia-3.0", true)
end

function M.InvalidateCatalogs()
  M._auraCatalog = nil
  M._fontPaths = nil
  M._soundPaths = nil
  M._presets = nil
end

local function appendUnique(list, pathStr)
  if type(pathStr) ~= "string" or pathStr == "" then
    return
  end
  for i = 1, #list do
    if list[i] == pathStr then
      return
    end
  end
  list[#list + 1] = pathStr
end

--- Incorpora Media\Alerts\User\ listado en AlertsUserMedia.lua.
function M.ApplyUserMedia()
  M.userTextures = M.userTextures or {}
  wipe(M.userTextures)
  local um = ns.AlertsUserMedia
  if type(um) ~= "table" then
    return
  end
  if type(um.textures) == "table" then
    for i = 1, #um.textures do
      local file = um.textures[i]
      if type(file) == "string" and file ~= "" then
        file = file:gsub("^\\+", ""):gsub("^/+", "")
        local full = path("User", file)
        appendUnique(M.powerAuras, full)
        appendUnique(M.texturesAll, full)
        appendUnique(M.userTextures, full)
      end
    end
  end
  if type(um.fonts) == "table" then
    for i = 1, #um.fonts do
      local f = um.fonts[i]
      if type(f) == "string" and f ~= "" then
        appendUnique(M.fonts, path("User", f:gsub("^\\+", ""):gsub("^/+", "")))
      end
    end
  end
  if type(um.sounds) == "table" then
    for i = 1, #um.sounds do
      local s = um.sounds[i]
      if type(s) == "string" and s ~= "" then
        appendUnique(M.sounds, path("User", s:gsub("^\\+", ""):gsub("^/+", "")))
      end
    end
  end
end

--- Publica media local en LSM (si está presente) para otros addons.
function M.RegisterIntoLSM()
  local lsm = M.GetLSM()
  if not lsm then
    return false
  end
  local function reg(mt, key, data)
    pcall(function()
      lsm:Register(mt, key, data)
    end)
  end
  for i = 1, #M.powerAuras do
    local p = M.powerAuras[i]
    local name = p:match("([^\\]+)$") or ("ChukieAura" .. i)
    reg("background", "Chukie:" .. name, p)
  end
  for i = 1, #M.rings do
    local p = M.rings[i]
    local name = p:match("([^\\]+)$") or ("ChukieRing" .. i)
    reg("border", "Chukie:" .. name, p)
  end
  for i = 1, #M.statusbars do
    local p = M.statusbars[i]
    local name = p:match("([^\\]+)$") or ("ChukieBar" .. i)
    reg("statusbar", "Chukie:" .. name, p)
  end
  for i = 1, #M.fonts do
    local p = M.fonts[i]
    local name = p:match("([^\\]+)$") or ("ChukieFont" .. i)
    reg("font", "Chukie:" .. name, p)
  end
  for i = 1, math.min(#M.sounds, 40) do
    local p = M.sounds[i]
    local name = p:match("([^\\]+)$") or ("ChukieSound" .. i)
    reg("sound", "Chukie:" .. name, p)
  end
  return true
end

local function ensureLsmCallbacks()
  if M._lsmCallbacksBound then
    return
  end
  local lsm = M.GetLSM()
  if not lsm or type(lsm.RegisterCallback) ~= "function" then
    return
  end
  local ok = pcall(function()
    lsm.RegisterCallback(M, "LibSharedMedia_Registered", function()
      M.InvalidateCatalogs()
    end)
    if lsm.UnregisterAllCallbacks or true then
      pcall(function()
        lsm.RegisterCallback(M, "LibSharedMedia_SetGlobal", function()
          M.InvalidateCatalogs()
        end)
      end)
    end
  end)
  if ok then
    M._lsmCallbacksBound = true
  end
end

function M.IsKnownMediaPath(p)
  if type(p) ~= "string" or p == "" then
    return false
  end
  local lists = { M.powerAuras, M.shapes, M.rings, M.texturesAll, M.fonts, M.userTextures, M.sounds }
  for li = 1, #lists do
    local list = lists[li]
    if type(list) == "table" then
      for i = 1, #list do
        if list[i] == p then
          return true
        end
      end
    end
  end
  local presets = M.GetPresets()
  for i = 1, #presets do
    if presets[i].path == p then
      return true
    end
  end
  -- Cualquier ruta bajo Media\Alerts\ del addon (incl. User).
  local root = ROOT:lower()
  if p:lower():sub(1, #root) == root then
    return true
  end
  local lsm = M.GetLSM()
  if lsm then
    for _, mt in ipairs({ "background", "statusbar", "border", "font", "sound" }) do
      local ht = lsm:HashTable(mt)
      if type(ht) == "table" then
        for _, data in pairs(ht) do
          if data == p then
            return true
          end
        end
      end
    end
  end
  return false
end

--- Presets curados para el wizard (label + path).
function M.GetPresets()
  if M._presets then
    return M._presets
  end
  local list = {
    { key = "aura1", label = "Aura 1", path = path("PowerAuras", "Aura1.tga") },
    { key = "aura10", label = "Aura 10", path = path("PowerAuras", "Aura10.tga") },
    { key = "aura25", label = "Aura 25", path = path("PowerAuras", "Aura25.tga") },
    { key = "aura50", label = "Aura 50", path = path("PowerAuras", "Aura50.tga") },
    { key = "aura75", label = "Aura 75", path = path("PowerAuras", "Aura75.tga") },
    { key = "aura100", label = "Aura 100", path = path("PowerAuras", "Aura100.tga") },
    { key = "newaura", label = "New aura", path = path("Textures", "newaura.tga") },
    { key = "ring_glow", label = "Ring glow", path = path("Textures", "ring_glow3.tga") },
    { key = "heart", label = "Heart", path = path("Textures", "waheart.tga") },
    { key = "circle", label = "Circle", path = path("Textures", "Circle_Smooth.tga") },
  }
  M._presets = list
  return list
end

function M.DefaultAuraPath()
  local p = M.GetPresets()
  return (p[1] and p[1].path) or (M.powerAuras[1] or "")
end

--- Rutas de fuentes: locales + LSM.
function M.GetFontPaths()
  if M._fontPaths then
    return M._fontPaths
  end
  ensureLsmCallbacks()
  local out = {}
  local seen = {}
  local function add(p)
    if type(p) ~= "string" or p == "" or seen[p] then
      return
    end
    seen[p] = true
    out[#out + 1] = p
  end
  for i = 1, #M.fonts do
    add(M.fonts[i])
  end
  local lsm = M.GetLSM()
  if lsm then
    local list = lsm:List("font") or {}
    for i = 1, #list do
      local fetch = lsm:Fetch("font", list[i], true)
      add(fetch)
    end
  end
  M._fontPaths = out
  return out
end

--- Rutas de sonido: locales + LSM.
function M.GetSoundPaths()
  if M._soundPaths then
    return M._soundPaths
  end
  ensureLsmCallbacks()
  local out = {}
  local seen = {}
  local function add(p)
    if type(p) ~= "string" or p == "" or seen[p] then
      return
    end
    seen[p] = true
    out[#out + 1] = p
  end
  for i = 1, #M.sounds do
    add(M.sounds[i])
  end
  local lsm = M.GetLSM()
  if lsm then
    local list = lsm:List("sound") or {}
    for i = 1, #list do
      local fetch = lsm:Fetch("sound", list[i], true)
      add(fetch)
    end
  end
  M._soundPaths = out
  return out
end

--- Catálogo para el picker de arte (presets + locales + User + LibSharedMedia).
function M.GetAuraCatalog()
  if M._auraCatalog then
    return M._auraCatalog
  end
  ensureLsmCallbacks()
  local out = {}
  local seen = {}
  local function add(label, texPath)
    if not texPath or texPath == "" or seen[texPath] then
      return
    end
    seen[texPath] = true
    out[#out + 1] = { label = label or texPath:match("([^\\]+)$") or texPath, path = texPath }
  end
  local presets = M.GetPresets()
  for i = 1, #presets do
    add(presets[i].label, presets[i].path)
  end
  for i = 1, #M.powerAuras do
    local p = M.powerAuras[i]
    add(p:match("([^\\]+)$"), p)
  end
  for i = 1, #M.rings do
    add(M.rings[i]:match("([^\\]+)$"), M.rings[i])
  end
  for i = 1, #M.shapes do
    local p = M.shapes[i]
    local name = p:match("([^\\]+)$") or ""
    if name:find("[Cc]ircle") or name:find("[Rr]ing") or name:find("heart") or name:find("aura") then
      add(name, p)
    end
  end
  if type(M.userTextures) == "table" then
    for i = 1, #M.userTextures do
      local p = M.userTextures[i]
      add("User: " .. (p:match("([^\\]+)$") or p), p)
    end
  end
  local lsm = M.GetLSM()
  if lsm then
    for _, mt in ipairs({ "background", "statusbar", "border" }) do
      local list = lsm:List(mt) or {}
      for i = 1, #list do
        local key = list[i]
        local fetch = lsm:Fetch(mt, key, true)
        if fetch then
          add("LSM " .. mt .. ": " .. key, fetch)
        end
      end
    end
  end
  M._auraCatalog = out
  return out
end

M.ApplyUserMedia()
M.RegisterIntoLSM()
ensureLsmCallbacks()

-- LSM a veces carga después (SharedMedia); reintentar al login.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" then
    if name == "LibSharedMedia-3.0" or name == "SharedMedia" or (type(name) == "string" and name:find("SharedMedia")) then
      M.InvalidateCatalogs()
      M.RegisterIntoLSM()
      ensureLsmCallbacks()
    end
    return
  end
  if event == "PLAYER_LOGIN" then
    M.InvalidateCatalogs()
    M.RegisterIntoLSM()
    ensureLsmCallbacks()
  end
end)

ns.AlertsMedia = M
