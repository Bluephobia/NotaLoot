local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

-- Abstract class

local Filter = {}
NotaLoot.Filter = Filter

function Filter:Create(t)
  t = t or {}
  setmetatable(t, self)
  self.__index = self
  return t
end

function Filter:Evaluate(item)
  return true
end

function Filter:Evaluate(item)
  return true
end

-- ClassFilter

local ClassFilterTable = {
  [1] = { -- Warrior
    [2] = { -- Weapon
      [0] = true, -- 1H Axe
      [1] = true, -- 2H Axe
      [2] = true, -- Bow
      [3] = true, -- Gun
      [4] = true, -- 1H Mace
      [5] = true, -- 2H Mace
      [6] = true, -- Polearm
      [7] = true, -- 1H Sword
      [8] = true, -- 2H Sword
      [10] = false, -- Staff
      [13] = true, -- Fist
      [15] = false, -- Dagger
      [16] = true, -- Thrown
      [18] = true, -- Crossbow
      [19] = false, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = false, -- Cloth
      [2] = true, -- Leather
      [3] = true, -- Mail
      [4] = true, -- Plate
      [6] = true, -- Shield
    },
  },
  [2] = { -- Paladin
    [2] = { -- Weapon
      [0] = true, -- 1H Axe
      [1] = true, -- 2H Axe
      [2] = false, -- Bow
      [3] = false, -- Gun
      [4] = true, -- 1H Mace
      [5] = true, -- 2H Mace
      [6] = true, -- Polearm
      [7] = true, -- 1H Sword
      [8] = true, -- 2H Sword
      [10] = false, -- Staff
      [13] = false, -- Fist
      [15] = false, -- Dagger
      [16] = false, -- Thrown
      [18] = false, -- Crossbow
      [19] = false, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = true, -- Cloth
      [2] = true, -- Leather
      [3] = true, -- Mail
      [4] = true, -- Plate
      [6] = true, -- Shield
      [7] = true, -- Libram
    },
  },
  [3] = { -- Hunter
    [2] = { -- Weapon
      [0] = true, -- 1H Axe
      [1] = true, -- 2H Axe
      [2] = true, -- Bow
      [3] = true, -- Gun
      [4] = false, -- 1H Mace
      [5] = false, -- 2H Mace
      [6] = true, -- Polearm
      [7] = true, -- 1H Sword
      [8] = true, -- 2H Sword
      [10] = true, -- Staff
      [13] = true, -- Fist
      [15] = true, -- Dagger
      [16] = false, -- Thrown
      [18] = true, -- Crossbow
      [19] = false, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = false, -- Cloth
      [2] = true, -- Leather
      [3] = true, -- Mail
      [4] = false, -- Plate
      [6] = false, -- Shield
    },
  },
  [4] = { -- Rogue
    [2] = { -- Weapon
      [0] = true, -- 1H Axe
      [1] = false, -- 2H Axe
      [2] = true, -- Bow
      [3] = true, -- Gun
      [4] = true, -- 1H Mace
      [5] = false, -- 2H Mace
      [6] = false, -- Polearm
      [7] = true, -- 1H Sword
      [8] = false, -- 2H Sword
      [10] = false, -- Staff
      [13] = true, -- Fist
      [15] = true, -- Dagger
      [16] = true, -- Thrown
      [18] = true, -- Crossbow
      [19] = false, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = false, -- Cloth
      [2] = true, -- Leather
      [3] = false, -- Mail
      [4] = false, -- Plate
      [6] = false, -- Shield
    },
  },
  [5] = { -- Priest
    [2] = { -- Weapon
      [0] = false, -- 1H Axe
      [1] = false, -- 2H Axe
      [2] = false, -- Bow
      [3] = false, -- Gun
      [4] = true, -- 1H Mace
      [5] = false, -- 2H Mace
      [6] = false, -- Polearm
      [7] = false, -- 1H Sword
      [8] = false, -- 2H Sword
      [10] = true, -- Staff
      [13] = false, -- Fist
      [15] = true, -- Dagger
      [16] = false, -- Thrown
      [18] = false, -- Crossbow
      [19] = true, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = true, -- Cloth
      [2] = false, -- Leather
      [3] = false, -- Mail
      [4] = false, -- Plate
      [6] = false, -- Shield
    },
  },
  [6] = { -- Death Knight
    [2] = { -- Weapon
      [0] = true, -- 1H Axe
      [1] = true, -- 2H Axe
      [2] = false, -- Bow
      [3] = false, -- Gun
      [4] = true, -- 1H Mace
      [5] = true, -- 2H Mace
      [6] = true, -- Polearm
      [7] = true, -- 1H Sword
      [8] = true, -- 2H Sword
      [10] = false, -- Staff
      [13] = false, -- Fist
      [15] = false, -- Dagger
      [16] = false, -- Thrown
      [18] = false, -- Crossbow
      [19] = false, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = false, -- Cloth
      [2] = false, -- Leather
      [3] = false, -- Mail
      [4] = true, -- Plate
      [6] = false, -- Shield
      [10] = true, -- Sigil
    },
  },
  [7] = { -- Shaman
    [2] = { -- Weapon
      [0] = true, -- 1H Axe
      [1] = false, -- 2H Axe
      [2] = false, -- Bow
      [3] = false, -- Gun
      [4] = true, -- 1H Mace
      [5] = false, -- 2H Mace
      [6] = false, -- Polearm
      [7] = false, -- 1H Sword
      [8] = false, -- 2H Sword
      [10] = true, -- Staff
      [13] = true, -- Fist
      [15] = true, -- Dagger
      [16] = false, -- Thrown
      [18] = false, -- Crossbow
      [19] = false, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = true, -- Cloth
      [2] = true, -- Leather
      [3] = true, -- Mail
      [4] = false, -- Plate
      [6] = true, -- Shield
      [9] = true, -- Totem
    },
  },
  [8] = { -- Mage
    [2] = { -- Weapon
      [0] = false, -- 1H Axe
      [1] = false, -- 2H Axe
      [2] = false, -- Bow
      [3] = false, -- Gun
      [4] = false, -- 1H Mace
      [5] = false, -- 2H Mace
      [6] = false, -- Polearm
      [7] = true, -- 1H Sword
      [8] = false, -- 2H Sword
      [10] = true, -- Staff
      [13] = false, -- Fist
      [15] = true, -- Dagger
      [16] = false, -- Thrown
      [18] = false, -- Crossbow
      [19] = true, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = true, -- Cloth
      [2] = false, -- Leather
      [3] = false, -- Mail
      [4] = false, -- Plate
      [6] = false, -- Shield
    },
  },
  [9] = { -- Warlock
    [2] = { -- Weapon
      [0] = false, -- 1H Axe
      [1] = false, -- 2H Axe
      [2] = false, -- Bow
      [3] = false, -- Gun
      [4] = false, -- 1H Mace
      [5] = false, -- 2H Mace
      [6] = false, -- Polearm
      [7] = true, -- 1H Sword
      [8] = false, -- 2H Sword
      [10] = true, -- Staff
      [13] = false, -- Fist
      [15] = true, -- Dagger
      [16] = false, -- Thrown
      [18] = false, -- Crossbow
      [19] = true, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = true, -- Cloth
      [2] = false, -- Leather
      [3] = false, -- Mail
      [4] = false, -- Plate
      [6] = false, -- Shield
    },
  },
  [11] = { -- Druid
    [2] = { -- Weapon
      [0] = false, -- 1H Axe
      [1] = false, -- 2H Axe
      [2] = false, -- Bow
      [3] = false, -- Gun
      [4] = true, -- 1H Mace
      [5] = true, -- 2H Mace
      [6] = true, -- Polearm
      [7] = false, -- 1H Sword
      [8] = false, -- 2H Sword
      [10] = true, -- Staff
      [13] = false, -- Fist
      [15] = true, -- Dagger
      [16] = false, -- Thrown
      [18] = false, -- Crossbow
      [19] = false, -- Wand
    },
    [4] = { -- Armor
      [0] = true, -- Misc e.g. Trinket, Ring, Neck
      [1] = true, -- Cloth
      [2] = true, -- Leather
      [3] = false, -- Mail
      [4] = false, -- Plate
      [6] = false, -- Shield
      [8] = true, -- Idol
    },
  },
}

local ClassFilter = Filter:Create()
function Filter:CreateForPlayerClassId(classId)
  return ClassFilter:Create({
    classId = classId
  })
end

function ClassFilter:Evaluate(item)
  -- Assume any non-armor non-weapon is usable by anyone
  if item.classId ~= 2 and item.classId ~= 4 then return true end

  -- Cloak is a special case because it's type Armor subtype Cloth, but anyone can equip
  if item.equipLoc == "INVTYPE_CLOAK" then return true end

  -- Safeguard against nil table index
  if not self.classId then return false end

  -- Assume an unknown class can equip anything
  if not ClassFilterTable[self.classId] then
    NotaLoot:Debug("Unknown classId", self.classId)
    return true
  end

  local itemClassTable = ClassFilterTable[self.classId][item.classId]
  if itemClassTable and itemClassTable[item.subclassId] then
    return true
  else
    return false
  end
end
