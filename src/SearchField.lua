local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

-- Lua APIs
local getmetatable, setmetatable = getmetatable, setmetatable

-- WoW APIs
local CreateFrame = CreateFrame

local SearchField = {}
SearchField.__index = SearchField
NotaLoot.SearchField = SearchField

local function UpdateText(self)
  if self.isFocused then return end

  local text = self:GetText()

  if not text or text == "" then
    self:SetText(self.placeholderText or "")
  else
    self:SetText(text)
  end
end

local function UpdateColors(self)
  if self.isFocused or self:GetText() ~= self.placeholderText then
    self:SetTextColor(1, 1, 1, 1)
  else
    self:SetTextColor(1, 1, 1, 0.4)
  end
end

local function EditBox_OnTextChanged(self)
  if not self.isFocused then return end
  self.filter:SetQuery(self:GetText())
end

local function EditBox_OnEditFocusGained(self)
  self.isFocused = true

  if self:GetText() == self.placeholderText then
    self:SetText("")
  else
    self:HighlightText()
  end

  UpdateColors(self)
end

local function EditBox_OnEditFocusLost(self)
  self.isFocused = false

  UpdateText(self)
  UpdateColors(self)
end

function SearchField:Create(parent)
  local searchField = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	searchField:SetAutoFocus(false)
  searchField:SetTextInsets(4, 4, 0, 0)
  searchField:SetJustifyH("LEFT")
	searchField:SetHeight(22)

  searchField:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  searchField:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  searchField:SetScript("OnEditFocusGained", function(self) EditBox_OnEditFocusGained(self) end)
  searchField:SetScript("OnTextChanged", function(self) EditBox_OnTextChanged(self) end)
  searchField:SetScript("OnEditFocusLost", function(self) EditBox_OnEditFocusLost(self) end)

  searchField.filter = NotaLoot.Filter:CreateForName()

  -- Add inheritence from SearchField
  local meta = getmetatable(searchField)
  setmetatable(searchField, {
    __index = function(t, k)
      return SearchField[k] or meta.__index[k]
    end
  })

  return searchField
end

function SearchField:GetFilter()
  return self.filter
end

function SearchField:GetPlaceholderText()
  return self.placeholderText
end

function SearchField:SetPlaceholderText(placeholderText)
  self.placeholderText = placeholderText
  UpdateText(self)
  UpdateColors(self)
end
