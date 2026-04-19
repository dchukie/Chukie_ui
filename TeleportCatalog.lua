--[[ Catálogo curado de teletransportes (reserved1). Inspirado en TeleportMenu;
     solo aparecen en la grilla las entradas válidas para el personaje (ítem en bolsa,
     juguete aprendido, hechizo conocido). dedupeKey colapsa mismo CD+destino (MVP por datos). ]]

local _, ns = ...

local list = {
  -- Piedra / hogar
  { key = "hearthstone", type = "item", id = 6948, label = "Piedra de hogar (ítem)", dedupeKey = "bind_hearth" },
  { key = "astral_recall", type = "spell", id = 556, label = "Recuerdo astral (chamán)" },
  { key = "dalaran_hearth", type = "toy", id = 140192, label = "Piedra de hogar a Dalaran", quest = { 44184, 44663 }, dedupeKey = "dalaran_legion_hs" },
  { key = "garrison_hearth", type = "toy", id = 110560, label = "Piedra de hogar de la ciudadela", quest = { 34378, 34586 }, dedupeKey = "garrison_hs" },
  { key = "toy_timewalker_hs", type = "toy", id = 193588, label = "Piedra del caminante del tiempo", dedupeKey = "bind_hearth" },
  { key = "toy_inn_daughter", type = "toy", id = 64488, label = "La hija del tabernero", dedupeKey = "bind_hearth" },
  { key = "toy_dark_portal", type = "toy", id = 93672, label = "Portal oscuro", dedupeKey = "bind_hearth" },
  { key = "tome_town_portal", type = "toy", id = 142542, label = "Tomo de portal a ciudad", dedupeKey = "bind_hearth" },
  { key = "toy_rune_random", type = "toy", id = 168907, label = "Runa de piedra de hogar aleatoria", dedupeKey = "bind_hearth" },

  -- Clase / raza
  { key = "zen_pilgrimage", type = "spell", id = 126892, label = "Peregrinación zen (monje)" },
  { key = "death_gate", type = "spell", id = 50977, label = "Portón de la muerte (caballero)" },
  { key = "teleport_moonglade", type = "spell", id = 18960, label = "Teletransporte: Claro de la Luna (druida)" },
  { key = "dreamwalk", type = "spell", id = 193753, label = "Caminar sueños (druida)" },
  { key = "vulpera_camp", type = "spell", id = 312370, label = "Acampar (vulpera)" },
  { key = "vulpera_return", type = "spell", id = 312372, label = "Volver al campamento (vulpera)" },
  { key = "mole_machine", type = "spell", id = 265225, label = "Máquina topo (enano hierro negro)" },
  { key = "rootwalking", type = "spell", id = 1238686, label = "Raíz andante (haranir)" },

  -- Ítems / juguetes de utilidad (TeleportMenu Items.lua, subset)
  { key = "item_direbrew_remote", type = "item", id = 37863, label = "Control remoto de Cerveza Festiva" },
  { key = "item_karabor_medallion", type = "item", id = 32757, label = "Medallón bendecido de Karabor" },
  { key = "item_wrap_sw", type = "item", id = 63206, label = "Capa: Ventormenta (Alianza)" },
  { key = "item_wrap_org", type = "item", id = 63207, label = "Capa: Orgrimmar (Horda)" },
  { key = "item_shroud_sw", type = "item", id = 63352, label = "Velo: cooperación Ventormenta" },
  { key = "item_shroud_org", type = "item", id = 63353, label = "Velo: cooperación Orgrimmar" },
  { key = "item_cloak_org", type = "item", id = 65274, label = "Capa de coordinación: Orgrimmar" },
  { key = "item_cloak_sw", type = "item", id = 65360, label = "Capa de coordinación: Ventormenta" },
  { key = "item_argent_tabard", type = "item", id = 46874, label = "Tabardo del Cruzado Argento" },
  { key = "item_last_relic_argus", type = "item", id = 64457, label = "Última reliquia de Argus" },
  { key = "item_kirin_beacon_a", type = "item", id = 95567, label = "Baliza del Kirin Tor (Alianza)" },
  { key = "item_kirin_beacon_h", type = "item", id = 95568, label = "Baliza Soleaver (Horda)" },
  { key = "item_time_lost_artifact", type = "item", id = 103678, label = "Artefacto perdido en el tiempo" },
  { key = "item_admirals_compass", type = "item", id = 128353, label = "Brújula del almirante" },
  { key = "item_mobile_telemancy", type = "item", id = 140324, label = "Baliza de telemancia móvil" },
  { key = "item_ultrasafe_mechagon", type = "item", id = 167075, label = "Transportador ultrasafe: Mecagon" },
  { key = "item_cypher_relocation", type = "item", id = 180817, label = "Cifra de reubicación (Refugio de Ve'nari)" },
  { key = "item_cartel_xy_proof", type = "item", id = 189827, label = "Prueba de iniciación del cartel Xy" },
  { key = "item_ring_hourglass", type = "item", id = 193000, label = "Reloj de arena anillado" },
  { key = "item_aylaag_windstone", type = "item", id = 200613, label = "Fragmento de piedra del viento Aylaag" },
  { key = "item_dragonscale_1", type = "item", id = 205456, label = "Escama de dragón perdida (1)" },
  { key = "item_dragonscale_2", type = "item", id = 205458, label = "Escama de dragón perdida (2)" },
  { key = "item_delve_bot", type = "item", id = 230850, label = "Delve-O-Bot 7001" },
  { key = "item_mana_ethergate", type = "item", id = 243056, label = "Étergate ligado a maná (profundidad)" },
  { key = "item_shadowguard_trans", type = "item", id = 249699, label = "Translocalizador guardia umbrío" },
  { key = "item_jaina_locket", type = "item", id = 52251, label = "Medallón de Jaina" },
  { key = "item_boots_bay", type = "item", id = 50287, label = "Botas de la bahía" },
  { key = "item_potion_deepholm", type = "item", id = 58487, label = "Poción de Infralar" },
  { key = "item_baradin_tabard_h", type = "item", id = 63378, label = "Tabardo Llegada de Hellscream" },
  { key = "item_baradin_tabard_a", type = "item", id = 63379, label = "Tabardo celadores de Baradin" },
  { key = "item_violet_seal", type = "item", id = 142469, label = "Sello violeta del gran magus" },
  { key = "item_niffen_mitts", type = "item", id = 205255, label = "Mitones de excavación niffen" },
  { key = "toy_arcantina_key", type = "toy", id = 253629, label = "Llave personal de la Arcantina" },

  -- Rutas del héroe / teletransporte a mazmorras y bandas (hechizo desbloqueado en el libro)
  { key = "spell_hero_410080", type = "spell", id = 410080, label = "Pináculo del Vórtice (Ruta del héroe)" },
  { key = "spell_hero_424142", type = "spell", id = 424142, label = "Trono de las Mareas (Ruta del héroe)" },
  { key = "spell_hero_445424", type = "spell", id = 445424, label = "Grim Batol (Ruta del héroe)" },
  { key = "spell_hero_1254555", type = "spell", id = 1254555, label = "Foso de Saron (Ruta del héroe)" },
  { key = "spell_hero_131204", type = "spell", id = 131204, label = "Templo del Dragón de Jade (Ruta del héroe)" },
  { key = "spell_hero_131205", type = "spell", id = 131205, label = "Cervecería del Trueno (Ruta del héroe)" },
  { key = "spell_hero_131206", type = "spell", id = 131206, label = "Monasterio del Shadopan (Ruta del héroe)" },
  { key = "spell_hero_131222", type = "spell", id = 131222, label = "Palacio Mogu'shan (Ruta del héroe)" },
  { key = "spell_hero_131225", type = "spell", id = 131225, label = "Puerta del Sol Poniente (Ruta del héroe)" },
  { key = "spell_hero_131228", type = "spell", id = 131228, label = "Asedio del Templo Niuzao (Ruta del héroe)" },
  { key = "spell_hero_131229", type = "spell", id = 131229, label = "Monasterio Escarlata (Ruta del héroe)" },
  { key = "spell_hero_131231", type = "spell", id = 131231, label = "Salas Escarlata (Ruta del héroe)" },
  { key = "spell_hero_131232", type = "spell", id = 131232, label = "Scholomance (Ruta del héroe)" },
  { key = "spell_hero_159901", type = "spell", id = 159901, label = "Floración Eterna (Ruta del héroe)" },
  { key = "spell_hero_159899", type = "spell", id = 159899, label = "Cementerio de Sombraluna (Ruta del héroe)" },
  { key = "spell_hero_159900", type = "spell", id = 159900, label = "Depósito de Hierro Negro (Ruta del héroe)" },
  { key = "spell_hero_159896", type = "spell", id = 159896, label = "Muelles de Hierro (Ruta del héroe)" },
  { key = "spell_hero_159895", type = "spell", id = 159895, label = "Minas de Fundición Sangre (Ruta del héroe)" },
  { key = "spell_hero_159897", type = "spell", id = 159897, label = "Auchindoun (Ruta del héroe)" },
  {
    key = "spell_hero_159898",
    type = "spell",
    id = 159898,
    label = "Trecho Celestial (Ruta del héroe)",
    dedupeKey = "hero_skyreach",
  },
  { key = "spell_hero_159902", type = "spell", id = 159902, label = "Cumbre de Roca Negra Superior (Ruta del héroe)" },
  {
    key = "spell_hero_1254557",
    type = "spell",
    id = 1254557,
    label = "Trecho Celestial — variante (Ruta del héroe)",
    dedupeKey = "hero_skyreach",
  },
  { key = "spell_hero_393764", type = "spell", id = 393764, label = "Salones del Valor (Ruta del héroe)" },
  { key = "spell_hero_410078", type = "spell", id = 410078, label = "Guarida de Neltharion (Ruta del héroe)" },
  { key = "spell_hero_393766", type = "spell", id = 393766, label = "Corte de las Estrellas (Ruta del héroe)" },
  { key = "spell_hero_373262", type = "spell", id = 373262, label = "Karazhan (Ruta del héroe)" },
  { key = "spell_hero_424153", type = "spell", id = 424153, label = "Fuerte Alaocaso (Ruta del héroe)" },
  { key = "spell_hero_424163", type = "spell", id = 424163, label = "Arboleda Corazón Oscuro (Ruta del héroe)" },
  { key = "spell_hero_1254551", type = "spell", id = 1254551, label = "Trono del Triunvirato (Ruta del héroe)" },
  { key = "spell_hero_410071", type = "spell", id = 410071, label = "Mar Libre (Ruta del héroe)" },
  { key = "spell_hero_410074", type = "spell", id = 410074, label = "Catacumbas Putrefactas (Ruta del héroe)" },
  { key = "spell_hero_373274", type = "spell", id = 373274, label = "Operación: Mecagon (Ruta del héroe)" },
  { key = "spell_hero_424167", type = "spell", id = 424167, label = "Mansión Crestavía (Ruta del héroe)" },
  { key = "spell_hero_424187", type = "spell", id = 424187, label = "Atal'Dazar (Ruta del héroe)" },
  { key = "spell_hero_445418", type = "spell", id = 445418, label = "Asedio de Boralus (Ruta del héroe, Alianza)" },
  { key = "spell_hero_464256", type = "spell", id = 464256, label = "Asedio de Boralus (Ruta del héroe, Horda)" },
  { key = "spell_hero_467553", type = "spell", id = 467553, label = "¡VETA MADRE! (Ruta del héroe, Alianza)" },
  { key = "spell_hero_467555", type = "spell", id = 467555, label = "¡VETA MADRE! (Ruta del héroe, Horda)" },
  { key = "spell_hero_354462", type = "spell", id = 354462, label = "Estela Necrótica (Ruta del héroe)" },
  { key = "spell_hero_354463", type = "spell", id = 354463, label = "Bajapeste (Ruta del héroe)" },
  { key = "spell_hero_354464", type = "spell", id = 354464, label = "Nieblas de Tirna Scithe (Ruta del héroe)" },
  { key = "spell_hero_354465", type = "spell", id = 354465, label = "Salones de la Expiación (Ruta del héroe)" },
  { key = "spell_hero_354466", type = "spell", id = 354466, label = "Agujas de ascensión (Ruta del héroe)" },
  { key = "spell_hero_354467", type = "spell", id = 354467, label = "Teatro del Dolor (Ruta del héroe)" },
  { key = "spell_hero_354468", type = "spell", id = 354468, label = "El otro lado (Ruta del héroe)" },
  { key = "spell_hero_354469", type = "spell", id = 354469, label = "Profundidades Sangrientas (Ruta del héroe)" },
  { key = "spell_hero_367416", type = "spell", id = 367416, label = "Tazavesh, el mercado velado (Ruta del héroe)" },
  { key = "spell_hero_373190", type = "spell", id = 373190, label = "Castillo Nathria (Ruta del héroe)" },
  { key = "spell_hero_373191", type = "spell", id = 373191, label = "Santuario de Dominación (Ruta del héroe)" },
  { key = "spell_hero_373192", type = "spell", id = 373192, label = "Sepulcro de los Primeros (Ruta del héroe)" },
  { key = "spell_hero_393256", type = "spell", id = 393256, label = "Estanques de Vida Rubí (Ruta del héroe)" },
  { key = "spell_hero_393262", type = "spell", id = 393262, label = "Ofensiva Nokhud (Ruta del héroe)" },
  { key = "spell_hero_393267", type = "spell", id = 393267, label = "Hondonada Brote Umbrío (Ruta del héroe)" },
  { key = "spell_hero_393273", type = "spell", id = 393273, label = "Academia Algeth'ar (Ruta del héroe)" },
  { key = "spell_hero_393276", type = "spell", id = 393276, label = "Neltharus (Ruta del héroe)" },
  { key = "spell_hero_393279", type = "spell", id = 393279, label = "La Cámara Azur (Ruta del héroe)" },
  { key = "spell_hero_393283", type = "spell", id = 393283, label = "Salas de la Infusión (Ruta del héroe)" },
  { key = "spell_hero_393222", type = "spell", id = 393222, label = "Uldaman: Legado de Tyr (Ruta del héroe)" },
  { key = "spell_hero_424197", type = "spell", id = 424197, label = "Alba del Infinito (Ruta del héroe)" },
  { key = "spell_hero_432254", type = "spell", id = 432254, label = "Bóveda de los Encarnados (Ruta del héroe)" },
  { key = "spell_hero_432257", type = "spell", id = 432257, label = "Aberrus, el crisol sombrío (Ruta del héroe)" },
  { key = "spell_hero_432258", type = "spell", id = 432258, label = "Amirdrassil, la esperanza del sueño (Ruta del héroe)" },
  { key = "spell_hero_445416", type = "spell", id = 445416, label = "Ciudad de los Hilos (Ruta del héroe)" },
  { key = "spell_hero_445414", type = "spell", id = 445414, label = "La Albarrocía (Ruta del héroe)" },
  { key = "spell_hero_445269", type = "spell", id = 445269, label = "La Caverna de Petrobarro (Ruta del héroe)" },
  { key = "spell_hero_445443", type = "spell", id = 445443, label = "La Arquería (Ruta del héroe)" },
  { key = "spell_hero_445440", type = "spell", id = 445440, label = "Cervecería Cebadiz (Ruta del héroe)" },
  { key = "spell_hero_445444", type = "spell", id = 445444, label = "Priorato de la Llama Sagrada (Ruta del héroe)" },
  { key = "spell_hero_445417", type = "spell", id = 445417, label = "Ara-Kara, ciudad de los ecos (Ruta del héroe)" },
  { key = "spell_hero_445441", type = "spell", id = 445441, label = "Grieta Oscilante (Ruta del héroe)" },
  { key = "spell_hero_1216786", type = "spell", id = 1216786, label = "Operación: compuerta (Ruta del héroe)" },
  { key = "spell_hero_1237215", type = "spell", id = 1237215, label = "Ecodomo Al'dani (Ruta del héroe)" },
  { key = "spell_hero_1226482", type = "spell", id = 1226482, label = "Liberación de Minahonda (Ruta del héroe)" },
  { key = "spell_hero_1239155", type = "spell", id = 1239155, label = "Manaforja Omega (Ruta del héroe)" },
  { key = "spell_hero_1254400", type = "spell", id = 1254400, label = "Aguja de los Vientoveloz (Ruta del héroe)" },
  { key = "spell_hero_1254559", type = "spell", id = 1254559, label = "Cavernas Maisara (Ruta del héroe)" },
  { key = "spell_hero_1254563", type = "spell", id = 1254563, label = "Punto Nexo Xenas (Ruta del héroe)" },
  { key = "spell_hero_1254572", type = "spell", id = 1254572, label = "Bancal del Magister (Ruta del héroe)" },
}

--- Una sola fila por tipo+id (evita duplicados al fusionar fuentes)
do
  local seen = {}
  local out = {}
  for i = 1, #list do
    local e = list[i]
    local sig = (e.type or "?") .. ":" .. tostring(e.id or 0)
    if not seen[sig] then
      seen[sig] = true
      out[#out + 1] = e
    end
  end
  list = out
end

ns.TeleportCatalog = ns.TeleportCatalog or {}

function ns.TeleportCatalog.GetList()
  return list
end

function ns.TeleportCatalog.GetByKey(key)
  if type(key) ~= "string" then
    return nil
  end
  for i = 1, #list do
    if list[i].key == key then
      return list[i]
    end
  end
  return nil
end
