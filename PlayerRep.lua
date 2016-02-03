
----------------------------------------
-- Variables
----------------------------------------

local addonName, _addonData = ...;
local _version = "";

local AceGUI = LibStub("AceGUI-3.0");
local PlayerRep = LibStub("AceAddon-3.0"):NewAddon("PlayerRep")

local _db = nil;

local defaults = {
	global = {
		
		playersMet = {},
		options = {
			formatDate = false;
			formatTime = false;
			showPopup = true;
			popupSound = true;
			saveTime = 86400;
			storageLimit = 10000;
			version = "";
		}
	}
}

local _options = {
			formatDate = false;
			formatTime = false;
			showPopup = true;
			popupSound = true;
			saveTime = 86400;
			storageLimit = 10000;
			version = "";
		}

local _allSavedPlayers = {};
local _benefitionalPlayers = {};
local _currentGroup = {};
local _newGroup = {};
local _openedDuringCombat = false;
local _dateTimeFormat = "";
local _inLoadingScreen = true;

_addonData.variables = {}
_addonData.help = {}
local _help = _addonData.help;

local DISPLAY_MET = 0;
local DISPLAY_LIKE = 1;
local DISPLAY_NOTE = 2;
local DISPLAY_ALL = 4;
local DISPLAY_DETAILS = 3;

local PLAYERS_PER_PAGE = 10;
local STORAGE_MAX = 10000;
local CUSTOMPATH = "Interface/AddOns/".. addonName .."/Images/"

local FORMAT_DATE_EU = "%d/%m/%Y";
local FORMAT_DATE_US = "%m/%d/%Y";
local FORMAT_TIME_24 = "%H:%M:%S";
local FORMAT_TIME_12 = "%I:%M:%S %p";
local FORMAT_STARNOTE = "Starred and noted %s";
local FORMAT_STAR = "Starred %s";
local FORMAT_NOTE = "Added note to %s";
local FORMAT_ADDED = "Added %s";

local TOOLTIP_OPTION_SAVETIME = "The time met players will\n be shown for (in sec).";
local TOOLTIP_OPTION_STORAGE = "Limit of how many players will be saved.\nPassing this limit results in the players not\n seen the longest being deleted.\nA large storage can result in small fps drops.\nRecommended: 10,000";

local HELP_INFO_MAIN = "As you join a party or a raid groups, you meet new people which will be added to this list.\n\nYou can star players for good behaviour or skill or add a note to remember them by.\n"
local HELP_INFO_TABS = "Over time, met players will become hidden.\n\nPlayers you starred of added a note for, will be stored in their respective tabs until you decide to remove the star or note.\n\nAll players, including older ones, can also be found by clicking the time icon on the right.\n";
local ERROR_OPEN_IN_COMBAT = "|cFFFFD100PREP:|r |cFFFF5555Can't open that during combat. It will open once you leave combat.|r";
local TOOLTIP_FRIEND_ICON = "Open PlayerRep";
local ERROR_INVALID_TARGET = "|cFFFFD100PREP:|r Could not add note to that target.";
local COLOR_GREEN = "|cFF00FF00";
local COLOR_ORANGE = "|cFFFFA500";
local COLOR_RED = "|cFFFF0000";

local _helpPlate = {
	FramePos = { x = 5,	y = -25 },
	FrameSize = { width = 440, height = 495	},
	[1] = { ButtonPos = { x = 200,	y = -200}, HighLightBox = { x = 40, y = -85, width = 365, height = 395 }, ToolTipDir = "DOWN", ToolTipText = HELP_INFO_MAIN },
	[2] = { ButtonPos = { x = 340,	y = -30}, HighLightBox = { x = 75, y = -30, width = 320, height = 45 }, ToolTipDir = "DOWN", ToolTipText = HELP_INFO_TABS }
}

local function FormatSeconds(secs)
	secs = tonumber(secs);
	local text = "";
	local t = date("!*t", secs);
	t.day = t.day - 1;
	if t.day > 0 then
		text = text .. t.day .. "day ";
	end
	if t.hour > 0 then
		text = text .. t.hour .. "hour ";
	end
	if t.min > 0 then
		text = text .. t.min .. "min ";
	end
	if t.sec > 0 then
		text = text .. t.sec .. "sec ";
	end
	
	return text;
end


local function CountStoredPlayers()
	local count = 0;
	for k, v in pairs(_allSavedPlayers) do
		count = count + 1;
	end
	return count;
end

local function SortPlayerList(list)
	-- sort by date, then times met, then name
	table.sort(list, function(a, b) 
		if a.latestStamp == b.latestStamp then
			if a.timesMet == b.timesMet then
				return a.name < b.name;
			end
			return a.timesMet > b.timesMet;
		end
		return a.latestStamp > b.latestStamp
	end);
end

local function SortForRemoval(list)
	-- more to least important
	-- starred > noted > met multiple times > date
	table.sort(list, function(a, b) 
		if (a.score == 1 and b.score == 1) or (a.score == 0 and b.score == 0) then
			if a.note == nil then
				a.note = "";
			end
			if b.note == nil then
				b.note = "";
			end
		
			if (a.note == b.note) or ( a.note == "" and b.note == "") then
			
				if a.timesMet == b.timesMet then
					return a.latestStamp > b.latestStamp;
				end
				return a.timesMet > b.timesMet;
			end
			
			return a.note > b.note;
		end
		return a.score > b.score
	end);
end

local function PlayerIsInCurrentGroup(player)
	for k, lPlayer in ipairs(_currentGroup) do
		if player.name == lPlayer.name then
			return true;
		end
	end
	return false;
end

local function CheckOverflow()
	local storedCount = CountStoredPlayers()
	if storedCount < _options.storageLimit + 1 then return; end
	local nrToDelete = storedCount - _options.storageLimit - 1;
	
	local list = {};
	for k, player in pairs(_allSavedPlayers) do
		table.insert(list, player);
	end
	SortForRemoval(list);
	
	local l = nil;
	for i=#list, #list-nrToDelete, -1 do
		l = list[i];
		_allSavedPlayers["" .. l.name] = nil;
	end
end

local function UpdateStorageCounter(count)
	if count == nil then
		count = CountStoredPlayers();
	end
	
	local color = COLOR_GREEN;
	if _options.storageLimit - count < 10 then
		color = COLOR_RED;
	elseif _options.storageLimit - count < 500 then
		color = COLOR_ORANGE;
	end
	PREP_Options.storageLimitText:SetText(color .. count .. " |r/ " .. _options.storageLimit);
end

local function UpdateShowButtons()

	local likeCount = 0;
	local oldsaves = CountStoredPlayers();
	local neutralCount = 0;
	local notedCount = 0;
	local now = time();
	for k, player in ipairs(_benefitionalPlayers) do
		if now - player.latestStamp < _options.saveTime then
			neutralCount = neutralCount + 1;
		end
		if player.score > 0 then
			likeCount = likeCount + 1;
		end
		if (player.note ~= "" and player.note ~= nil) then
			notedCount = notedCount + 1;
		end
	end
	
	local btn = PREP_PlayerMetContainer.showMetButton;
	btn.count:SetText(neutralCount);
	
	btn = PREP_PlayerMetContainer.showLikeButton;
	btn.count:SetText(likeCount);
	
	btn = PREP_PlayerMetContainer.showNotedButton;
	btn.count:SetText(notedCount);

	return neutralCount, likeCount, oldsaves, notedCount;
end

