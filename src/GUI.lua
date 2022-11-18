local AceGUI = LibStub("AceGUI-3.0")
local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

local GUI = {}
GUI.__index = GUI
NotaLoot.GUI = GUI

local Table = {}
Table.__index = Table
GUI.Table = Table

-- Lua APIs
local _G, getmetatable, setmetatable = _G, getmetatable, setmetatable
local math, pairs, table = math, pairs, table

-- WoW APIs
local ACCEPT, DECLINE = ACCEPT, DECLINE
local GameTooltip, StaticPopupDialogs, StaticPopup_Show = GameTooltip, StaticPopupDialogs, StaticPopup_Show

-- Similar to default Fill, but with space at the top
AceGUI:RegisterLayout("NotaLootWindow",
function(content, children)
	local width = content.width or content:GetWidth() or 0
	local offset = content.yOffset or 0

	if children[1] then
		local child = children[1]
		child:SetWidth(content:GetWidth() or 0)
		child:SetHeight(content:GetHeight() or 0)
		child.frame:ClearAllPoints()
		child.frame:SetPoint("TOPLEFT", content, 0, offset)
		child.frame:SetPoint("BOTTOMRIGHT", content)
		child.frame:Show()
	end

	if content.obj.LayoutFinished then
		content.obj:LayoutFinished(nil, nil)
	end
end
)

-- Window

function GUI:CreateWindow(name, title)
	local window = _G[name] or AceGUI:Create("Frame")
	window:SetTitle(title)
	window:SetLayout("NotaLootWindow")
	window:SetCallback("OnClose", function(w) w.table:Clear() end)
	window:SetCallback("OnEnterStatusBar", function(w)
		if window.statusTooltip then
			GameTooltip:SetOwner(w.frame, "ANCHOR_CURSOR")
			GameTooltip:SetText(window.statusTooltip)
		end
	end)
	window:SetCallback("OnLeaveStatusBar", function() GameTooltip:Hide() end)

	-- Size and position are persisted in SavedVariables
	-- This can't be done automatically via the layout cache because:
	-- 1) AceGUI creates anonymous frames
	-- 2) Our windows aren't created before PLAYER_LOGIN
	local xKey, yKey, widthKey, heightKey = name.."X", name.."Y", name.."Width", name.."Height"
	window:SetWidth(NotaLoot:GetPref(widthKey) or 550)
	window:SetHeight(NotaLoot:GetPref(heightKey) or 500)

	-- Restore saved position
	if NotaLoot:GetPref(xKey) then
		window:SetPoint("LEFT", NotaLoot:GetPref(xKey), 0)
	end
	if NotaLoot:GetPref(yKey) then
		window:SetPoint("BOTTOM", 0, NotaLoot:GetPref(yKey))
	end

	-- Save prefs before a reload or logout
	window.frame:RegisterEvent("PLAYER_LOGOUT")
	window.frame:HookScript("OnEvent", function(frame, event)
		-- if event ~= "PLAYER_LOGOUT" then return end
		local x, y = frame:GetLeft(), frame:GetBottom()
		local width, height = frame:GetSize()
		NotaLoot:SetPref(xKey, math.floor(x))
		NotaLoot:SetPref(yKey, math.floor(y))
		NotaLoot:SetPref(widthKey, math.floor(width))
		NotaLoot:SetPref(heightKey, math.floor(height))
	end)

	local backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	}
	window.frame:SetBackdrop(backdrop)
	window.frame:SetBackdropColor(0, 0, 0, 1)

	local tableContainer = AceGUI:Create("SimpleGroup")
	tableContainer:SetLayout("Fill")
	window:AddChild(tableContainer)

	window.table = GUI:CreateTable()
	tableContainer:AddChild(window.table)

	local tipText = window.statustext:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tipText:SetPoint("TOPRIGHT", -7, -2)
	tipText:SetPoint("BOTTOMLEFT", 7, 2)
	tipText:SetHeight(20)
	tipText:SetJustifyH("RIGHT")
	tipText:SetTextColor(0.5, 0.5, 0.5, 1)
	window.tipText = tipText

	table.insert(UISpecialFrames, name)
	_G[name] = window

	return window
end

-- Table

function GUI:CreateTable()
	local table = AceGUI:Create("ScrollFrame")
	table:SetLayout("List")

	-- Add inheritence from Table
	local meta = getmetatable(table)
	setmetatable(table, {
		__index = function(t, k)
			return Table[k] or meta.__index[k]
		end
	})

	table.rows = {}

	return table
