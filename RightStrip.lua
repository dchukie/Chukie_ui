--[[ Franja derecha del panel (slot PanelCore `right` bajo `rightPanel`).
     Solo grilla fija inferior 2x2: moneda + bolsas (clic = ToggleAllBags). ]]

local _, ns = ...

local RS = {}
ns.RightStrip = RS

local PANEL_ID = "rightPanel"
local SLOT_ID = "right"

local ICON_GOLD_PATH = "Interface\\MoneyFrame\\UI-GoldIcon"
local ICON_SILVER_PATH = "Interface\\MoneyFrame\\UI-SilverIcon"
local ICON_COPPER_PATH = "Interface\\MoneyFrame\\UI-CopperIcon"
local ICON_BAG_PATH = "Interface\\Icons\\INV_Misc_Bag_08"
local BLIZZARD_BAG_BAR_FRAMES = {
  "MainMenuBarBackpackButton",
  "CharacterBag0Slot",
  "CharacterBag1Slot",
  "CharacterBag2Slot",
  "CharacterBag3Slot",
  "CharacterReagentBag0Slot",
  "BagBarExpandToggle",
}
local FONT_FACES = {
  [0] = STANDARD_TEXT_FONT,
  [1] = "Fonts\\FRIZQT__.TTF",
  [2] = "Fonts\\ARIALN.TTF",
  [3] = "Fonts\\MORPHEUS.TTF",
  [4] = "Fonts\\SKURRI.TTF",
}

local function db()
  if ns.Profile and ns.Profile.GetRightPanelModel then
    return ns.Profile:GetRightPanelModel()
  end
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  p.minimapPosition = p.minimapPosition or {}
  return p.minimapPosition
end

local function compactNumber(n)
  n = tonumber(n) or 0
  if n >= 1000000 then
    local v = math.floor((n / 1000000) * 10 + 0.5) / 10
    if math.abs(v - math.floor(v)) < 0.001 then
      return string.format("%dm", math.floor(v))
    end
    return string.format("%.1fm", v)
  end
  if n >= 1000 then
    local v = math.floor((n / 1000) * 10 + 0.5) / 10
    if math.abs(v - math.floor(v)) < 0.001 then
      return string.format("%dk", math.floor(v))
    end
    return string.format("%.1fk", v)
  end
  return tostring(math.floor(n))
end

local function formatMoneyShort(copper)
  copper = math.max(0, math.floor(tonumber(copper) or 0))
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local bron = copper % 100
  if gold >= 1000 then
    return compactNumber(gold), ICON_GOLD_PATH
  end
  if gold > 0 then
    return tostring(gold), ICON_GOLD_PATH
  end
  if silver > 0 then
    return tostring(silver), ICON_SILVER_PATH
  end
  return tostring(bron), ICON_COPPER_PATH
end

local function getCarriedBagUsedTotal()
  local total, used = 0, 0
  local GetNum = C_Container and C_Container.GetContainerNumSlots
  local GetInfo = C_Container and C_Container.GetContainerItemInfo
  if not GetNum or not GetInfo then
    return used, total
  end
  local last = _G.NUM_BAG_FRAMES or 4
  if type(Enum) == "table" and Enum.BagIndex and Enum.BagIndex.ReagentBag ~= nil then
    local rb = tonumber(Enum.BagIndex.ReagentBag)
    if rb and rb > last then
      last = rb
    end
  end
  for bag = _G.BACKPACK_CONTAINER or 0, last do
    local n = GetNum(bag)
    if type(n) == "number" and n > 0 then
      total = total + n
      for slot = 1, n do
        local info = GetInfo(bag, slot)
        if info and info.itemID then
          used = used + 1
        end
      end
    end
  end
  return used, total
end

local function setupValueFS(fs)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("MIDDLE")
  fs:SetTextColor(0.95, 0.93, 0.75, 1)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.9)
end

local function layoutTwoByTwo(section, rowH, iconSize, gapY)
  section.grid:SetHeight((rowH * 2) + gapY)

  section.icon1:SetSize(iconSize, iconSize)
  section.icon1:ClearAllPoints()
  section.icon1:SetPoint("TOPLEFT", section.grid, "TOPLEFT", 0, 0)

  section.val1:ClearAllPoints()
  section.val1:SetPoint("LEFT", section.icon1, "RIGHT", 4, 0)
  section.val1:SetPoint("RIGHT", section.grid, "RIGHT", 0, 0)
  section.val1:SetPoint("TOP", section.grid, "TOP", 0, 0)
  section.val1:SetHeight(rowH)

  section.icon2:SetSize(iconSize, iconSize)
  section.icon2:ClearAllPoints()
  section.icon2:SetPoint("TOPLEFT", section.grid, "TOPLEFT", 0, -rowH - gapY)

  section.val2:ClearAllPoints()
  section.val2:SetPoint("LEFT", section.icon2, "RIGHT", 4, 0)
  section.val2:SetPoint("RIGHT", section.grid, "RIGHT", 0, 0)
  section.val2:SetPoint("TOP", section.val1, "BOTTOM", 0, -gapY)
  section.val2:SetHeight(rowH)
