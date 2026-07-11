--[[ Curated teleport catalog (reserved1). Inspired by TeleportMenu;
     only entries valid for the character appear in the grid (item in bags,
     toy learned, spell known). dedupeKey collapses same CD+destination (MVP by data). ]]

local _, ns = ...

local list = {
  -- Hearth / home
  { key = "hearthstone", type = "item", id = 6948, label = "Hearthstone (item)", dedupeKey = "bind_hearth" },
  { key = "astral_recall", type = "spell", id = 556, label = "Astral Recall (shaman)" },
  { key = "dalaran_hearth", type = "toy", id = 140192, label = "Dalaran Hearthstone", quest = { 44184, 44663 }, dedupeKey = "dalaran_legion_hs" },
  { key = "garrison_hearth", type = "toy", id = 110560, label = "Garrison Hearthstone", quest = { 34378, 34586 }, dedupeKey = "garrison_hs" },
  { key = "toy_timewalker_hs", type = "toy", id = 193588, label = "Timewalker's Hearthstone", dedupeKey = "bind_hearth" },
  { key = "toy_inn_daughter", type = "toy", id = 64488, label = "The Innkeeper's Daughter", dedupeKey = "bind_hearth" },
  { key = "toy_dark_portal", type = "toy", id = 93672, label = "Dark Portal", dedupeKey = "bind_hearth" },
  { key = "tome_town_portal", type = "toy", id = 142542, label = "Tome of Town Portal", dedupeKey = "bind_hearth" },
  { key = "toy_rune_random", type = "toy", id = 168907, label = "Random Hearthstone Rune", dedupeKey = "bind_hearth" },

  -- Class / race
  { key = "zen_pilgrimage", type = "spell", id = 126892, label = "Zen Pilgrimage (monk)" },
  { key = "death_gate", type = "spell", id = 50977, label = "Death Gate (death knight)" },
  { key = "teleport_moonglade", type = "spell", id = 18960, label = "Teleport: Moonglade (druid)" },
  { key = "dreamwalk", type = "spell", id = 193753, label = "Dreamwalk (druid)" },
  { key = "vulpera_camp", type = "spell", id = 312370, label = "Make Camp (vulpera)" },
  { key = "vulpera_return", type = "spell", id = 312372, label = "Return to Camp (vulpera)" },
  { key = "mole_machine", type = "spell", id = 265225, label = "Mole Machine (dark iron dwarf)" },
  { key = "rootwalking", type = "spell", id = 1238686, label = "Rootwalking (haranir)" },

  -- Utility items / toys (TeleportMenu Items.lua subset)
  { key = "item_direbrew_remote", type = "item", id = 37863, label = "Direbrew Remote" },
  { key = "item_karabor_medallion", type = "item", id = 32757, label = "Blessed Medallion of Karabor" },
  { key = "item_wrap_sw", type = "item", id = 63206, label = "Wrap: Stormwind (Alliance)" },
  { key = "item_wrap_org", type = "item", id = 63207, label = "Wrap: Orgrimmar (Horde)" },
  { key = "item_shroud_sw", type = "item", id = 63352, label = "Shroud: Stormwind Cooperation" },
  { key = "item_shroud_org", type = "item", id = 63353, label = "Shroud: Orgrimmar Cooperation" },
  { key = "item_cloak_org", type = "item", id = 65274, label = "Cloak of Coordination: Orgrimmar" },
  { key = "item_cloak_sw", type = "item", id = 65360, label = "Cloak of Coordination: Stormwind" },
  { key = "item_argent_tabard", type = "item", id = 46874, label = "Argent Crusader's Tabard" },
  { key = "item_last_relic_argus", type = "item", id = 64457, label = "The Last Relic of Argus" },
  { key = "item_kirin_beacon_a", type = "item", id = 95567, label = "Kirin Tor Beacon (Alliance)" },
  { key = "item_kirin_beacon_h", type = "item", id = 95568, label = "Sunreaver Beacon (Horde)" },
  { key = "item_time_lost_artifact", type = "item", id = 103678, label = "Time-Lost Artifact" },
  { key = "item_admirals_compass", type = "item", id = 128353, label = "Admiral's Compass" },
  { key = "item_mobile_telemancy", type = "item", id = 140324, label = "Mobile Telemancy Beacon" },
  { key = "item_ultrasafe_mechagon", type = "item", id = 167075, label = "Ultrasafe Transporter: Mechagon" },
  { key = "item_cypher_relocation", type = "item", id = 180817, label = "Cypher of Relocation (Ve'nari Refuge)" },
  { key = "item_cartel_xy_proof", type = "item", id = 189827, label = "Cartel Xy Initiation Proof" },
  { key = "item_ring_hourglass", type = "item", id = 193000, label = "Ringed Hourglass" },
  { key = "item_aylaag_windstone", type = "item", id = 200613, label = "Aylaag Windstone Fragment" },
  { key = "item_dragonscale_1", type = "item", id = 205456, label = "Lost Dragonscale (1)" },
  { key = "item_dragonscale_2", type = "item", id = 205458, label = "Lost Dragonscale (2)" },
  { key = "item_delve_bot", type = "item", id = 230850, label = "Delve-O-Bot 7001" },
  { key = "item_mana_ethergate", type = "item", id = 243056, label = "Mana-Bound Ethergate (depths)" },
  { key = "item_shadowguard_trans", type = "item", id = 249699, label = "Shadowguard Translocator" },
  { key = "item_jaina_locket", type = "item", id = 52251, label = "Jaina's Locket" },
  { key = "item_boots_bay", type = "item", id = 50287, label = "Boots of the Bay" },
  { key = "item_potion_deepholm", type = "item", id = 58487, label = "Potion of Deepholm" },
  { key = "item_baradin_tabard_h", type = "item", id = 63378, label = "Hellscream's Reach Tabard" },
  { key = "item_baradin_tabard_a", type = "item", id = 63379, label = "Baradin Wardens Tabard" },
  { key = "item_violet_seal", type = "item", id = 142469, label = "Violet Seal of the Grand Magus" },
  { key = "item_niffen_mitts", type = "item", id = 205255, label = "Niffen Digging Mitts" },
  { key = "toy_arcantina_key", type = "toy", id = 253629, label = "Personal Arcantina Key" },

  -- Hero's Path / dungeon and raid teleports (spell unlocked in spellbook)
  { key = "spell_hero_410080", type = "spell", id = 410080, label = "The Vortex Pinnacle (Hero's Path)" },
  { key = "spell_hero_424142", type = "spell", id = 424142, label = "Throne of the Tides (Hero's Path)" },
  { key = "spell_hero_445424", type = "spell", id = 445424, label = "Grim Batol (Hero's Path)" },
  { key = "spell_hero_1254555", type = "spell", id = 1254555, label = "Pit of Saron (Hero's Path)" },
  { key = "spell_hero_131204", type = "spell", id = 131204, label = "Temple of the Jade Serpent (Hero's Path)" },
  { key = "spell_hero_131205", type = "spell", id = 131205, label = "Stormstout Brewery (Hero's Path)" },
  { key = "spell_hero_131206", type = "spell", id = 131206, label = "Shado-Pan Monastery (Hero's Path)" },
  { key = "spell_hero_131222", type = "spell", id = 131222, label = "Mogu'shan Palace (Hero's Path)" },
  { key = "spell_hero_131225", type = "spell", id = 131225, label = "Gate of the Setting Sun (Hero's Path)" },
  { key = "spell_hero_131228", type = "spell", id = 131228, label = "Siege of Niuzao Temple (Hero's Path)" },
  { key = "spell_hero_131229", type = "spell", id = 131229, label = "Scarlet Monastery (Hero's Path)" },
  { key = "spell_hero_131231", type = "spell", id = 131231, label = "Scarlet Halls (Hero's Path)" },
  { key = "spell_hero_131232", type = "spell", id = 131232, label = "Scholomance (Hero's Path)" },
  { key = "spell_hero_159901", type = "spell", id = 159901, label = "The Everbloom (Hero's Path)" },
  { key = "spell_hero_159899", type = "spell", id = 159899, label = "Shadowmoon Burial Grounds (Hero's Path)" },
  { key = "spell_hero_159900", type = "spell", id = 159900, label = "Blackrock Foundry (Hero's Path)" },
  { key = "spell_hero_159896", type = "spell", id = 159896, label = "Iron Docks (Hero's Path)" },
  { key = "spell_hero_159895", type = "spell", id = 159895, label = "Bloodmaul Slag Mines (Hero's Path)" },
  { key = "spell_hero_159897", type = "spell", id = 159897, label = "Auchindoun (Hero's Path)" },
  {
    key = "spell_hero_159898",
    type = "spell",
    id = 159898,
    label = "Skyreach (Hero's Path)",
    dedupeKey = "hero_skyreach",
  },
  { key = "spell_hero_159902", type = "spell", id = 159902, label = "Upper Blackrock Spire (Hero's Path)" },
  {
    key = "spell_hero_1254557",
    type = "spell",
    id = 1254557,
    label = "Skyreach — variant (Hero's Path)",
    dedupeKey = "hero_skyreach",
  },
  { key = "spell_hero_393764", type = "spell", id = 393764, label = "Halls of Valor (Hero's Path)" },
  { key = "spell_hero_410078", type = "spell", id = 410078, label = "Neltharion's Lair (Hero's Path)" },
  { key = "spell_hero_393766", type = "spell", id = 393766, label = "Court of Stars (Hero's Path)" },
  { key = "spell_hero_373262", type = "spell", id = 373262, label = "Karazhan (Hero's Path)" },
  { key = "spell_hero_424153", type = "spell", id = 424153, label = "Black Rook Hold (Hero's Path)" },
  { key = "spell_hero_424163", type = "spell", id = 424163, label = "Darkheart Thicket (Hero's Path)" },
  { key = "spell_hero_1254551", type = "spell", id = 1254551, label = "Seat of the Triumvirate (Hero's Path)" },
  { key = "spell_hero_410071", type = "spell", id = 410071, label = "Freehold (Hero's Path)" },
  { key = "spell_hero_410074", type = "spell", id = 410074, label = "The Underrot (Hero's Path)" },
  { key = "spell_hero_373274", type = "spell", id = 373274, label = "Operation: Mechagon (Hero's Path)" },
  { key = "spell_hero_424167", type = "spell", id = 424167, label = "Waycrest Manor (Hero's Path)" },
  { key = "spell_hero_424187", type = "spell", id = 424187, label = "Atal'Dazar (Hero's Path)" },
  { key = "spell_hero_445418", type = "spell", id = 445418, label = "Siege of Boralus (Hero's Path, Alliance)" },
  { key = "spell_hero_464256", type = "spell", id = 464256, label = "Siege of Boralus (Hero's Path, Horde)" },
  { key = "spell_hero_467553", type = "spell", id = 467553, label = "Motherlode!! (Hero's Path, Alliance)" },
  { key = "spell_hero_467555", type = "spell", id = 467555, label = "Motherlode!! (Hero's Path, Horde)" },
  { key = "spell_hero_354462", type = "spell", id = 354462, label = "The Necrotic Wake (Hero's Path)" },
  { key = "spell_hero_354463", type = "spell", id = 354463, label = "Plaguefall (Hero's Path)" },
  { key = "spell_hero_354464", type = "spell", id = 354464, label = "Mists of Tirna Scithe (Hero's Path)" },
  { key = "spell_hero_354465", type = "spell", id = 354465, label = "Halls of Atonement (Hero's Path)" },
  { key = "spell_hero_354466", type = "spell", id = 354466, label = "Spires of Ascension (Hero's Path)" },
  { key = "spell_hero_354467", type = "spell", id = 354467, label = "Theater of Pain (Hero's Path)" },
  { key = "spell_hero_354468", type = "spell", id = 354468, label = "De Other Side (Hero's Path)" },
  { key = "spell_hero_354469", type = "spell", id = 354469, label = "Sanguine Depths (Hero's Path)" },
  { key = "spell_hero_367416", type = "spell", id = 367416, label = "Tazavesh, the Veiled Market (Hero's Path)" },
  { key = "spell_hero_373190", type = "spell", id = 373190, label = "Castle Nathria (Hero's Path)" },
  { key = "spell_hero_373191", type = "spell", id = 373191, label = "Sanctum of Domination (Hero's Path)" },
  { key = "spell_hero_373192", type = "spell", id = 373192, label = "Sepulcher of the First Ones (Hero's Path)" },
  { key = "spell_hero_393256", type = "spell", id = 393256, label = "Ruby Life Pools (Hero's Path)" },
  { key = "spell_hero_393262", type = "spell", id = 393262, label = "The Nokhud Offensive (Hero's Path)" },
  { key = "spell_hero_393267", type = "spell", id = 393267, label = "Brackenhide Hollow (Hero's Path)" },
  { key = "spell_hero_393273", type = "spell", id = 393273, label = "Algeth'ar Academy (Hero's Path)" },
  { key = "spell_hero_393276", type = "spell", id = 393276, label = "Neltharus (Hero's Path)" },
  { key = "spell_hero_393279", type = "spell", id = 393279, label = "The Azure Vault (Hero's Path)" },
  { key = "spell_hero_393283", type = "spell", id = 393283, label = "Halls of Infusion (Hero's Path)" },
  { key = "spell_hero_393222", type = "spell", id = 393222, label = "Uldaman: Legacy of Tyr (Hero's Path)" },
  { key = "spell_hero_424197", type = "spell", id = 424197, label = "Dawn of the Infinite (Hero's Path)" },
  { key = "spell_hero_432254", type = "spell", id = 432254, label = "Vault of the Incarnates (Hero's Path)" },
  { key = "spell_hero_432257", type = "spell", id = 432257, label = "Aberrus, the Shadowed Crucible (Hero's Path)" },
  { key = "spell_hero_432258", type = "spell", id = 432258, label = "Amirdrassil, the Dream's Hope (Hero's Path)" },
  { key = "spell_hero_445416", type = "spell", id = 445416, label = "City of Threads (Hero's Path)" },
  { key = "spell_hero_445414", type = "spell", id = 445414, label = "The Dawnbreaker (Hero's Path)" },
  { key = "spell_hero_445269", type = "spell", id = 445269, label = "The Stonevault (Hero's Path)" },
  { key = "spell_hero_445443", type = "spell", id = 445443, label = "The Rookery (Hero's Path)" },
  { key = "spell_hero_445440", type = "spell", id = 445440, label = "Cinderbrew Meadery (Hero's Path)" },
  { key = "spell_hero_445444", type = "spell", id = 445444, label = "Priory of the Sacred Flame (Hero's Path)" },
  { key = "spell_hero_445417", type = "spell", id = 445417, label = "Ara-Kara, City of Echoes (Hero's Path)" },
  { key = "spell_hero_445441", type = "spell", id = 445441, label = "Darkflame Cleft (Hero's Path)" },
  { key = "spell_hero_1216786", type = "spell", id = 1216786, label = "Operation: Floodgate (Hero's Path)" },
  { key = "spell_hero_1237215", type = "spell", id = 1237215, label = "Al'dani Ecodome (Hero's Path)" },
  { key = "spell_hero_1226482", type = "spell", id = 1226482, label = "Liberation of Undermine (Hero's Path)" },
  { key = "spell_hero_1239155", type = "spell", id = 1239155, label = "Manaforge Omega (Hero's Path)" },
  { key = "spell_hero_1254400", type = "spell", id = 1254400, label = "Windrunner Spire (Hero's Path)" },
  { key = "spell_hero_1254559", type = "spell", id = 1254559, label = "Maisara Caverns (Hero's Path)" },
  { key = "spell_hero_1254563", type = "spell", id = 1254563, label = "Xenas Nexus Point (Hero's Path)" },
  { key = "spell_hero_1254572", type = "spell", id = 1254572, label = "Magister's Terrace (Hero's Path)" },
}

--- One row per type+id (avoids duplicates when merging sources)
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

function ns.TeleportCatalog.GetDisplayLabel(entry)
  if not entry then
    return "?"
  end
  if type(entry.label) == "string" and entry.label ~= "" then
    return entry.label
  end
  return tostring(entry.key or "?")
end
