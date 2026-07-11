--[[ Panel izquierdo (independiente del panel derecho).
     El modo debug solo muestra guías visuales de sectores.
     L1 y su ventana fueron retirados por diseño actual. ]]

local _, ns = ...

local LP = {}
ns.LeftPanel = LP

local BASE_W = 348
local BASE_H = 252

local FONT_FACES = {
  [0] = STANDARD_TEXT_FONT,
  [1] = "Fonts\\FRIZQT__.TTF",
  [2] = "Fonts\\ARIALN.TTF",
  [3] = "Fonts\\MORPHEUS.TTF",
  [4] = "Fonts\\SKURRI.TTF",
}

local SECTOR_COLORS = {
  { 0.92, 0.40, 0.40, 0.9 },
  { 0.90, 0.34, 0.34, 0.9 },
  { 0.95, 0.52, 0.40, 0.9 },
  { 0.96, 0.62, 0.40, 0.9 },
  { 0.99, 0.70, 0.42, 0.9 },
}

-- Coordenadas normalizadas sobre BASE_W x BASE_H.
local LAYOUT = {
  { id = "L2", x = 0 / BASE_W, y = 115 / BASE_H, w = 17 / BASE_W, h = 143 / BASE_H },
  { id = "L3", x = 19 / BASE_W, y = 115 / BASE_H, w = 176 / BASE_W, h = 143 / BASE_H },
  { id = "L4", x = 197 / BASE_W, y = 115 / BASE_H, w = 166.1 / BASE_W, h = 119 / BASE_H },
  { id = "L5", x = 197 / BASE_W, y = 236 / BASE_H, w = 166.1 / BASE_W, h = 22 / BASE_H },
}

local L1_SUBS_DEFAULT = {
  loot = true,
  money = true,
  currency = true,
  tradeskills = true,
  system = true,
  combatMisc = true,
  skill = true,
  bgSystem = true,
  raidWarning = true,
  uiError = true,
  uiInfo = true,
  tradeChannel = true,
  blizzardGeneralMirror = true,
}

local L3_SUBS_DEFAULT = {
  say = true,
  yell = true,
  emote = true,
  guild = true,
  officer = true,
  party = true,
  raid = true,
  instance = true,
  whisper = true,
  whisperInform = true,
  bnWhisper = true,
  bnWhisperInform = true,
  channel = true,
  communities = true,
}

local function db()
  if ns.Profile and ns.Profile.GetRightPanelModel then
    return ns.Profile:GetRightPanelModel()
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  p.minimapPosition = p.minimapPosition or {}
  return p.minimapPosition
end

local function getLayoutById(id)
  for i = 1, #LAYOUT do
    if LAYOUT[i].id == id then
      return LAYOUT[i]
    end
  end
  return nil
end

local function subEnabled(groupKey, key)
  local d = db()
  d[groupKey] = type(d[groupKey]) == "table" and d[groupKey] or {}
  local current = d[groupKey][key]
  local defaults = (groupKey == "leftPanelL1Subs") and L1_SUBS_DEFAULT or L3_SUBS_DEFAULT
  local fallback = defaults[key] ~= false
  if current == nil then
    return fallback
  end
  return current == true or current == 1
end

local function isUsableChatString(s)
  if s == nil then
    return false
  end
  if issecretvalue and issecretvalue(s) then
    return false
  end
  return type(s) == "string" and s ~= ""
end

local function isTradeChannelName(channelName)
  if not isUsableChatString(channelName) then
    return false
  end
  local low = strlower(channelName)
  local tradeToken = strlower(tostring(_G.TRADE or "Trade"))
  if strfind(low, tradeToken, 1, true) then
    return true
  end
  return strfind(low, "trade", 1, true) ~= nil
end

local function colorForChatType(chatType)
  local ci = ChatTypeInfo and ChatTypeInfo[chatType]
  if ci then
    return ci.r or 1, ci.g or 1, ci.b or 1
  end
  return 1, 1, 1
end

local function getNow()
  if GetTimePreciseSec then
    return GetTimePreciseSec()
  end
  return GetTime and GetTime() or 0
end

local function isSystemLikeColor(r, g, b)
  r = tonumber(r) or 1
  g = tonumber(g) or 1
  b = tonumber(b) or 1
  local yellow = r >= 0.80 and g >= 0.70 and b <= 0.35
  local orange = r >= 0.90 and g >= 0.40 and g <= 0.75 and b <= 0.30
  return yellow or orange
