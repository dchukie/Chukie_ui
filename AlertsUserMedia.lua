--[[ Media extra del usuario para alertas.
     1) Poné archivos .tga / .blp en Media\Alerts\User\
     2) Listá el nombre del archivo abajo (WoW no puede escanear carpetas).
     3) /reload

     Formato recomendado: TGA con alpha, tamaño potencia de 2 (64/128/256/512). ]]

local _, ns = ...

ns.AlertsUserMedia = ns.AlertsUserMedia or {}

--- Solo el nombre de archivo (relativo a Media\Alerts\User\).
ns.AlertsUserMedia.textures = {
  -- "mi_aura.tga",
  -- "mi_anillo.blp",
}

ns.AlertsUserMedia.fonts = {
  -- "MiFuente.ttf",
}

ns.AlertsUserMedia.sounds = {
  -- "mi_alerta.ogg",
}
