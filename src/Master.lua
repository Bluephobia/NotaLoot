local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

local Master = {}
Master.__index = Master
NotaLoot.Master = Master

LibStub("AceHook-3.0"):Embed(Master)

-- Lua APIs
local pairs, math, setmetatable = pairs, math, setmetatable
local string, table, tonumber = string, table, tonumber

-- WoW APIs
local CloseDropDownMenus, CreateFrame, InCombatLockdown = CloseDropDownMenus, CreateFrame, InCombatLockdown
local LOOT_ITEM_SELF, MAX_TRADABLE_ITEMS, TradeFrame = LOOT_ITEM_SELF, MAX_TRADABLE_ITEMS, TradeFrame
local SendChatMessage, SendSystemMessage = SendChatMessage, SendSystemMessage
local UseContainerItem = C_Container and C_Container.UseContainerItem or UseContainerItem
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth

-- Lifecycle

function Master:Create()
  local master = {
    viewers = {},
    pendingAutoAddedItems = {},
  }
  setmetatable(master, Master)

  master.session = master:CreateSession()

  -- Remote messages
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.INIT, function(_, sender, version)
    master:OnRemoteInit(sender, version)
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.BID_ITEM, function(_, sender, index, bid, ...)
    master:OnBidRequest(sender, tonumber(index), tonumber(bid), ...)
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.SYNC_REQUEST, function(_, sender)
    master:OnSyncRequest(sender)
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.VIEW_REQUEST, function(_, sender, view)
    view = (view == "true")
    master:OnViewRequest(sender, view)
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.VIEW_RESPONSE, function(_, sender, granted, encodedBids)
    granted = (granted == "true")
    master:OnViewResponse(sender, granted, encodedBids)
  end)

  -- Local events
  master:SecureHook("ContainerFrameItemButton_OnModifiedClick")
  NotaLoot:RegisterEvent("TRADE_SHOW", function()
    master:OnTradeOpened()
  end)
  -- This event is no longer fired in 3.4.1 - workaround below
  -- NotaLoot:RegisterEvent("BAG_UPDATE_DELAYED", function()
  --   master:OnInventoryUpdate()
  -- end)
  NotaLoot:RegisterEvent("BAG_UPDATE", function()
    C_Timer.After(0.001, function() master:OnInventoryUpdate() end)
  end)
  NotaLoot:RegisterEvent("CHAT_MSG_LOOT", function(_, ...)
    master:OnLootMessage(...)
  end)

  return master
end

function Master:CreateWindow()
  local window = NotaLoot.GUI:CreateWindow("NotaLootMaster", "NotaLoot Master - v"..NotaLoot.version)
  window.content.yOffset = -20

  local clearButton = CreateFrame("Button", nil, window.frame, "UIPanelButtonTemplate")
  clearButton:SetPoint("TOPRIGHT", -16, -16)
  clearButton:SetSize(100, 22)
  clearButton:SetScript("OnClick", function() self:OnClearButtonClicked() end)
  window.clearButton = clearButton

  local openClientButton = CreateFrame("Button", nil, window.frame, "UIPanelButtonTemplate")
  openClientButton:SetText("Open Client")
  openClientButton:SetPoint("TOPLEFT", 16, -16)
  openClientButton:SetSize(100, 22)
  openClientButton:SetScript("OnClick", function()
    NotaLoot:Broadcast(NotaLoot.MESSAGE.OPEN_CLIENT)
    NotaLoot.client:Show()
  end)

  local instructions = CreateFrame("Frame", nil, window.frame)
  instructions:SetAllPoints(window.content)
  window.instructions = instructions

  local instructionsText  = instructions:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
  instructionsText:SetText("Alt + Left-Click items in your inventory\nto add them to the loot session.\n\n\nOr you can request to view another loot master's session using the dropdown below.")
  instructionsText:SetSize(300, 100)
  instructionsText:SetJustifyH("CENTER")
  instructionsText:SetJustifyV("CENTER")
  instructionsText:SetPoint("CENTER", 0, 20)

  local sessionsDropdown = CreateFrame("Frame", "NotaLootViewableSessionsDropdown", instructions, "UIDropDownMenuTemplate")
  sessionsDropdown:SetPoint("CENTER", 0, -50)
  UIDropDownMenu_SetWidth(sessionsDropdown, 150)
  sessionsDropdown.initialize = function(_, level, menuList)
    self:ConfigureSessionsDropdown(level, menuList)
  end
  instructions.dropdown = sessionDropdown

  window:DoLayout()

  return window
end

