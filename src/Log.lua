local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

-- Lua APIs
local setmetatable, string, table = setmetatable, string, table

-- WoW APIs
local date, GetServerTime = date, GetServerTime

-- Abstract class

local Log = {}

function Log:_Create(t)
  t = t or {}
  setmetatable(t, self)
  self.__index = self
  return t
end

function Log:Write(...)
end

function Log:Dump()
end

function Log:Clear()
end

-- DebugLog

local DebugLog = Log:_Create()
NotaLoot.DebugLog = DebugLog

function DebugLog:Create()
  return DebugLog:_Create({
    name = "Debug Log",
    lines = {},
  })
end

function DebugLog:Write(...)
  local line = string.format("%s %s", date("%H:%M:%S"), table.concat({...}, " "))
  table.insert(self.lines, line)
end

function DebugLog:Dump()
  local header = "NotaLoot "..NotaLoot.version.."\n"
  return header..table.concat(self.lines, "\n")
end

function DebugLog:Clear()
  self.lines = {}
end

-- SessionLog

local SessionLog = Log:_Create()
NotaLoot.SessionLog = SessionLog

function SessionLog:Create()
  return SessionLog:_Create({
    name = "Session Log",
    assignments = {}, -- { date, itemID, itemName, player, note }
    indexes = {}, -- { item: index }
  })
end

function SessionLog:Write(item, bid)
  if not item then return end

  if self.indexes[item] then
    table.remove(self.assignments, self.indexes[item])
  end

  local assignment = {
    date("%d-%m-%Y"),
    item.id or 0,
    item.name or "",
    item:GetWinner() or "",
    NotaLoot.BID_TEXT[bid or 0] or "",
  }

  table.insert(self.assignments, assignment)
  self.indexes[item] = #self.assignments
end

function SessionLog:Dump()
  local assignmentCount = #self.assignments
  if assignmentCount == 0 then return "" end

  local header = "date,itemID,itemName,player,note"
  local lines = { header }

  for i = 1, assignmentCount do
    table.insert(lines, table.concat(self.assignments[i], ","))
  end

  return table.concat(lines, "\n")
end

function SessionLog:Clear()
  self.assignments = {}
  self.indexes = {}
end