local function SetPageDisplay(display)
	if display == DISPLAY_MET then
		PREP_PlayerMetContainer.showMetButton.select:Show();
	else
		PREP_PlayerMetContainer.showMetButton.select:Hide();
	end
	if display == DISPLAY_LIKE then
		PREP_PlayerMetContainer.showLikeButton.select:Show();
	else
		PREP_PlayerMetContainer.showLikeButton.select:Hide();
	end
	if display == DISPLAY_NOTE then
		PREP_PlayerMetContainer.showNotedButton.select:Show();
	else
		PREP_PlayerMetContainer.showNotedButton.select:Hide();
	end
	PREP_PlayerMetContainer.display = display;
end

function PREP_ShowHelpUnlocks(show)
	-- when showing help, if there's no unlocks, show dummy unlocks
	local now = time();
	local tutPlayers = {{
				["race"] = "Tauren",
				["note"] = "Friendly player",
				["name"] = "Norm",
				["sex"] = "Male",
				["firstStamp"] = now,
				["class"] = "Shaman",
				["score"] = 1,
				["latestStamp"] = now,
				["timesMet"] = 5,
				["tutorial"] = true,
			},
			{
				["race"] = "Bloodelf",
				["note"] = "Ninjapuller",
				["name"] = "Ameyna",
				["sex"] = "Female",
				["firstStamp"] = now,
				["class"] = "Warlock",
				["score"] = 0,
				["latestStamp"] = now,
				["timesMet"] = 11,
				["tutorial"] = true,
			},
			{
				["race"] = "Human",
				["note"] = "",
				["name"] = "Leeroy",
				["sex"] = "Male",
				["firstStamp"] = now,
				["class"] = "Paladin",
				["score"] = 0,
				["latestStamp"] = now,
				["timesMet"] = 3,
				["tutorial"] = true,
			}
			}
			
	if show then 
		local n, l, d = UpdateShowButtons();
		SetPageDisplay(DISPLAY_MET);
		if (n == 0) then
			for k, p in ipairs(tutPlayers) do
				table.insert(_benefitionalPlayers, p);
			end
		end
	else
		for i=#_benefitionalPlayers,1,-1 do
			if _benefitionalPlayers[i].tutorial then
				table.remove(_benefitionalPlayers, i);
			end
		end
	end
	
	PREP_UpdateContainer();
end

local function SetDateTimeFormat(useUS, use12)
	local text = "";
	if (useUS) then
		text = FORMAT_DATE_US;
	else
		text = FORMAT_DATE_EU;
	end
	
	if (use12) then
		text = text .. " " .. FORMAT_TIME_12;
	else
		text = text .. " " ..  FORMAT_TIME_24;
	end
	
	_dateTimeFormat = text;
end

function PREP_TutorialButton_OnClick()
	PREP_Options:Hide();

	if PREP_HelpFrame:IsShown() then
		_help:HideTutorial();
		PREP_ShowHelpUnlocks(false);
	else
		_help:ShowTutorial();
		PREP_ShowHelpUnlocks(true);
	end
end

local function GetFullDoubleDigit(number)
	return string.format("%02d", number);
end

local function ShowMainFrame()

	-- prevent opening in combat because blizzard protection
	if InCombatLockdown() then 
		_openedDuringCombat = true;
		print(ERROR_OPEN_IN_COMBAT);
		return;
	else
		PREP_AlertPopup:Hide();
		PREP_FriendsTab:SetChecked(true);
		PREP_PlayerMetContainer:Show();
		PlaySound("igSpellBookOpen");
	end
	
end

local function Popup_OnClick(self, button)
	if(button == "LeftButton") then
		ShowMainFrame();
		
	end
	self:Hide();
end

function PREP_ClearButton_OnClick()
	PREP_ClearNeutral();
end

local function ToggleOptionFrame()

	if (PREP_Options:IsShown()) then
		PREP_Options:Hide();
		PREP_AlertPopup:Hide();
	else
		PREP_Options:Show();
		PREP_AlertPopup:Show();
	end

end

function PREP_OptionsFrame_EnableBack(enabled)
	-- if options are show, darken all background items to half their color
	-- and prevent the player from interacting with buttons
	local color = 1;
	if not enabled then
		color = 0.5;
	end
	
	-- players
	for i=1, PLAYERS_PER_PAGE do
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(i)];
		button:EnableMouse(enabled);
		button.upvote:EnableMouse(enabled);
		button.upvote.texture:SetVertexColor(color, color, color, 1);
		--button.downvote:EnableMouse(enabled);
		--button.downvote.texture:SetVertexColor(color, color, color, 1);
		button.noteBtn:EnableMouse(enabled);
		button.noteBtn.texture:SetVertexColor(color, color, color, 1);
		button.iconRace:SetVertexColor(color, color, color, 1);
		button.iconClass:SetVertexColor(color, color, color, 1);
		button.scorePositive:SetVertexColor(0, color, 0, 0.2);
		
		if enabled then
			button.name:SetTextColor(1.0, 0.82, 0, 1);
			button.encounters:SetTextColor(1.0, 0.82, 0, 1);
			button.partyHighlight:SetVertexColor(1, 1, 1, 0.2);
		else
			button.name:SetTextColor(0.5, 0.42, 0, 1);
			button.encounters:SetTextColor(0.5, 0.42, 0, 1);
			button.partyHighlight:SetVertexColor(1, 1, 1, 0.1);
		end
	end

	-- tab buttons
	PREP_PlayerMetContainer.showMetButton:EnableMouse(enabled);
	PREP_PlayerMetContainer.showLikeButton:EnableMouse(enabled);
	PREP_PlayerMetContainer.showAllButton:EnableMouse(enabled);
	PREP_PlayerMetContainer.showMetButton.bg:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.showLikeButton.bg:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.showNotedButton.bg:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.showMetButton.icon:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.showLikeButton.icon:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.showNotedButton.icon:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.showAllButton.normal:SetVertexColor(color, color, color, 1);
	
	PREP_PlayerMetContainer.showMetButton.select:SetVertexColor(color, color, color, 0.5);
	PREP_PlayerMetContainer.showLikeButton.select:SetVertexColor(color, color, color, 0.5);
	PREP_PlayerMetContainer.showNotedButton.select:SetVertexColor(color, color, color, 0.5);
	if enabled then
		PREP_PlayerMetContainer.showMetButton.count:SetVertexColor(1.0, 0.82, 0, 1);
		PREP_PlayerMetContainer.showLikeButton.count:SetVertexColor(1.0, 0.82, 0, 1);
		PREP_PlayerMetContainer.showNotedButton.count:SetVertexColor(1.0, 0.82, 0, 1);

	else
		PREP_PlayerMetContainer.showMetButton.count:SetVertexColor(0.5, 0.42, 0, 1);
		PREP_PlayerMetContainer.showLikeButton.count:SetVertexColor(0.5, 0.42, 0, 1);
		PREP_PlayerMetContainer.showNotedButton.count:SetVertexColor(0.5, 0.42, 0, 1);
	end
	
	-- search box
	PREP_PlayerMetContainer.searchIcon:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.search.editbox:EnableMouse(enabled);
	PREP_PlayerMetContainer.search.editbox.Left:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.search.editbox.Middle:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.search.editbox.Right:SetVertexColor(color, color, color, 1);
	
	PREP_PlayerMetContainer.Navigation.Prev:EnableMouse(enabled);
	PREP_PlayerMetContainer.Navigation.Prev.normal:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.Navigation.Prev.disabled:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.Navigation.Next:EnableMouse(enabled);
	PREP_PlayerMetContainer.Navigation.Next.normal:SetVertexColor(color, color, color, 1);
	PREP_PlayerMetContainer.Navigation.Next.disabled:SetVertexColor(color, color, color, 1);
	
	PREP_PlayerMetContainer.bg:SetVertexColor(color, color, color, 1);
	
	-- Player detail
	PREP_PlayerDetails.iconRace:SetVertexColor(color, color, color, 1);
	PREP_PlayerDetails.iconClass:SetVertexColor(color, color, color, 1);
	PREP_PlayerDetails.scorePositive:SetVertexColor(0, color, 0, 0.2);
	if enabled then
		PREP_PlayerDetails.name:SetTextColor(1.0, 0.82, 0, 1);
		PREP_PlayerDetails.txt01:SetTextColor(1.0, 0.82, 0, 1);
		PREP_PlayerDetails.txt02:SetTextColor(1.0, 0.82, 0, 1);
	else
		PREP_PlayerDetails.name:SetTextColor(0.5, 0.42, 0, 1);
		PREP_PlayerDetails.txt01:SetTextColor(0.5, 0.42, 0, 1);
		PREP_PlayerDetails.txt02:SetTextColor(0.5, 0.42, 0, 1);
	end
	