function Master:Show()
  if not self.window then
    self.window = self:CreateWindow()
  end

  self.window:Show()

  self:UpdateStatusText()
  self:UpdateInstructions()
  self:ReloadTable()
end

function Master:Toggle()
  if self.window and self.window:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function Master:Hide()
  if self.window then self.window:Hide() end
end

-- GUI

function Master:UpdateStatusText()
  local window = self.window
  if not window or not window:IsShown() then return end

  local session = self.session

  if session.owner or self.pendingViewRequest then
    window.clearButton:SetText("Stop Viewing")
    window.statusTooltip = nil

    if session.owner then
      window.tipText:SetText(string.format("Viewing %s's Session", session.owner))
    else
      window.tipText:SetText(nil)
    end
  else
    window.clearButton:SetText("Clear All")

    local viewers = {}
    for viewer in pairs(self.viewers) do
      table.insert(viewers, viewer)
    end

    if #viewers > 0 then
      window.statusTooltip = table.concat(viewers, "\n")
      window.tipText:SetText(string.format("%d remote %s", #viewers, #viewers == 1 and "viewer" or "viewers"))
    else
      window.statusTooltip = nil
      window.tipText:SetText(nil)
    end
  end

  if self.pendingViewRequest then
    window:SetStatusText(string.format("Requesting to view %s's Session...", self.pendingViewRequest))
  else
    window:SetStatusText("Total Items: "..session:GetItemCount())
  end
end

function Master:UpdateInstructions()
  if not self.window or not self.window:IsShown() then return end

  if self.session.owner or self.pendingViewRequest or self.session:GetItemCount() > 0 then
    self.window.instructions:Hide()
  else
    self.window.instructions:Show()
  end
end

function Master:ReloadTable()
  if not self.window or not self.window:IsShown() then return end

  local table = self.window.table
  local savedScroll = (table.status or table.localstatus).scrollvalue

  table:Clear()

  for index, item in pairs(self.session.items) do
    table:CreateRow("NotaLootItemRow", index, item, function(r, i)
      self:ConfigureItemRow(r, i)
    end)
  end

  table:SetScroll(savedScroll)
end

function Master:ConfigureItemRow(row, item)
  row.image:SetTexture(item.texture)
  row.ilvlText:SetText(item.ilvl)
  row.linkText:SetText(item.link)

  local bidCount = self.session:GetBidCountForItem(item)

  row:SetBidTextVisible(true)
  row.bidText:SetText(string.format("%d %s", bidCount, bidCount == 1 and "Bid" or "Bids"))

  row:SetDropdownText(item:GetWinner(), "Assignment")
  row:SetDropDownEnabled(bidCount > 0)
  row.dropdownConfig = function(_, level, menuList) self:ConfigureItemDropdown(item, level, menuList) end

  row:SetDeleteButtonVisible(not self.session.owner)
  row:RegisterMessage(NotaLoot.MESSAGE.DELETE_ITEM, function() self.session:RemoveItem(item) end)
end

function Master:ConfigureItemDropdown(item, level, menuList)
  local itemBids = self.session.bids[item]
  if not itemBids then return end

  if level == 1 then -- Top level menus
    local menuInfo = UIDropDownMenu_CreateInfo()
    menuInfo.notCheckable = true
    menuInfo.hasArrow = true

    for bid, text in pairs(NotaLoot.BID_TEXT) do
      if bid ~= NotaLoot.BID.PASS then
        local count = 0
        for _, it in pairs(itemBids) do
          if it == bid then count = count + 1 end
        end
        if count > 0 then
          menuInfo.text = string.format("%s (%d)", text, count)
          menuInfo.menuList = bid
          UIDropDownMenu_AddButton(menuInfo)
        end
      end
    end
  else -- Sub menus
    local menuInfo = UIDropDownMenu_CreateInfo()
    local biddingPlayers = {}

    for player, bid in pairs(itemBids) do
      if menuList == bid then
        table.insert(biddingPlayers, player)

        menuInfo.text = player
        menuInfo.func = function()
          CloseDropDownMenus()
          self:AssignItem(item, player)
        end
        UIDropDownMenu_AddButton(menuInfo, level)
      end
    end

    -- If more than 1 player has bid, show the Randomize option
    if #biddingPlayers > 1 then
      menuInfo.icon = "interface/buttons/ui-grouploot-dice-up"
      menuInfo.text = "Randomize"
      menuInfo.func = function()
        CloseDropDownMenus()

        local randomWinner = biddingPlayers[math.random(1, #biddingPlayers)]
        self:AssignItem(item, randomWinner, true)
      end
      UIDropDownMenu_AddButton(menuInfo, level)
    end
  end
end

function Master:ConfigureSessionsDropdown(level, menuList)
  local sessions = NotaLoot.client.sessions
  if not sessions then return end

  local menuInfo = UIDropDownMenu_CreateInfo()
  menuInfo.notCheckable = true

  for _, session in pairs(sessions) do
    if session.owner and session.owner ~= NotaLoot.player then
      menuInfo.text = string.format("%s's Session", session.owner)
      menuInfo.func = function() self:RequestToViewRemoteSession(session) end
      UIDropDownMenu_AddButton(menuInfo)
    end
  end
end

-- Actions

function Master:CreateSession()
  local session = NotaLoot.Session:Create()
  session:EnableLog()

  session:RegisterMessage(NotaLoot.MESSAGE.ADD_ITEM, function(_, _, index, item)
    self:OnAddItem(index, item)
  end)
  session:RegisterMessage(NotaLoot.MESSAGE.BID_ITEM, function(_, _, item)
    self:ReloadItem(item)
  end)
  session:RegisterMessage(NotaLoot.MESSAGE.ASSIGN_ITEM, function(_, _, item, winner, isByRandom)
    self:OnAssignItem(item, winner, isByRandom)
  end)
  session:RegisterMessage(NotaLoot.MESSAGE.DELETE_ITEM, function(_, _, index)
    self:OnDeleteItem(index)
  end)
  session:RegisterMessage(NotaLoot.MESSAGE.ON_CHANGE, function(_, _, ...)
    self:OnSessionChanged(...)
  end)

  return session
end

function Master:RequestToViewRemoteSession(session)
  if not session or not session.owner or session.owner == NotaLoot.player then return end

  if self.pendingViewRequest then
    NotaLoot:Debug("Attempted to view", session.owner, "while already requesting to view", self.pendingViewRequest)
    return
  end

  self.pendingViewRequest = session.owner
  NotaLoot:Whisper(NotaLoot.MESSAGE.VIEW_REQUEST, "true", session.owner)

  self:OnSessionChanged()
end

function Master:StopViewingRemoteSession()
  if self.pendingViewRequest then
    NotaLoot:Whisper(NotaLoot.MESSAGE.VIEW_REQUEST, "false", self.pendingViewRequest)
    self.pendingViewRequest = nil
  end

  if self.session.owner then
    NotaLoot:Whisper(NotaLoot.MESSAGE.VIEW_REQUEST, "false", self.session.owner)
    self.session = self:CreateSession()
  end

  self:OnSessionChanged()
end

function Master:DisconnectViewers()
  for viewer in pairs(self.viewers) do
    self:DeclineViewRequest(viewer)
  end
  self.viewers = {}
end

function Master:ConfirmViewRequest(sender)
  -- Check whether the requester is a guild officer that should be allowed automatically
  if NotaLoot:GetPref("AutoAllowOfficers", true) and NotaLoot:IsGuildOfficer(sender) then
    self:AllowViewRequest(sender)
    return
  end

  -- Show confirmation dialog for all other requests
  NotaLoot.GUI:ShowViewConfirmation(sender, function()
    self:AllowViewRequest(sender)
  end, function()
    self:DeclineViewRequest(sender)
  end)
end

function Master:AllowViewRequest(sender)
  NotaLoot:Whisper(NotaLoot.MESSAGE.VIEW_RESPONSE, { "true", self.session:EncodeBids() }, sender)

  self.viewers[sender] = true
  self:UpdateStatusText()

  NotaLoot:Info(sender, "is now viewing bids in your session.")
end

function Master:DeclineViewRequest(sender)
  NotaLoot.GUI:HideViewConfirmation(sender)
  NotaLoot:Whisper(NotaLoot.MESSAGE.VIEW_RESPONSE, "false", sender)
end

function Master:AssignItem(item, player, isByRandom)
  if self.session.owner then
    NotaLoot:Info("Items can only be assigned by", self.session.owner)
    return
  end
  self.session:AssignItem(item, player, isByRandom)
end

function Master:ReloadItem(item)
  local index = self.session:GetIndexOfItem(item)
  if index and self.window and self.window:IsShown() then
    self.window.table:ReloadRowAtIndex(index, item)
  end
end

function Master:ProcessAutoAddedItems()
  local count = #self.pendingAutoAddedItems

  for i = 1, count do
    local pendingItem = self.pendingAutoAddedItems[i]
    self.pendingAutoAddedItems[i] = nil

    if pendingItem then
      -- Find where the item ended up in our inventory
      -- Stop searching once successfully added to the session
      NotaLoot.Item:LocationInInventory(function(loc)
        local invItem = NotaLoot.Item:CreateFromLocation(loc)
        if invItem.id == pendingItem.id and self.session:AddItem(invItem, nil, true) then
          NotaLoot:Info("Added", invItem.link, "to the loot session")
          return true
        end
        return false
      end)
    end
  end
end

-- Events

function Master:OnAddItem(index, item)
  if not self.session.owner then
    NotaLoot:Broadcast(NotaLoot.MESSAGE.ADD_ITEM, { index, item:Encode() })
    NotaLoot.client:OnAddItem(NotaLoot.player, index, item)
  end

  if self.window and self.window:IsShown() then
    self.window.table:CreateRow("NotaLootItemRow", index, item, function(r, i)
      self:ConfigureItemRow(r, i)
    end)
  end
end

function Master:OnDeleteItem(index)
  if not self.session.owner then
    NotaLoot:Broadcast(NotaLoot.MESSAGE.DELETE_ITEM, index)
    NotaLoot.client:OnDeleteItem(NotaLoot.player, index)
  end

  if self.window and self.window:IsShown() then
    self.window.table:DeleteRowAtIndex(index, true)
  end
end

function Master:OnAssignItem(item, winner, isByRandom)
  local index = self.session:GetIndexOfItem(item)
  if not index or not winner then return end

  if not self.session.owner then
    NotaLoot:Broadcast(NotaLoot.MESSAGE.ASSIGN_ITEM, { index, winner, isByRandom and "true" or "false" })
    NotaLoot.client:OnAssignItem(NotaLoot.player, index, winner, isByRandom)
    self:ReloadItem(item)
  end

  local msgFormat = ""
  if isByRandom == true then
    msgFormat = "Assigned %s to %s by Randomize"
  else
    msgFormat = "Assigned %s to %s"
  end
  local msg = string.format(msgFormat, item.link, winner)
  local useSystemMessage = true

  if NotaLoot:GetPref("AnnounceAssign") then
    local announceChannel = NotaLoot:GetPref("AnnounceChannel")
    if (
      announceChannel == "GUILD" or
      announceChannel == "OFFICER" or
      announceChannel == "RAID" or
      announceChannel == "RAID_WARNING"
    ) then
      SendChatMessage(msg, announceChannel)
      useSystemMessage = false
    elseif announceChannel and announceChannel:len() > 0 then
      SendChatMessage(msg, "CHANNEL", nil, GetChannelName(announceChannel))
      useSystemMessage = false
    end
  end

  if useSystemMessage then
    SendSystemMessage(msg)
  end
end

function Master:OnRemoteInit(sender, version)
  -- If sender was previously a viewer it's not now due to reload or relog
  if sender and self.viewers[sender] then
    self.viewers[sender] = nil
    self:UpdateStatusText()
  end

  -- Check for version upgrade
  if version then NotaLoot:OnVersionReceived(version) end
end

function Master:OnBidRequest(sender, index, bid, bidder)
  local item = self.session:GetItemAtIndex(index)
  self.session:RegisterBid(bidder or sender, item, bid)

  -- Notify viewers as well
  for viewer in pairs(self.viewers) do
    NotaLoot:Whisper(NotaLoot.MESSAGE.BID_ITEM, { index, bid, sender }, viewer)
  end
end

function Master:OnSyncRequest(sender)
  if self.session.owner then return end -- Don't send response when viewing
  if self.session:GetItemCount() == 0 then return end -- Don't send response if empty
  local encodedItems = self.session:EncodeItems()
  NotaLoot:Whisper(NotaLoot.MESSAGE.SYNC_RESPONSE, encodedItems, sender)
end

function Master:OnViewRequest(sender, view)
  -- Decline view request if currently viewing another session
  if view and self.session.owner then
    self:DeclineViewRequest(sender)
    return
  end

  if view then
    self:ConfirmViewRequest(sender)
  else
    NotaLoot.GUI:HideViewConfirmation(sender)
    self.viewers[sender] = nil
    self:UpdateStatusText()
  end
end

function Master:OnViewResponse(sender, granted, encodedBids)
  if not granted then
    NotaLoot:Info(sender, "denied your request to view their session.")
    self:StopViewingRemoteSession()
    return
  elseif sender ~= self.pendingViewRequest then
    NotaLoot:Debug("Received granted view response from", sender, "while not requesting to view.")
    return
  end

  if self.session.owner then
    NotaLoot:Debug("Attempted to view", sender, "but already viewing", self.session.owner)
    return
  end

  -- Guard against the case where we start viewing a session while one is in progress
  -- In practice this shouldn't happen due to UI constraints
  if self.session:GetItemCount() > 0 then
    NotaLoot:Debug("Attempted to view remote session while a local one is in progress")
    return
  end

  -- Can only view sessions that are being tracked by the client
  -- In practice this should always be the case due to UI constraints
  local session = NotaLoot.client:GetSession(sender)
  if not session then
    NotaLoot:Debug("Attempted to view untracked session owned by", sender)
    return
  end

  -- "Upgrade" the tracked session to contain master info
  session:ImportBids(encodedBids)

  -- "Disconnect" any existing viewers
  self:DisconnectViewers()

  -- Finally change the session
  self.session = session
  self.pendingViewRequest = nil

  -- Only 1 callback can be registered per message type
  -- This is a workaround to hook into before any message is sent
  NotaLoot:HookMessageSystem(session, function(msg, session, ...)
    if session == self.session then
      self:OnViewedSessionMessage(msg, ...)
    end
  end)

  self:OnSessionChanged()
end

function Master:OnClearButtonClicked()
  if self.session.owner or self.pendingViewRequest then
    self:StopViewingRemoteSession()
  else
    self.session:Clear()
    NotaLoot:Broadcast(NotaLoot.MESSAGE.DELETE_ALL_ITEMS)
    NotaLoot.client:OnDeleteAllItems(NotaLoot.player)
  end
end

function Master:OnTradeOpened()
  if not self.window or not TradeFrame:IsShown() then return end

  -- I guess trading acts like an NPC interaction
  local sender = UnitName("NPC")

  local items = self.session:GetItemsAssignedToPlayer(sender)
  local itemCount = #items
  if itemCount == 0 then return end

  if InCombatLockdown() then
    NotaLoot:Info("Auto-trading is disabled during combat.")
    return
  end

  for i = 1, math.min(itemCount, MAX_TRADABLE_ITEMS) do
    local item = items[i]
    item:UpdateLocation()
    if item.location then
      local bag, slot = item.location:GetBagAndSlot()
      UseContainerItem(bag, slot)
    end
  end
end

function Master:OnSessionChanged(index)
  self:UpdateStatusText()
  self:UpdateInstructions()

  -- If index is present then it's a change local to 1 item
  -- This will have already beed handled in the item-specific message
  if not index then
    self:ReloadTable()
  end
end

function Master:OnViewedSessionMessage(msg, ...)
  if msg == NotaLoot.MESSAGE.ADD_ITEM then
    self:OnAddItem(...)
  elseif msg == NotaLoot.MESSAGE.DELETE_ITEM then
    self:OnDeleteItem(...)
  elseif msg == NotaLoot.MESSAGE.BID_ITEM or msg == NotaLoot.MESSAGE.ASSIGN_ITEM then
    self:ReloadItem(...)
  elseif msg == NotaLoot.MESSAGE.ON_CHANGE then
    self:OnSessionChanged(...)
  end
end

function Master:OnLootMessage(text, ...)
  if self.session.owner or self.pendingViewRequest then return end -- Skip if viewing a remote session
  if not NotaLoot:GetPref("AutoAdd") then return end -- Skip if pref not set

  local player = select(4, ... )
  if player ~= NotaLoot.player then return end

  local _, itemId = text:match(LOOT_ITEM_SELF:sub(1, -4)..".*|Hitem:((%d+).-)|h")
  if not itemId then return end

  local item = NotaLoot.Item:CreateForId(tonumber(itemId))
  if item.quality >= 4 then -- Only auto add epic or higher quality
    table.insert(self.pendingAutoAddedItems, item)
  end
end

function Master:OnInventoryUpdate()
  -- Skip if viewing a remote session
  if self.session.owner or self.pendingViewRequest then return end

  if NotaLoot:GetPref	("AutoAdd") then
    self:ProcessAutoAddedItems()
  end

  if NotaLoot:GetPref("AutoRemove", true) then
    self.session:RemoveItemsWithoutLocation()
  end
end

function Master:ContainerFrameItemButton_OnModifiedClick(button, type)
  if not IsAltKeyDown() or type ~= "LeftButton" then return end

  if self.session.owner or self.pendingViewRequest then
    NotaLoot:Info("Items can't be added while viewing another session.")
    return
  end

  local bag, slot = button:GetParent():GetID(), button:GetID();
  local item = NotaLoot.Item:CreateFromContainer(bag, slot)

  self.session:AddItem(item)
end