end

local function isMachineLikeColor(r, g, b)
  r = tonumber(r) or 1
  g = tonumber(g) or 1
  b = tonumber(b) or 1
  local greenInfo = g >= 0.75 and r <= 0.60 and b <= 0.60
  local redAlert = r >= 0.75 and g <= 0.35 and b <= 0.35
  return isSystemLikeColor(r, g, b) or greenInfo or redAlert
end

local function isLikelyMachineLine(text, r, g, b)
  if type(text) ~= "string" or text == "" then
    return false
  end
  if isMachineLikeColor(r, g, b) then
    return true
  end
  local low = strlower(text)
  if strfind(low, "guild message of the day", 1, true) then
    return true
  end
  if strfind(low, "loot specialization", 1, true) then
    return true
  end
  if strfind(low, "zygor guides viewer", 1, true) then
    return true
  end
  return false
end

local function getPlayerShortName()
  if not LP._playerShortName or LP._playerShortName == "" then
    local p = UnitName and UnitName("player") or ""
    if Ambiguate then
      p = Ambiguate(p, "short")
    end
    p = tostring(p or ""):gsub("%-.*$", "")
    LP._playerShortName = p
  end
  return LP._playerShortName
end

local function shortSenderName(name)
  if not isUsableChatString(name) then
    return nil
  end
  local out = name
  if Ambiguate then
    out = Ambiguate(out, "short")
  end
  out = tostring(out):gsub("%-.*$", "")
  if out == "" then
    return nil
  end
  return out
end

local function withSenderPrefix(text, sender)
  if issecretvalue and issecretvalue(text) then
    return nil
  end
  local msg = tostring(text or "")
  local s = shortSenderName(sender)
  if not s then
    s = getPlayerShortName()
  end
  if not s then
    return msg
  end
  return string.format("[%s] - %s", s, msg)
end

local function createDebugSector(parent, idx)
  local c = SECTOR_COLORS[idx] or SECTOR_COLORS[#SECTOR_COLORS]
  local f = CreateFrame("Frame", "ChukieUi_LeftPanelSector_" .. tostring(idx), parent)
  f:SetFrameStrata("TOOLTIP")
  f:SetFixedFrameStrata(true)
  f:SetFrameLevel(65520 - idx)
  local fill = f:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(f)
  local top = f:CreateTexture(nil, "OVERLAY")
  top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  top:SetHeight(2)
  local bot = f:CreateTexture(nil, "OVERLAY")
  bot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  bot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  bot:SetHeight(2)
  local left = f:CreateTexture(nil, "OVERLAY")
  left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  left:SetWidth(2)
  local right = f:CreateTexture(nil, "OVERLAY")
  right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(2)
  f._dbgFill = fill
  f._dbgTop = top
  f._dbgBot = bot
  f._dbgLeft = left
  f._dbgRight = right
  f._dbgBaseR = c[1]
  f._dbgBaseG = c[2]
  f._dbgBaseB = c[3]
  f._dbgBaseA = c[4]
  local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER", f, "CENTER", 0, 0)
  label:SetText((LAYOUT[idx] and LAYOUT[idx].id) or ("L" .. tostring(idx)))
  label:SetTextColor(1, 1, 1, 0.95)
  label:SetShadowOffset(1, -1)
  label:SetShadowColor(0, 0, 0, 0.9)
  f._label = label
  return f
end

local function setSectorDebugVisual(seg, showDebug)
  local alphaFill = showDebug and 0.12 or 0
  local alphaBorder = showDebug and (seg._dbgBaseA or 0.9) or 0
  seg._dbgFill:SetColorTexture(seg._dbgBaseR or 1, seg._dbgBaseG or 1, seg._dbgBaseB or 1, alphaFill)
  for _, r in ipairs({ seg._dbgTop, seg._dbgBot, seg._dbgLeft, seg._dbgRight }) do
    r:SetColorTexture(seg._dbgBaseR or 1, seg._dbgBaseG or 1, seg._dbgBaseB or 1, alphaBorder)
  end
  if seg._label then
    seg._label:SetShown(showDebug)
  end
end

function LP:EnsureLootTradeFeed()
  -- Ventana L1 eliminada por configuración actual.
end

function LP:ApplyLootTradeStyle()
  -- Ventana L1 eliminada por configuración actual.
end

function LP:AppendLootTrade(chatType, text)
  -- Ventana L1 eliminada por configuración actual.
end

function LP:EnsureGeneralFeed()
  if self._feedGeneral and self._feedGeneral.msg then
    return
  end
  local holder = CreateFrame("Frame", nil, self._group)
  holder:EnableMouse(true)
  holder:SetMouseClickEnabled(true)

  local bg = holder:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(holder)
  bg:SetColorTexture(0, 0, 0, 0.35)

  local msg = CreateFrame("ScrollingMessageFrame", nil, holder)
  msg:SetPoint("TOPLEFT", holder, "TOPLEFT", 6, -6)
  msg:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -22, 6)
  msg:SetJustifyH("LEFT")
  msg:SetJustifyV("TOP")
  if msg.SetIndentedWordWrap then
    msg:SetIndentedWordWrap(true)
  end
  msg:SetFading(false)
  msg:SetMaxLines(500)
  if msg.SetHyperlinksEnabled then
    msg:SetHyperlinksEnabled(true)
  end
  msg:EnableMouse(true)
  msg:EnableMouseWheel(true)
  msg:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then
      self:ScrollUp()
    else
      self:ScrollDown()
    end
  end)
  msg:SetScript("OnHyperlinkClick", function(self, link, text, button)
    if ChatFrame_OnHyperlinkShow then
      ChatFrame_OnHyperlinkShow(self, link, text, button)
    elseif SetItemRef then
      SetItemRef(link, text, button, self)
    end
  end)
  msg:SetScript("OnHyperlinkEnter", function(self, link, text)
    if ChatFrame_OnHyperlinkEnter then
      ChatFrame_OnHyperlinkEnter(self, link, text)
    end
  end)
  msg:SetScript("OnHyperlinkLeave", function(self, link, text)
    if ChatFrame_OnHyperlinkLeave then
      ChatFrame_OnHyperlinkLeave(self, link, text)
    end
  end)

  local up = CreateFrame("Button", nil, holder, "UIPanelScrollUpButtonTemplate")
  up:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -2, -4)
  up:SetScript("OnClick", function()
    msg:ScrollUp()
  end)
  local down = CreateFrame("Button", nil, holder, "UIPanelScrollDownButtonTemplate")
  down:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 4)
  down:SetScript("OnClick", function()
    msg:ScrollDown()
  end)

  self._feedGeneral = { holder = holder, bg = bg, msg = msg, up = up, down = down }
