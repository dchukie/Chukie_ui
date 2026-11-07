--[[ Botones libres para las opciones fijas que Forever no tiene.
     No reimplementan esa opción: aceptan una acción, un hechizo o un ítem.
     De arriba a abajo: teletransporte (catálogo de retail), acción extra,
     habilidad de zona (no está C_ZoneAbility) y objeto de misión rastreada
     (no está C_QuestLog.IsQuestTracked).

     Cada botón usa una ranura de la página que las barras no numeran
     (133–136). Ahí el cliente guarda lo que se suelta, y sobrevive al /reload. ]]

local _, ns = ...

local DS = {}
ns.DragSlots = DS

local SLOTS = {
  { id = "teleport", was = "teletransporte", action = 133 },
  { id = "extra", was = "acción extra", action = 134 },
  { id = "zone", was = "habilidad de zona", action = 135 },
  { id = "questitem", was = "objeto de misión", action = 136 },
}

local function isSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

local function inCombat()
  return InCombatLockdown and InCombatLockdown()
end

local function slotBusy(slot)
  if C_ActionBar and C_ActionBar.HasAction then
    local ok, has = pcall(C_ActionBar.HasAction, slot)
    if ok and not isSecret(has) then
      return has and true or false
    end
  end
  if HasAction then
    local ok, has = pcall(HasAction, slot)
    if ok and not isSecret(has) then
      return has and true or false
    end
  end
  return false
end

local function slotTexture(slot)
  if C_ActionBar and C_ActionBar.GetActionTexture then
    local ok, tex = pcall(C_ActionBar.GetActionTexture, slot)
    if ok and tex and not isSecret(tex) then
      return tex
    end
  end
  if GetActionTexture then
    local ok, tex = pcall(GetActionTexture, slot)
    if ok and tex and not isSecret(tex) then
      return tex
    end
  end
  return nil
end

local function refresh(btn)
  local tex = slotBusy(btn._actionSlot) and slotTexture(btn._actionSlot) or nil
  if tex then
    btn.icon:SetTexture(tex)
    btn.icon:Show()
  else
    btn.icon:SetTexture(nil)
    btn.icon:Hide()
  end
end

local function cursorBusy()
  if not GetCursorInfo then
    return false
  end
  local kind = GetCursorInfo()
  return kind ~= nil and not isSecret(kind)
end

local function combatNotice()
  print("|cffff9900Chukie UI|r: en combate; se aplica al salir.")
end

local function receive(btn)
  if not cursorBusy() or not PlaceAction then
    return
  end
  if inCombat() then
    combatNotice()
    return
  end
  pcall(PlaceAction, btn._actionSlot)
  refresh(btn)
end

local function showTip(btn)
  if not GameTooltip then
    return
  end
  GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
  if slotBusy(btn._actionSlot) and GameTooltip.SetAction then
    pcall(GameTooltip.SetAction, GameTooltip, btn._actionSlot)
  else
    GameTooltip:SetText("Botón libre")
  end
  GameTooltip:AddLine("Antes: " .. (btn._was or "opción fija") .. ". Ya no existe en Forever.", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine("Arrastrá una acción, un hechizo o un ítem.", 1, 1, 1, true)
  GameTooltip:AddLine("Clic derecho: vaciar.", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

function DS:Ensure(parent)
  if self._buttons then
    return
  end
  self._buttons = {}
  for i = 1, #SLOTS do
    local spec = SLOTS[i]
    local btn = CreateFrame("Button", "ChukieUi_Free" .. i, parent, "SecureActionButtonTemplate")
    btn._dragId = spec.id
    btn._was = spec.was
    btn._actionSlot = spec.action
    btn:SetAttribute("type", "action")
    btn:SetAttribute("action", spec.action)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:RegisterForDrag("LeftButton")
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(60)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:Hide()
    btn.icon = icon
    btn:SetScript("OnReceiveDrag", receive)
    btn:SetScript("PreClick", function(button, mouseButton, down)
      if down then
        return
      end
      if mouseButton == "RightButton" and not cursorBusy() then
        if inCombat() then
          combatNotice()
        elseif PickupAction and ClearCursor then
          pcall(PickupAction, button._actionSlot)
          ClearCursor()
          refresh(button)
        end
        button:SetAttribute("type", nil)
        button._restoreType = true
        return
      end
      if not cursorBusy() then
        return
      end
      receive(button)
      button:SetAttribute("type", nil)
      button._restoreType = true
    end)
    btn:SetScript("PostClick", function(button)
      if not button._restoreType or inCombat() then
        return
      end
      button._restoreType = nil
      button:SetAttribute("type", "action")
      button:SetAttribute("action", button._actionSlot)
    end)
    btn:SetScript("OnDragStart", function(button)
      if inCombat() then
        combatNotice()
        return
      end
      if not slotBusy(button._actionSlot) or not PickupAction then
        return
      end
      pcall(PickupAction, button._actionSlot)
      refresh(button)
    end)
    btn:SetScript("OnEnter", showTip)
    btn:SetScript("OnLeave", function(button)
      if GameTooltip and GameTooltip:IsOwned(button) then
        GameTooltip:Hide()
      end
    end)
    refresh(btn)
    self._buttons[i] = btn
  end
end

--- Columna de botones del panel derecho: el slot izquierdo del árbol (al lado del mapa).
local function buttonColumn()
  local rp = ns.RightPanel
  local slot = rp and rp._panelTreeLeft
  if not slot and ns.PanelCore and ns.PanelCore.GetSlotFrame then
    slot = ns.PanelCore:GetSlotFrame("rightPanel", "left")
  end
  if not slot or not slot.GetWidth then
    return nil
  end
  local w, h = slot:GetWidth(), slot:GetHeight()
  if (w or 0) < 16 or (h or 0) < 16 then
    return nil
  end
  return slot
end

function DS:Layout(block, size, gap)
  if inCombat() then
    if ns.RightPanel and ns.RightPanel.RequestApplyAfterCombat then
      ns.RightPanel:RequestApplyAfterCombat()
    end
    return
  end
  local column = buttonColumn()
  local parent = column or block
  if not parent then
    return
  end
  self:Ensure(column and UIParent or parent)
  size = math.max(18, tonumber(size) or 36)
  gap = math.max(0, tonumber(gap) or 2)
  local pad = 2
  if column then
    local roomW = math.max(18, (column:GetWidth() or size) - pad * 2)
    local roomH = (column:GetHeight() or size) - pad * 2 - gap * (#self._buttons - 1)
    local fitted = math.floor(math.min(roomW, roomH / #self._buttons) + 0.5)
    size = math.max(18, math.min(size, fitted))
  end
  local x = (not column) and (block:GetWidth() + gap) or 0
  for i = 1, #self._buttons do
    local btn = self._buttons[i]
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(80)
    if column then
      if btn:GetParent() ~= UIParent then
        btn:SetParent(UIParent)
      end
      btn:SetSize(size, size)
      btn:ClearAllPoints()
      btn:SetPoint("TOP", column, "TOP", 0, -(pad + (i - 1) * (size + gap)))
    else
      if btn:GetParent() ~= block then
        btn:SetParent(block)
      end
      btn:SetSize(size, size)
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", block, "TOPLEFT", x, -((i - 1) * (size + gap)))
    end
    btn:Show()
    refresh(btn)
  end
end
