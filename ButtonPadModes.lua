--[[ Formatos de la botonera principal (barras 1–4).

     Los 24 botones y sus ranuras no cambian al pasar de modo: barra N botón i
     sigue siendo el slot (N−1)×12+i. En pantalla solo se ven los botones.

     Nostromo: 4 filas de 6. Teclas 12345 / QWERT / ASDFG / ZXCV.

     Keyzen: los mismos botones, centrados, con la forma del keypad. El perfil
     del aparato se queda en JOY (JOY #10 dispara el botón 1 de la barra 1);
     la tecla de Nostromo sigue atada por si el perfil manda teclado.
     La fila 10 11 12 13 5 es la barra 1 (botones 1–5): ahí caen la
     misión, el vehículo y el vuelo de la barra 1. El resto sigue el teclado
     que ya tenía Nostromo (9=R, 4=F, 18=C, y el resto en la misma posición).

     Quedan afuera el stick, la cruceta y JOY #20, #21 y #22. ]]

local _, ns = ...

--- col/fila de la grilla del keypad. `key` vacío = el botón existe, sin atajo de Nostromo.
local KEYZEN_CELLS = {
  --- Barra 1, botones 1–5: la fila que cambia con misión, vehículo y vuelo.
  { bar = 1, index = 1, col = 1, row = 1, joy = 10, key = "1" },
  { bar = 1, index = 2, col = 2, row = 1, joy = 11, key = "2" },
  { bar = 1, index = 3, col = 3, row = 1, joy = 12, key = "3" },
  { bar = 1, index = 4, col = 4, row = 1, joy = 13, key = "4" },
  { bar = 1, index = 5, col = 5, row = 1, joy = 5, key = "5" },
  { bar = 1, index = 6, col = 2, row = 0, joy = 15 },
  --- Barra 2: Q W E R T. El 9 es R.
  { bar = 2, index = 1, col = 1, row = 2, joy = 6, key = "Q" },
  { bar = 2, index = 2, col = 2, row = 2, joy = 7, key = "W" },
  { bar = 2, index = 3, col = 3, row = 2, joy = 8, key = "E" },
  { bar = 2, index = 4, col = 4, row = 2, joy = 9, key = "R" },
  { bar = 2, index = 5, col = 5, row = 2, joy = 26, key = "T" },
  { bar = 2, index = 6, col = 3, row = 0, joy = 16 },
  --- Barra 3: A S D F G. El 4 es F.
  { bar = 3, index = 1, col = 1, row = 3, joy = 1, key = "A" },
  { bar = 3, index = 2, col = 2, row = 3, joy = 2, key = "S" },
  { bar = 3, index = 3, col = 3, row = 3, joy = 3, key = "D" },
  { bar = 3, index = 4, col = 4, row = 3, joy = 4, key = "F" },
  { bar = 3, index = 5, col = 5, row = 3, joy = 27, key = "G" },
  { bar = 3, index = 6, col = 4, row = 0, joy = 17 },
  --- Barra 4: Z X C V. El 18 es C.
  { bar = 4, index = 1, col = 1, row = 4, joy = 24, key = "Z" },
  { bar = 4, index = 2, col = 2, row = 4, joy = 25, key = "X" },
  { bar = 4, index = 3, col = 3, row = 4, joy = 18, key = "C" },
  { bar = 4, index = 4, col = 4, row = 4, joy = 19, key = "V" },
  { bar = 4, index = 5, col = 0, row = 2, joy = 14 },
  { bar = 4, index = 6, col = 0, row = 3, joy = 23 },
}

--- Nombres que WoW sí acepta en un binding. JOY #N no es uno de ellos: hay que traducirlo.
local PAD_NAMES = {
  "PAD1",
  "PAD2",
  "PAD3",
  "PAD4",
  "PAD5",
  "PAD6",
  "PADLSTICK",
  "PADRSTICK",
  "PADDUP",
  "PADDDOWN",
  "PADDLEFT",
  "PADDRIGHT",
  "PADPADDLE1",
  "PADPADDLE2",
  "PADPADDLE3",
  "PADPADDLE4",
  "PADFORWARD",
  "PADBACK",
  "PADSYSTEM",
  "PADSOCIAL",
  "PADLSHOULDER",
  "PADRSHOULDER",
  "PADLTRIGGER",
  "PADRTRIGGER",
}

local function keysFromCells(cells)
  local joys = {}
  for i = 1, #cells do
    joys[#joys + 1] = cells[i].joy
  end
  table.sort(joys)
  local padByJoy = {}
  for i = 1, #joys do
    padByJoy[joys[i]] = PAD_NAMES[i]
  end
  local keys = { {}, {}, {}, {} }
  for i = 1, #cells do
    local cell = cells[i]
    cell.pad = padByJoy[cell.joy]
    cell.label = cell.key
    if cell.key then
      keys[cell.bar][cell.index] = cell.key
    end
  end
  return keys, padByJoy
end

local MODES = {
  {
    id = "nostromo",
    label = "Modo Nostromo",
    flow = "row",
    bars = 4,
    buttonsPerBar = 6,
    columns = 6,
    keys = {
      [1] = { "1", "2", "3", "4", "5" },
      [2] = { "Q", "W", "E", "R", "T" },
      [3] = { "A", "S", "D", "F", "G" },
      [4] = { "Z", "X", "C", "V" },
    },
  },
  {
    id = "keyzen",
    label = "Modo Keyzen",
    --- Distinto del id para reaplicar: antes solo estaban las teclas, y JOY #N no llegaba.
    bindToken = "keyzen-joy",
    flow = "placed",
    bars = 4,
    buttonsPerBar = 6,
    columns = 6,
    rows = 5,
    cells = KEYZEN_CELLS,
    keys = select(1, keysFromCells(KEYZEN_CELLS)),
    padByJoy = select(2, keysFromCells(KEYZEN_CELLS)),
  },
}

local byId = {}
for i = 1, #MODES do
  byId[MODES[i].id] = MODES[i]
end

local Pad = {}
ns.ButtonPad = Pad
Pad.Modes = MODES
Pad.DefaultId = "nostromo"

function Pad.Get(id)
  if type(id) == "string" and byId[id] then
    return byId[id]
  end
  return byId[Pad.DefaultId]
end

function Pad.Current()
  local p = ns.Profile and ns.Profile.GetActive and ns.Profile:GetActive()
  local bars = p and p.actionBars
  return Pad.Get(bars and bars.buttonPadMode)
end

function Pad.Cell(mode, barId, index)
  local cells = mode and mode.cells
  if not cells then
    return nil
  end
  for i = 1, #cells do
    local cell = cells[i]
    if cell.bar == barId and cell.index == index then
      return cell
    end
  end
  return nil
end