end

local function hideFrameHard(frame)
  if not frame then
    return
  end
  if frame.Hide then
    frame:Hide()
  end
  if frame.SetAlpha then
    frame:SetAlpha(0)
  end
  if frame.EnableMouse then
    frame:EnableMouse(false)
  end
end

function RS:EnsureBlizzardBagHideHook(frame)
  if not frame or frame._chukieBagHideHook then
    return
  end
  frame._chukieBagHideHook = true
  if frame.HookScript then
    frame:HookScript("OnShow", function(self)
      if InCombatLockdown() then
        RS._bagBarHidePending = true
        return
      end
      hideFrameHard(self)
    end)
  end
  hooksecurefunc(frame, "SetShown", function(self, shown)
    if not shown then
      return
    end
    if InCombatLockdown() then
      RS._bagBarHidePending = true
      return
    end
    hideFrameHard(self)
  end)
end

function RS:HideBlizzardBagBar()
  if InCombatLockdown() then
    self._bagBarHidePending = true
    return
  end
  self._bagBarHidePending = nil
  for i = 1, #BLIZZARD_BAG_BAR_FRAMES do
    local frame = _G[BLIZZARD_BAG_BAR_FRAMES[i]]
    if frame and type(frame) == "table" and frame.GetObjectType then
      self:EnsureBlizzardBagHideHook(frame)
      hideFrameHard(frame)
    end
  end
end

function RS:RefreshText()
  if not (self._bottom and self._bottom.val1) then
    return
  end
  local money = GetMoney and GetMoney() or 0
  local moneyTxt, moneyIcon = formatMoneyShort(money)
  local used, total = getCarriedBagUsedTotal()
  local free = math.max(0, (tonumber(total) or 0) - (tonumber(used) or 0))
  local bagTxt = (total > 0) and (tostring(free) .. "/" .. tostring(total)) or "-"

  self._bottom.val1:SetText(moneyTxt)
  self._bottom.icon1:SetTexture(moneyIcon)
  self._bottom.val2:SetText(bagTxt)
  self._bottom.icon2:SetTexture(ICON_BAG_PATH)
end

function RS:Ensure()
  local pc = ns.PanelCore
  if not pc or not pc.GetSlotFrame then
    return
  end
  local slot = pc:GetSlotFrame(PANEL_ID, SLOT_ID)
  if not slot then
    return
  end

  if self._host and self._host:GetParent() ~= slot then
    self._host:SetParent(slot)
  end
  if self._host then
    return
  end

  local host = CreateFrame("Frame", "ChukieUi_RightStripHost", slot)
  host:SetFrameStrata("MEDIUM")
  host:SetFixedFrameStrata(true)
  host:SetFrameLevel(8)
  host:EnableMouse(false)
  self._host = host

  local bottomBtn = CreateFrame("Button", nil, host)
  bottomBtn:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 2, 2)
  bottomBtn:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 2)
  bottomBtn:RegisterForClicks("LeftButtonUp")
  bottomBtn:SetScript("OnClick", function()
    if ToggleAllBags then
      ToggleAllBags()
    end
  end)
  bottomBtn:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText("Abrir/Cerrar bolsas")
      GameTooltip:Show()
    end
  end)
  bottomBtn:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  if bottomBtn.SetNormalTexture then
    bottomBtn:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    local nt = bottomBtn.GetNormalTexture and bottomBtn:GetNormalTexture()
    if nt and nt.SetAlpha then
      nt:SetAlpha(0)
    end
  end
  if bottomBtn.SetHighlightTexture then
    bottomBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local ht = bottomBtn.GetHighlightTexture and bottomBtn:GetHighlightTexture()
    if ht and ht.SetBlendMode then
      ht:SetBlendMode("ADD")
    end
  end

  local bGrid = CreateFrame("Frame", nil, bottomBtn)
  bGrid:SetPoint("BOTTOMLEFT", bottomBtn, "BOTTOMLEFT", 2, 2)
  bGrid:SetPoint("BOTTOMRIGHT", bottomBtn, "BOTTOMRIGHT", -2, 2)
  bGrid:SetFrameStrata("MEDIUM")
  bGrid:SetFrameLevel((bottomBtn:GetFrameLevel() or 8) + 20)

  local bottom = {
    frame = bottomBtn,
    grid = bGrid,
    icon1 = bGrid:CreateTexture(nil, "ARTWORK"),
    val1 = bGrid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
    icon2 = bGrid:CreateTexture(nil, "ARTWORK"),
    val2 = bGrid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
  }
  setupValueFS(bottom.val1)
  setupValueFS(bottom.val2)
  self._bottom = bottom

  -- Icono proxy para Masque: permite borde/backdrop sin tocar los iconos reales de la grilla.
  local msqIcon = bottomBtn:CreateTexture(nil, "ARTWORK")
  msqIcon:SetAllPoints(bottomBtn)
  msqIcon:SetTexture("Interface\\Buttons\\WHITE8X8")
  msqIcon:SetAlpha(0)
  bottomBtn._msqIcon = msqIcon

  local ef = CreateFrame("Frame", nil, host)
  ef:SetFrameStrata("MEDIUM")
  ef:SetFrameLevel(9)
  ef:RegisterEvent("PLAYER_MONEY")
  ef:RegisterEvent("PLAYER_ENTERING_WORLD")
  ef:RegisterEvent("BAG_UPDATE")
  ef:RegisterEvent("BAG_UPDATE_DELAYED")
  ef:RegisterEvent("PLAYER_REGEN_ENABLED")
  ef:SetScript("OnEvent", function(_, event)
    RS:RefreshText()
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
      RS:HideBlizzardBagBar()
    end
  end)
  self._event = ef