end

-- string, number, any, function(row, data)
function Table:CreateRow(className, index, data, config)
	self:DeleteRowAtIndex(index)

	local row = AceGUI:Create(className)
	if not row then
		NotaLoot:Error("Table failed to create row of unknown type '"..className.."'")
		return
	end

	row:SetFullWidth(true)

	local rowInfo = row:GetUserDataTable()
	rowInfo.className = className
	rowInfo.table = self
	rowInfo.config = config

	row:SetCallback("OnRelease", function()
		if rowInfo.data and rowInfo.data.UnregisterMessage then
			rowInfo.data:UnregisterMessage(NotaLoot.MESSAGE.ON_CHANGE)
		end
	end)

	self.rows[index] = row
	self:ReloadRowAtIndex(index, data)

	local sibling = nil
	for i, r in pairs(self.rows) do
		if i > index then
			sibling = r
			break
		end
	end

	self:AddChild(row, sibling)

	return row
end

function Table:ReloadRow(row, data)
	for index, it in pairs(self.rows) do
		if it == row then
			self:ReloadRowAtIndex(index, data)
			break
		end
	end
end

function Table:ReloadRowAtIndex(index, data)
	local row = self.rows[index]
	if not row then return end

	local rowInfo = row:GetUserDataTable()
	rowInfo.data = data or rowInfo.data

	if rowInfo.data and rowInfo.data.UnregisterMessage then
		rowInfo.data:UnregisterMessage(NotaLoot.MESSAGE.ON_CHANGE)
	end

	if rowInfo.data and rowInfo.data.RegisterMessage then
		rowInfo.data:RegisterMessage(NotaLoot.MESSAGE.ON_CHANGE, function(_, item)
			if rowInfo.table then rowInfo.table:ReloadRow(row) end
		end)
	end

	if rowInfo.config then
		rowInfo.config(row, rowInfo.data)
	end
end

function Table:DeleteRow(row, reindex)
	for index, it in pairs(self.rows) do
		if it == row then
			self:DeleteRowAtIndex(index, reindex)
			break
		end
	end
end

function Table:DeleteRowAtIndex(index, reindex)
	local row = self.rows[index]
	if not row then return end

	if reindex then
		-- Shift every index forward
		local maxIndex = self:GetMaxIndex()
		for i = index + 1, maxIndex do
			self.rows[i - 1] = self.rows[i]
		end
		self.rows[maxIndex] = nil
	else
		self.rows[index] = nil
	end

	row:Release()

	for i = 1, #self.children do
		if self.children[i] == row then
			table.remove(self.children, i)
			break
		end
	end

	self:DoLayout()
end

function Table:GetRowCount()
	local count = 0
	for _ in pairs(self.rows) do
		count = count + 1
	end
	return count
end

function Table:GetMaxIndex()
	local maxIndex = 0
	for index in pairs(self.rows) do
		maxIndex = math.max(maxIndex, index)
	end
	return maxIndex
end

function Table:Clear()
	for index, row in pairs(self.rows) do
		row:Release()
		self.rows[index] = nil
	end
	self.children = {}
end

-- Confirmation Dialog

local ConfirmationDialogs = {}
StaticPopupDialogs["NOTA_LOOT_VIEW_CONFIRMATION"] = {
	text = "[NotaLoot]\n%s is requesting access to view bids in your session.",
	button1 = ACCEPT,
	button2 = DECLINE,
	OnAccept = function(_, data) if data.onAccept then data.onAccept() end end,
	OnCancel = function(_, data) if data.onCancel then data.onCancel() end end,
	OnHide = function(_, data) if data.sender then ConfirmationDialogs[data.sender] = nil end end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

function GUI:ShowViewConfirmation(sender, onAccept, onCancel)
	local dialog = ConfirmationDialogs[sender] or StaticPopup_Show("NOTA_LOOT_VIEW_CONFIRMATION", sender)

	if dialog then
		dialog.data = {
			sender = sender,
			onAccept = onAccept,
			onCancel = onCancel,
		}
	end

	ConfirmationDialogs[sender] = dialog
end

function GUI:HideViewConfirmation(sender)
	if sender and ConfirmationDialogs[sender] then
		ConfirmationDialogs[sender]:Hide()
	end
end