end

function PREP_OptionsButton_OnClick()
	ToggleOptionFrame();
end

function PREP_PrevPageButton_OnClick()
	if (PREP_PlayerMetContainer.CurrentPage == 1) then return; end
	PlaySound("igAbiliityPageTurn");
	PREP_PlayerMetContainer.CurrentPage = PREP_PlayerMetContainer.CurrentPage - 1;
	PREP_PlayerMetContainer.Navigation.Text:SetText("Page ".. PREP_PlayerMetContainer.CurrentPage);
	PREP_UpdateContainer();
end

function PREP_NextPageButton_OnClick()
	if (PREP_PlayerMetContainer.CurrentPage >= PREP_UpdateNavigation()) then return; end
	PlaySound("igAbiliityPageTurn");
	PREP_PlayerMetContainer.CurrentPage = PREP_PlayerMetContainer.CurrentPage + 1;
	PREP_PlayerMetContainer.Navigation.Text:SetText("Page ".. PREP_PlayerMetContainer.CurrentPage);
	PREP_UpdateContainer();
end

function UnlockContainer_OnMouseWheel(self, delta)
	if delta == 1 then
		PREP_PrevPageButton_OnClick();
	else
		PREP_NextPageButton_OnClick();
	end
end

function PREP_UpdateNavigation()

	local n, l, d, noted = UpdateShowButtons()

	local totalPages = 0;
	
	if (PREP_PlayerMetContainer.display == DISPLAY_MET) then
		totalPages = ceil(n/PLAYERS_PER_PAGE);
	elseif (PREP_PlayerMetContainer.display == DISPLAY_LIKE) then
		totalPages = ceil(l/PLAYERS_PER_PAGE);
	elseif (PREP_PlayerMetContainer.display == DISPLAY_NOTE) then
		totalPages = ceil(noted/PLAYERS_PER_PAGE);
	elseif (PREP_PlayerMetContainer.display == DISPLAY_ALL) then
		totalPages = ceil(d/PLAYERS_PER_PAGE);
	end

	if (totalPages > 0 and PREP_PlayerMetContainer.CurrentPage > totalPages) then
		PREP_PlayerMetContainer.CurrentPage = totalPages;
	end

	PREP_PlayerMetContainer.Navigation.Text:SetText("Page ".. PREP_PlayerMetContainer.CurrentPage);
	
	PREP_PlayerMetContainer.Navigation.Prev:Enable();
	PREP_PlayerMetContainer.Navigation.Next:Enable();

	-- disable prev on first page;
	if (PREP_PlayerMetContainer.CurrentPage == 1) then
		PREP_PlayerMetContainer.Navigation.Prev:Disable();
	end

	-- disable next page if on last page
	if (totalPages == 0 or PREP_PlayerMetContainer.CurrentPage == totalPages) then
		PREP_PlayerMetContainer.Navigation.Next:Disable();
	end

	return totalPages;
	
end

local function ChangePlayerScore(button, starred)
	local parent = button:GetParent();
	
	local player = nil;

	for k, p in ipairs(_benefitionalPlayers) do
		if p.name == parent.player.name then
			player = p;
			break;
		end
	end
	
	-- player not in benefitional yet
	if player == nil then
		player = _allSavedPlayers["" .. parent.player.name];
		table.insert(_benefitionalPlayers, player);
	end
	
	player.score = starred and 1 or 0;
	
	PREP_UpdateContainer();
	
end

local function ChangePlayerNote(button, note)
	local player = nil;
	
	for k, p in ipairs(_benefitionalPlayers) do
		if p.name == button.player.name then
			player = p;
			break;
		end
	end
	
	-- player not in benefitional yet
	if player == nil then
		player = _allSavedPlayers["" .. button.player.name];
		table.insert(_benefitionalPlayers, player);
	end
	
	player.note = note;
	PREP_UpdateContainer();
end

local function ShowPlayerDetails(player)
	if player == nil then return; end
	PREP_PlayerDetails.player = player;
	PREP_PlayerDetails.name:SetText(player.name);
	PREP_PlayerDetails.stampFirst:SetText(date(_dateTimeFormat, player.firstStamp));
	PREP_PlayerDetails.stampLast:SetText(date(_dateTimeFormat, player.latestStamp));
	
	PREP_PlayerDetails.upvote:SetNormalTexture("Interface/Buttons/Arrow-Up-Disabled");
	PREP_PlayerDetails.downvote:SetNormalTexture("Interface/Buttons/Arrow-Down-Disabled");
	
	local faction = UnitFactionGroup("player");
	faction = faction == "Neutral" and "Horde" or faction;
	PREP_PlayerDetails.iconClass:SetTexture("Interface/ICONS/ClassIcon_" .. string.gsub(player.class, " ", ""));
	local path = CUSTOMPATH .. "Race_" .. player.race .. "_" .. player.sex;
	path = player.race == "Pandaren" and path .. "_" .. faction or path;
	PREP_PlayerDetails.iconRace:SetTexture(path);
	
	PREP_PlayerDetails.scorePositive:Hide();
	PREP_PlayerDetails.partyHighlight:Hide();
	if player.score > 0 then
			PREP_PlayerDetails.scorePositive:Show();
			PREP_PlayerDetails.upvote:SetNormalTexture("Interface/Buttons/Arrow-Up-Up");
		elseif player.score < 0 then
			PREP_PlayerDetails.partyHighlight:Show();
			PREP_PlayerDetails.downvote:SetNormalTexture("Interface/Buttons/Arrow-Down-Up");
		end
	
	PREP_PlayerDetails.editBox:SetText(player.note);
end

function PREP_HideThingsFromAllPlayerButtons(currentButton)
	for i=1, PLAYERS_PER_PAGE do
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(i)];
		if button ~= currentButton then
			button:UnlockHighlight();
			--button.befriend:Hide();
			button.noteBtn:Hide();
			button.inPartyBtn:Hide();
		end
	end
end

function PREP_EnterPlayerButton(self)
	PREP_HideThingsFromAllPlayerButtons(self);

	self:LockHighlight();
	--self.befriend:Show();
	self.noteBtn:Show();
	if	self.partyHighlight:IsShown() then
		self.inPartyBtn:Show();
	end
end