end

function LP:ApplyGeneralStyle()
  self:EnsureGeneralFeed()
  local feed = self._feedGeneral
  if not (feed and feed.msg) then
    return
  end
  local d = db()
  local alphaPct = tonumber(d.leftPanelGeneralBgAlphaPercent) or 35
  alphaPct = math.max(0, math.min(100, math.floor(alphaPct + 0.5)))
  d.leftPanelGeneralBgAlphaPercent = alphaPct
  feed.bg:SetColorTexture(0, 0, 0, alphaPct / 100)

  local autoFont = math.max(9, math.min(16, math.floor(((feed.holder:GetHeight() or 120) / 14) + 0.5)))
  local manual = tonumber(d.leftPanelGeneralFontSize) or 0
  local fontPx = (manual > 0) and math.max(8, math.min(32, math.floor(manual + 0.5))) or autoFont
  local path = FONT_FACES[tonumber(d.leftPanelGeneralFontFace) or 0] or STANDARD_TEXT_FONT
  local ok = feed.msg:SetFont(path, fontPx, "")
  if not ok then
    feed.msg:SetFont("Fonts\\FRIZQT__.TTF", fontPx, "")
  end

  local maxLines = tonumber(d.leftPanelGeneralHistoryMax) or 500
  maxLines = math.max(50, math.min(2000, math.floor(maxLines + 0.5)))
  d.leftPanelGeneralHistoryMax = maxLines
  feed.msg:SetMaxLines(maxLines)
end

function LP:EnsureGeneralInputBox()
  self:EnsureGeneralFeed()
  if self._generalInput then
    return
  end
  local eb = _G.ChatFrame1EditBox
  if not eb then
    return
  end
  self._generalInput = eb
  if not self._generalInputHooked then
    self._generalInputHooked = true
    eb:HookScript("OnShow", function(box)
      if LP._group and LP._group:IsShown() then
        box:SetParent(LP._group)
        LP:ApplyGeneralInputStyle()
      end
    end)
  end
