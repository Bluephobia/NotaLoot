local AceGUI = LibStub("AceGUI-3.0")
local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

local Client = {}
Client.__index = Client
NotaLoot.Client = Client

-- Lua APIs
local pairs, setmetatable, tonumber = pairs, setmetatable, tonumber

-- WoW APIs
local SendSystemMessage = SendSystemMessage
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton

-- Lifecycle

function Client:Create()
  local client = {
    sessions = {},
    activeSession = nil,
  }
  setmetatable(client, Client)

  -- Remote messages
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.OPEN_CLIENT, function(_, sender)
    client:OnShowRequest(sender)
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.ADD_ITEM, function(_, sender, index, encodedItem)
    client:OnAddItem(sender, tonumber(index), NotaLoot.Item:Decode(encodedItem))
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.ASSIGN_ITEM, function(_, sender, index, winner)
    client:OnAssignItem(sender, tonumber(index), winner)
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.DELETE_ITEM, function(_, sender, index)
    client:OnDeleteItem(sender, tonumber(index))
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.DELETE_ALL_ITEMS, function(_, sender)
    client:OnDeleteAllItems(sender)
  end)
  NotaLoot:RegisterMessage(NotaLoot.MESSAGE.SYNC_RESPONSE, function(_, sender, encodedItems)
    client:OnSyncResponse(sender, encodedItems)
  end)

  return client
end

function Client:CreateWindow()
  local window = NotaLoot.GUI:CreateWindow("NotaLootClient", "NotaLoot - v"..NotaLoot.version)
  window.content.yOffset = -25

  if window.frame.SetMinResize then
    window.frame:SetMinResize(420, 300)
  end

  local filterButton = CreateFrame("Button", nil, window.frame, "UIPanelButtonTemplate")
  filterButton:SetNormalFontObject("GameFontNormalSmall2")
  filterButton:SetHighlightFontObject("GameFontHighlightSmall2")
  filterButton:SetPoint("TOPRIGHT", -14, -16)
  filterButton:SetSize(105, 22)
  filterButton:SetScript("OnClick", function() self:ToggleClassFilter(true) end)
  window.filterButton = filterButton

  local sessionDropdown = AceGUI:Create("Dropdown")
  window:AddChild(sessionDropdown)
  sessionDropdown:SetPoint("TOP", 1, 10)
  sessionDropdown:SetWidth(174)
  window.sessionDropdown = sessionDropdown

  sessionDropdown:SetCallback("OnValueChanged", function(_, _, owner)
    local session = self:GetSession(owner)
    if session then self:SetActiveSession(session) end
  end)

  window:DoLayout()

  return window
end

function Client:OnShowRequest(sender)
  -- Show the client window if either requests aren't restricted to officers,
  --  or the sender is an officer of the user's guild
  if not NotaLoot:GetPref("ShowClientOfficers") or NotaLoot:IsGuildOfficer(sender) then
    self:Show()
  end
end

function Client:Show()
  if not self.window then
    self.window = self:CreateWindow()
    self:ToggleClassFilter(false)
  end

  self.window:Show()

  self:ReloadTable()
  self:UpdateSessionInfo(true)
end

function Client:Toggle()
  if self.window and self.window:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function Client:Hide()
  if self.window then self.window:Hide() end
end

function Client:Reset()
  self:Hide()
  self.sessions = {}
  self.activeSession = nil
end

-- GUI

function Client:UpdateSessionInfo(reloadDropdown)
  if not self.window or not self.window:IsShown() then return end

  local activeSession = self.activeSession
  local sessionOwner = activeSession and activeSession.owner or nil
  local itemCount = activeSession and activeSession:GetItemCount() or 0
  local rowCount = self.window.table:GetRowCount()
  local dropdown = self.window.sessionDropdown

  if reloadDropdown then
    local sessionList = {}
    for owner, _ in pairs(self.sessions) do
      local rowText = owner == NotaLoot.player and "Your Session" or string.format("%s's Session", owner);
      sessionList[owner] = rowText
    end

    dropdown:SetList(sessionList)
    dropdown:SetValue(sessionOwner)
  end

  if sessionOwner then
    dropdown.frame:Show()
  else
    dropdown.frame:Hide()
  end

  self.window:SetStatusText("Total Items: "..itemCount)

  if rowCount < itemCount then
    local filteredCount = itemCount - rowCount
    self.window.tipText:SetText(string.format("%d filtered %s", filteredCount, filteredCount == 1 and "item" or "items"))
  else
    self.window.tipText:SetText(nil)
  end
end

function Client:ReloadTable()
  if not self.window or not self.window:IsShown() then return end

  local table = self.window.table
  local savedScroll = (table.status or table.localstatus).scrollvalue

  table:Clear()

  if not self.activeSession then return end

  for index, item in pairs(self.activeSession.items) do
    if not self.filter or self.filter:Evaluate(item) then
      table:CreateRow("NotaLootItemRow", index, item, function(r, i)
        self:ConfigureItemRow(r, i)
      end)
    end
  end

  table:SetScroll(savedScroll)
end

