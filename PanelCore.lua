--[[ Core multipanel (base).
     Regla: un solo root técnico del addon; paneles y slots siempre hijos de ese root.
     El layout interno del addon no depende de anclas externas volátiles. ]]

local ADDON_NAME, ns = ...

local PC = {}
ns.PanelCore = PC

local ROOT_FRAME_NAME = "ChukieUi_Root"

local function sameNum(a, b)
  return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < 0.0001
end

local function setBottomRightRectIfChanged(frame, parent, w, h, x, y)
  frame._pcRect = frame._pcRect or {}
  local r = frame._pcRect
  if r.mode == "br"
    and r.parent == parent
    and sameNum(r.w, w)
    and sameNum(r.h, h)
    and sameNum(r.x, x)
    and sameNum(r.y, y)
  then
    return
  end
  frame:SetSize(w, h)
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", x, y)
  r.mode, r.parent, r.w, r.h, r.x, r.y = "br", parent, w, h, x, y
end

local function setInsetRectIfChanged(frame, parent, l, t, rgt, b)
  frame._pcRect = frame._pcRect or {}
  local r = frame._pcRect
  if r.mode == "inset"
    and r.parent == parent
    and sameNum(r.l, l)
    and sameNum(r.t, t)
    and sameNum(r.r, rgt)
    and sameNum(r.b, b)
  then
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", l, t)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", rgt, b)
  r.mode, r.parent, r.l, r.t, r.r, r.b = "inset", parent, l, t, rgt, b
end

local function setAttachRectIfChanged(frame, opts, rel)
  frame._pcRect = frame._pcRect or {}
  local r = frame._pcRect
  local mode = "attach"
  local p = opts.point or "TOPLEFT"
  local rp = opts.relativePoint or "TOPLEFT"
  local x = tonumber(opts.x) or 0
  local y = tonumber(opts.y) or 0
  local w = opts.width and math.max(1, tonumber(opts.width) or 1) or nil
  local h = opts.height and math.max(1, tonumber(opts.height) or 1) or nil
  if r.mode == mode
    and r.parent == rel
    and r.p == p
    and r.rp == rp
    and sameNum(r.x, x)
    and sameNum(r.y, y)
    and ((w == nil and r.w == nil) or sameNum(r.w or 0, w or 0))
    and ((h == nil and r.h == nil) or sameNum(r.h or 0, h or 0))
  then
    return
  end
  frame:ClearAllPoints()
  if w and h then
    frame:SetSize(w, h)
  end
  frame:SetPoint(p, rel, rp, x, y)
  r.mode, r.parent, r.p, r.rp, r.x, r.y, r.w, r.h = mode, rel, p, rp, x, y, w, h
end

function PC:EnsureRoot()
  local f = self._rootFrame
  if f then
    return f
  end
  if not UIParent then
    return nil
  end
  f = CreateFrame("Frame", ROOT_FRAME_NAME, UIParent)
  f:EnableMouse(false)
  f:SetFrameStrata("BACKGROUND")
  f:SetFixedFrameStrata(true)
  f:SetFrameLevel(0)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
  self._rootFrame = f
  self._panels = self._panels or {}
  return f
end

function PC:RefreshRootBounds()
  local root = self:EnsureRoot()
  if not root or not UIParent then
    return
  end
  root:ClearAllPoints()
  root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  root:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
end

function PC:EnsurePanel(panelId)
  if not panelId or panelId == "" then
    return nil
  end
  local root = self:EnsureRoot()
  if not root then
    return nil
  end
  self._panels = self._panels or {}
  local rec = self._panels[panelId]
  if rec and rec.frame then
    return rec.frame
  end
  local frame = CreateFrame("Frame", "ChukieUi_Panel_" .. panelId, root)
  frame:EnableMouse(false)
  frame:SetFrameStrata("BACKGROUND")
  frame:SetFixedFrameStrata(true)
  frame:SetFrameLevel(0)
  frame:SetSize(1, 1)
  frame:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
  rec = rec or {}
  rec.frame = frame
  rec.slots = rec.slots or {}
  self._panels[panelId] = rec
  return frame
end

function PC:SetPanelBottomRight(panelId, width, height, offsetX, offsetY)
  local panel = self:EnsurePanel(panelId)
  if not panel then
    return nil
  end
  local w = math.max(1, tonumber(width) or 1)
  local h = math.max(1, tonumber(height) or 1)
  setBottomRightRectIfChanged(panel, self:EnsureRoot(), w, h, tonumber(offsetX) or 0, tonumber(offsetY) or 0)
  return panel
end

function PC:EnsureSlot(panelId, slotId)
  if not slotId or slotId == "" then
    return nil
  end
  local panel = self:EnsurePanel(panelId)
  if not panel then
    return nil
  end
  local rec = self._panels and self._panels[panelId]
  if not rec then
    return nil
  end
  rec.slots = rec.slots or {}
  local f = rec.slots[slotId]
  if f then
    return f
  end
  f = CreateFrame("Frame", "ChukieUi_Slot_" .. panelId .. "_" .. slotId, panel)
  f:EnableMouse(false)
  f:SetFrameStrata("BACKGROUND")
  f:SetFixedFrameStrata(true)
  f:SetFrameLevel(0)
  rec.slots[slotId] = f
  return f
end

function PC:LayoutSlotByInsets(panelId, slotId, left, top, right, bottom)
  local f = self:EnsureSlot(panelId, slotId)
  if not f then
    return nil
  end
  local panel = self:EnsurePanel(panelId)
  if not panel then
    return nil
  end
  setInsetRectIfChanged(f, panel, tonumber(left) or 0, tonumber(top) or 0, tonumber(right) or 0, tonumber(bottom) or 0)
  return f
end

function PC:LayoutSlotByAttach(panelId, slotId, opts)
  local f = self:EnsureSlot(panelId, slotId)
  if not f then
    return nil
  end
  opts = opts or {}
  local rel = opts.relativeTo or self:EnsurePanel(panelId)
  if not rel then
    return f
  end
  setAttachRectIfChanged(f, opts, rel)
  return f
end

function PC:GetPanelFrame(panelId)
  return self._panels and self._panels[panelId] and self._panels[panelId].frame or nil
end

function PC:GetSlotFrame(panelId, slotId)
  local rec = self._panels and self._panels[panelId]
  return rec and rec.slots and rec.slots[slotId] or nil
end

