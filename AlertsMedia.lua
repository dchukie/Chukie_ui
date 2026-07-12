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
  }
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

function M.IsKnownMediaPath(p)
  if type(p) ~= "string" or p == "" then
    return false
  end
  local lists = { M.powerAuras, M.shapes, M.rings, M.texturesAll, M.fonts }
  for li = 1, #lists do
    local list = lists[li]
    for i = 1, #list do
      if list[i] == p then
        return true
      end
    end
  end
  local presets = M.GetPresets()
  for i = 1, #presets do
    if presets[i].path == p then
      return true
    end
  end
  return false
end

--- Catálogo para el picker de arte (presets primero, luego powerAuras + rings + shapes útiles).
function M.GetAuraCatalog()
  if M._auraCatalog then
    return M._auraCatalog
  end
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
  M._auraCatalog = out
  return out
end

ns.AlertsMedia = M
