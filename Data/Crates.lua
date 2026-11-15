-- Generado por tools/gen_crates.py (cliente de WoW Forever, wago.tools DB2). No editar a mano.
-- Waylaid Crates: cada una se llena con UNO de sus paquetes (fills = { { objeto, cantidad } })
-- y se entrega al representante de tu bando por Merchant's Favor (favor; guess = estimado).
local _, ES = ...
ES.Data = ES.Data or {}
ES.Data.ItemNames = ES.Data.ItemNames or {}
ES.Data.FAVOR_CURRENCY = 3402
ES.Data.Crates = {
  { id = 248682, tier = 1, kind = "Herbs", crafted = false, favor = 5, level = 10, fills = { { 2447, 20 }, { 765, 20 }, { 2449, 10 }, { 785, 10 }, { 2450, 10 } } }, -- Waylaid Crate: Apprentice Herbs
  { id = 248683, tier = 1, kind = "Ore", crafted = false, favor = 5, level = 10, fills = { { 2770, 20 }, { 2771, 20 } } }, -- Waylaid Crate: Apprentice Ore
  { id = 248684, tier = 1, kind = "Textiles", crafted = false, favor = 5, level = 10, fills = { { 2589, 40 }, { 2318, 20 } } }, -- Waylaid Crate: Apprentice Textiles
  { id = 248685, tier = 1, kind = "Curiosities", crafted = false, favor = 5, level = 10, fills = { { 10940, 20 }, { 10939, 4 }, { 10978, 6 }, { 11084, 2 } } }, -- Waylaid Crate: Apprentice Curiosities
  { id = 248686, tier = 2, kind = "Herbs", crafted = false, favor = 10, level = 10, fills = { { 3820, 10 }, { 2453, 10 }, { 3355, 10 }, { 3369, 10 }, { 3356, 10 } } }, -- Waylaid Crate: Journeyman Herbs
  { id = 248687, tier = 2, kind = "Ore", crafted = false, favor = 10, level = 10, fills = { { 2775, 10 }, { 2772, 20 } } }, -- Waylaid Crate: Journeyman Ore
  { id = 248688, tier = 2, kind = "Textiles", crafted = false, favor = 10, level = 10, fills = { { 2592, 20 }, { 4306, 40 }, { 2319, 20 } } }, -- Waylaid Crate: Journeyman Textiles
  { id = 248689, tier = 2, kind = "Curiosities", crafted = false, favor = 10, level = 10, fills = { { 11083, 20 }, { 11082, 4 }, { 11138, 6 }, { 11139, 2 } } }, -- Waylaid Crate: Journeyman Curiosities
  { id = 248690, tier = 3, kind = "Earthly Herbs", crafted = false, favor = 15, level = 20, fills = { { 3357, 20 }, { 3818, 10 }, { 3821, 10 }, { 3358, 10 } } }, -- Waylaid Crate: Earthly Expert Herbs
  { id = 248691, tier = 3, kind = "Flowering Herbs", crafted = false, favor = 15, level = 20, fills = { { 3819, 10 }, { 4625, 10 }, { 8831, 20 }, { 8836, 10 } } }, -- Waylaid Crate: Flowering Expert Herbs
  { id = 248692, tier = 3, kind = "Ore", crafted = false, favor = 15, level = 20, fills = { { 2776, 10 }, { 3858, 20 } } }, -- Waylaid Crate: Expert Ore
  { id = 248693, tier = 3, kind = "Textiles", crafted = false, favor = 15, level = 20, fills = { { 4338, 40 }, { 4234, 20 } } }, -- Waylaid Crate: Expert Textiles
  { id = 248694, tier = 3, kind = "Curiosities", crafted = false, favor = 15, level = 20, fills = { { 11137, 20 }, { 11135, 4 }, { 11177, 6 }, { 11178, 2 } } }, -- Waylaid Crate: Expert Curiosities
  { id = 248695, tier = 4, kind = "Earthly Herbs", crafted = false, favor = 20, guess = true, level = 35, fills = { { 13464, 10 }, { 8838, 20 }, { 8839, 10 }, { 8845, 10 }, { 8846, 10 } } }, -- Waylaid Crate: Earthly Artisan Herbs
  { id = 248696, tier = 4, kind = "Flowering Herbs", crafted = false, favor = 20, guess = true, level = 35, fills = { { 13463, 20 }, { 13465, 20 }, { 13466, 20 }, { 13467, 20 } } }, -- Waylaid Crate: Flowering Artisan Herbs
  { id = 248697, tier = 4, kind = "Ore", crafted = false, favor = 20, guess = true, level = 35, fills = { { 7911, 10 }, { 10620, 20 }, { 11370, 20 } } }, -- Waylaid Crate: Artisan Ore
  { id = 248698, tier = 4, kind = "Textiles", crafted = false, favor = 20, guess = true, level = 35, fills = { { 14047, 40 }, { 4304, 20 }, { 8170, 20 } } }, -- Waylaid Crate: Artisan Textiles
  { id = 248699, tier = 4, kind = "Curiosities", crafted = false, favor = 20, guess = true, level = 35, fills = { { 11176, 20 }, { 11175, 4 }, { 14343, 6 }, { 14344, 2 } } }, -- Waylaid Crate: Artisan Curiosities
  { id = 248702, tier = 1, kind = "Fabrics", crafted = true, favor = 10, level = 10, fills = { { 4231, 2 }, { 2996, 20 } } }, -- Waylaid Crate: Apprentice Fabrics
  { id = 248703, tier = 1, kind = "Ingots", crafted = true, favor = 10, level = 10, fills = { { 2840, 20 }, { 3576, 20 }, { 2841, 10 } } }, -- Waylaid Crate: Apprentice Ingots
  { id = 248704, tier = 1, kind = "Parts", crafted = true, favor = 10, level = 10, fills = { { 4359, 16 }, { 4361, 16 }, { 4363, 4 } } }, -- Waylaid Crate: Apprentice Parts
  { id = 248705, tier = 2, kind = "Fabrics", crafted = true, favor = 20, level = 10, fills = { { 2997, 6 }, { 4305, 10 }, { 4233, 2 } } }, -- Waylaid Crate: Journeyman Fabrics
  { id = 248706, tier = 2, kind = "Ingots", crafted = true, favor = 20, level = 10, fills = { { 2842, 10 }, { 3575, 20 } } }, -- Waylaid Crate: Journeyman Ingots
  { id = 248707, tier = 2, kind = "Parts", crafted = true, favor = 20, level = 10, fills = { { 4371, 8 }, { 4375, 7 }, { 4382, 4 }, { 10558, 45 } } }, -- Waylaid Crate: Journeyman Parts
  { id = 248708, tier = 3, kind = "Fabrics", crafted = true, favor = 30, level = 20, fills = { { 4339, 8 }, { 4236, 2 } } }, -- Waylaid Crate: Expert Fabrics
  { id = 248709, tier = 3, kind = "Ingots", crafted = true, favor = 30, level = 20, fills = { { 3860, 20 }, { 3859, 15 }, { 3577, 10 } } }, -- Waylaid Crate: Expert Ingots
  { id = 248710, tier = 3, kind = "Parts", crafted = true, favor = 30, level = 20, fills = { { 4387, 8 }, { 10559, 5 }, { 10560, 12 }, { 10561, 5 } } }, -- Waylaid Crate: Expert Parts
  { id = 248711, tier = 4, kind = "Fabrics", crafted = true, favor = 40, guess = true, level = 35, fills = { { 14048, 8 }, { 8172, 2 } } }, -- Waylaid Crate: Artisan Fabrics
  { id = 248712, tier = 4, kind = "Ingots", crafted = true, favor = 40, guess = true, level = 35, fills = { { 11371, 2 }, { 6037, 10 }, { 12359, 20 } } }, -- Waylaid Crate: Artisan Ingots
  { id = 248713, tier = 4, kind = "Parts", crafted = true, favor = 40, guess = true, level = 35, fills = { { 15994, 5 }, { 18631, 5 }, { 16000, 2 } } }, -- Waylaid Crate: Artisan Parts
}
ES.Data.ItemNames[765] = ES.Data.ItemNames[765] or "Silverleaf"
ES.Data.ItemNames[785] = ES.Data.ItemNames[785] or "Mageroyal"
ES.Data.ItemNames[2318] = ES.Data.ItemNames[2318] or "Light Leather"
ES.Data.ItemNames[2319] = ES.Data.ItemNames[2319] or "Medium Leather"
ES.Data.ItemNames[2447] = ES.Data.ItemNames[2447] or "Peacebloom"
ES.Data.ItemNames[2449] = ES.Data.ItemNames[2449] or "Earthroot"
ES.Data.ItemNames[2450] = ES.Data.ItemNames[2450] or "Briarthorn"
ES.Data.ItemNames[2453] = ES.Data.ItemNames[2453] or "Bruiseweed"
ES.Data.ItemNames[2589] = ES.Data.ItemNames[2589] or "Linen Cloth"
ES.Data.ItemNames[2592] = ES.Data.ItemNames[2592] or "Wool Cloth"
ES.Data.ItemNames[2770] = ES.Data.ItemNames[2770] or "Copper Ore"
ES.Data.ItemNames[2771] = ES.Data.ItemNames[2771] or "Tin Ore"
ES.Data.ItemNames[2772] = ES.Data.ItemNames[2772] or "Iron Ore"
ES.Data.ItemNames[2775] = ES.Data.ItemNames[2775] or "Silver Ore"
ES.Data.ItemNames[2776] = ES.Data.ItemNames[2776] or "Gold Ore"
ES.Data.ItemNames[2840] = ES.Data.ItemNames[2840] or "Copper Bar"
ES.Data.ItemNames[2841] = ES.Data.ItemNames[2841] or "Bronze Bar"
ES.Data.ItemNames[2842] = ES.Data.ItemNames[2842] or "Silver Bar"
ES.Data.ItemNames[2996] = ES.Data.ItemNames[2996] or "Bolt of Linen Cloth"
ES.Data.ItemNames[2997] = ES.Data.ItemNames[2997] or "Bolt of Woolen Cloth"
ES.Data.ItemNames[3355] = ES.Data.ItemNames[3355] or "Wild Steelbloom"
ES.Data.ItemNames[3356] = ES.Data.ItemNames[3356] or "Kingsblood"
ES.Data.ItemNames[3357] = ES.Data.ItemNames[3357] or "Liferoot"
ES.Data.ItemNames[3358] = ES.Data.ItemNames[3358] or "Khadgar's Whisker"
ES.Data.ItemNames[3369] = ES.Data.ItemNames[3369] or "Grave Moss"
ES.Data.ItemNames[3575] = ES.Data.ItemNames[3575] or "Iron Bar"
ES.Data.ItemNames[3576] = ES.Data.ItemNames[3576] or "Tin Bar"
ES.Data.ItemNames[3577] = ES.Data.ItemNames[3577] or "Gold Bar"
ES.Data.ItemNames[3818] = ES.Data.ItemNames[3818] or "Fadeleaf"
ES.Data.ItemNames[3819] = ES.Data.ItemNames[3819] or "Wintersbite"
ES.Data.ItemNames[3820] = ES.Data.ItemNames[3820] or "Stranglekelp"
ES.Data.ItemNames[3821] = ES.Data.ItemNames[3821] or "Goldthorn"
ES.Data.ItemNames[3858] = ES.Data.ItemNames[3858] or "Mithril Ore"
ES.Data.ItemNames[3859] = ES.Data.ItemNames[3859] or "Steel Bar"
ES.Data.ItemNames[3860] = ES.Data.ItemNames[3860] or "Mithril Bar"
ES.Data.ItemNames[4231] = ES.Data.ItemNames[4231] or "Cured Light Hide"
ES.Data.ItemNames[4233] = ES.Data.ItemNames[4233] or "Cured Medium Hide"
ES.Data.ItemNames[4234] = ES.Data.ItemNames[4234] or "Heavy Leather"
ES.Data.ItemNames[4236] = ES.Data.ItemNames[4236] or "Cured Heavy Hide"
ES.Data.ItemNames[4304] = ES.Data.ItemNames[4304] or "Thick Leather"
ES.Data.ItemNames[4305] = ES.Data.ItemNames[4305] or "Bolt of Silk Cloth"
ES.Data.ItemNames[4306] = ES.Data.ItemNames[4306] or "Silk Cloth"
ES.Data.ItemNames[4338] = ES.Data.ItemNames[4338] or "Mageweave Cloth"
ES.Data.ItemNames[4339] = ES.Data.ItemNames[4339] or "Bolt of Mageweave"
ES.Data.ItemNames[4359] = ES.Data.ItemNames[4359] or "Handful of Copper Bolts"
ES.Data.ItemNames[4361] = ES.Data.ItemNames[4361] or "Copper Tube"
ES.Data.ItemNames[4363] = ES.Data.ItemNames[4363] or "Copper Modulator"
ES.Data.ItemNames[4371] = ES.Data.ItemNames[4371] or "Bronze Tube"
ES.Data.ItemNames[4375] = ES.Data.ItemNames[4375] or "Whirring Bronze Gizmo"
ES.Data.ItemNames[4382] = ES.Data.ItemNames[4382] or "Bronze Framework"
ES.Data.ItemNames[4387] = ES.Data.ItemNames[4387] or "Iron Strut"
ES.Data.ItemNames[4625] = ES.Data.ItemNames[4625] or "Firebloom"
ES.Data.ItemNames[6037] = ES.Data.ItemNames[6037] or "Truesilver Bar"
ES.Data.ItemNames[7911] = ES.Data.ItemNames[7911] or "Truesilver Ore"
ES.Data.ItemNames[8170] = ES.Data.ItemNames[8170] or "Rugged Leather"
ES.Data.ItemNames[8172] = ES.Data.ItemNames[8172] or "Cured Thick Hide"
ES.Data.ItemNames[8831] = ES.Data.ItemNames[8831] or "Purple Lotus"
ES.Data.ItemNames[8836] = ES.Data.ItemNames[8836] or "Arthas' Tears"
ES.Data.ItemNames[8838] = ES.Data.ItemNames[8838] or "Sungrass"
ES.Data.ItemNames[8839] = ES.Data.ItemNames[8839] or "Blindweed"
ES.Data.ItemNames[8845] = ES.Data.ItemNames[8845] or "Ghost Mushroom"
ES.Data.ItemNames[8846] = ES.Data.ItemNames[8846] or "Gromsblood"
ES.Data.ItemNames[10558] = ES.Data.ItemNames[10558] or "Gold Power Core"
ES.Data.ItemNames[10559] = ES.Data.ItemNames[10559] or "Mithril Tube"
ES.Data.ItemNames[10560] = ES.Data.ItemNames[10560] or "Unstable Trigger"
ES.Data.ItemNames[10561] = ES.Data.ItemNames[10561] or "Mithril Casing"
ES.Data.ItemNames[10620] = ES.Data.ItemNames[10620] or "Thorium Ore"
ES.Data.ItemNames[10939] = ES.Data.ItemNames[10939] or "Greater Magic Essence"
ES.Data.ItemNames[10940] = ES.Data.ItemNames[10940] or "Strange Dust"
ES.Data.ItemNames[10978] = ES.Data.ItemNames[10978] or "Small Glimmering Shard"
ES.Data.ItemNames[11082] = ES.Data.ItemNames[11082] or "Greater Astral Essence"
ES.Data.ItemNames[11083] = ES.Data.ItemNames[11083] or "Soul Dust"
ES.Data.ItemNames[11084] = ES.Data.ItemNames[11084] or "Large Glimmering Shard"
ES.Data.ItemNames[11135] = ES.Data.ItemNames[11135] or "Greater Mystic Essence"
ES.Data.ItemNames[11137] = ES.Data.ItemNames[11137] or "Vision Dust"
ES.Data.ItemNames[11138] = ES.Data.ItemNames[11138] or "Small Glowing Shard"
ES.Data.ItemNames[11139] = ES.Data.ItemNames[11139] or "Large Glowing Shard"
ES.Data.ItemNames[11175] = ES.Data.ItemNames[11175] or "Greater Nether Essence"
ES.Data.ItemNames[11176] = ES.Data.ItemNames[11176] or "Dream Dust"
ES.Data.ItemNames[11177] = ES.Data.ItemNames[11177] or "Small Radiant Shard"
ES.Data.ItemNames[11178] = ES.Data.ItemNames[11178] or "Large Radiant Shard"
ES.Data.ItemNames[11370] = ES.Data.ItemNames[11370] or "Dark Iron Ore"
ES.Data.ItemNames[11371] = ES.Data.ItemNames[11371] or "Dark Iron Bar"
ES.Data.ItemNames[12359] = ES.Data.ItemNames[12359] or "Thorium Bar"
ES.Data.ItemNames[13463] = ES.Data.ItemNames[13463] or "Dreamfoil"
ES.Data.ItemNames[13464] = ES.Data.ItemNames[13464] or "Golden Sansam"
ES.Data.ItemNames[13465] = ES.Data.ItemNames[13465] or "Mountain Silversage"
ES.Data.ItemNames[13466] = ES.Data.ItemNames[13466] or "Plaguebloom"
ES.Data.ItemNames[13467] = ES.Data.ItemNames[13467] or "Icecap"
ES.Data.ItemNames[14047] = ES.Data.ItemNames[14047] or "Runecloth"
ES.Data.ItemNames[14048] = ES.Data.ItemNames[14048] or "Bolt of Runecloth"
ES.Data.ItemNames[14343] = ES.Data.ItemNames[14343] or "Small Brilliant Shard"
ES.Data.ItemNames[14344] = ES.Data.ItemNames[14344] or "Large Brilliant Shard"
ES.Data.ItemNames[15994] = ES.Data.ItemNames[15994] or "Thorium Widget"
ES.Data.ItemNames[16000] = ES.Data.ItemNames[16000] or "Thorium Tube"
ES.Data.ItemNames[18631] = ES.Data.ItemNames[18631] or "Truesilver Transformer"
ES.Data.ItemNames[248682] = ES.Data.ItemNames[248682] or "Waylaid Crate: Apprentice Herbs"
ES.Data.ItemNames[248683] = ES.Data.ItemNames[248683] or "Waylaid Crate: Apprentice Ore"
ES.Data.ItemNames[248684] = ES.Data.ItemNames[248684] or "Waylaid Crate: Apprentice Textiles"
ES.Data.ItemNames[248685] = ES.Data.ItemNames[248685] or "Waylaid Crate: Apprentice Curiosities"
ES.Data.ItemNames[248686] = ES.Data.ItemNames[248686] or "Waylaid Crate: Journeyman Herbs"
ES.Data.ItemNames[248687] = ES.Data.ItemNames[248687] or "Waylaid Crate: Journeyman Ore"
ES.Data.ItemNames[248688] = ES.Data.ItemNames[248688] or "Waylaid Crate: Journeyman Textiles"
ES.Data.ItemNames[248689] = ES.Data.ItemNames[248689] or "Waylaid Crate: Journeyman Curiosities"
ES.Data.ItemNames[248690] = ES.Data.ItemNames[248690] or "Waylaid Crate: Earthly Expert Herbs"
ES.Data.ItemNames[248691] = ES.Data.ItemNames[248691] or "Waylaid Crate: Flowering Expert Herbs"
ES.Data.ItemNames[248692] = ES.Data.ItemNames[248692] or "Waylaid Crate: Expert Ore"
ES.Data.ItemNames[248693] = ES.Data.ItemNames[248693] or "Waylaid Crate: Expert Textiles"
ES.Data.ItemNames[248694] = ES.Data.ItemNames[248694] or "Waylaid Crate: Expert Curiosities"
ES.Data.ItemNames[248695] = ES.Data.ItemNames[248695] or "Waylaid Crate: Earthly Artisan Herbs"
ES.Data.ItemNames[248696] = ES.Data.ItemNames[248696] or "Waylaid Crate: Flowering Artisan Herbs"
ES.Data.ItemNames[248697] = ES.Data.ItemNames[248697] or "Waylaid Crate: Artisan Ore"
ES.Data.ItemNames[248698] = ES.Data.ItemNames[248698] or "Waylaid Crate: Artisan Textiles"
ES.Data.ItemNames[248699] = ES.Data.ItemNames[248699] or "Waylaid Crate: Artisan Curiosities"
ES.Data.ItemNames[248702] = ES.Data.ItemNames[248702] or "Waylaid Crate: Apprentice Fabrics"
ES.Data.ItemNames[248703] = ES.Data.ItemNames[248703] or "Waylaid Crate: Apprentice Ingots"
ES.Data.ItemNames[248704] = ES.Data.ItemNames[248704] or "Waylaid Crate: Apprentice Parts"
ES.Data.ItemNames[248705] = ES.Data.ItemNames[248705] or "Waylaid Crate: Journeyman Fabrics"
ES.Data.ItemNames[248706] = ES.Data.ItemNames[248706] or "Waylaid Crate: Journeyman Ingots"
ES.Data.ItemNames[248707] = ES.Data.ItemNames[248707] or "Waylaid Crate: Journeyman Parts"
ES.Data.ItemNames[248708] = ES.Data.ItemNames[248708] or "Waylaid Crate: Expert Fabrics"
ES.Data.ItemNames[248709] = ES.Data.ItemNames[248709] or "Waylaid Crate: Expert Ingots"
ES.Data.ItemNames[248710] = ES.Data.ItemNames[248710] or "Waylaid Crate: Expert Parts"
ES.Data.ItemNames[248711] = ES.Data.ItemNames[248711] or "Waylaid Crate: Artisan Fabrics"
ES.Data.ItemNames[248712] = ES.Data.ItemNames[248712] or "Waylaid Crate: Artisan Ingots"
ES.Data.ItemNames[248713] = ES.Data.ItemNames[248713] or "Waylaid Crate: Artisan Parts"
