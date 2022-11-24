local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

local Session = {}
Session.__index = Session
NotaLoot.Session = Session

-- Lua APIs
local pairs, math, setmetatable = pairs, math, setmetatable
local string, table, tonumber = string, table, tonumber

function Session:Create(owner)
  local session = {
    owner = owner,
    items = {},
    bids = {},
    assignments = {},
  }
  setmetatable(session, Session)

  NotaLoot:AddMessageSystem(session)

  return session
end

function Session:EnableLog()
  if not self.log then
    self.log = NotaLoot.SessionLog:Create()
  end
end

function Session:ClearLog()
  if self.log then self.log:Clear() end
end

function Session:Contains(item)
  if not item or not item.guid then return false end

  for _, it in pairs(self.items) do
    if it.guid == item.guid then return true end
  end

  return false
end

function Session:AddItem(item, index, skipLog)
  if not item then return false end

  -- Disallow soulbound items
  if item.isBound and not item:IsTradeable() then
    if not skipLog then
      NotaLoot:Error("Soulbound items can't be added to the loot session")
    end
    return false
  end

  -- Disallow duplicate items (by guid)
  if self:Contains(item) then
    if not skipLog then
      NotaLoot:Error("That item is already in the loot session!")
    end
    return false
  end

  index = index or (self:GetItemCount() + 1)
  self.items[index] = item

  if item:GetStatus() == NotaLoot.STATUS.NONE then
    item:SetStatus(NotaLoot.STATUS.BIDDING)
  end

  self:SendMessage(NotaLoot.MESSAGE.ADD_ITEM, index, item)
  self:SendMessage(NotaLoot.MESSAGE.ON_CHANGE, index)

  return true
end

function Session:GetItemAtIndex(index)
  return self.items[index]
end

function Session:GetIndexOfItem(item)
  if not item then return nil end
  for index, it in pairs(self.items) do
    if it == item then return index end
  end
  return nil
end

function Session:GetItemCount()
  local maxIndex = 0
  for index in pairs(self.items) do
    maxIndex = math.max(maxIndex, index)
  end
  return maxIndex
end

function Session:GetBidForPlayer(item, player)
  local itemBids = self.bids[item]
  if not itemBids then return nil end
  return itemBids[player]
end

function Session:GetBidCountForItem(item, includePass)
  local itemBids = self.bids[item]
  if not itemBids then return 0 end

  local count = 0
  for _, bid in pairs(itemBids) do
    if bid ~= NotaLoot.BID.PASS or includePass then
      count = count + 1
    end
  end

  return count
end

function Session:RegisterBid(player, item, bid)
  if not item then return end
  if item:GetStatus() ~= NotaLoot.STATUS.BIDDING then
    NotaLoot:Error("Attempted to bid on '"..item.name.."' not in bidding state")
    return
  end

  local itemBids = self.bids[item] or {}

  if itemBids[player] ~= bid then
    itemBids[player] = bid
    self.bids[item] = itemBids
    self:SendMessage(NotaLoot.MESSAGE.BID_ITEM, item, bid, player)
  end
end

function Session:AssignItem(item, winner)
  if not item or self.assignments[item] == winner then return end

  self.assignments[item] = winner
  item:SetWinner(winner)

  if self.log then
    self.log:Write(item, self:GetBidForPlayer(item, winner))
  end

  self:SendMessage(NotaLoot.MESSAGE.ASSIGN_ITEM, item, winner)
end

function Session:GetItemsAssignedToPlayer(player)
  local items = {}

  for item, winner in pairs(self.assignments) do
    if winner == player then table.insert(items, item) end
  end

  return items
end

function Session:RemoveItem(item)
  local index = self:GetIndexOfItem(item)
  if not index then return end
  self:RemoveItemAtIndex(index)
end

function Session:RemoveItemAtIndex(index)
  local itemCount = self:GetItemCount()
  if index < 0 or index > itemCount then return end

  local item = self.items[index]

  -- Shift every item forward
  for i = index + 1, itemCount do
    self.items[i - 1] = self.items[i]
  end
  self.items[itemCount] = nil

  if item then
    self.bids[item] = nil
    self.assignments[item] = nil
  end

  self:SendMessage(NotaLoot.MESSAGE.DELETE_ITEM, index, item)
  self:SendMessage(NotaLoot.MESSAGE.ON_CHANGE, index)
end

function Session:RemoveItemsWithoutLocation()
  local removals = {}

  for _, item in pairs(self.items) do
    if item then item:UpdateLocation() end
    if not item or not item.location then
      table.insert(removals, item)
    end
  end

  for i = 1, #removals do
    self:RemoveItem(removals[i])
  end
end

function Session:Clear()
  self.items = {}
  self.bids = {}
  self.assignments = {}

  self:SendMessage(NotaLoot.MESSAGE.DELETE_ALL_ITEMS)
  self:SendMessage(NotaLoot.MESSAGE.ON_CHANGE)
end

function Session:EncodeItems()
  local items = {}
  for index, item in pairs(self.items) do
    table.insert(items, index)
    table.insert(items, item:Encode())
  end
  return table.concat(items, NotaLoot.SEPARATOR.LIST_ELEMENT)
end

function Session:EncodeBids()
  local bids = {}
  for item, itemBids in pairs(self.bids) do
    table.insert(bids, self:GetIndexOfItem(item))

    local bidPairs = {}
    for player, bid in pairs(itemBids) do
      table.insert(bidPairs, player)
      table.insert(bidPairs, bid)
    end

    table.insert(bids, table.concat(bidPairs, NotaLoot.SEPARATOR.SUBLIST_ELEMENT))
  end
  return table.concat(bids, NotaLoot.SEPARATOR.LIST_ELEMENT)
end

function Session:ImportItems(encodedItems)
  self.items = {}

  if not encodedItems then return end
  local elements = NotaLoot:Split(encodedItems, NotaLoot.SEPARATOR.LIST_ELEMENT)

  for i = 1, #elements, 2 do
    local index = tonumber(elements[i])
    local decodedItem = NotaLoot.Item:Decode(elements[i + 1])

    if index and decodedItem then
      self.items[index] = decodedItem
    end
  end

  self:SendMessage(NotaLoot.MESSAGE.ON_CHANGE)
end

function Session:ImportBids(encodedBids)
  self.bids = {}

  if not encodedBids then return end
  local elements = NotaLoot:Split(encodedBids, NotaLoot.SEPARATOR.LIST_ELEMENT)

  for i = 1, #elements, 2 do
    local index = tonumber(elements[i])
    local item = self:GetItemAtIndex(index)

    if item then
      local itemBids = {}
      local bidElements = NotaLoot:Split(elements[i + 1], NotaLoot.SEPARATOR.SUBLIST_ELEMENT)
      for j = 1, #bidElements, 2 do
        itemBids[bidElements[j]] = tonumber(bidElements[j + 1])
      end

      self.bids[item] = itemBids
    end
  end

  self:SendMessage(NotaLoot.MESSAGE.ON_CHANGE)
end
