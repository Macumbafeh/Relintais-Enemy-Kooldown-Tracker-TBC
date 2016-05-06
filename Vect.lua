
--TODOS:
--Enable/disable on frames
--Player Entering World -> cleanup the db
--CD Sort Order
--Chat Command
--DR timers

--"Globals"
local aceDB = LibStub("AceDB-3.0")
local aceCDialog = LibStub("AceConfigDialog-3.0")
local aceConfig = LibStub("AceConfig-3.0")
local libSharedMedia = LibStub("LibSharedMedia-3.0")

Vect.MovableFrames = nil

Vect.targets = {
	["target"] = nil,
	["focus"] = nil
}

Vect.cds = {}

Vect.frames = {
	["target"] = {},
	["focus"] = {}
}

Vect.defaults = {
   profile = {
		enabled = true,
		locked = true,
		debugLevel = 0,
		spellCastDebug = false,
		spellAuraDebug = false,
		allCDebug = false,
		selfCDRegister = false,
		target = {
			enabled = true,
			size = 27,
			xPos = 350,
			yPos = 350,
			growOrder = 2,
			sortOrder = 5
		},
		focus = {
			enabled = true,
			size = 27,
			xPos = 380,
			yPos = 380,
			growOrder = 2,
			sortOrder = 5
		}
   }
}

function Vect:Reset()
   Vect.cds = {}
   Vect.target = {unitGUID = -1, timers = {}}
   Vect.focus = {unitGUID = -1, timers = {}}
end
   
function Vect:OnInitialize()
	self.db = aceDB:New("VectDB", self.defaults);
	self.db.RegisterCallback(self, "OnProfileChanged", function() self:ApplySettings() end);
	self.db.RegisterCallback(self, "OnProfileCopied", function() self:ApplySettings() end);
	self.db.RegisterCallback(self, "OnProfileReset", function() self:ApplySettings() end);
	self:Print(self.appName .. " v. " .. Vect.version .. ". Chat command is /vect");
	aceConfig:RegisterOptionsTable("Vect", self:GetVectOptions());
	aceCDialog:AddToBlizOptions("Vect");
	
	self:RegisterChatCommand("vect", "ChatCommand");
end

function Vect:OnEnable()
	self:Reset()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:CreateFrames("target");
	self:CreateFrames("focus");
	self:ApplySettings();
end


function Vect:OnDisable()
   self.Reset();
end


function Vect:ChatCommand(input)
   --TODO
end

function Vect:COMBAT_LOG_EVENT_UNFILTERED(_, timestamp, eventType, srcGUID, srcName, srcFlags, 
					  dstGUID, dstName, dstFlags, spellID, spellName, spellSchool,
					  detail1, detail2, detail3)
	local db =  Vect.db.profile;
	
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
	  
		if Vect.spells[spellID] then
			Vect:AddCd(srcGUID, spellID);
		end
   end
end

function Vect:PLAYER_TARGET_CHANGED()
	local unitGUID = UnitGUID("target");
	self.targets["target"] = unitGUID;
	self:ReassignCds("target");
end

function Vect:PLAYER_FOCUS_CHANGED()
	local unitGUID = UnitGUID("focus");
	self.targets["focus"] = unitGUID;
	self:ReassignCds("focus");
end

function Vect:PLAYER_ENTERING_WORLD()
	--TODO clean up the db
end

function Vect:ZONE_CHANGED_NEW_AREA()
	local type = select(2, IsInInstance())
	-- If we are entering an arena
	if (type == "arena") then
		self:Reset();
	end
end

--gets called when a cd is finished, reassigns the cds to frames.
function Vect:ReassignCds(which)
	--first hide all
	for i = 1, 23 do
		local frame = Vect.frames[which][i]["frame"];
		frame:Hide();
	end
	local db =  Vect.db.profile;
	--check if frames are unlocked
	if not db["locked"] then return end;
	--check if we need to display them for the player
	if not db["selfCDRegister"] and self.targets[which] == UnitGUID("player") then return end;
	--check if we have cooldown for that unit
	if not self.cds[self.targets[which]] then return end;
	--sort them
	Vect:SortCDs(which);
	--let's fill them up
	local i = 1;
	for k, v in pairs(self.cds[self.targets[which]]) do
		local frame = Vect.frames[which][i]["frame"];
		local text = Vect.frames[which][i]["texture"];
		text:SetTexture(v[4]);
		local CoolDown = Vect.frames[which][i]["cooldown"];
		CoolDown:SetCooldown(v[1], v[3]);
		frame:Show();
		i = i + 1;
	end
end