function Client:ConfigureItemRow(row, item)
  row.image:SetTexture(item.texture)
  row.ilvlText:SetText(item.ilvl)
  row.linkText:SetText(item.link)

  local winner = item:GetWinner()
  row:SetBidTextVisible(winner)
  row.bidText:SetText(winner)

  local currentBid = NotaLoot.BID_TEXT[self.activeSession:GetBidForPlayer(item, NotaLoot.player)]
  row:SetDropdownText(currentBid, "Selection")
  row:SetDropDownEnabled(item:GetStatus() == NotaLoot.STATUS.BIDDING)
  row.dropdownConfig = function() self:ConfigureDropdown(item) end
end

function Client:ConfigureDropdown(item)
  local menuInfo = UIDropDownMenu_CreateInfo()
  for bid, text in pairs(NotaLoot.BID_TEXT) do
    menuInfo.text = text
    menuInfo.func = function() self:BidOnItem(item, bid) end
    UIDropDownMenu_AddButton(menuInfo)
  end
end

-- Actions

function Client:GetSession(owner)
  return self.sessions[owner]
end

function Client:CreateSession(owner, notify)
  if self.sessions[owner] then
    NotaLoot:error("Attempted to create a new session for", owner, "but one already exists!")
    return
  end

  local session = NotaLoot.Session:Create(owner)
  session:RegisterMessage(NotaLoot.MESSAGE.BID_ITEM, function(_, ...)
    self:OnBidItem(...)
  end)
  session:RegisterMessage(NotaLoot.MESSAGE.ON_CHANGE, function(_, session, index)
    self:OnSessionChanged(session, false, index)
  end)

  self.sessions[owner] = session

  if not self.activeSession then
    self:SetActiveSession(session)
  else
    self:UpdateSessionInfo(true)
  end

  if notify then
    local notifyText = owner == NotaLoot.player and "You started a session" or string.format("%s started a new session", owner)
    NotaLoot:NotifyLocal(notifyText)
  end

  return session
end

function Client:SetActiveSession(session)
  if session ~= self.activeSession then
    self.activeSession = session
    self:OnSessionChanged(session, true)
  end
end

function Client:ToggleClassFilter(reload)
  if self.filter then
    self.filter = nil
    if self.window and self.window.filterButton then
      self.window.filterButton:SetText("Hide Unusable")
    end
  else
    self.filter = NotaLoot.Filter:CreateForPlayerClassId(NotaLoot.playerClass)
    if self.window and self.window.filterButton then
      self.window.filterButton:SetText("Show Unusable")
    end
  end

  if reload then
    self:ReloadTable()
    self:UpdateSessionInfo()
  end
end

function Client:BidOnItem(item, bid)
  if not self.activeSession then return end
  self.activeSession:RegisterBid(NotaLoot.player, item, bid)
end

-- Events

function Client:OnAddItem(sender, index, item)
  local session = self.sessions[sender] or self:CreateSession(sender, true)
  session:AddItem(item, index)

  if session == self.activeSession and self.window and self.window:IsShown() then
    if not self.filter or self.filter:Evaluate(item) then
      self.window.table:CreateRow("NotaLootItemRow", index, item, function(r, i)
        self:ConfigureItemRow(r, i)
      end)
      self:UpdateSessionInfo()
    end
  end
end

function Client:OnBidItem(session, item, bid, bidder)
  if bidder ~= NotaLoot.player then return end

  local index = session:GetIndexOfItem(item)
  if not index then return end

  NotaLoot:Whisper(NotaLoot.MESSAGE.BID_ITEM, { index, bid }, session.owner)

  if session == self.activeSession and self.window and self.window:IsShown() then
    self.window.table:ReloadRowAtIndex(index, item)
  end
end

function Client:OnAssignItem(sender, index, winner)
  local session = self.sessions[sender]
  if not session then
    NotaLoot:Debug("Received", NotaLoot.MESSAGE.ASSIGN_ITEM, "for untracked session", sender)
    return
  end

  local item = session:GetItemAtIndex(index)
  if not item then return end

  session:AssignItem(item, winner)

  if session.owner and item.link and winner then
    SendSystemMessage(string.format("%s assigned %s to %s", session.owner, item.link, winner))

    if winner == NotaLoot.player then
      NotaLoot:NotifyLocal(string.format("You won %s", item.link))
    end
  end

  if session == self.activeSession and self.window and self.window:IsShown() then
    self.window.table:ReloadRowAtIndex(index, item)
  end
end

function Client:OnDeleteItem(sender, index)
  local session = self.sessions[sender]

  if not session then
    NotaLoot:Debug("Received", NotaLoot.MESSAGE.DELETE_ITEM, "for untracked session", sender)
    return
  end

  session:RemoveItemAtIndex(index)

  if session == self.activeSession and self.window and self.window:IsShown() then
    self.window.table:DeleteRowAtIndex(index, true)
    self:UpdateSessionInfo()
  end
end

function Client:OnDeleteAllItems(sender)
  local session = self.sessions[sender]
  if session then session:Clear() end
end

function Client:OnSyncResponse(sender, encodedItems)
  local session = self.sessions[sender] or self:CreateSession(sender, false)
  session:ImportItems(encodedItems)
end

function Client:OnSessionChanged(session, reloadDropdown, index)
  if session ~= self.activeSession then return end

  -- If index is present then it's a change local to 1 item
  -- This will have already beed handled in the item-specific message
  if not index then
    self:ReloadTable()
  end

  -- UpdateSessionInfo relies on the table row count, so call after ReloadTable
  self:UpdateSessionInfo(reloadDropdown)
end

NotaLoot.client = Client:Create()
