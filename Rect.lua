
--"Globals"
local aceDB = LibStub("AceDB-3.0");
local aceCDialog = LibStub("AceConfigDialog-3.0");
local aceConfig = LibStub("AceConfig-3.0");
local libSharedMedia = LibStub("LibSharedMedia-3.0");
local libDRData = LibStub('DRData-1.0');

Rect.MovableFrames = nil

Rect.targets = {
	["target"] = nil,
	["focus"] = nil,
	["self"] = nil
}

Rect.cds = {}
Rect.drs = {}

Rect.frames = {
	["target"] = {},
	["focus"] = {},
	["targetdr"] = {},
	["focusdr"] = {},
	["selfdr"] = {}
}

Rect.defaults = {
   profile = {
		enabled = true,
		locked = true,
		debugLevel = 0,
		spellCastDebug = false,
		spellAuraDebug = false,
		allCDebug = false,
		selfCDRegister = false,
		specdetection = false,
		petcdguessing = true,
		target = {
			enabled = true,
			size = 27,
			xPos = 350,
			yPos = 350,
			growOrder = tostring(2),
			sortOrder = tostring(5),
			colorframeenabled = true,
			colorframesize = 4
		},
		focus = {
			enabled = true,
			size = 27,
			xPos = 380,
			yPos = 380,
			growOrder = tostring(2),
			sortOrder = tostring(5),
			colorframeenabled = true,
			colorframesize = 4
		},
		targetdr = {
			enabled = true,
			size = 27,
			xPos = 380,
			yPos = 380,
			growOrder = tostring(2),
			sortOrder = tostring(5),
			drnumsize = 14,
			drnumposition = tostring(1)
		},
		focusdr = {
			enabled = true,
			size = 27,
			xPos = 380,
			yPos = 380,
			growOrder = tostring(2),
			sortOrder = tostring(5),
			drnumsize = 14,
			drnumposition = tostring(1)
		},
		selfdr = {
			enabled = true,
			size = 27,
			xPos = 380,
			yPos = 380,
			growOrder = tostring(2),
			sortOrder = tostring(5),
			drnumsize = 14,
			drnumposition = tostring(1)
		},
		color = {
			gapcloser = {
				a = 1,
				b = 0,
				g = 0.8117647058823529,
				r = 1,
			},
			anticc = {
				a = 1,
				b = 0.796078431372549,
				g = 1,
				r = 0,
			},
			disarm = {
				a = 1,
				b = 0.9647058823529412,
				g = 1,
				r = 0,
			},
			defensive = {
				a = 1,
				b = 0.08627450980392157,
				g = 1,
				r = 0.2,
			},
			nuke = {
				a = 1,
				b = 0,
				g = 0,
				r = 1,
			},
			shield = {
				a = 1,
				b = 0.3333333333333333,
				g = 1,
				r = 0.8901960784313725,
			},
			potion = {
				a = 1,
				b = 0.6313725490196078,
				g = 0.7372549019607844,
				r = 1,
			},
			cdreset = {
				a = 1,
				b = 1,
				g = 0,
				r = 0.6274509803921569,
			},
			silence = {
				a = 1,
				b = 1,
				g = 0.03529411764705882,
				r = 0.1882352941176471,
			},
			stun = {
				a = 1,
				b = 1,
				g = 0.07450980392156863,
				r = 0.9137254901960784,
			},
			uncategorized = {
				a = 1,
				b = 1,
				g = 0.9058823529411765,
				r = 0.9607843137254902,
			},
			cc = {
				a = 1,
				b = 0.3686274509803922,
				g = 0.3568627450980392,
				r = 0.3764705882352941,
			},
		},
		cdtypesortorder = {
			enabled = true,
			silence = 1,
			gapcloser = 2,
			defensive = 6,
			potion = 12,
			nuke = 7,
			anticc = 5,
			cc = 4,
			stun = 3,
			disarm = 9,
			cdreset = 10,
			shield = 5,
			uncategorized = 13
		}
   }
}

function Rect:Reset()
   Rect.cds = {}
   Rect.drs = {}
   Rect.target = {unitGUID = -1, timers = {}}
   Rect.focus = {unitGUID = -1, timers = {}}
   Rect:HideSelfDRFrames();
end
   
function Rect:OnInitialize()
	self.db = aceDB:New("RectDB", self.defaults);
	self.db.RegisterCallback(self, "OnProfileChanged", function() self:ApplySettings() end);
	self.db.RegisterCallback(self, "OnProfileCopied", function() self:ApplySettings() end);
	self.db.RegisterCallback(self, "OnProfileReset", function() self:ApplySettings() end);
	aceConfig:RegisterOptionsTable("Rect", self:GetRectOptions());
	aceCDialog:AddToBlizOptions("Rect");
	self:RegisterChatCommand("Rect", "ChatCommand");
end

function Rect:OnEnable()
	self:Reset()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:CreateFrames("target");
	self:CreateFrames("focus");
	self:CreateDRFrames("targetdr");
	self:CreateDRFrames("focusdr");
	self:CreateDRFrames("selfdr");
	self:ApplySettings();
	self.targets["self"] = UnitGUID("player");
end


