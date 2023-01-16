local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local AddonName = "NotaLoot"
local NotaLoot = LibStub("AceAddon-3.0"):GetAddon(AddonName)

function NotaLoot:RegisterOptionsTable()
  local options = {
    name = AddonName,
    type = "group",
    args = {
      lmSettings = {
        order = 0,
        name = "Loot Master Settings",
        type = "group",
        inline = true,
        args = {
          autoAdd = {
            order = 0,
            name = "Auto Add Looted Epics",
            desc = "Whether to automatically add items you loot to your session.",
            type = "toggle",
            width = 3,
            set = function(_, val) self:SetPref("AutoAdd", val) end,
            get = function() return self:GetPref("AutoAdd") end,
          },
          autoRemove = {
            order = 1,
            name = "Auto Remove Items",
            desc = "Whether to automatically remove items from the session when they're no longer in your inventory (e.g. after a trade).",
            type = "toggle",
            width = 3,
            set = function(_, val) self:SetPref("AutoRemove", val) end,
            get = function() return self:GetPref("AutoRemove", true) end,
          },
          autoAllowOfficers = {
            order = 2,
            name = "Auto Allow Officers to View Bids",
            desc = "If enabled, requests from guild officers to view your loot session are automatically accepted.",
            type = "toggle",
            width = 3,
            set = function(_, val) self:SetPref("AutoAllowOfficers", val) end,
            get = function() return self:GetPref("AutoAllowOfficers", true) end,
          },
          announceAssignment = {
            order = 3,
            name = "Announce Assignments",
            desc = "Whether to announce assignments to a channel instead of the default local system message.",
            type = "toggle",
            width = 1.25,
            set = function(_, val) self:SetPref("AnnounceAssign", val) end,
            get = function() return self:GetPref("AnnounceAssign") end,
          },
          announceChannel = {
            order = 4,
            name = "Announcement Channel",
            desc = "Name of channel to announce assignments. Specify GUILD, OFFICER, RAID, RAID_WARNING, or a custom channel name.",
            type = "input",
            set = function(_, val) self:SetPref("AnnounceChannel", val) end,
            get = function() return self:GetPref("AnnounceChannel") end,
          },
        },
      },
      client = {
        order = 1,
        name = "Client Settings",
        type = "group",
        inline = true,
        args = {
          showClient = {
            order = 0,
            name = "Restrict Open Client to Officers",
            desc = "If enabled, the loot window will only be able to be automatically shown by officers in your guild.",
            type = "toggle",
            width = 2,
            set = function(_, val) self:SetPref("ShowClientOfficers", val) end,
            get = function() return self:GetPref("ShowClientOfficers") end,
          }
        }
      },
      devTools = {
        order = 2,
        name = "Developer Tools",
        type = "group",
        inline = true,
        args = {
          debugLog = {
            order = 0,
            name = "Enable Debug Log",
            desc = "Enable debug logging to submit more helpful issue reports.",
            type = "toggle",
            set = function(_, val) self:SetPref("DebugLog", val) end,
            get = function() return self:GetPref("DebugLog") end,
          },
        },
      },
    }
  }
  AceConfig:RegisterOptionsTable(AddonName, options)
  AceConfigDialog:AddToBlizOptions(AddonName)
end