function PREP_CreateContainer()
	PREP_PlayerMetContainer:SetPoint("center", UIParent, "center", 0, 0);

	PREP_PlayerMetContainer:SetMovable(true);
	PREP_PlayerMetContainer:EnableMouse(true);
	PREP_PlayerMetContainer:SetClampedToScreen(true);
	PREP_PlayerMetContainer:SetToplevel(true)
	PREP_PlayerMetContainer:RegisterForDrag("LeftButton");
	PREP_PlayerMetContainer:SetScript("OnDragStart", PREP_PlayerMetContainer.StartMoving );
	PREP_PlayerMetContainer:SetScript("OnDragStop", PREP_PlayerMetContainer.StopMovingOrSizing);
	-- allows the player to close the frame using Esc like regular blizzard windows
	table.insert(UISpecialFrames, "PREP_PlayerMetContainer")
	
	PREP_PlayerMetContainer.showMetButton:SetScript("OnClick", function(self)
									SetPageDisplay(DISPLAY_MET);
									--PREP_PlayerMetContainer.display = DISPLAY_MET;
									PREP_PlayerMetContainer.CurrentPage = 1;
									PREP_UpdateContainer(); 
								end);
	PREP_PlayerMetContainer.showLikeButton:SetScript("OnClick", function(self)
									--PREP_PlayerMetContainer.display = DISPLAY_LIKE;
									SetPageDisplay(DISPLAY_LIKE);
									PREP_PlayerMetContainer.CurrentPage = 1;
									PREP_UpdateContainer(); 
								end);
	PREP_PlayerMetContainer.showNotedButton:SetScript("OnClick", function(self)
									--PREP_PlayerMetContainer.display = DISPLAY_NOTE;
									SetPageDisplay(DISPLAY_NOTE);
									PREP_PlayerMetContainer.CurrentPage = 1;
									PREP_UpdateContainer(); 
								end);
	PREP_PlayerMetContainer.showAllButton:SetScript("OnClick", function(self)
									--PREP_PlayerMetContainer.display = DISPLAY_ALL;
									SetPageDisplay(DISPLAY_ALL);
									PREP_PlayerMetContainer.CurrentPage = 1;
									PREP_UpdateContainer(); 
								end);
	
	PREP_PlayerMetContainer.CurrentPage = 1;
	--PREP_PlayerMetContainer.display = DISPLAY_MET;
	SetPageDisplay(DISPLAY_MET);

	--PREP_PlayerMetContainerInsetBg:Hide();
	--PREP_PlayerMetContainerBg:Hide();
	
	for i=1, PLAYERS_PER_PAGE do
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(i)];
		
		button.upvote:SetScript("OnClick", function(self) ChangePlayerScore(self, self:GetChecked()) end);
		--button.downvote:SetScript("OnClick", function(self) ChangePlayerScore(self, -1) end);
		
		button:SetScript("OnEnter", function(self) 
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				GameTooltip:SetText(self.player.name);
				GameTooltip:AddDoubleLine("Seen First", date(_dateTimeFormat, self.player.firstStamp),1 ,1 ,1 ,1 ,1 ,1);
				GameTooltip:AddDoubleLine("Seen Last", date(_dateTimeFormat, self.player.latestStamp),1 ,1 ,1 ,1 ,1 ,1);
				GameTooltip:AddDoubleLine("Times Met", self.player.timesMet,1 ,1 ,1 ,1 ,1 ,1);
				GameTooltip:AddLine(self.player.note ,1 ,0.82 ,0 ,true);
				GameTooltip:Show();
				
				PREP_EnterPlayerButton(self);
			end);
		button:SetScript("OnLeave", function(self) 
				PREP_HideThingsFromAllPlayerButtons(currentButton);
				GameTooltip:Hide();
			end);
		
		button.gui = AceGUI:Create("SimpleGroup");
		button.gui:SetWidth(175);
		button.gui:SetHeight(15);
		button.gui:SetLayout("flow");
		button.gui.frame:SetParent(button);
		button.gui.frame:SetPoint("BOTTOMLEFT", 120, -1);
		
		button.editBox = AceGUI:Create("EditBox");
		button.editBox:SetLabel("");
		button.editBox:SetText("Write note");
		button.editBox.editbox.Left:Hide();
		button.editBox.editbox.Middle:Hide();
		button.editBox.editbox:SetTextColor(0, 0, 0, 1);
		button.editBox.editbox:SetShadowColor(0, 0, 0, 0);
		button.editBox.editbox.Right:Hide();
		button.editBox.editbox:SetFontObject("GameFontNormal");
		button.editBox.editbox:EnableMouse(false);
		button.editBox:SetCallback("OnEnterPressed", function(__,__, value)
				ChangePlayerNote(button, value);
				button.editBox.editbox:SetCursorPosition(0);
				button.editBox.editbox:EnableMouse(false);
				button.editBox.editbox:ClearFocus();
			end)
		button.editBox.editbox:SetScript("OnEditFocusLost", function(self) 
				button.editBox.editbox:EnableMouse(false);
			end);
		
		button.gui:AddChild(button.editBox);
		
		button.noteBtn:SetScript("OnClick", function(self) 
				button.editBox.editbox:EnableMouse(true);
				button.editBox.editbox:SetFocus();
				button.editBox.editbox:SetCursorPosition(button.editBox.editbox:GetNumLetters());
			end);
	end
	-- Hide befriend and other buttons from all buttons
	PREP_HideThingsFromAllPlayerButtons();
	
	-- Note on player details
	PREP_PlayerDetails.gui = AceGUI:Create("SimpleGroup");
	PREP_PlayerDetails.gui:SetWidth(250);
	PREP_PlayerDetails.gui:SetHeight(50);
	PREP_PlayerDetails.gui:SetLayout("flow");
	PREP_PlayerDetails.gui.frame:SetParent(PREP_PlayerDetails);
	PREP_PlayerDetails.gui.frame:SetPoint("TOP", 25, -80);

	PREP_PlayerDetails.editBox = AceGUI:Create("EditBox");
	PREP_PlayerDetails.editBox:SetRelativeWidth(1);
	PREP_PlayerDetails.editBox:SetLabel("");
	PREP_PlayerDetails.editBox:SetText("");
	PREP_PlayerDetails.editBox:DisableButton(true);
	PREP_PlayerDetails.editBox.editbox.Left:Hide();
	PREP_PlayerDetails.editBox.editbox.Right:Hide();
	PREP_PlayerDetails.editBox.editbox.Middle:Hide();
	PREP_PlayerDetails.editBox.editbox:SetTextColor(0, 0, 0, 1);
	PREP_PlayerDetails.editBox.editbox:SetShadowColor(0, 0, 0, 0);
	
	PREP_PlayerDetails.editBox:SetCallback("OnEnterPressed", function(__,__, value)
			PREP_PlayerDetails.player.note = value;
			PREP_PlayerDetails.editBox.editbox:SetCursorPosition(0);
			PREP_PlayerDetails.editBox.editbox:EnableMouse(false);
			PREP_PlayerDetails.editBox.editbox:ClearFocus();
		end)
	
	PREP_PlayerDetails.gui:AddChild(PREP_PlayerDetails.editBox);
	
	-- Search
	PREP_PlayerMetContainer.gui = AceGUI:Create("SimpleGroup");
	PREP_PlayerMetContainer.gui:SetWidth(100);
	PREP_PlayerMetContainer.gui:SetHeight(50);
	PREP_PlayerMetContainer.gui:SetLayout("flow");
	PREP_PlayerMetContainer.gui.frame:SetParent(PREP_PlayerMetContainer);
	PREP_PlayerMetContainer.gui.frame:SetPoint("TOP", 0, -59);
	
	PREP_PlayerMetContainer.search = AceGUI:Create("EditBox");
	PREP_PlayerMetContainer.search:SetRelativeWidth(1);
	PREP_PlayerMetContainer.search:SetLabel("");
	PREP_PlayerMetContainer.search:SetText("");
	PREP_PlayerMetContainer.search:DisableButton(true);
	PREP_PlayerMetContainer.search:SetCallback("OnTextChanged", function(__,__, value)
			PREP_UpdateContainer();
		end)
	PREP_PlayerMetContainer.search:SetCallback("OnEnterPressed", function(__,__, value)
			PREP_PlayerMetContainer.search.editbox:ClearFocus();
		end)

	
	PREP_PlayerMetContainer.gui:AddChild(PREP_PlayerMetContainer.search);
	
	SetPortraitToTexture(PREP_PlayerMetContainerPortrait, "Interface\\ICONS\\Achievement_Reputation_01");
	PREP_PlayerMetContainerTitleText:SetText(addonName);
	PREP_PlayerMetContainerCloseButton:SetScript("OnMouseUp", function() PREP_FriendsTab:SetChecked(false); end );
	
	ButtonFrameTemplate_HideButtonBar(PREP_PlayerMetContainer);
	ButtonFrameTemplate_HideAttic(PREP_PlayerMetContainer);
	
	
	-- Options savetime
	PREP_Options.gui = AceGUI:Create("SimpleGroup");
	PREP_Options.gui:SetWidth(100);
	PREP_Options.gui:SetHeight(50);
	PREP_Options.gui:SetLayout("flow");
	PREP_Options.gui.frame:SetParent(PREP_Options);
	PREP_Options.gui.frame:SetPoint("TOPLEFT", PREP_Options.showPopup, "BOTTOMLEFT" ,  0, 5);
		
	PREP_Options.saveTime = AceGUI:Create("EditBox");
	PREP_Options.saveTime:SetRelativeWidth(1);
	PREP_Options.saveTime:SetLabel("Recently met time");
	PREP_Options.saveTime:SetText("");
	PREP_Options.saveTime:DisableButton(true);
	PREP_Options.saveTime:SetCallback("OnEnterPressed", function(__,__, value)
			if tonumber(value) ~= nil then
				_options.saveTime = tonumber(value);
				PREP_Options.saveTimeText:SetText(FormatSeconds(_options.saveTime)); 
			else
				PREP_Options.saveTime:SetText(_options.saveTime);
			end;
			PREP_Options.saveTime.editbox:ClearFocus();
		end)
	PREP_Options.saveTime.editbox:SetScript("OnEnter", function(self) 
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(TOOLTIP_OPTION_SAVETIME);
		end )
	PREP_Options.saveTime.editbox:SetScript("OnLeave", function(self) 
			GameTooltip:Hide();
		end )
		
	PREP_Options.gui:AddChild(PREP_Options.saveTime);
	
	-- Options storage limit
	PREP_Options.gui2 = AceGUI:Create("SimpleGroup");
	PREP_Options.gui2:SetWidth(100);
	PREP_Options.gui2:SetHeight(50);
	PREP_Options.gui2:SetLayout("flow");
	PREP_Options.gui2.frame:SetParent(PREP_Options);
	PREP_Options.gui2.frame:SetPoint("TOPLEFT", PREP_Options.format, "BOTTOMLEFT" ,  0, 0);
		
	PREP_Options.storageLimit = AceGUI:Create("EditBox");
	PREP_Options.storageLimit:SetRelativeWidth(1);
	PREP_Options.storageLimit:SetLabel("Storage Limit");
	PREP_Options.storageLimit:SetText("");
	PREP_Options.storageLimit:DisableButton(true);
	PREP_Options.storageLimit:SetCallback("OnEnterPressed", function(__,__, value)
			if tonumber(value) ~= nil then
				_options.storageLimit = tonumber(value);
				CheckOverflow();
				UpdateStorageCounter();
				
			else
				PREP_Options.storageLimit:SetText(_options.storageLimit);
			end;
			PREP_Options.storageLimit.editbox:ClearFocus();
		end)
	PREP_Options.storageLimit.editbox:SetScript("OnEnter", function(self) 
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(TOOLTIP_OPTION_STORAGE);
		end )
	PREP_Options.storageLimit.editbox:SetScript("OnLeave", function(self) 
			GameTooltip:Hide();
		end )
		
	PREP_Options.gui2:AddChild(PREP_Options.storageLimit);
	
	PREP_Options.showPopup:SetScript("OnClick", function(self) 
			_options.showPopup = self:GetChecked();
			if self:GetChecked() then
				PREP_Options.popupSound:Enable();
			else
				PREP_Options.popupSound:Disable();
			end
		end );
	PREP_Options.popupSound:SetScript("OnClick", function(self) 
			_options.popupSound = self:GetChecked();
			if _options.popupSound then
				PlaySound("FX_Shimmer_Whoosh_Generic");
			end
		end );
	PREP_Options.format.date:SetScript("OnClick", function(self) 
			SetDateTimeFormat(self:GetChecked(), PREP_Options.format.time:GetChecked());
			--ShowPlayerDetails(PREP_PlayerDetails.player);
			_options.formatDate = self:GetChecked();
		end );
	PREP_Options.format.time:SetScript("OnClick", function(self) 
			SetDateTimeFormat(PREP_Options.format.date:GetChecked(), self:GetChecked());
			--ShowPlayerDetails(PREP_PlayerDetails.player);
			_options.formatTime = self:GetChecked();
		end );

	PREP_UpdateNavigation()
	
	return L_BGS_ContainerBG