function Vect:AddCd(srcGUID, spellID)
	local db =  Vect.db.profile;
	if not db["enabled"] then return end;
	
	if not Vect.cds[srcGUID] then Vect.cds[srcGUID] = {} end
	local cd, reset = Vect.spells[spellID][1], Vect.spells[spellID][2];
	local spellName, spellRank, spellIcon = GetSpellInfo(spellID);
	local currentTime = GetTime();
	local endTime = currentTime + cd;
	Vect.cds[srcGUID][spellID] = {
		currentTime,
		endTime,
		cd,
		spellIcon,
		spellID
	}
	
	--self:Print(Vect.cds[srcGUID][spellID][1] .. " " .. Vect.cds[srcGUID][spellID][2] .. " " .. Vect.cds[srcGUID][spellID][3]);
	
	if reset then
		Vect:CdRemoval(srcGUID, reset);
	end
	
	--self:Print(self.targets["target"]);
	--self:Print(s
	
	if self.targets["target"] == srcGUID then
		self:ReassignCds("target");
	end
	
	if self.targets["focus"] == srcGUID then
		self:ReassignCds("focus");
	end
end

function Vect:CdRemoval(srcGUID, resetArray)
	if not self.cds[srcGUID] then return end
	for k, v in pairs(self.cds[srcGUID]) do
		for j, x in pairs(resetArray) do
			if v[5] == x then
				--self:Print("Removed cd: " .. v[5]);
				self.cds[srcGUID][v[5]] = nil;
			end
		end
	end
end

function Vect:SortCDs(which)
	--TODO
end

function Vect:CreateFrames(which)
	for i = 1, 23 do
		local frame = CreateFrame("Frame", nil, UIParent, nil);
		frame:SetFrameStrata("MEDIUM");
		frame:SetWidth(150);
		frame:SetHeight(150);
		if i == 1 then
			frame:SetScript("OnUpdate", function() self:VOnTimerUpdate(which) end)
		end
		local text = frame:CreateTexture();
		text:SetTexture("Interface\\Icons\\Spell_Arcane_Blink")
		text:SetAllPoints(frame);
		frame.texture = text;
		local CoolDown = CreateFrame("Cooldown", "VectCoolDown" .. i, frame);
		CoolDown:SetAllPoints()
		CoolDown:SetCooldown(GetTime(), 50);
		--frame:Show();
		Vect.frames[which][i] = {}
		Vect.frames[which][i]["frame"] = frame;
		Vect.frames[which][i]["texture"] = text;
		Vect.frames[which][i]["cooldown"] = CoolDown;
	end
end

function Vect:MoveTimersStop(which)
	local db = Vect.db.profile;
	local x = db[which]["xPos"];
	local y = db[which]["yPos"];
	local size = db[which]["size"];
	local growOrder = db[which]["growOrder"];
	
	for i = 1, 23 do
		local frame = Vect.frames[which][i]["frame"];
		frame:ClearAllPoints();
		frame:SetFrameStrata("MEDIUM");
		frame:SetWidth(size);
		frame:SetHeight(size);
		local text = Vect.frames[which][i]["texture"];
		text:SetAllPoints(frame);
		frame.texture = text;
		--set them based on the grow type
		if growOrder == "1" then --Up
			frame:SetPoint("BOTTOMLEFT", x, y + ((i - 1) * size));
		elseif growOrder == "2" then --Right
			frame:SetPoint("BOTTOMLEFT", x + ((i - 1) * size), y);
		elseif growOrder == "3" then --Down
			frame:SetPoint("BOTTOMLEFT", x, y - ((i - 1) * size));
		else --Left
			frame:SetPoint("BOTTOMLEFT", x - ((i - 1) * size), y);
		end
		local CoolDown = Vect.frames[which][i]["cooldown"];
		CoolDown:SetAllPoints();
		--frame:Show();
	end
end

function Vect:ApplySettings()
	local db = Vect.db.profile;
	Vect:MoveTimersStop("target");
	Vect:MoveTimersStop("focus");
	Vect:ReassignCds("target");
	Vect:ReassignCds("focus");
	if not db["locked"] then self:ShowMovableFrames() end;
end

function Vect:VOnTimerUpdate(which)
	--check if we have cooldown for that unit
	if not self.cds[self.targets[which]] then return end
	--let's check if one of the cooldowns finished
	for k, v in pairs(self.cds[self.targets[which]]) do
		if v[2] <= GetTime() then
			self.cds[self.targets[which]][v[5]] = nil;
			self:ReassignCds(which);
		end
	end
end

--Utility Functions for the options

--enable
function Vect:isEnabled()
	local db = Vect.db.profile;
	return db["enabled"];
end

function Vect:setEnabledOrDisabled(enable)
	if enable then 
		Vect:Enable() 
	else 
		Vect:Disable() 
	end
end

function Vect:isPartEnabled(which)
	local db = Vect.db.profile;
	return db[which]["enabled"];
end

function Vect:SetPartEnabledOrDisabled(which, enable)
	local db = Vect.db.profile;
	db[which]["enabled"] = enable;
	
end

--lock
function Vect:isLocked()
	return Vect.db.profile["locked"];
end

function Vect:LockFrames()
	self:MoveTimersStop("target");
	self:MoveTimersStop("focus");
	self:HideMovableFrames()
	self:ReassignCds("target");
	self:ReassignCds("focus");
end

function Vect:UnlockFrames()
	--this will hide the frames
	self:ReassignCds("target");
	self:ReassignCds("focus");
	Vect:ShowMovableFrames();
end

function Vect:HideMovableFrames()
	if not Vect.MovableFrames then return end;
	--Hide them
	for k, v in pairs(Vect.MovableFrames) do
		v["frame"]:EnableMouse(false);
		v["frame"]:SetMovable(false);
		v["frame"]:Hide();
	end
end

function Vect:ShowMovableFrames()
	local db = Vect.db.profile;
	--Create them if they doesn't exists
	if not Vect.MovableFrames then
		Vect.MovableFrames = {}
		for i = 1, 2 do
			local frame = CreateFrame("Frame", nil, UIParent, nil);
			frame:SetFrameStrata("BACKGROUND");
			frame:SetScript("OnDragStart", function() self:MovableFrameDragStart() end)
			frame:SetScript("OnDragStop", function() self:MovableFrameDragStop() end)
			local text = frame:CreateTexture();
			text:SetTexture("Interface\\Icons\\Spell_Arcane_Blink")
			text:SetAllPoints(frame);
			frame.texture = text;

			local which = "";
			if i == 1 then
				which = "target";
			elseif i == 2 then
				which = "focus";
			end
			
			frame.DragID = which;
			
			Vect.MovableFrames[i] = {}
			Vect.MovableFrames[i]["frame"] = frame;
			Vect.MovableFrames[i]["texture"] = text;
		end
	end

	--Show, resize them
	for k, v in pairs(Vect.MovableFrames) do
		v["frame"]:EnableMouse(true)
		v["frame"]:SetMovable(true)
		v["frame"]:RegisterForDrag("LeftButton")
		v["frame"]:SetPoint("BOTTOMLEFT", db[v["frame"].DragID]["xPos"], db[v["frame"].DragID]["yPos"]);
		v["frame"]:SetWidth(db[v["frame"].DragID]["size"]);
		v["frame"]:SetHeight(db[v["frame"].DragID]["size"]);
		v["frame"]:Show();
	end
end

function Vect:MovableFrameDragStart()
	this:StartMoving();
end

function Vect:MovableFrameDragStop()
	local db = Vect.db.profile;
	db[this.DragID]["xPos"] = this:GetLeft();
	db[this.DragID]["yPos"] = this:GetBottom();
	--Vect:Print(this:GetLeft() .. " " .. this:GetBottom());
	this:StopMovingOrSizing();
end

--size Functions

function Vect:getFrameSize(which)
	local db = Vect.db.profile;
	return db[which]["size"];
end

function Vect:setFrameSize(which, size)
	local db = Vect.db.profile;
	db[which]["size"] = size;
	
	Vect:MoveTimersStop(which)
	
	if not db["locked"] then
		Vect:ShowMovableFrames();
	end
end

--Grow Order
function Vect:getGrowOrder(which)
	local db = Vect.db.profile;
	return db[which]["growOrder"];
end

function Vect:setGrowOrder(which, v)
	local db = Vect.db.profile;
	db[which]["growOrder"] = v;
	Vect:MoveTimersStop(which)
end

--Sort Order
function Vect:getSortOrder(which)
	local db = Vect.db.profile;
	return db[which]["sortOrder"];
end

function Vect:setSortOrder(which, v)
	local db = Vect.db.profile;
	db[which]["sortOrder"] = v;
	Vect:ReassignCds(which);
end

--Debug settings
function Vect:getDebugLevel()
	local db = Vect.db.profile;
	return db["debugLevel"];
end

function Vect:setDebugLevel(v)
	local db = Vect.db.profile;
	db["debugLevel"] = v;
end
		
function Vect:getSpellCastDebug()
	local db = Vect.db.profile;
	return db["spellCastDebug"];
end

function Vect:setSpellCastDebug(v)
	local db = Vect.db.profile;
	db["spellCastDebug"] = v;
end

function Vect:getSpellAuraDebug()
	local db = Vect.db.profile;
	return db["spellAuraDebug"];
end

function Vect:setSpellAuraDebug(v)
	local db = Vect.db.profile;
	db["spellAuraDebug"] = v;
end

function Vect:getAllCDebug()
	local db = Vect.db.profile;
	return db["allCDebug"];
end

function Vect:setAllCDebug(v)
	local db = Vect.db.profile;
	db["allCDebug"] = v;
end

function Vect:getSelfCDRegister()
	local db = Vect.db.profile;
	return db["selfCDRegister"];
end

function Vect:setSelfCDRegister(v)
	local db = Vect.db.profile;
	db["selfCDRegister"] = v;
	Vect:ReassignCds("target");
	Vect:ReassignCds("focus");
end