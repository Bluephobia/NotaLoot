--[[-----------------------------------------------------------------------------
Adapted from AceGUI-3.0 widget template
-------------------------------------------------------------------------------]]
local Type, Version = "NotaLootItemRow", 10
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
local NotaLoot = LibStub("AceAddon-3.0"):GetAddon("NotaLoot")

-- Lua APIs
local math, pairs = math, pairs

-- WoW APIs
local CreateFrame, GameTooltip, UIParent = CreateFrame, GameTooltip, UIParent
local UIDropDownMenu_EnableDropDown, UIDropDownMenu_DisableDropDown = UIDropDownMenu_EnableDropDown, UIDropDownMenu_DisableDropDown
local UIDropDownMenu_SetText = UIDropDownMenu_SetText

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {

  -- Lifecycle

  ["OnAcquire"] = function(self)
    self:SetFullWidth(true)
    self:SetHeight(46)

    self.image:SetTexture(nil)
    self.linkText:SetText(nil)
    self:SetBidTextVisible(false)
    self:SetDropDownEnabled(true)
    self:SetDropdownText(nil, nil)
    self:SetDeleteButtonVisible(false)
  end,

  ["OnRelease"] = function(self)
    self.dropdownConfig = nil
    self:UnregisterAllCallbacks()
  end,

  ["OnWidthSet"] = function(self, width)
    local content = self.content
    local contentwidth = math.max(0, width)
    content:SetWidth(contentwidth)
    content.width = contentwidth
  end,

  ["OnHeightSet"] = function(self, height)
    local content = self.content
    local contentheight = max(0, height)
    content:SetHeight(contentheight)
    content.height = contentheight
  end,

  -- Utility

  ["GetCurrentItem"] = function(self)
    return self:GetUserDataTable().data
  end,

  -- Actions

  ["ShowTooltip"] = function(self)
    local item = self:GetCurrentItem()
    if not item or not item.link then return end

    GameTooltip:SetOwner(self.image, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(item.link)
  end,

  ["HideTooltip"] = function(self)
    GameTooltip:Hide()
  end,

  ["SetDropDownEnabled"] = function(self, enabled)
    if enabled then
      UIDropDownMenu_EnableDropDown(self.dropdown)
    else
      UIDropDownMenu_DisableDropDown(self.dropdown)
    end
  end,

  ["SetDropdownText"] = function(self, text, label)
    UIDropDownMenu_SetText(self.dropdown, text)
    self.dropdownLabel:SetText(label)
  end,

  ["SetBidTextVisible"] = function(self, visible)
    if visible then
      self.bidText:Show()
      self.linkText:SetPoint("RIGHT", self.bidText, "LEFT", -8)
    else
      self.bidText:Hide()
      self.linkText:SetPoint("RIGHT", self.dropdown, "LEFT", -8)
    end
  end,

  ["SetDeleteButtonVisible"] = function(self, visible)
    if visible then
      self.deleteButton:Show()
      self.dropdown:SetPoint("RIGHT", self.deleteButton, "LEFT", -16, -8)
    else
      self.deleteButton:Hide()
      self.dropdown:SetPoint("RIGHT", -8, -8)
    end
  end,

  ["OnTooltipClicked"] = function(self, button)
    -- An unmodified click would open the default item tooltip frame
    -- This seems unnecessary, so is disabled for now
    if not IsModifiedClick() then return end

    local item = self:GetCurrentItem()
    if not item or not item.link then return end

    -- Handles pasting link to chat frame, dressup, etc.
    SetItemRef(item.link, item.link, button)
  end,

  ["OnDeletePressed"] = function(self)
    self:FireMessage(NotaLoot.MESSAGE.DELETE_ITEM)
  end,
}

local backdrop = {
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  tile = true, tileSize = 16,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
  local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame:SetBackdrop(backdrop)
  frame:SetBackdropColor(0, 0, 0, 0.9)

  -- lTR layout

  local image = frame:CreateTexture(nil, "OVERLAY")
  image:SetPoint("LEFT", 8, 0)
  image:SetSize(32, 32)

  local ilvlText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ilvlText:SetTextColor(1, 1, 1)
  ilvlText:SetPoint("BOTTOMLEFT", image, 1, 1)
  ilvlText:SetPoint("BOTTOMRIGHT", image, -1, 1)
  ilvlText:SetJustifyH("CENTER")

  local linkText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  linkText:SetPoint("TOPLEFT", image, "TOPRIGHT", 8, 0)
  linkText:SetPoint("BOTTOMLEFT", image, "BOTTOMRIGHT", 8, 0)
  linkText:SetJustifyH("LEFT")

  local tooltipRegion = CreateFrame("Button", nil, frame)
  tooltipRegion:SetPoint("TOPLEFT", image)
  tooltipRegion:SetPoint("BOTTOMRIGHT", linkText)

  -- RTL layout

  local deleteButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
  deleteButton:SetPoint("RIGHT", -4, 0)
  deleteButton:SetSize(28, 28)

  local dropdown = CreateFrame("Frame", "NotaLootItemRowDropdown"..AceGUI:GetNextWidgetNum(Type), frame, "UIDropDownMenuTemplate")
  dropdown:SetWidth(150)

  local dropdownLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dropdownLabel:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 16, 0)
  dropdownLabel:SetPoint("BOTTOMRIGHT", dropdown, "TOPRIGHT", - 16, 0)
  dropdownLabel:SetJustifyH("LEFT")
  dropdownLabel:SetHeight(14)

  local bidText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bidText:SetPoint("TOP")
  bidText:SetPoint("RIGHT", dropdown, "LEFT")
  bidText:SetPoint("BOTTOM")
  bidText:SetJustifyH("CENTER")
  bidText:SetWidth(90)

  -- Container Support
  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT")
  content:SetPoint("BOTTOMRIGHT")

  local widget = {
    frame = frame,
    content = content,
    image = image,
    ilvlText = ilvlText,
    linkText = linkText,
    bidText = bidText,
    dropdown = dropdown,
    dropdownLabel = dropdownLabel,
    deleteButton = deleteButton,
    type = Type,
  }

  -- Methods and events
  for method, func in pairs(methods) do
    widget[method] = func
  end

  -- Alternative to UIDropDownMenu_Initialize to not invoke the function immediately
  dropdown.initialize = function(dropdown, level, menuList)
    if widget.dropdownConfig then
      widget.dropdownConfig(dropdown, level, menuList)
    end
  end

  tooltipRegion:HookScript("OnEnter", function() widget:ShowTooltip() end)
  tooltipRegion:HookScript("OnLeave", function() widget:HideTooltip() end)
  tooltipRegion:HookScript("OnClick", function(_, button) widget:OnTooltipClicked(button) end)
  deleteButton:HookScript("OnClick", function() widget:OnDeletePressed() end)

  NotaLoot:AddMessageSystem(widget)

  return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