end

local function ShowPopUp(liked, notes, met)
	if (not _options.showPopup) then return; end
	if InCombatLockdown() then 
		PREP_AlertPopup.shownInCombat = true;
		PREP_AlertPopup.combatFunc = function() ShowPopUp(liked, notes, met) end;
		return; 
	end
	if _inLoadingScreen then
		PREP_AlertPopup.shownInLoading = true;
		PREP_AlertPopup.combatFunc = function() ShowPopUp(liked, notes, met) end;
		return; 
	end
	
	PREP_AlertPopup:Show();
	if _options.popupSound then
		PlaySound("FX_Shimmer_Whoosh_Generic");
	end
	PREP_AlertPopup:SetAlpha(1);
	PREP_AlertPopup.liked:SetText(liked);
	PREP_AlertPopup.notes:SetText(notes);
	PREP_AlertPopup.met:SetText(met);

end

local function CreatePopupAnimation(self)
	-- create flashing animation to highlight popup
	self.animationA = self:CreateAnimationGroup();
	self.animationA.alpha = self.animationA:CreateAnimation("Alpha");
	self.animationA.alpha:SetChange(-1);
	self.animationA.alpha:SetSmoothing("IN");
	self.animationB = self.highlight:CreateAnimationGroup();
	self.animationB.alpha = self.animationB:CreateAnimation("Alpha");
	self.animationB.alpha:SetChange(-1);
	self.animationB.alpha:SetSmoothing("OUT");
	
	self.animationA:SetScript("OnFinished", function() self.animationB:Play(); end);
	self.animationB:SetScript("OnFinished", function() self.highlight:Hide(); end);
end

local function PlayPopupAnimation(self)
	self:Show();
	if not self.animationA then
		CreatePopupAnimation(self)
	end
	self.animationA.alpha:SetDuration(0.2);
	self.animationB.alpha:SetDuration(0.3);
	self.animationA:Play(true);
end

local function StopPopupAnimation(self)
	self:Hide();
	if not self.animationA then
		return;
	end
	self.animationA:Stop();
	self.animationB:Stop();
end

local function CreateHideAnimation(self)
	-- create fade out animation for popup
	self.animationHide = self:CreateAnimationGroup();
	self.animationHide.alpha = self.animationHide:CreateAnimation("Alpha");
	self.animationHide.alpha:SetChange(-1);
	self.animationHide.alpha:SetFromAlpha(0);
	self.animationHide.alpha:SetToAlpha(1);
	self.animationHide.alpha:SetSmoothing("NONE");

	self.animationHide:SetScript("OnFinished", function()
			self:Hide();
			PREP_AlertPopup.showTime = 0;
		end);
end

local function PlayHideAnimation(self)
	self:Show();
	if not self.animationHide then
		CreateHideAnimation(self)
	end
	self.animationHide.alpha:SetDuration(0.5);
	self.animationHide:Play(true);
	
end

