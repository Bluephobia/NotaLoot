local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

local MessageQueue = {}
MessageQueue.__index = MessageQueue
NotaLoot.MessageQueue = MessageQueue

-- Lua APIs
local setmetatable = setmetatable

-- WoW APIs
local CreateObjectPool = CreateObjectPool

function MessageQueue:Create()
  local queue = {
    head = 0,
    tail = -1,
    messagePool = CreateObjectPool(function() return {} end)
  }
  setmetatable(queue, MessageQueue)
  return queue
end

function MessageQueue:IsEmpty()
  return self.head > self.tail
end

function MessageQueue:Enqueue(payload, channel, target)
  self.tail = self.tail + 1

  local message = self.messagePool:Acquire()
  message.payload = payload
  message.channel = channel
  message.target = target

  self[self.tail] = message
end

function MessageQueue:Peek()
  if self:IsEmpty() then return end

  local value = self[self.head]
  if not value then return end

  return value.payload,  value.channel, value.target
end

function MessageQueue:Dequeue()
  local head = self.head
  if head > self.tail then return end

  local value = self[head]
  self[head] = nil
  self.head = head + 1

  if not value then return end

  local payload, channel, target = value.payload, value.channel, value.target
  self.messagePool:Release(value)

  return payload, channel, target
end

function MessageQueue:Clear()
  local head, tail = self.head, self.tail
  for i = head, tail do
    self.messagePool:Release(self[i])
    self[i] = nil
  end
  self.head, self.tail = 0, -1
end

NotaLoot.messageQueue = MessageQueue:Create()
