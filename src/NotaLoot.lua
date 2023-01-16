local CallbackHandler = LibStub("CallbackHandler-1.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

-- Lua APIs
local pairs, print, table, type, unpack = pairs, print, table, type, unpack

-- WoW APIs
local C_Timer, FlashClientIcon, IsInGroup = C_Timer, FlashClientIcon, IsInGroup
local GetAddOnMetadata, InCombatLockdown, UnitName = GetAddOnMetadata, InCombatLockdown, UnitName
local GetNumGuildMembers, GetGuildRosterInfo = GetNumGuildMembers, GetGuildRosterInfo
local RaidNotice_AddMessage, RaidWarningFrame = RaidNotice_AddMessage, RaidWarningFrame

-- Addon setup

local AddonName = "NotaLoot"
local Version = GetAddOnMetadata(AddonName, "Version")
local CommPrefix = AddonName..Version:sub(Version:find("[^.]*"))

local NotaLoot = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceComm-3.0", "AceEvent-3.0")
NotaLoot.version = Version
-- NotaLoot.debugPrint = true

-- Constants

NotaLoot.BID = {
  PASS = 1,
  BIS = 2,
  UPGRADE = 3,
  OS = 4,
}

NotaLoot.BID_TEXT = {
  "Pass",
  "BIS",
  "Upgrade",
  "OS",
}

NotaLoot.MESSAGE = {
  ADD_ITEM = "Add",
  ASSIGN_ITEM = "Assign",
  BID_ITEM = "Bid",
  DELETE_ITEM = "Delete",
  DELETE_ALL_ITEMS = "DeleteAll",
  INIT = "Init",
  ON_CHANGE = "OnChange",
  OPEN_CLIENT = "OpenClient",
  SYNC_REQUEST = "SyncReq",
  SYNC_RESPONSE = "Sync",
  VIEW_REQUEST = "ViewReq",
  VIEW_RESPONSE = "View",
}

NotaLoot.SEPARATOR = {
  ARG = ";",
  ELEMENT = ",",
  LIST_ELEMENT = ":",
  MESSAGE = "&",
  SUBLIST_ELEMENT = "/",
}

NotaLoot.STATUS = {
  BIDDING = 1,
  ASSIGNED = 2,
}

-- Lifecycle

function NotaLoot:OnInitialize()
  -- During initialization commands are queued
  self.initializing = true
  self.commandQueue = {}

  SLASH_NOTALOOT1 = "/nl"
  SlashCmdList["NOTALOOT"] = function(...) self:ProcessCommand("nl", ...) end

  SLASH_NOTALOOTMASTER1 = "/nlm"
  SlashCmdList["NOTALOOTMASTER"] = function(...) self:ProcessCommand("nlm", ...) end

  self:RegisterComm(CommPrefix)
  self:RegisterOptionsTable()

  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("GROUP_JOINED")
  self:RegisterEvent("GROUP_LEFT")
end

function NotaLoot:OnEnable()
  self.player = UnitName("player")
  self.playerClass = select(3, UnitClass("player"))

  -- Addon messages are rate limited
  -- To work around this, send at most 1 message every 750ms (empirical "safe" interval)
  -- In practice this mostly rate limits broadcast messages, but those can be combined anyway
  self.messageTimer = C_Timer.NewTicker(0.75, function()
    self:SendCommImmediate()
  end)
end

function NotaLoot:PLAYER_ENTERING_WORLD(_, login, reload)
  if login or reload then
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    -- There is some period of time after logging in or reloading where addon messages aren't sent
    -- This delay is an attempt to wait a "safe" amount of time before attempting init messages
    C_Timer.After(8, function()
      self.initializing = false
      if IsInGroup() then
        self:GROUP_JOINED()
      end
      self:ProcessQueuedCommands()
    end);
  end
end

function NotaLoot:GROUP_JOINED()
  if self.initializing then return end
  self:Broadcast(NotaLoot.MESSAGE.INIT, self.version) -- Inform raid of my version
  self:Broadcast(NotaLoot.MESSAGE.DELETE_ALL_ITEMS) -- Delete any items from my previous session
  self:Broadcast(NotaLoot.MESSAGE.SYNC_REQUEST) -- Sync with existing sessions
end

function NotaLoot:GROUP_LEFT()
  self.client:Reset()
  self.master:DisconnectViewers()
  self.master:StopViewingRemoteSession()
end

-- Commands

function NotaLoot:ProcessCommand(cmd, ...)
  local arg = select(1, ...)

  if arg == "opt" then
    InterfaceOptionsFrame_Show()
    InterfaceOptionsFrame_OpenToCategory(AddonName)
  elseif arg == "dlog" then
    NotaLoot.GUI:ShowLogWindow(self.debugLog)
  elseif cmd == "nlm" and arg == "export" then
    NotaLoot.GUI:ShowLogWindow(self.master.session.log)
  elseif self.initializing then
    self:Info("Initializing... one moment please!")
    self.commandQueue[cmd] = true
  elseif cmd == "nl" then
    self.client:Toggle()
  elseif cmd == "nlm" then
    self.master:Toggle()
  end
end

function NotaLoot:ProcessQueuedCommands()
  for cmd in pairs(self.commandQueue) do
    self:ProcessCommand(cmd)
  end
  self.commandQueue = {}
end

-- Communication

function NotaLoot:Broadcast(msg, data)
  self:SendComm(msg, data, "RAID")
end

-- This is an addon message whisper not a chat whisper
function NotaLoot:Whisper(msg, data, target)
  if not target then
    self:Debug("Attempted to whisper invalid target", target)
    return
  end
  self:SendComm(msg, data, "WHISPER", target)
end

function NotaLoot:SendComm(msg, data, channel, target)
  data = type(data) == 'table' and table.concat(data, NotaLoot.SEPARATOR.ARG) or data
  local payload = data and msg..NotaLoot.SEPARATOR.ARG..data or msg

  -- Messages are sent at a recurring interval to avoid being rate limited
  self.messageQueue:Enqueue(payload, channel, target)
end

function NotaLoot:OnCommReceived(prefix, encodedPayload, channel, sender)
  if sender == NotaLoot.player and channel ~= "WHISPER" then return end

  local decodedPayload = LibDeflate:DecodeForWoWAddonChannel(encodedPayload)
  if not decodedPayload then self:Debug("Failed to decode", encodedPayload); return end
  local decompressedPayload = LibDeflate:DecompressDeflate(decodedPayload)
  if not decompressedPayload then self:Debug("Failed to decompress", encodedPayload); return end
  local success, payload = LibSerialize:Deserialize(decompressedPayload)
  if not success then self:Debug("Failed to deserialize", encodedPayload); return end

  self:Debug("OnCommReceived", payload, channel, sender)

  local messages = self:Split(payload, NotaLoot.SEPARATOR.MESSAGE)

  for i = 1, #messages do
    local data = self:Split(messages[i], NotaLoot.SEPARATOR.ARG)
    local msg = table.remove(data, 1)
    if not msg then return end

    self:SendMessage(msg, sender, unpack(data))
  end
end

-- Do not invoke this function directly
-- It's called from a recurring timer to avoid addon message rate limiting
function NotaLoot:SendCommImmediate()
  local payload, channel, target = self.messageQueue:Dequeue()

  -- Keep pulling messages with the same destination, because they can be combined
  while not self.messageQueue:IsEmpty() do
    local nextPayload, nextChannel, nextTarget = self.messageQueue:Peek()
    if not nextPayload or nextChannel ~= channel or nextTarget ~= target then break end
    payload = payload..NotaLoot.SEPARATOR.MESSAGE..nextPayload
    self.messageQueue:Dequeue()
  end

  if not payload then return end

  self:Debug("SendCommImmediate", payload, channel, target)

  local serializedPayload = LibSerialize:Serialize(payload)
  local compressedPayload = LibDeflate:CompressDeflate(serializedPayload)
  local encodedPayload = LibDeflate:EncodeForWoWAddonChannel(compressedPayload)

  self:SendCommMessage(CommPrefix, encodedPayload, channel, target)
end

function NotaLoot:OnVersionReceived(remoteVersion)
  if not self.versionUpdateAvailable and self:CompareVersion(remoteVersion) > 0 then
    self.versionUpdateAvailable = true
    self:Info("A newer version", remoteVersion, "is available. Please consider updating.")
  end
end

function NotaLoot:NotifyLocal(msg, r, g, b)
  if msg and not InCombatLockdown() then
    local color = { r = r or 1, g = g or 0.96, b = b or 0.41 }
    RaidNotice_AddMessage(RaidWarningFrame, "[NotaLoot] "..msg, color, 5);
  end
  FlashClientIcon()
end

-- Persistence

function NotaLoot:SetPref(key, value)
  if not self.prefs then self.prefs = NotaLootPrefs or {} end
  self.prefs[key] = value
  NotaLootPrefs = self.prefs
end

function NotaLoot:GetPref(key, default)
  if not self.prefs then self.prefs = NotaLootPrefs or {} end

  if self.prefs[key] == nil then
    return default
  end

  return self.prefs[key]
end

-- Utility

function NotaLoot:Debug(...)
  if self.debugPrint then
    self:Info(...)
  end
  self:Log("[Debug]", ...)
end

function NotaLoot:Info(...)
  print("|cFFFF6900[NotaLoot]|cFFFFFFFF", ...)
  self:Log("[Info]", ...)
end

function NotaLoot:Error(...)
  print("|cFFFF6900[NotaLoot]|cFFFF0000 Error:|cFFFFFFFF", ...)
  self:Log("[Error]", ...)
end

function NotaLoot:Log(...)
  if self:GetPref("DebugLog") then
    if not self.debugLog then self.debugLog = NotaLoot.DebugLog:Create() end
    self.debugLog:Write(...)
  end
end

function NotaLoot:Split(str, sep)
  local t = {}
  for s in str:gmatch("([^"..sep.."]+)") do
    table.insert(t, s)
  end
  return t
end

function NotaLoot:GetGuildRank(playerName)
  local count = GetNumGuildMembers()

  for i = 1, count do
    local name, _, rankIdx = GetGuildRosterInfo(i)
    name = self:Split(name, "-")[1]

    if name == playerName then
      return rankIdx
    end
  end

  return nil
end

function NotaLoot:AddMessageSystem(target)
  if target.messageSystem then return end

  local messageSystem = {}
  messageSystem.callbacks = CallbackHandler:New(messageSystem)
  target.messageSystem = messageSystem

  target.RegisterMessage = messageSystem.RegisterCallback
  target.UnregisterMessage = messageSystem.UnregisterCallback
  target.UnregisterAllMessages = messageSystem.UnregisterAllCallbacks
  target.SendMessage = function(self, msg, ...) messageSystem.callbacks:Fire(msg, self, ...) end
end

function NotaLoot:HookMessageSystem(target, callback)
  if not target.messageSystem or target.messageSystem.hooked then return end
  target.messageSystem.hooked = true

  local sendMessage = target.SendMessage
  target.SendMessage = function(self, msg, ...)
    callback(msg, self, ...)
    sendMessage(self, msg, ...)
  end
end

function NotaLoot:CompareVersion(remoteVersion)
  local versionRegex = "([^.]*).([^.]*).([^.]*)"
  local l1, l2, l3 = self.version:match(versionRegex)
  local r1, r2, r3 = remoteVersion:match(versionRegex)

  if r1 > l1 then return 1 end -- Remote major is higher
  if r1 < l1 then return -1 end -- Remote major is lower

  -- Remote major is the same
  if r2 > l2 then return 1 end -- Remote minor is higher
  if r2 < l2 then return -1 end -- Remote minor is lower

  -- Remote minor is the same
  if r3 > l3 then return 1 end -- Remote patch is higher
  if r3 < l3 then return -1 end -- Remote patch is lower

  -- Versions are identical
  return 0
end