local function PREP_CreatePopup()
	PREP_AlertPopup:SetPoint("center", UIParent, "center", 400, 0);
	PREP_AlertPopup:RegisterForDrag("LeftButton");
	PREP_AlertPopup:SetScript("OnDragStart", PREP_AlertPopup.StartMoving );
	PREP_AlertPopup:SetScript("OnDragStop", PREP_AlertPopup.StopMovingOrSizing);
	PREP_AlertPopup:SetScript("OnShow", function(self) 
			PlayPopupAnimation(self);
			self.highlight:Show();
			self.highlight:SetAlpha(1);
		end );
		
	PREP_AlertPopup:SetScript("OnHide", function(self) 
			PREP_AlertPopup.showTime = 0;
		end );
	
	PREP_AlertPopup.showTime = 0;
	
	PREP_AlertPopup:SetScript("OnClick", function(self, button) Popup_OnClick(self, button);end );
	PREP_AlertPopup:SetScript("OnUpdate", function(self, elapsed) 
			if (PREP_AlertPopup:IsShown() and not PREP_Options:IsShown()) then
				PREP_AlertPopup.showTime = PREP_AlertPopup.showTime + elapsed;
				if (PREP_AlertPopup.showTime >= 5) then
					PREP_AlertPopup.showTime = -5;
					PlayHideAnimation(self);
				end
			end
		end );
	
	PREP_AlertPopup:RegisterForClicks("LeftButtonUp", "RightButtonUp");
end

local function ToggleMainFrame(show)
	if InCombatLockdown() then return; end
	
	if (show) then
		ShowMainFrame();
	else
		PREP_PlayerMetContainer:Hide();
	end

end

local function CreateSpellbookIcon()

	local L_PREP_FriendsTab = CreateFrame("CheckButton", "PREP_FriendsTab", FriendsFrame, "PREP_FriendsButtonTemplate");
	L_PREP_FriendsTab:SetPoint("TOPRIGHT", FriendsFrame, "BOTTOMRIGHT", -15, 1);
	L_PREP_FriendsTab.bg:SetTexture(CUSTOMPATH .. "TabBackground");
	L_PREP_FriendsTab:Show();
	L_PREP_FriendsTab:SetScript("OnEnter", function(self) 
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);
		if InCombatLockdown() then
			GameTooltip:SetText(TOOLTIP_COMBAT);
		else
			GameTooltip:SetText(TOOLTIP_FRIEND_ICON);
		end
	end);
	L_PREP_FriendsTab:SetScript("OnClick", function() 
			if InCombatLockdown() then
				L_PREP_FriendsTab:SetChecked(false);
			else
				ToggleMainFrame(not PREP_PlayerMetContainer:IsShown()); 
			end
		end);

	L_PREP_FriendsTab.icon = L_PREP_FriendsTab:CreateTexture("PREP_FriendsTabIcon");
	L_PREP_FriendsTab.icon:SetPoint("center", L_PREP_FriendsTab, "center", 0, 1);
	L_PREP_FriendsTab.icon:SetSize(32, 32);
	L_PREP_FriendsTab.icon:SetTexture("Interface/ICONS/Achievement_Reputation_01");
	
end

local function ResetButtons()
	for i=1, PLAYERS_PER_PAGE do
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(i)];
		button.player = nil;
		button.name:SetText("PlayerName"..i);
		button.encounters:SetText("99+");
		button.scorePositive:Hide();
		button.partyHighlight:Hide();
		button.upvote:SetChecked(false);
		--button.downvote:SetNormalTexture("Interface/Buttons/Arrow-Down-Disabled");
		button.iconRace:SetTexture("Interface/PaperDoll/UI-PaperDoll-Slot-Head");
		button.iconClass:SetTexture("Interface/PaperDoll/UI-PaperDoll-Slot-MainHand");
		button:Hide();

	end
	--PREP_UpdateNavigation();
end

local function GetPlayersToDisplay(search)
	local temp = {};
	local relevant = {}
	for k, player in pairs(_benefitionalPlayers) do
		if player.race ~= nil or player.class ~= nil then
			table.insert(relevant, player);
		end
	end
	
	if PREP_PlayerMetContainer.display == DISPLAY_MET then
		local currentTime = time();
		for k, player in pairs(relevant) do
			if currentTime - player.latestStamp < _options.saveTime then
				table.insert(temp, player);
			end
		end
	elseif PREP_PlayerMetContainer.display == DISPLAY_LIKE then
		for k, player in pairs(relevant) do
			if (player.score > 0) then
				table.insert(temp, player);
			end
		end
	elseif PREP_PlayerMetContainer.display == DISPLAY_NOTE then
		for k, player in pairs(relevant) do
			if (player.note ~= nil and player.note ~= "") then
				table.insert(temp, player);
			end
		end
	elseif PREP_PlayerMetContainer.display == DISPLAY_ALL then
		for k, player in pairs(_allSavedPlayers) do
				table.insert(temp, player);
		end
	end
	
	-- Apply search to list
	if search ~= "" then
		local searched = {};
		for k, player in pairs(temp) do
			if string.find(player.name:lower(), search:lower()) then
				table.insert(searched, player);
			end
		end
		return searched;
	end
		
	return temp;
end

local function DeleteOldNeutralPlayers()
	local currentTime = time();
	for i=#_benefitionalPlayers,1,-1 do
		if currentTime - _benefitionalPlayers[i].latestStamp > _options.saveTime and _benefitionalPlayers[i].score == 0 and (_benefitionalPlayers[i].note == "" or _benefitionalPlayers[i].note == nil)then
			table.remove(_benefitionalPlayers, i);
		end
	end
end




function PREP_UpdateContainer()
	
	-- Only update when the main window is open
	if (not PREP_PlayerMetContainer:IsShown()) then return; end

	ResetButtons();
	DeleteOldNeutralPlayers();
	local _, _, storage = UpdateShowButtons();
	
	-- update storage counter on options frame
	UpdateStorageCounter(storage)

	PREP_PlayerDetails:Hide();
	if PREP_PlayerMetContainer.display == DISPLAY_DETAILS then
		PREP_PlayerDetails:Show();
	end
	
	local playersToShow = GetPlayersToDisplay(PREP_PlayerMetContainer.search:GetText());
	
	SortPlayerList(playersToShow);
	
	local faction = UnitFactionGroup("player");
	-- change neutral panda to horde because looks left... also FOR THE HORDE!
	faction = faction == "Neutral" and "Horde" or faction;
	local count = 1;
	local player = nil;
	local pageNr = PREP_PlayerMetContainer.CurrentPage;
	local start = (pageNr-1) * PLAYERS_PER_PAGE;
	local nrToShow = (#playersToShow-start) > PLAYERS_PER_PAGE and PLAYERS_PER_PAGE or #playersToShow - start;
	for i = start + 1, (start + nrToShow) do
		player = playersToShow[i];
			
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(count)];
		button.player = player;
		

		button:Show();
		button.name:SetText(player.name);
		button.encounters:SetText(player.timesMet < 100 and player.timesMet or "99+");
		if(player.class ~= nil) then
			button.iconClass:SetTexture("Interface/ICONS/ClassIcon_" .. string.gsub(player.class, " ", ""));
		end
		if(player.race ~= nil) then
			local path = CUSTOMPATH .. "Race_" .. player.race .. "_" .. player.sex;
			path = player.race == "Pandaren" and path .. "_" .. faction or path;
			button.iconRace:SetTexture(path);
		end
		
		if PlayerIsInCurrentGroup(player) then
			button.partyHighlight:Show();
		end
		
		if player.score > 0 then
			button.scorePositive:Show();
			button.upvote:SetChecked(true);
		end
		
		button.editBox:SetText(player.note);
			
		count = count +1;
	end
	
	PREP_UpdateNavigation();

end

