SLPlague = LibStub("AceAddon-3.0"):NewAddon("SLPlague", "AceTimer-3.0", "AceEvent-3.0","AceComm-3.0","AceConsole-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local plague = "Unbound Plague"
local sickness = "Plague Sickness"


local newOrder
do
	local current = 0
	function newOrder()
		current = current + 1
		return current
	end
end

-- Options
SLPlague.options = {
	name = "Slap Plague",
	handler = SLPlague,
	type = "group",
	childGroups = "tab",
	get = "OptionsGet",
	set = "OptionsSet",
	args = {
-- First Tab General Options
		options = {
			type = "group",
			name = "Options",
			order = newOrder(),
			childGroups = "tree",
			args = {
				master = {
					type = "toggle",
					name = "Enable Master Mode",
					desc = "The master sends out all whispers and marks targets. Only one player in the raid is needed for that!",
					order = newOrder(),
				},
				raidmarksgroup = {
					type = "group",
					name = "Raid Marks",
					order = newOrder(),
					args = {
						raidmarks = {
							type = "toggle",
							name = "Enable Raid Marks",
							order = newOrder(),
						},
						currenttargetmark = {
							type = "select",
							name = "Current Plague Target",
							values = {
								star = "Star",
								circle = "Circle",
								diamond = "Diamond",
								triangle = "Triangle",
								moon = "Moon",
								square = "Square",
								cross = "Cross",
								skull = "Skull",
							},
							order = newOrder(),
						},
						nexttargetmark = {
							type = "select",
							name = "Next Plague Target",
							values = {
								star = "Star",
								circle = "Circle",
								diamond = "Diamond",
								triangle = "Triangle",
								moon = "Moon",
								square = "Square",
								cross = "Cross",
								skull = "Skull",
							},
							order = newOrder(),
						},
					}
				}, --raidmarksgroup
				chatgroup = {
					type = "group",
					name = "Chat Settings",
					order = newOrder(),
					args = {
						raidwarning = {
							type = "toggle",
							name = "Enable Raid Warnings",
							order = newOrder(),
						},
						whispers = {
							type = "toggle",
							name = "Enable Whispers",
							order = newOrder(),
						},
					}
				}, --chatgroup
			}
		}, --options
		targets = {
			type = "group",
			name = "Targets",
			order = newOrder(),
			args = {
				desc = {
					order = 0,
					type = "description",
					name = "Choose up to 8 players who will share the plague between themselves",
				},
			}
		}, --targets
	}
}

-- Generate 8 Boxes for the possible targets
for i = 1, 8 do
	SLPlague.options.args.targets.args["targets"..i] = {
		order = i,
		type = "select",
		name = "Player "..tostring(i),
		values = function() return SLPlague:GetUnitsForDropdown("targets", i) end,
		get = function() return SLPlague.db.profile.targets[i] end,
		set = function(self, val) SLPlague.db.profile.targets[i] = val end,
	}
end

local defaults = {
	profile = {
		nexttargetmark = "star",
		currenttargetmark = "skull",
		master = false,
		raidwarning = false,
		whispers = false,
		raidmarks = false,
		targets = {},
	},
}

function SLPlague:GetUnitsForDropdown(type, num)
	local t = { [""] = "" }
	
	if SLPlague.db.profile[type][num] then
		local playerName = SLPlague.db.profile[type][num]
		t[playerName] = playerName
	end

	if not UnitInRaid("player") then return t end
	local numRaid = GetNumRaidMembers()
	for i = 1, numRaid do
		local playerName = GetRaidRosterInfo(i)
		local found = false
		for index, playerName2 in pairs(SLPlague.db.profile.targets) do
			if playerName2 == playerName then
				found = true
				break
			end
		end
		if not found and playerName then t[playerName] = playerName end
		end
	return t
end

function SLPlague:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SLPlagueDB", defaults, "Default")
	
	self.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("SLPlague", self.options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SLPlague", "SLPlague")

	self:RegisterChatCommand("slp", "ChatCommand")

end

function SLPlague:OnEnable()
	self.timerCount = 0
	self.debug = false
	self:UnregisterAllEvents()
	if (self.db.profile.master==true) then
		-- This is going to be the Master of Disaster!
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "SpellApplied")
	end
	-- Listen for Addon Comm from the Master
	self:UnregisterAllComm()
	self:RegisterComm("SLPlague", "MessageReceived")
end

function SLPlague:MessageReceived(prefix, message, distribution, sender)
	-- Got a Message let's see whats up
	local messageType, timerTime = strsplit(" ", message, 2)
	self.maxTimerTime = timerTime
	if (messageType=="STPCT") then
		-- We have been infected, let's fire up the Timer
		self.pwtimer = self:ScheduleRepeatingTimer("PlagueWearingTimer", 1)
	elseif (messageType=="STPNT") then
		-- We are supposed to pick up the plague soonish
		self.ptotimer = self:ScheduleRepeatingTimer("PlagueTakeOverTimer", 1)
	end
end

-- This Timerfunction is handling the player that has the plague atm
function SLPlague:PlagueWearingTimer()
	self.timerCount = self.timerCount + 1
	local timeLeft = self.maxTimerTime - self.timerCount
	if (timeLeft<=1 and timeLeft>=0) then
		print("Get rid of the plague now!")
	end
	if (self.timerCount>=self.maxTimerTime) then
		-- Check if Plague is gone
		local name = UnitDebuff("player", plague)
		if not name then
			self:CancelTimer(self.pwtimer)
		end
	end
end

-- This Timerfunction is handling the player that has to take over the plague
function SLPlague:PlagueTakeOverTimer()
	self.timerCount = self.timerCount + 1
	local timeLeft = self.maxTimerTime - self.timerCount
	if (timeLeft<=1 and timeLeft>=0) then
		print("Take over the plague now!")
	end
	if (self.timerCount>=self.maxTimerTime) then
		-- Check if Plague jumped over to us
		local name = UnitDebuff("player", plague)
		if name then
			self:CancelTimer(self.ptotimer)
		end
	end
end

-- This Timerfunction checks if the Raid Marks have been changed
function SLPlague:CheckRaidMarksTimer()
end

function SLPlague:SpellApplied(event, timestamp, eventType, srcGuid, srcName, srcFlags, dstGuid, dstName, dstFlags, ...)
	if (eventType=="SPELL_AURA_APPLIED") then
		local spellId, spellName, spellSchool = select (1, ... )
		if (spellName==plague) then
			-- Check if current target has sickness already and adjust the Timer
			local name, _, _, count = UnitDebuff(dstName, sickness)
			if not name then
				maxTimerTime = 12
			else
				maxTimerTime = 12/(count+1)
			end
			-- Get the next Target from our list
			-- Also checks if players can get the debuff or not.
			target = self:GetNextTarget(dstName)
			if (target~=nil) then
				if (self.debug==true)
				then
					print(("DEBUG - Next Target is %s"):format(target))
				end

			-- Send an addon message to both players and start the timer on em
			-- First to the debuffed player to start his timer
--TODO		SendAddonMessage("SLPlague","STPCT ".maxTimerTime,"WHISPER",self.currentTarget)
--TODO		SendChatMessage(target." is taking the plague off you!","WHISPER",GetDefaultLanguage("player"),self.currentTarget)
			
			-- Second to the designated next target
--TODO		SendAddonMessage("SLPlague","STPNT ".maxTimerTime,"WHISPER",target)
--TODO		SendChatMessage("Take the plague off ".self.currentTarget,"WHISPER",GetDefaultLanguage("player"),target)
				if (self.db.profile.raidmarks==true) then
					SetRaidTarget(cTarget,ConvertToIconIndex(self.db.profile.nexttargetmark))
					SetRaidTarget(cTarget,ConvertToIconIndex(self.db.profile.currenttargetmark))
					if (self.debug==true) then
						print(("DEBUG - Setting %s on Current Target"):format(self.db.profile.currenttarget))
						print(("DEBUG - Setting %s on Next Target"):format(self.db.profile.nexttarget))
					end
				end
			end
		end
	end
end

function SLPlague:ConvertToIconIndex(mark)
	if (mark=="Star") then index=1 
	elseif (mark=="Circle") then index=2
	elseif (mark=="Diamond") then index=3
	elseif (mark=="Triangle") then index=4
	elseif (mark=="Moon") then index=5
	elseif (mark=="Square") then index=6
	elseif (mark=="Cross") then index=7
	elseif (mark=="Skull") then index=8
	end
	return index
end

function SLPlague:ChatCommand()
	if (self.debug==false) then
		self.debug=true
		print("DEBUG - Active!")
	else
		self.debug=false
		print("DEBUG - Deactivated!")
	end
end

function SLPlague:OptionsGet(info)
	return self.db.profile[info[#info]]
end

function SLPlague:OptionsSet(info, value)
	self.db.profile[info[#info]] = value
end

function SLPlague:GetNextTarget(curr_target)
	--Loop over the list of possible targets
	local dist = 0
	local tmpdist = 0
	local nextTarget = nil
	for i, poss_target in pairs(SLPlague.db.profile.targets) do
		if UnitInRaid(poss_target) and not UnitIsDeadOrGhost(poss_target) and UnitIsConnected(poss_target) and not curr_target==poss_target then
			local name = UnitDebuff(poss_target, sickness)
			if not name then
				-- Get the Distance between the two players and remember it
				if (dist==0) then
				-- First Call
					dist=SLPlague:CalculateRange(self.currentTarget,poss_target)	
					nextTarget = poss_target
				else
				-- We have a distance already check if current player is closer
					tmpdist=SLPlague:CalculateRange(self.currentTarget,poss_target)
					if (tmpdist<dist) then
						nextTarget = poss_target
					end
				end
			end
		end
	end
	return nextTarget
end

function SLPlague:OptionsGet(info)
	return self.db.profile[info[#info]]
end

function SLPlague:OptionsSet(info, value)
	self.db.profile[info[#info]] = value
end
	  

-- TODO
-- Get the Addon communication working
-- A function to check the marks every second and if they got changed set em back
-- Fire up a local bar to show when you have to do something