function Rect:OnDisable()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
	self.Reset();
end


function Rect:ChatCommand(input)
	if not input or input:trim() == "" then
		aceCDialog:Open("Rect");
	else
		LibStub("AceConfigCmd-3.0").HandleCommand(Rect, "Rect", "Rect", input);
	end
end

local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local COMBATLOG_OBJECT_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER


function Rect:COMBAT_LOG_EVENT_UNFILTERED(_, timestamp, eventType, srcGUID, srcName, srcFlags, 
					  dstGUID, dstName, dstFlags, spellID, spellName, spellSchool,
					  detail1, detail2, detail3)
	local db =  Rect.db.profile;

	if not db["enabled"] then return end;
	
	--debugAll
	if db["allCDebug"] then
		self:Print("eventType: " .. eventType .. " id: " .. spellID .. " spellName: " .. spellName);
	end
	
	--debugAura
	if db["spellAuraDebug"] then
		if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REMOVED" or eventType == "SPELL_AURA_APPLIED_DOSE" or
				eventType == "SPELL_AURA_REMOVED_DOSE" or eventType == "SPELL_AURA_REFRESH" or eventType == "SPELL_AURA_BROKEN" or
				eventType == "SPELL_AURA_BROKEN_SPELL" then
			self:Print("eventType: " .. eventType .. " id: " .. spellID .. " spellName: " .. spellName);
		end
	end
	
   if eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_AURA_APPLIED" then
		--debug spell
		if db["spellCastDebug"] and eventType == "SPELL_CAST_SUCCESS" then
			self:Print("id: " .. spellID .. " spellName: " .. spellName);
		end
	  
		if Rect.spells[spellID] then
			Rect:AddCd(srcGUID, spellID);
		end
	end

	--DR stuff
	if( eventType == "SPELL_AURA_APPLIED" ) then
		if(detail1 == "DEBUFF" and libDRData:GetSpellCategory(spellID)) then
			local isPlayer = (bit.band(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER or bit.band(dstFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == COMBATLOG_OBJECT_CONTROL_PLAYER)
			
			if (not isPlayer and not libDRData:IsPVE(drCat)) then
				return
			end
			
			local drCat = libDRData:GetSpellCategory(spellID);
			Rect:DRDebuffGained(spellID, dstGUID, isPlayer);
		end
	
	-- Enemy had a debuff refreshed before it faded, so fade + gain it quickly
	elseif(eventType == "SPELL_AURA_REFRESH" ) then
		if(detail1 == "DEBUFF" and libDRData:GetSpellCategory(spellID)) then
			local isPlayer = (bit.band(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER or bit.band(dstFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == COMBATLOG_OBJECT_CONTROL_PLAYER)
			
			if (not isPlayer and not libDRData:IsPVE(drCat)) then
				return
			end
			
			Rect:DRDebuffFaded(spellID, dstGUID, isPlayer);
			Rect:DRDebuffGained(spellID, dstGUID, isPlayer);
		end
	
	-- Buff or debuff faded from an enemy
	elseif(eventType == "SPELL_AURA_REMOVED" ) then
		if(detail1 == "DEBUFF" and libDRData:GetSpellCategory(spellID)) then
			local isPlayer = (bit.band(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER or bit.band(dstFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == COMBATLOG_OBJECT_CONTROL_PLAYER)
			
			if (not isPlayer and not libDRData:IsPVE(drCat)) then
				return
			end
			
			Rect:DRDebuffFaded(spellID, dstGUID, isPlayer);
		end
	end
end

function Rect:PLAYER_TARGET_CHANGED()
	local unitGUID = UnitGUID("target");
	self.targets["target"] = unitGUID;
	self:ReassignCds("target");
	self:ReassignDRs("targetdr");
end

function Rect:PLAYER_FOCUS_CHANGED()
	local unitGUID = UnitGUID("focus");
	self.targets["focus"] = unitGUID;
	self:ReassignCds("focus");
	self:ReassignDRs("focusdr");
end

function Rect:PLAYER_ENTERING_WORLD()
	--DB cleanup
	local t = GetTime();
	for k, v in pairs(Rect.cds) do
		for i, j in pairs(v) do
			if not (i == "spec") then
				if j[2] < t then
					--self:Print(Rect.cds[k][i][4]);
					Rect.cds[k][i] = nil;
				end
			end
		end
	end
	Rect.drs = {}
end

function Rect:ZONE_CHANGED_NEW_AREA()
	local type = select(2, IsInInstance())
	-- If we are entering an arena
	if (type == "arena") then
		self:Reset();
	end
end

function Rect:ApplySettings()
	local db = Rect.db.profile;
	Rect:MoveTimersStop("target");
	Rect:MoveTimersStop("focus");
	Rect:ReassignCds("target");
	Rect:ReassignCds("focus");
	Rect:MoveDRTimersStop("targetdr");
	Rect:MoveDRTimersStop("focusdr");
	Rect:MoveDRTimersStop("selfdr");
	Rect:ReassignDRs("targetdr");
	Rect:ReassignDRs("focusdr");
	Rect:ReassignDRs("selfdr");
	if not db["locked"] then self:ShowMovableFrames() end;
end