end

function LP:EnsureGeneralInputCleanSkin()
  self:EnsureGeneralInputBox()
  local eb = self._generalInput
  if not eb then
    return
  end
  if eb._chukieSkinFrame then
    return
  end
  local skin = CreateFrame("Frame", nil, eb)
  skin:SetPoint("TOPLEFT", eb, "TOPLEFT", -2, 2)
  skin:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 2, -2)
  skin:SetFrameLevel(eb:GetFrameLevel() - 1)
  local bg = skin:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(skin)
  local top = skin:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT", skin, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", skin, "TOPRIGHT", 0, 0)
  top:SetHeight(1)
  local bot = skin:CreateTexture(nil, "BORDER")
  bot:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", 0, 0)
  bot:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", 0, 0)
  bot:SetHeight(1)
  local left = skin:CreateTexture(nil, "BORDER")
  left:SetPoint("TOPLEFT", skin, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", 0, 0)
  left:SetWidth(1)
  local right = skin:CreateTexture(nil, "BORDER")
  right:SetPoint("TOPRIGHT", skin, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(1)
  eb._chukieSkinFrame = skin
  eb._chukieSkinBg = bg
  eb._chukieSkinTop = top
  eb._chukieSkinBot = bot
  eb._chukieSkinLeft = left
  eb._chukieSkinRight = right
end

function LP:ApplyGeneralInputStyle()
  self:EnsureGeneralInputBox()
  local eb = self._generalInput
  if not eb then
    return
  end
  local d = db()
  local alphaPct = tonumber(d.leftPanelGeneralInputBgAlphaPercent) or 55
  alphaPct = math.max(0, math.min(100, math.floor(alphaPct + 0.5)))
  d.leftPanelGeneralInputBgAlphaPercent = alphaPct
  local alpha = alphaPct / 100
  local useClean = d.leftPanelGeneralInputCleanStyle ~= false
  local borderAlphaPct = tonumber(d.leftPanelGeneralInputBorderAlphaPercent) or 45
  borderAlphaPct = math.max(0, math.min(100, math.floor(borderAlphaPct + 0.5)))
  d.leftPanelGeneralInputBorderAlphaPercent = borderAlphaPct
  local borderAlpha = borderAlphaPct / 100
  local borderSize = tonumber(d.leftPanelGeneralInputBorderSize) or 1
  borderSize = math.max(1, math.min(3, math.floor(borderSize + 0.5)))
  d.leftPanelGeneralInputBorderSize = borderSize

  local path = FONT_FACES[tonumber(d.leftPanelGeneralInputFontFace) or 0] or STANDARD_TEXT_FONT
  local autoFont = math.max(9, math.min(16, math.floor(((eb:GetHeight() or 24) / 1.8) + 0.5)))
  local manual = tonumber(d.leftPanelGeneralInputFontSize) or 0
  local fontPx = (manual > 0) and math.max(8, math.min(32, math.floor(manual + 0.5))) or autoFont
  local ok = eb:SetFont(path, fontPx, "")
  if not ok then
    eb:SetFont("Fonts\\FRIZQT__.TTF", fontPx, "")
  end

  self:EnsureGeneralInputCleanSkin()
  if eb._chukieSkinFrame then
    eb._chukieSkinFrame:SetShown(useClean)
    eb._chukieSkinBg:SetColorTexture(0.02, 0.02, 0.03, alpha)
    for _, line in ipairs({ eb._chukieSkinTop, eb._chukieSkinBot, eb._chukieSkinLeft, eb._chukieSkinRight }) do
      line:SetColorTexture(0.90, 0.70, 0.45, borderAlpha)
    end
    eb._chukieSkinTop:SetHeight(borderSize)
    eb._chukieSkinBot:SetHeight(borderSize)
    eb._chukieSkinLeft:SetWidth(borderSize)
    eb._chukieSkinRight:SetWidth(borderSize)
  end

  local artAlpha = useClean and 0 or alpha
  if eb.Left then
    eb.Left:SetAlpha(artAlpha)
  end
  if eb.Mid then
    eb.Mid:SetAlpha(artAlpha)
  end
  if eb.Right then
    eb.Right:SetAlpha(artAlpha)
  end
  if eb.FocusLeft then
    eb.FocusLeft:SetAlpha(artAlpha)
  end
  if eb.FocusMid then
    eb.FocusMid:SetAlpha(artAlpha)
  end
  if eb.FocusRight then
    eb.FocusRight:SetAlpha(artAlpha)
  end
  if eb.HighlightLeft then
    eb.HighlightLeft:SetAlpha(artAlpha)
  end
  if eb.HighlightMid then
    eb.HighlightMid:SetAlpha(artAlpha)
  end
  if eb.HighlightRight then
    eb.HighlightRight:SetAlpha(artAlpha)
  end
  if eb.NineSlice then
    eb.NineSlice:SetShown(not useClean)
  end
  -- Algunos clientes recrean/retocan la art clásica por regiones.
  -- Forzamos alpha en todas las texturas del editbox.
  local n = eb.GetNumRegions and eb:GetNumRegions() or 0
  for i = 1, n do
    local reg = select(i, eb:GetRegions())
    if reg and reg.GetObjectType and reg:GetObjectType() == "Texture" then
      reg:SetAlpha(artAlpha)
    end
  end
end

function LP:AppendGeneral(chatType, text)
  -- Ventana de texto L3 eliminada por configuración actual.
end

function LP:AppendGeneralRaw(text, r, g, b)
  -- Ventana de texto L3 eliminada por configuración actual.
end

function LP:EnsureGeneralMirrorHook()
  local d = db()
  if d.leftPanelGeneralMirrorFromBlizzard == false then
    return
  end
  local idx = tonumber(d.leftPanelGeneralMirrorFrame) or 1
  idx = math.max(1, math.min(10, math.floor(idx + 0.5)))
  d.leftPanelGeneralMirrorFrame = idx
  local src = _G["ChatFrame" .. tostring(idx)] or DEFAULT_CHAT_FRAME
  if not (src and src.AddMessage) then
    return
  end
  if self._generalMirrorSource == src then
    return
  end
  self._generalMirrorSource = src
  hooksecurefunc(src, "AddMessage", function(_, text, r, g, b)
    local m = db()
    if m.leftPanelEnabled == false or m.leftPanelGeneralMirrorFromBlizzard == false then
      return
    end
    self:AppendGeneralRaw(text, r, g, b)
  end)
end

function LP:EnsureSystemMirrorHook()
  -- Desactivado: AddMessage puede entregar "secret string value" en contexto taint,
  -- y cualquier comparación/manipulación de `text` aquí provoca errores en combate.
  -- La captura principal de sistema ya se hace por eventos CHAT_MSG_* en EnsureEvents().
  return
end

function LP:EnsureEvents()
  if self._ev then
    return
  end
  local ev = CreateFrame("Frame")
  self._ev = ev
  ev:RegisterEvent("CHAT_MSG_LOOT")
  ev:RegisterEvent("CHAT_MSG_MONEY")
  ev:RegisterEvent("CHAT_MSG_CURRENCY")
  ev:RegisterEvent("CHAT_MSG_TRADESKILLS")
  ev:RegisterEvent("CHAT_MSG_SYSTEM")
  ev:RegisterEvent("CHAT_MSG_COMBAT_MISC_INFO")
  ev:RegisterEvent("CHAT_MSG_SKILL")
  ev:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
  ev:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
  ev:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
  ev:RegisterEvent("CHAT_MSG_RAID_WARNING")
  ev:RegisterEvent("UI_ERROR_MESSAGE")
  ev:RegisterEvent("UI_INFO_MESSAGE")
  ev:RegisterEvent("CHAT_MSG_SAY")
  ev:RegisterEvent("CHAT_MSG_YELL")
  ev:RegisterEvent("CHAT_MSG_EMOTE")
  ev:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
  ev:RegisterEvent("CHAT_MSG_GUILD")
  ev:RegisterEvent("CHAT_MSG_OFFICER")
  ev:RegisterEvent("CHAT_MSG_PARTY")
  ev:RegisterEvent("CHAT_MSG_PARTY_LEADER")
  ev:RegisterEvent("CHAT_MSG_RAID")
  ev:RegisterEvent("CHAT_MSG_RAID_LEADER")
  ev:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
  ev:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
  ev:RegisterEvent("CHAT_MSG_WHISPER")
  ev:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
  ev:RegisterEvent("CHAT_MSG_BN_WHISPER")
  ev:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")
  ev:RegisterEvent("CHAT_MSG_COMMUNITIES_CHANNEL")
  ev:RegisterEvent("CHAT_MSG_CHANNEL")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("UI_SCALE_CHANGED")
  ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
  ev:SetScript("OnEvent", function(_, event, ...)
    local d = db()
    local mirrorGeneral = d.leftPanelGeneralMirrorFromBlizzard ~= false
    if event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
      LP:Refresh()
      return
    end
    if d.leftPanelEnabled == false then
      return
    end
    if InCombatLockdown and InCombatLockdown() then
      if event:match("^CHAT_MSG_") or event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
        return
      end
    end
    if event == "CHAT_MSG_CHANNEL" then
      local msg, sender = ...
      if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then
        return
      end
      local channelName = select(9, ...)
      if issecretvalue and issecretvalue(channelName) then
        return
      end
      local line = withSenderPrefix(msg, sender)
      if not line then
        return
      end
      if isTradeChannelName(channelName) then
        if subEnabled("leftPanelL1Subs", "tradeChannel") then
          LP:AppendLootTrade("CHANNEL", string.format("[%s] %s", tostring(channelName or "Trade"), tostring(line or "")))
        end
      elseif (not mirrorGeneral) and subEnabled("leftPanelL3Subs", "channel") then
        LP:AppendGeneral("CHANNEL", string.format("[%s] %s", tostring(channelName or "Canal"), tostring(line or "")))
      end
      return
    elseif event == "CHAT_MSG_COMMUNITIES_CHANNEL" then
      if (not mirrorGeneral) and subEnabled("leftPanelL3Subs", "communities") then
        local msg, sender = ...
        if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then
          return
        end
        local channelLabel = select(4, ...)
        local line = withSenderPrefix(msg, sender)
        if not line then
          return
        end
        LP:AppendGeneral("CHANNEL", string.format("[%s] %s", tostring(channelLabel or "Comunidad"), tostring(line or "")))
      end
      return
    end
    local msg, sender = ...
    if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then
      return
    end
    if event == "CHAT_MSG_LOOT" then
      if subEnabled("leftPanelL1Subs", "loot") then
        LP:AppendLootTrade("LOOT", msg)
      end
    elseif event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_CURRENCY" then
      local key = (event == "CHAT_MSG_MONEY") and "money" or "currency"
      if subEnabled("leftPanelL1Subs", key) then
        LP:AppendLootTrade("MONEY", msg)
      end
    elseif event == "CHAT_MSG_TRADESKILLS" then
      if subEnabled("leftPanelL1Subs", "tradeskills") then
        LP:AppendLootTrade("TRADESKILLS", msg)
      end
    elseif event == "CHAT_MSG_SYSTEM" then
      if subEnabled("leftPanelL1Subs", "system") then
        LP:AppendLootTrade("SYSTEM", msg)
      end
    elseif event == "CHAT_MSG_COMBAT_MISC_INFO" then
      if subEnabled("leftPanelL1Subs", "combatMisc") then
        LP:AppendLootTrade("COMBAT_MISC_INFO", msg)
      end
    elseif event == "CHAT_MSG_SKILL" then
      if subEnabled("leftPanelL1Subs", "skill") then
        LP:AppendLootTrade("SKILL", msg)
      end
    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
      if subEnabled("leftPanelL1Subs", "bgSystem") then
        LP:AppendLootTrade("BG_SYSTEM_NEUTRAL", msg)
      end
    elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" then
      if subEnabled("leftPanelL1Subs", "bgSystem") then
        LP:AppendLootTrade("BG_SYSTEM_ALLIANCE", msg)
      end
    elseif event == "CHAT_MSG_BG_SYSTEM_HORDE" then
      if subEnabled("leftPanelL1Subs", "bgSystem") then
        LP:AppendLootTrade("BG_SYSTEM_HORDE", msg)
      end
    elseif event == "CHAT_MSG_RAID_WARNING" then
      if subEnabled("leftPanelL1Subs", "raidWarning") then
        LP:AppendLootTrade("RAID_WARNING", msg)
      end
    elseif event == "UI_ERROR_MESSAGE" then
      if subEnabled("leftPanelL1Subs", "uiError") then
        LP:AppendLootTrade("SYSTEM", select(2, ...))
      end
    elseif event == "UI_INFO_MESSAGE" then
      if subEnabled("leftPanelL1Subs", "uiInfo") then
        LP:AppendLootTrade("SYSTEM", select(2, ...))
      end
    elseif (not mirrorGeneral) and event == "CHAT_MSG_SAY" then
      if subEnabled("leftPanelL3Subs", "say") then
        LP:AppendGeneral("SAY", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and event == "CHAT_MSG_YELL" then
      if subEnabled("leftPanelL3Subs", "yell") then
        LP:AppendGeneral("YELL", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and (event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_TEXT_EMOTE") then
      if subEnabled("leftPanelL3Subs", "emote") then
        LP:AppendGeneral("EMOTE", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and event == "CHAT_MSG_GUILD" then
      if subEnabled("leftPanelL3Subs", "guild") then
        LP:AppendGeneral("GUILD", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and event == "CHAT_MSG_OFFICER" then
      if subEnabled("leftPanelL3Subs", "officer") then
        LP:AppendGeneral("OFFICER", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and (event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER") then
      if subEnabled("leftPanelL3Subs", "party") then
        LP:AppendGeneral("PARTY", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") then
      if subEnabled("leftPanelL3Subs", "raid") then
        LP:AppendGeneral("RAID", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and (event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER") then
      if subEnabled("leftPanelL3Subs", "instance") then
        LP:AppendGeneral("INSTANCE_CHAT", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and event == "CHAT_MSG_WHISPER" then
      if subEnabled("leftPanelL3Subs", "whisper") then
        LP:AppendGeneral("WHISPER", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and event == "CHAT_MSG_WHISPER_INFORM" then
      if subEnabled("leftPanelL3Subs", "whisperInform") then
        LP:AppendGeneral("WHISPER_INFORM", withSenderPrefix(msg, UnitName and UnitName("player") or nil))
      end
    elseif (not mirrorGeneral) and event == "CHAT_MSG_BN_WHISPER" then
      if subEnabled("leftPanelL3Subs", "bnWhisper") then
        LP:AppendGeneral("BN_WHISPER", withSenderPrefix(msg, sender))
      end
    elseif (not mirrorGeneral) and event == "CHAT_MSG_BN_WHISPER_INFORM" then
      if subEnabled("leftPanelL3Subs", "bnWhisperInform") then
        LP:AppendGeneral("BN_WHISPER_INFORM", withSenderPrefix(msg, UnitName and UnitName("player") or nil))
      end
    end
  end)
end

function LP:Ensure()
  local root = (ns.PanelCore and ns.PanelCore.EnsureRoot and ns.PanelCore:EnsureRoot()) or UIParent
  if not root then
    return
  end
  if not self._group then
    local g = CreateFrame("Frame", "ChukieUi_LeftPanelGroup", UIParent)
    g:SetFrameStrata("TOOLTIP")
    g:SetFixedFrameStrata(true)
    g:SetFrameLevel(65521)
    self._group = g
    self._sectors = {}
    for i = 1, #LAYOUT do
      self._sectors[i] = createDebugSector(g, i)
    end
  end
  if self._group:GetParent() ~= root then
    self._group:SetParent(root)
  end
  self:EnsureLootTradeFeed()
  self:EnsureGeneralFeed()
  self:EnsureGeneralInputBox()
  self:EnsureEvents()
  self:EnsureSystemMirrorHook()
  self:EnsureGeneralMirrorHook()
end

function LP:Hide()
  if self._feedLoot and self._feedLoot.holder then
    self._feedLoot.holder:Hide()
  end
  if self._feedGeneral and self._feedGeneral.holder then
    self._feedGeneral.holder:Hide()
  end
  if self._generalInput then
    if ChatEdit_DeactivateChat then
      ChatEdit_DeactivateChat(self._generalInput)
    else
      self._generalInput:Hide()
    end
  end
  if self._sectors then
    for i = 1, #self._sectors do
      self._sectors[i]:Hide()
    end
  end
  if self._group then
    self._group:Hide()
  end
end

function LP:Refresh()
  self:Ensure()
  if not self._group then
    return
  end
  local d = db()
  local showDebug = d.debugLeftPanelBounds == true or d.debugLeftPanelBounds == 1
  local showPanel = d.leftPanelEnabled ~= false
  if not showDebug and not showPanel then
    self:Hide()
    return
  end

  local scalePct = tonumber(d.leftPanelScalePercent) or 100
  scalePct = math.max(60, math.min(220, math.floor(scalePct + 0.5)))
  d.leftPanelScalePercent = scalePct
  local scale = scalePct / 100
  local groupW = math.max(2, math.floor((BASE_W * scale) + 0.5))
  local groupH = math.max(2, math.floor((BASE_H * scale) + 0.5))

  local offX = math.max(-1200, math.min(1200, math.floor((tonumber(d.leftPanelDebugOffsetX) or 0) + 0.5)))
  local offY = math.max(-1200, math.min(1200, math.floor((tonumber(d.leftPanelDebugOffsetY) or 0) + 0.5)))
  d.leftPanelDebugOffsetX = offX
  d.leftPanelDebugOffsetY = offY

  self._group:ClearAllPoints()
  self._group:SetSize(groupW, groupH)
  self._group:SetPoint("BOTTOMLEFT", self._group:GetParent(), "BOTTOMLEFT", offX, offY)
  self._group:Show()

  for i = 1, #LAYOUT do
    local def = LAYOUT[i]
    local seg = self._sectors[i]
    local sx = math.floor((def.x * groupW) + 0.5)
    local sy = math.floor((def.y * groupH) + 0.5)
    local sw = math.max(2, math.floor((def.w * groupW) + 0.5))
    local sh = math.max(2, math.floor((def.h * groupH) + 0.5))
    seg:ClearAllPoints()
    seg:SetPoint("TOPLEFT", self._group, "TOPLEFT", sx, -sy)
    seg:SetSize(sw, sh)
    if showDebug then
      seg:Show()
      setSectorDebugVisual(seg, true)
    else
      seg:Hide()
      setSectorDebugVisual(seg, false)
    end
  end

  local l3 = getLayoutById("L3")
  local l4 = getLayoutById("L4")
  if not l3 or not l4 then
    return
  end
  local l3x = math.floor((l3.x * groupW) + 0.5)
  local l3y = math.floor((l3.y * groupH) + 0.5)
  local l3w = math.max(2, math.floor((l3.w * groupW) + 0.5))
  local l3Bottom = math.floor(((l3.y + l3.h) * groupH) + 0.5)
  local l4Bottom = math.floor(((l4.y + l4.h) * groupH) + 0.5)
  local l3h = math.max(2, l4Bottom - l3y)
  self._feedGeneral.holder:ClearAllPoints()
  self._feedGeneral.holder:SetPoint("TOPLEFT", self._group, "TOPLEFT", l3x + 2, -(l3y + 2))
  self._feedGeneral.holder:SetSize(math.max(2, l3w - 4), math.max(2, l3h - 4))
  self._feedGeneral.holder:SetShown(false)
  local inputH = math.max(18, math.min(40, math.floor((tonumber(d.leftPanelGeneralInputHeight) or 24) + 0.5)))
  d.leftPanelGeneralInputHeight = inputH
  local inputPadX = math.max(0, math.min(24, math.floor((tonumber(d.leftPanelGeneralInputHorizontalPad) or 4) + 0.5)))
  d.leftPanelGeneralInputHorizontalPad = inputPadX
  self:EnsureGeneralInputBox()
  if self._generalInput then
    self._generalInput:SetParent(self._group)
    self._generalInput:ClearAllPoints()
    local freeTop = l4Bottom + 2
    local freeBottom = l3Bottom - 2
    local freeH = freeBottom - freeTop
    if freeH >= 8 then
      local h = math.max(8, math.min(inputH, freeH))
      local inputY = freeTop + math.floor((freeH - h) / 2)
      self._generalInput:SetPoint("TOPLEFT", self._group, "TOPLEFT", l3x + inputPadX, -inputY)
      self._generalInput:SetPoint("TOPRIGHT", self._group, "TOPLEFT", l3x + l3w - inputPadX, -inputY)
      self._generalInput:SetHeight(h)
    else
      -- Fallback seguro si no hay banda inferior libre suficiente.
      self._generalInput:SetPoint("BOTTOMLEFT", self._feedGeneral.holder, "BOTTOMLEFT", inputPadX, 4)
      self._generalInput:SetPoint("BOTTOMRIGHT", self._feedGeneral.holder, "BOTTOMRIGHT", -inputPadX, 4)
      self._generalInput:SetHeight(inputH)
    end
    self._generalInput:SetShown(showPanel)
  end
  self._feedGeneral.msg:Hide()
  if showPanel then
    self:ApplyGeneralInputStyle()
  end
end

function LP:Initialize()
  self:Refresh()
end

