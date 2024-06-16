local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

-- Lua APIs
local _G, setmetatable, table, tonumber = _G, setmetatable, table, tonumber

-- WoW APIs
local C_Item, BItem, GetItemInfo, ItemLocation = C_Item, Item, GetItemInfo, ItemLocation
local GetContainerItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local BIND_TRADE_TIME_REMAINING, NUM_BAG_SLOTS = BIND_TRADE_TIME_REMAINING, NUM_BAG_SLOTS
local CreateFrame, UIParent = CreateFrame, UIParent

local Item = {}
Item.__index = Item
NotaLoot.Item = Item

-- Dummy frame used for scanning tooltip for BIND_TRADE_TIME_REMAINING
-- https://wowpedia.fandom.com/wiki/UIOBJECT_GameTooltip
local Tooltip = CreateFrame("GameTooltip", "NotaLootItemTooltip", nil, "GameTooltipTemplate")
Tooltip:SetOwner(UIParent, "ANCHOR_NONE")

function Item:CreateForLink(itemLink)
  local itemId, itemName = itemLink:match("|Hitem:(%d+).+|h%[(.+)%]|h")
  if not itemId then return nil end

  itemId = tonumber(itemId)

  local item = {
    id = itemId,
    isBound = false,
  }
  setmetatable(item, Item)

  NotaLoot:AddMessageSystem(item)

  -- GetItemInfo returns nil if the item has not yet been cached
  -- If not cached, we have to load it first before populating properties
  if C_Item.IsItemDataCachedByID(itemId) then
    item:PopulateStaticProperties(itemLink, itemName)
  else
    BItem:CreateFromItemID(itemId):ContinueOnItemLoad(function()
      item:PopulateStaticProperties(itemLink, itemName)
    end)
  end

  return item
end

function Item:CreateFromContainer(bag, slot)
  local link = GetContainerItemLink(bag, slot)
  if not link then return nil end

  local item = Item:CreateForLink(link)
  item.location = ItemLocation:CreateFromBagAndSlot(bag, slot)
  item.guid = C_Item.GetItemGUID(item.location)
  item.isBound = C_Item.IsBound(item.location)

  return item
end

function Item:CreateFromLocation(location)
  if not location.bagID or not location.slotIndex then return nil end
  return Item:CreateFromContainer(location.bagID, location.slotIndex)
end

function Item:PopulateStaticProperties(link, name)
  self.name, self.link, self.quality, self.ilvl, self.minLevel, _, _, _, self.equipLoc, self.texture, _, self.classId, self.subclassId = GetItemInfo(self.id)
  if not self.name then
    NotaLoot:Error("Invalid itemId", self.id)
  end

  -- To handle items with variable suffixes, if is passed directly from the container item,
  -- instead of loaded from GetItemInfo, which returns only the link without suffixes
  if link then self.link = link end
  if name then self.name = name end

  self:FireMessage(NotaLoot.MESSAGE.ON_CHANGE)
end

function Item:IsTradeable()
  if not self.location then return false end

  -- Search the item's tooltip for the BIND_TRADE_TIME_REMAINING text
  -- Sadly there doesn't seem to be a better way...
  Tooltip:ClearLines()
  Tooltip:SetBagItem(self.location:GetBagAndSlot())

  for i = 1, Tooltip:NumLines() do
    local line = _G["NotaLootItemTooltipTextLeft"..i]:GetText()
    if(string.find(line, string.format(BIND_TRADE_TIME_REMAINING, ".*"))) then
      return true
    end
  end

  return false
end

function Item:GetStatus()
  return self.info and self.info.status or NotaLoot.STATUS.NONE
end

function Item:SetStatus(status)
  local info = self.info or {}
  if status ~= info.status then
    info.status = status
    self.info = info
    self:FireMessage(NotaLoot.MESSAGE.ON_CHANGE)
  end
end

function Item:GetWinner()
  return self.info and self.info.winner or nil
end

function Item:SetWinner(winner)
  local info = self.info or {}
  if winner ~= info.winner then
    info.winner = winner

    if winner then
      info.status = NotaLoot.STATUS.ASSIGNED
    end

    self.info = info
    self:FireMessage(NotaLoot.MESSAGE.ON_CHANGE)
  end
end

function Item:UpdateLocation()
  if not self.guid then return end

  -- C_Item:GetItemLocation(guid) doesn't seem to be available yet...
  -- So implementing the lookup manually
  local loc = self.location

  -- Check if location hasn't changed (no update needed)
  if loc and C_Item.DoesItemExist(loc) and C_Item.GetItemGUID(loc) == self.guid then
    return
  end

  -- Find the new location somewhere in our inventory
  self.location = self:LocationInInventory(function(loc)
    return C_Item.GetItemGUID(loc) == self.guid
  end)
end

function Item:LocationInInventory(filter)
  local loc = self.location or ItemLocation:CreateEmpty()

  -- Iterate over inventory to find a location matching the filter
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots(bag) do
      loc:SetBagAndSlot(bag, slot)
      if C_Item.DoesItemExist(loc) and filter(loc) then
        return loc
      end
    end
  end

  -- Item not found in inventory
  return nil
end

function Item:Encode()
  return table.concat({ self.link, self.info.status, self.info.winner }, NotaLoot.SEPARATOR.ELEMENT)
end

function Item:Decode(encodedStr)
  local elements = NotaLoot:Split(encodedStr, NotaLoot.SEPARATOR.ELEMENT)

  local item = self:CreateForLink(elements[1])
  item.info = { status = tonumber(elements[2]), winner = elements[3] }

  return item
end