local function GetPlayerSave(name)
	for k, player in ipairs(_benefitionalPlayers) do
		if player.name == name then
			player.latestStamp = time();
			return player;
		end
	end
	
	return nil;
end

local function IsInCurrentGroup(name) 
	for k, player in ipairs(_currentGroup) do
		if player.name == name then
			return true;
		end
	end
	
	return false;
end

local function CheckForNewPlayers()
	local liked = 0;
	local metBefore = 0;
	local notes = 0;
	
	local playerSave = nil ;
	
	for k, player in ipairs(_newGroup) do
		if (not IsInCurrentGroup(player.name)) then
			playerSave = _allSavedPlayers[""..player.name];
			playerSave.timesMet = playerSave.timesMet + 1;
			-- if more than 1 = met player before
			if playerSave.timesMet > 1 then
				metBefore = metBefore + 1;
			end
			if playerSave.score == 1 then
				liked = liked + 1;
			end
			if playerSave.note ~= nil then
				notes = notes + 1;
			end
		end
	end
	
	if liked > 0 or notes > 0 or metBefore > 0 then
		ShowPopUp(liked, notes, metBefore);
	end
	
	_currentGroup = {};
	for k, player in ipairs(_newGroup) do
		table.insert(_currentGroup, player);
	end
	_newGroup = {};
end

local function AddPlayerToList(unit)
	local name = GetUnitName(unit, true);
	if name == "Unknown" then
		PREP_LoadFrame.time = 0;
		PREP_LoadFrame.foundUnknown = true;
		return nil;
	end;
	if (unit ~= "player" and name == GetUnitName("player", true)) or not UnitIsPlayer(unit) then
		return nil;
	end
	name = string.find(name, "-") and name or name .. "-" .. GetRealmName();
	local temp = {};
	temp.name = name
	
	
	temp.class = UnitClass(unit);
	temp.sex = UnitSex(unit) == 2 and "Male" or "Female";
	temp.race = select(2, UnitRace(unit));
	temp.firstStamp = time();
	temp.latestStamp = time();
	temp.score = 0;
	temp.timesMet = unit == "target" and 1 or 0;
	local save = _allSavedPlayers["" .. name];
	if save == nil then
		_allSavedPlayers["" .. name] = temp;
	end
	
	local playerSave = GetPlayerSave(temp.name);
	if playerSave == nil then
		table.insert(_benefitionalPlayers, _allSavedPlayers["" .. name]);
	end
	
	table.insert(_newGroup, temp);
	
	PREP_UpdateContainer();
	
	return true;
end

local function AddTargetPlayer(star, note)
	local name = GetUnitName("target", true);
	-- don't want to check unknown or self
	if name == "Unknown" or name == GetUnitName("player", true) then
		return;
	end
	name = string.find(name, "-") and name or name .. "-" .. GetRealmName();
	local player = _allSavedPlayers[""..name];
	if player == nil then
		if AddPlayerToList("target") == nil then
			print(ERROR_INVALID_TARGET);
			return;
		end
		player = _allSavedPlayers[""..name];
	end
	
	-- Star if requested
	if star then
		player.score = 1;
	end
	
	-- Add note if provided
	if note ~= nil and note ~= "" then
		if player.note == nil then
			player.note = note;
		else
			player.note = player.note .. " - " .. note;
		end
	end
	
	if star and note ~= nil and note ~= "" then
		print(string.format(FORMAT_STARNOTE, name));
	elseif star then
		print(string.format(FORMAT_STAR, name));
	elseif note ~= nil and note ~= "" then
		print(string.format(FORMAT_NOTE, name));
	else
		print(string.format(FORMAT_ADDED, name));
	end
	
	CheckOverflow();
	PREP_UpdateContainer();
end

local function AddInstance()
	local num = GetNumGroupMembers()-1;
	if IsInRaid() then
		num = num + 1;
	end
	
	for i=1, num do
		if IsInRaid() then
			AddPlayerToList("raid"..i);
		else
			AddPlayerToList("party"..i);
		end
	end
	
	CheckForNewPlayers(newGroup);
	CheckOverflow();
	PREP_UpdateContainer();
end

function PREP_ClearNeutral()
	for i=#_benefitionalPlayers,1,-1 do
		if _benefitionalPlayers[i].score == 0 then
			table.remove(_benefitionalPlayers, i);
		end
	end
	PREP_UpdateContainer();
end

function PlayerRep:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PrepDB", defaults, true);
end

local L_PREP_LoadFrame = CreateFrame("FRAME", "PREP_LoadFrame"); 
PREP_LoadFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
PREP_LoadFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
PREP_LoadFrame:RegisterEvent("ADDON_LOADED");
PREP_LoadFrame:RegisterEvent("GROUP_JOINED");
PREP_LoadFrame:RegisterEvent("LOADING_SCREEN_DISABLED");
PREP_LoadFrame:RegisterEvent("LOADING_SCREEN_ENABLED");
PREP_LoadFrame:RegisterEvent("GROUP_ROSTER_UPDATE");
--PREP_LoadFrame:RegisterEvent("PLAYER_LOGOUT");
PREP_LoadFrame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
PREP_LoadFrame.time = 0;
PREP_LoadFrame.foundUnknown = false;
PREP_LoadFrame:SetScript("OnUpdate", function(self, elapsed)
		if PREP_LoadFrame.foundUnknown then
			PREP_LoadFrame.time = PREP_LoadFrame.time + elapsed;
			if PREP_LoadFrame.time >= 1 then
				PREP_LoadFrame.time = 0;
				PREP_LoadFrame.foundUnknown = false;
				AddInstance();
			end
		end
	end)

function PREP_LoadFrame:LOADING_SCREEN_DISABLED()
	_inLoadingScreen = false;
	if PREP_AlertPopup.shownInLoading then
		PREP_AlertPopup.combatFunc();
		PREP_AlertPopup.shownInLoading = false;
	end
end
function PREP_LoadFrame:LOADING_SCREEN_ENABLED()
	_inLoadingScreen = true;
	
end
	
function PREP_LoadFrame:PLAYER_REGEN_DISABLED()
	PREP_AlertPopup:Hide();
	PREP_PlayerMetContainer:Hide();
end

function PREP_LoadFrame:PLAYER_REGEN_ENABLED()
	
	if _openedDuringCombat then
		ShowMainFrame();
		_openedDuringCombat = false;
	end
	
	if PREP_AlertPopup.shownInCombat then
		PREP_AlertPopup.combatFunc();
		PREP_AlertPopup.shownInCombat = false;
	end
end

function PREP_LoadFrame:GROUP_JOINED()
	AddInstance();
end

function PREP_LoadFrame:GROUP_ROSTER_UPDATE()
	AddInstance();
end

function PREP_LoadFrame:PLAYER_LOGOUT()
	for k, player in pairs(_benefitionalPlayers) do
		if _allSavedPlayers[""..player.name] == nil then
			local save = {};
			save.race = player.race;
			save.note = player.note;
			save.name = player.name;
			save.sex = player.sex;
			save.firstStamp = player.firstStamp;
			save.class = player.class;
			save.score = player.score;
			save.latestStamp = player.latestStamp;
			save.timesMet = player.timesMet;

			_allSavedPlayers[""..player.name] = save;
		end
	end
end

local function CheckVersionDifference(version)
	_options.version = GetAddOnMetadata(addonName, "Version");
	if version == nil or version < "6.2.02" then
		-- Fix lack of timesMet
		for k, player in pairs(_allSavedPlayers) do
			if player.timesMet == nil then
				player.timesMet = 1;
			end
			if player.score < 0 then
				player.score = 0;
				if player.note == "" or player.note == nil then
					player.note = "Disliked in 6.2.01";
				else
					player.note = player.note .. " - Disliked in 6.2.01";
				end
			end
		end
		return;
	end