end

function RS:GetMasqueGroup()
  local d = db()
  if d.rightStripUseMasque ~= true then
    return nil
  end
  local stub = _G.LibStub
  if not stub then
    return nil
  end
  local msq = stub("Masque", true)
  if not msq or type(msq.Group) ~= "function" then
    return nil
  end
  if not self._masqueGroup then
    self._masqueGroup = msq:Group("Chukie UI", "RightStrip")
  end
  return self._masqueGroup
end

function RS:ApplyMasque()
  if not self._bottom or not self._bottom.frame then
    return
  end
  local btn = self._bottom.frame
  local grp = self:GetMasqueGroup()
  if not grp then
    if self._masqueGroup and self._masqueGroup.RemoveButton then
      pcall(function()
        self._masqueGroup:RemoveButton(btn)
      end)
    end
    return
  end
  if grp.RemoveButton then
    pcall(function()
      grp:RemoveButton(btn)
    end)
  end
  if grp.AddButton then
    grp:AddButton(btn, {
      Icon = btn._msqIcon or false,
      Normal = false,
      Disabled = false,
      Pushed = false,
      Flash = false,
      Checked = false,
      Border = false,
      IconBorder = false,
      DebuffBorder = false,
      EnchantBorder = false,
      Highlight = false,
    }, "Legacy")
  end
  if grp.ReSkin then
    grp:ReSkin()
  end
end

function RS:Layout()
  self:Ensure()
  if not (self._host and self._bottom) then
    return
  end

  local slot = self._host:GetParent()
  if not slot then
    return
  end

  self._host:ClearAllPoints()
  self._host:SetAllPoints(slot)

  local w = math.floor(math.max(0, (slot:GetWidth() or 0)) + 0.5)
  local h = math.floor(math.max(0, (slot:GetHeight() or 0)) + 0.5)
  local baseH = math.min(w, h)
  local botH = math.max(32, math.floor((baseH * 0.5) + 0.5))
  botH = math.min(botH, h)

  local d = db()
  local scalePct = tonumber(d.rightStripGridScalePercent) or 100
  scalePct = math.max(60, math.min(180, math.floor(scalePct + 0.5)))
  d.rightStripGridScalePercent = scalePct
  local scale = scalePct / 100

  local autoFont = math.max(9, math.min(13, math.floor((w / 10) + 0.5)))
  local manual = tonumber(d.rightStripFontSize) or 0
  local textPx = (manual > 0) and math.max(8, math.min(32, math.floor(manual + 0.5))) or autoFont
  local iconSize = math.max(8, math.min(36, math.floor(((textPx + 1) * scale) + 0.5)))
  local gapY = 1
  local rowH = iconSize + math.max(2, math.floor((2 * scale) + 0.5))
  local gridH = (rowH * 2) + gapY
  local maxGridH = math.max(20, botH - 4)
  if gridH > maxGridH then
    rowH = math.max(9, math.floor((maxGridH - gapY) / 2))
    gridH = (rowH * 2) + gapY
  end

  self._bottom.frame:SetHeight(botH)
  layoutTwoByTwo(self._bottom, rowH, iconSize, gapY)

  local fontPath = FONT_FACES[tonumber(d.rightStripFontFace) or 0] or STANDARD_TEXT_FONT
  local ok1 = self._bottom.val1:SetFont(fontPath, textPx, "")
  if not ok1 then
    self._bottom.val1:SetFont("Fonts\\FRIZQT__.TTF", textPx, "")
  end
  local ok2 = self._bottom.val2:SetFont(fontPath, textPx, "")
  if not ok2 then
    self._bottom.val2:SetFont("Fonts\\FRIZQT__.TTF", textPx, "")
  end

  self:ApplyMasque()
  self:HideBlizzardBagBar()
  self:RefreshText()
end

function RS:Refresh()
  self:Layout()
end