end

function PREP_LoadFrame:ADDON_LOADED(loadedAddon)
	if (loadedAddon ~= addonName) then return; end
	
	PREP_LoadFrame:UnregisterEvent("ADDON_LOADED")
	
	
	PREP_CreateContainer();
	SetDateTimeFormat(false, false);
	PREP_CreatePopup()
	CreateSpellbookIcon();
	
	_help:Initialise(PREP_PlayerMetContainer, _helpPlate);
	
	
	local currentTime = time();
	for k, player in pairs(PlayerRep.db.global.playersMet) do
		if (player.score == nil) then
			player.score = 0;
		end
		if player.score ~= 0 or currentTime - player.latestStamp < _options.saveTime or (player.note ~= "" and player.note ~= nil) then
			table.insert(_benefitionalPlayers, player);
		else
			
		end
		_allSavedPlayers[""..player.name] = player;
	end
	PlayerRep.db.global.playersMet = _allSavedPlayers;
	
	_options.formatDate = PlayerRep.db.global.options.formatDate;
	_options.formatTime = PlayerRep.db.global.options.formatTime;
	_options.showPopup = PlayerRep.db.global.options.showPopup;
	_options.popupSound = PlayerRep.db.global.options.popupSound;
	_options.saveTime = PlayerRep.db.global.options.saveTime;
	_options.version = PlayerRep.db.global.options.version;
	_options.storageLimit = PlayerRep.db.global.options.storageLimit;
	PlayerRep.db.global.options = _options;

	PREP_Options.format.date:SetChecked(_options.formatDate);
	PREP_Options.format.time:SetChecked(_options.formatTime);
	PREP_Options.showPopup:SetChecked(_options.showPopup);
	PREP_Options.popupSound:SetChecked(_options.popupSound);
	PREP_Options.saveTime:SetText(_options.saveTime);
	PREP_Options.saveTimeText:SetText(FormatSeconds(_options.saveTime)); 
	PREP_Options.storageLimit:SetText(_options.storageLimit);
	UpdateStorageCounter();
	
	SetDateTimeFormat(PREP_Options.format.date:GetChecked(), PREP_Options.format.time:GetChecked());
	
	CheckVersionDifference(_options.version);
end

----------------------------------------
-- Slash Commands
----------------------------------------



SLASH_PREPSLASH1 = '/prep';
SLASH_PREPSLASH2 = '/playerrep';
local function slashcmd(msg, editbox)
	if msg == 'options' then
		ShowMainFrame();
		PREP_Options:Show();
	elseif msg == "add" then
		AddTargetPlayer(false, nil);
		--if UnitIsPlayer("target") then
		--	AddPlayerToList("target");
		--end
		
	elseif string.sub(msg, 1, 4) == "note" then
		AddTargetPlayer(false, string.sub(msg, 6));
	elseif string.sub(msg, 1, 4) == "star" then
		AddTargetPlayer(true, string.sub(msg, 6));
	--[[
	elseif msg == "p" then
		local liked = 0;
		local metBefore = 0;
		local notes = 0;
		
		local playerSave = nil ;
		
		for k, player in pairs(_allSavedPlayers) do
				if player.timesMet > 1 then
					metBefore = metBefore + 1;
				end
				if player.score == 1 then
					liked = liked + 1;
				end
				if player.note ~= nil then
					notes = notes + 1;
				end
		end
		ShowPopUp(liked, notes, metBefore);
	elseif msg == "h" then
		for k, v in pairs(PlayerRep.db.global.options) do
			print(k);
			print(v);
		end
	elseif string.find(msg, "test") then


		local now = time();
		local temp = {{
				["race"] = "Human",
				["note"] = "Friendly player",
				["name"] = "Hankin-Greymane",
				["sex"] = "Female",
				["firstStamp"] = 1,
				["class"] = "Priest",
				["score"] = 1,
				["latestStamp"] = 5,
				["timesMet"] = 2,
			},
			{
				["race"] = "Bloodelf",
				["note"] = "",
				["name"] = "Kalle-Shadowsong",
				["sex"] = "Male",
				["firstStamp"] = 6,
				["class"] = "Warlock",
				["score"] = 0,
				["latestStamp"] = 7,
				["timesMet"] = 1,
			},
			{
				["race"] = "Scourge",
				["note"] = "",
				["name"] = "Ophelia-Frostmane",
				["sex"] = "Female",
				["firstStamp"] = 4,
				["class"] = "Rogue",
				["score"] = 0,
				["latestStamp"] = 2,
				["timesMet"] = 1,
			},
			{
				["race"] = "Pandaren",
				["note"] = "Ninjapuller and insulting people",
				["name"] = "Sying-Mazrigos",
				["sex"] = "Female",
				["firstStamp"] = 1,
				["class"] = "Monk",
				["score"] = 0,
				["latestStamp"] = 8,
				["timesMet"] = 1,
			},
			{
				["race"] = "Dwarf",
				["note"] = "",
				["name"] = "Bramrim-Earthen Ring",
				["sex"] = "Male",
				["firstStamp"] = 6,
				["class"] = "Paladin",
				["score"] = 1,
				["latestStamp"] = 5,
				["timesMet"] = 1,
			},
			{
				["race"] = "Dwarf",
				["note"] = "",
				["name"] = "Bramrien Ring",
				["sex"] = "Male",
				["firstStamp"] = 6,
				["class"] = "Paladin",
				["score"] = 1,
				["latestStamp"] = 5,
				["timesMet"] = 2,
			},
			{
				["race"] = "Tauren",
				["note"] = "",
				["name"] = "Bemen-Magtheridon",
				["sex"] = "Male",
				["firstStamp"] = 2,
				["class"] = "Warrior",
				["score"] = 0,
				["latestStamp"] = 1,
				["timesMet"] = 3,
			},
			{
				["race"] = "Dwarf",
				["note"] = "Great healer",
				["name"] = "Bren Ring",
				["sex"] = "Male",
				["firstStamp"] = 4,
				["class"] = "Paladin",
				["score"] = 0,
				["latestStamp"] = 3,
				["timesMet"] = 1,
			},
			{
				["race"] = "Dwarf",
				["note"] = "",
				["name"] = "Bramr= Ring",
				["sex"] = "Male",
				["firstStamp"] = 5,
				["class"] = "Paladin",
				["score"] = 0,
				["latestStamp"] = 8,
				["timesMet"] = 2,
			},
			{
				["race"] = "Dwarf",
				["note"] = "Great healer",
				["name"] = "Bing",
				["sex"] = "Male",
				["firstStamp"] = 4,
				["class"] = "Paladin",
				["score"] = 1,
				["latestStamp"] = 3,
				["timesMet"] = 1,
			},
			}
			
			local blah = {};
		for k, player in pairs(_allSavedPlayers) do
			table.insert(blah, player);
		end
			
		SortForRemoval(blah);
		for k, player in ipairs(blah) do
			print(player.name .. " = " .. player.score .. " - " .. player.note .. " - " .. player.timesMet .. " - " .. player.latestStamp);
		end
		
		local start = CountStoredPlayers();
		for i=start, start + times do
			local now = time();
			local temp = {
				["timesMet"] = 1,
				["race"] = "Tauren",
				["note"] = "nr "..i,
				["name"] = "Test_"..i,
				["sex"] = "Male",
				["firstStamp"] = now,
				["class"] = "Shaman",
				["score"] = 0,
				["latestStamp"] = now, -- 86400
			}
			table.insert(_allSavedPlayers, temp);
			
		end
		CheckOverflow();
		]]--
	else
		ShowMainFrame();
	end
end
SlashCmdList["PREPSLASH"] = slashcmd
