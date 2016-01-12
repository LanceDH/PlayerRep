
----------------------------------------
-- Variables
----------------------------------------

local addonName, _addonData = ...;

local AceGUI = LibStub("AceGUI-3.0");
local PlayerRepAddon = LibStub("AceAddon-3.0"):NewAddon("PlayerRep")

local _defaults = {
	global = {
		playersMet = {{
			["race"] = "",
			["name"] = "",
			["sex"] = "",
			["score"] = 0,
			["class"] = "",
			["firstStamp"] = 0,
			["latestStamp"] = 0,
		}}
	}
}

local _playersMet = {};
local _currentGroup = {};
local _newGroup = {};
local _playerLeveled = false;
local _openedDuringCombat = false;

_addonData.variables = {}
local _aVar = _addonData.variables;
_aVar.TBC_HEROIC = -1;
_aVar.WOTLK_HEROIC = -3;
_aVar.WOTLK_RAID = -4;
_aVar.CATA_HEROIC = -5;
_aVar.CATA_RAID = -6;
_aVar.MOP_HEROIC = -7;
_aVar.MOP_RAID = -8;
_aVar.WOD_HEROIC = -9;
_aVar.WOD_RAID = -10;

_addonData.help = {}
local _help = _addonData.help;

local DISPLAY_MET = 0;
local DISPLAY_LIKE = 1;
local DISPLAY_DISLIKE = 2;
local DISPLAY_DETAILS = 3;

local SAVE_TIME = 1800;

local UNLOCKTYPE_SPELL = "spell";
local UNLOCKTYPE_TALENT = "talent";
local UNLOCKTYPE_GLYPH = "glyph";
local UNLOCKTYPE_DUNGEON = "instance";
local UNLOCKTYPE_PVP = "pvp";
local UNLOCKTYPE_RIDING = "riding";
local UNLOCKTYPE_TUTORIAL = "tutorial";
local PLAYERS_PER_PAGE = 10;
local ICON_TALENT = "Interface/ICONS/Ability_Marksmanship";
local ICON_GLYPH = "Interface/ICONS/INV_Glyph_PrimeDruid";
local CUSTOMPATH = "Interface/AddOns/".. addonName .."/Images/"

local FORMAT_DATE_EU = "%d/%m/%Y";
local FORMAT_DATE_US = "%m/%d/%Y";
local FORMAT_TIME_24 = "%H:%M:%S";
local FORMAT_TIME_12 = "%I:%M:%S %p";

local _dateTimeFormat = "";

local HELP_INFO_MAIN = "As you join a party or a raid group you meet new people which will be added to this list.\n\nYou can like or dislike players for their behaviour and add a note.\n\nLiked or disliked players are saved while neutral players will disappear over time.\n\n"
local HELP_INFO_TABS = "Over time, players in the list of people you met will dissapear.\n\nPlayers you liked of disliked will be stored in their respective tabs until you decide to make them neutral again.\n\n";
local ERROR_OPEN_IN_COMBAT = "|cFFFFD100WIP:|r |cFFFF5555Can't open that during combat. It will open once you leave combat.|r";
local TOOLTIP_TALENT = "Left click to pick your new talent.";
local TOOLTIP_INSTANCE = "Left click to open the encounter\n journal for this instance.";
local TOOLTIP_GLYPH = "Left click to pick your new glyphs.";
local TOOLTIP_PVP = "Left click to open the\n battleground window.";
local TOOLTIP_COMBAT = "|cFFFF5555Can't open during combat|r";
local TOOLTIP_SPELLBOOK_ICON = "Unlocked content";

local _helpPlate = {
	FramePos = { x = 5,	y = -25 },
	FrameSize = { width = 440, height = 495	},
	[1] = { ButtonPos = { x = 200,	y = -200}, HighLightBox = { x = 20, y = -85, width = 405, height = 420 }, ToolTipDir = "DOWN", ToolTipText = HELP_INFO_MAIN },
	[2] = { ButtonPos = { x = 340,	y = -30}, HighLightBox = { x = 60, y = -30, width = 335, height = 45 }, ToolTipDir = "DOWN", ToolTipText = HELP_INFO_TABS }
}

local function UpdateShowButtons()

	local likeCount = 0;
	local dislikeCount = 0;
	local neutralCount = 0;
	for k, player in ipairs(_playersMet) do
		if player.score > 0 then
			likeCount = likeCount + 1;
		elseif player.score < 0 then
			dislikeCount = dislikeCount + 1;
		else
			neutralCount = neutralCount + 1;
		end
	end
	
	local btn = PREP_UnlockContainer.showMetButton;
	btn.count:SetText(neutralCount);
	
	btn = PREP_UnlockContainer.showLikeButton;
	btn.count:SetText(likeCount);
	
	btn = PREP_UnlockContainer.showDislikeButton;
	btn.count:SetText(dislikeCount);
	
	return neutralCount, likeCount, dislikeCount;
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
				["tutorial"] = true,
			},
			{
				["race"] = "Bloodelf",
				["note"] = "Ninjapuller",
				["name"] = "Ameyna",
				["sex"] = "Female",
				["firstStamp"] = now,
				["class"] = "Warlock",
				["score"] = -1,
				["latestStamp"] = now,
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
				["tutorial"] = true,
			}
			}
			
	if show then 
		local n, l, d = UpdateShowButtons();
		PREP_UnlockContainer.display = DISPLAY_MET;
		if (n == 0) then
			for k, p in ipairs(tutPlayers) do
				table.insert(_playersMet, p);
			end
		end
	else
		for i=#_playersMet,1,-1 do
			if _playersMet[i].tutorial then
				table.remove(_playersMet, i);
			end
		end
	end
	
	PREP_ShowUnlockedContent();
end

local function SetDateTimeFormat(useEU, use24)
	local text = "";
	if (useEU) then
		text = FORMAT_DATE_EU;
	else
		text = FORMAT_DATE_US;
	end
	
	if (use24) then
		text = text .. " " .. FORMAT_TIME_24;
	else
		text = text .. " " ..  FORMAT_TIME_12;
	end
	
	_dateTimeFormat = text;
end

function PREP_TutorialButton_OnClick()
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

local function ShowUnlockContainer()

	-- prevent opening in combat because blizzard protection
	if InCombatLockdown() then 
		_openedDuringCombat = true;
		print(ERROR_OPEN_IN_COMBAT);
		return;
	else
		PREP_AlertPopup:Hide();
		PREP_SpellBookTab:SetChecked(true);
		PREP_UnlockContainer:Show();
		PlaySound("igSpellBookOpen");
	end
	
end

local function Popup_OnClick(self, button)
	if(button == "LeftButton") then
		ShowUnlockContainer();
	end
	self:Hide();
end

function PREP_ClearButton_OnClick()
	PREP_ClearUnlockList();
end

local function ToggleOptionFrame()

	if (PREP_UnlockContainerOptions:IsShown()) then
		PREP_UnlockContainerOptions:Hide();
	else
		PREP_UnlockContainerOptions:Show();
	end

end

function PREP_OptionsFrame_EnableBack(enabled)
	-- if options are show, darken all background items to half their color
	-- and prevent the player from interacting with buttons
	local color = 1;
	if not enabled then
		color = 0.5;
	end
	
	for i=1, PLAYERS_PER_PAGE do
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(i)];
		button:EnableMouse(enabled);
		if enabled then
			button.name:SetTextColor(1.0, 0.82, 0, 1);
		else
			button.name:SetTextColor(0.5, 0.42, 0, 1);
		end
	end

	PREP_UnlockContainer.Clear:EnableMouse(enabled);
	PREP_UnlockContainer.Navigation.Prev:EnableMouse(enabled);
	PREP_UnlockContainer.Navigation.Next:EnableMouse(enabled);
	
	PREP_UnlockContainer.bg:SetVertexColor(color, color, color, 1);
end

function PREP_OptionsButton_OnClick()
	ToggleOptionFrame();
end

function PREP_PrevPageButton_OnClick()
	if (PREP_UnlockContainer.CurrentPage == 1) then return; end
	PlaySound("igAbiliityPageTurn");
	PREP_UnlockContainer.CurrentPage = PREP_UnlockContainer.CurrentPage - 1;
	PREP_UnlockContainer.Navigation.Text:SetText("Page ".. PREP_UnlockContainer.CurrentPage);
	PREP_ShowUnlockedContent();
end

function PREP_NextPageButton_OnClick()
	if (PREP_UnlockContainer.CurrentPage >= ceil(#_playersMet/PLAYERS_PER_PAGE)) then return; end
	PlaySound("igAbiliityPageTurn");
	PREP_UnlockContainer.CurrentPage = PREP_UnlockContainer.CurrentPage + 1;
	PREP_UnlockContainer.Navigation.Text:SetText("Page ".. PREP_UnlockContainer.CurrentPage);
	PREP_ShowUnlockedContent();
end

function UnlockContainer_OnMouseWheel(self, delta)
	if delta == 1 then
		PREP_PrevPageButton_OnClick();
	else
		PREP_NextPageButton_OnClick();
	end
end

local function GetPlayerLevel()
	return UnitLevel("player");
end

local function GetPlayerSpec()
	if (GetSpecialization() ~= nil) then
		return GetSpecializationInfo(GetSpecialization());
	end
	
	return nil;
end



function PREP_UpdateNavigation()

	local n, l, d = UpdateShowButtons()

	local totalPages = 0;
	
	if (PREP_UnlockContainer.display == DISPLAY_MET) then
		totalPages = ceil(n/PLAYERS_PER_PAGE);
	elseif (PREP_UnlockContainer.display == DISPLAY_LIKE) then
		totalPages = ceil(l/PLAYERS_PER_PAGE);
	elseif (PREP_UnlockContainer.display == DISPLAY_DISLIKE) then
		totalPages = ceil(d/PLAYERS_PER_PAGE);
	end

	if (totalPages > 0 and PREP_UnlockContainer.CurrentPage > totalPages) then
		PREP_UnlockContainer.CurrentPage = totalPages;
	end

	PREP_UnlockContainer.Navigation.Text:SetText("Page ".. PREP_UnlockContainer.CurrentPage);
	
	PREP_UnlockContainer.Navigation.Prev:Enable();
	PREP_UnlockContainer.Navigation.Next:Enable();

	-- disable prev on first page;
	if (PREP_UnlockContainer.CurrentPage == 1) then
		PREP_UnlockContainer.Navigation.Prev:Disable();
	end

	-- disable next page if on last page
	if (totalPages == 0 or PREP_UnlockContainer.CurrentPage == totalPages) then
		PREP_UnlockContainer.Navigation.Next:Disable();
	end

end

local function CreateUnlockAnimation(self)
	-- create an animation to slide and fade in
	self.animation = self:CreateAnimationGroup();
	self.animation.translate = self.animation:CreateAnimation("Translation");
	self.animation.translate:SetSmoothing("IN");
	self.animation.alpha = self.animation:CreateAnimation("Alpha");
	self.animation.alpha:SetChange(-1);
	self.animation.alpha:SetSmoothing("IN");
end

local function PlayUnlockAnination(self)
	self.animation:SetScript("OnFinished", function() self.data.new = false; end);
	self.animation.translate:SetOffset(-50, 0);
	self.animation.translate:SetDuration(0.5);
	self.animation.alpha:SetDuration(0.5);
	self.animation:Play(true);
end

local function ChangePlayerScore(button, change)
	local parent = button:GetParent();
	
	
	
	for k, player in ipairs(_playersMet) do
		if player.name == parent.name:GetText() then
			player.score = player.score + change;
			
			if (player.score < -1 or player.score > 1) then
				player.score = 0;
			end
			break;
		end
	end
	
	PREP_ShowUnlockedContent();
	
end

local function ShowPlayerDetails(player)
	PREP_PlayerDetails.name:SetText(player.name);
	PREP_PlayerDetails.stampFirst:SetText(date(_dateTimeFormat, player.firstStamp));
	PREP_PlayerDetails.stampLast:SetText(date(_dateTimeFormat, player.latestStamp));
	
	local faction = UnitFactionGroup("player");
	faction = faction == "Neutral" and "Horde" or faction;
	PREP_PlayerDetails.iconClass:SetTexture("Interface/ICONS/ClassIcon_" .. string.gsub(player.class, " ", ""));
	local path = CUSTOMPATH .. "Race_" .. player.race .. "_" .. player.sex;
	path = player.race == "Pandaren" and path .. "_" .. faction or path;
	PREP_PlayerDetails.iconRace:SetTexture(path);
	
	PREP_PlayerDetails.scorePositive:Hide();
	PREP_PlayerDetails.scoreNegative:Hide();
	if player.score > 0 then
			PREP_PlayerDetails.scorePositive:Show();
			--button.upvote:SetNormalTexture("Interface/Buttons/Arrow-Up-Up");
		elseif player.score < 0 then
			PREP_PlayerDetails.scoreNegative:Show();
			--button.downvote:SetNormalTexture("Interface/Buttons/Arrow-Down-Up");
		end
	
	PREP_PlayerDetails.editBox:SetText(player.note);
end

function PREP_CreateContainer()
	PREP_UnlockContainer:SetPoint("center", UIParent, "center", 0, 0);

	PREP_UnlockContainer:SetMovable(true);
	PREP_UnlockContainer:EnableMouse(true);
	PREP_UnlockContainer:SetClampedToScreen(true);
	PREP_UnlockContainer:SetToplevel(true)
	PREP_UnlockContainer:RegisterForDrag("LeftButton");
	PREP_UnlockContainer:SetScript("OnDragStart", PREP_UnlockContainer.StartMoving );
	PREP_UnlockContainer:SetScript("OnDragStop", PREP_UnlockContainer.StopMovingOrSizing);
	-- allows the player to close the frame using Esc like regular blizzard windows
	table.insert(UISpecialFrames, "PREP_UnlockContainer")
	
	PREP_UnlockContainer.showMetButton:SetScript("OnClick", function(self)
									PREP_UnlockContainer.display = DISPLAY_MET;
									PREP_UnlockContainer.CurrentPage = 1;
									PREP_ShowUnlockedContent(); 
								end);
	PREP_UnlockContainer.showLikeButton:SetScript("OnClick", function(self)
									PREP_UnlockContainer.display = DISPLAY_LIKE;
									PREP_UnlockContainer.CurrentPage = 1;
									PREP_ShowUnlockedContent(); 
								end);
	PREP_UnlockContainer.showDislikeButton:SetScript("OnClick", function(self)
									PREP_UnlockContainer.display = DISPLAY_DISLIKE;
									PREP_UnlockContainer.CurrentPage = 1;
									PREP_ShowUnlockedContent(); 
								end);
	
	PREP_UnlockContainer.CurrentPage = 1;
	PREP_UnlockContainer.display = DISPLAY_MET;
	
	for i=1, PLAYERS_PER_PAGE do
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(i)];
		button.upvote:SetScript("OnClick", function(self) ChangePlayerScore(self, 1) end);
		button.downvote:SetScript("OnClick", function(self) ChangePlayerScore(self, -1) end);
		button:SetScript("OnClick", function(self) 
				PREP_UnlockContainer.display = DISPLAY_DETAILS;
				ShowPlayerDetails(self.player);
				PREP_ShowUnlockedContent();
			end);
					
		button.gui = AceGUI:Create("SimpleGroup");
		button.gui:SetWidth(165);
		button.gui:SetHeight(15);
		button.gui:SetLayout("flow");
		button.gui.frame:SetParent(button);
		button.gui.frame:SetPoint("BOTTOMLEFT", 130, 0);
		
		button.editBox = AceGUI:Create("EditBox");
		button.editBox:SetLabel("");
		button.editBox:SetText("Write note");
		button.editBox.editbox.Left:Hide();
		button.editBox.editbox.Middle:Hide();
		--button.editBox.editbox.Middle:SetTexture("Interface/LootFrame/LootHistory-NewItemGlow");
		button.editBox.editbox:SetTextColor(0, 0, 0, 1);
		button.editBox.editbox:SetShadowColor(0, 0, 0, 0);
		button.editBox.editbox.Right:Hide();
		button.editBox.editbox:SetFontObject("GameFontNormal");
		button.editBox.editbox:EnableMouse(false);
		button.editBox:SetCallback("OnEnterPressed", function(__,__, value)
				button.player.note = value;
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
	
	PREP_PlayerDetails.gui = AceGUI:Create("SimpleGroup");
	PREP_PlayerDetails.gui:SetWidth(300);
	PREP_PlayerDetails.gui:SetHeight(50);
	PREP_PlayerDetails.gui:SetLayout("flow");
	PREP_PlayerDetails.gui.frame:SetParent(PREP_PlayerDetails);
	PREP_PlayerDetails.gui.frame:SetPoint("TOPLEFT", 0, -100);
	
	PREP_PlayerDetails.editBox = AceGUI:Create("EditBox");
	PREP_PlayerDetails.editBox:SetRelativeWidth(1);
	PREP_PlayerDetails.editBox:SetLabel("");
	PREP_PlayerDetails.editBox:SetText("Write note");
	PREP_PlayerDetails.editBox.editbox.Left:Hide();
	PREP_PlayerDetails.editBox.editbox.Middle:Hide();
	PREP_PlayerDetails.editBox.editbox:SetTextColor(0, 0, 0, 1);
	PREP_PlayerDetails.editBox.editbox:SetShadowColor(0, 0, 0, 0);
	PREP_PlayerDetails.editBox.editbox.Right:Hide();
	PREP_PlayerDetails.editBox.editbox:SetFontObject("GameFontNormal");
	PREP_PlayerDetails.editBox.editbox:EnableMouse(false);
	PREP_PlayerDetails.editBox:SetCallback("OnEnterPressed", function(__,__, value)
			PREP_PlayerDetails.player.note = value;
			PREP_PlayerDetails.editBox.editbox:SetCursorPosition(0);
			PREP_PlayerDetails.editBox.editbox:EnableMouse(false);
			PREP_PlayerDetails.editBox.editbox:ClearFocus();
		end)
	PREP_PlayerDetails.editBox.editbox:SetScript("OnEditFocusLost", function(self) 
			PREP_PlayerDetails.editBox.editbox:EnableMouse(false);
		end);
	
	PREP_PlayerDetails.gui:AddChild(PREP_PlayerDetails.editBox);
	
	SetPortraitToTexture(PREP_UnlockContainerPortrait, "Interface\\ICONS\\Achievement_Reputation_01");
	PREP_UnlockContainerTitleText:SetText(addonName);
	PREP_UnlockContainerCloseButton:SetScript("OnMouseUp", function() PREP_SpellBookTab:SetChecked(false); end );
	
	ButtonFrameTemplate_HideButtonBar(PREP_UnlockContainer);
	ButtonFrameTemplate_HideAttic(PREP_UnlockContainer);
	
	PREP_UpdateNavigation()
	
	return L_BGS_ContainerBG
end

local function ShowPopUp()
	if (#_unlockedList == 0 or not PREP_UnlockContainerOptions.CBShowPopup:GetChecked() or InCombatLockdown()) then return; end
	PREP_AlertPopup:Show();
	PREP_AlertPopup:SetAlpha(1);
	PREP_AlertPopup.text:SetText(#_unlockedList.." unread unlock" .. (#_unlockedList == 1 and "" or "s") .."!")
end

local function CreatePopupAnimation(self)
	-- create flashing animation to highlight popup
	self.animationA = self:CreateAnimationGroup();
	self.animationA.alpha = self.animationA:CreateAnimation("Alpha");
	self.animationA.alpha:SetChange(-1);
	self.animationA.alpha:SetSmoothing("IN");
	self.animationB = self:CreateAnimationGroup();
	self.animationB.alpha = self.animationB:CreateAnimation("Alpha");
	self.animationB.alpha:SetChange(-1);
	self.animationB.alpha:SetSmoothing("OUT");
	
	self.animationA:SetScript("OnFinished", function() self.animationB:Play(); end);
	self.animationB:SetScript("OnFinished", function() self:Hide(); end);
end

local function PlayPopupAnimation(self)
	self:Show();
	if not self.animationA then
		CreatePopupAnimation(self)
	end
	self.animationA.alpha:SetDuration(0.3);
	self.animationB.alpha:SetDuration(0.3);
	self.animationA:Play(true);
end

local function PREP_CreatePopup()
	PREP_AlertPopup:SetPoint("center", UIParent, "center", 400, 0);
	PREP_AlertPopup:RegisterForDrag("LeftButton");
	PREP_AlertPopup:SetScript("OnDragStart", PREP_AlertPopup.StartMoving );
	PREP_AlertPopup:SetScript("OnDragStop", PREP_AlertPopup.StopMovingOrSizing);
	PREP_AlertPopup:SetScript("OnShow", function(self) PlayPopupAnimation(self.highlight) end );
	PREP_AlertPopup:SetScript("OnClick", function(self, button) Popup_OnClick(self, button);end );
	PREP_AlertPopup:RegisterForClicks("LeftButtonUp", "RightButtonUp");
end

local function ToggleUnlockedPage(show)
	if InCombatLockdown() then return; end
	
	if (show) then
		ShowUnlockContainer();
	else
		PREP_UnlockContainer:Hide();
	end

end

local function CreateSpellbookIcon()

	local L_PREP_SpellBookTab = CreateFrame("CheckButton", "PREP_SpellBookTab", SpellBookSideTabsFrame, "SpellBookSkillLineTabTemplate");
	L_PREP_SpellBookTab:SetPoint("bottomleft", SpellBookSideTabsFrame, "bottomright", 0, 100);
	L_PREP_SpellBookTab:Show();
	-- overwrite scripts from template
	L_PREP_SpellBookTab:SetScript("OnEnter", function(self) 
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);
		if InCombatLockdown() then
			GameTooltip:SetText(TOOLTIP_COMBAT);
		else
			GameTooltip:SetText(TOOLTIP_SPELLBOOK_ICON);
		end
	end);
	L_PREP_SpellBookTab:SetScript("OnClick", function() 
			if InCombatLockdown() then
				L_PREP_SpellBookTab:SetChecked(false);
			else
				ToggleUnlockedPage(not PREP_UnlockContainer:IsShown()); 
			end
		end);

	L_PREP_SpellBookTab.icon = L_PREP_SpellBookTab:CreateTexture("PREP_SpellBookTabIcon");
	L_PREP_SpellBookTab.icon:SetPoint("center", L_PREP_SpellBookTab);
	L_PREP_SpellBookTab.icon:SetSize(32, 32);
	L_PREP_SpellBookTab.icon:SetTexture("Interface/ICONS/Achievement_Reputation_01");
	
	
end

local function ResetButtons()
	for i=1, PLAYERS_PER_PAGE do
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(i)];
		button.player = nil;
		button.name:SetText("PlayerName"..i);
		--button.subText:SetText(i);
		button.scorePositive:Hide();
		button.scoreNegative:Hide();
		button.upvote:SetNormalTexture("Interface/Buttons/Arrow-Up-Disabled");
		button.downvote:SetNormalTexture("Interface/Buttons/Arrow-Down-Disabled");
		button:Hide();

	end
	PREP_UpdateNavigation();
end

local function SortPlayerList()
	table.sort(_playersMet, function(a, b) 
		if a.latestStamp == b.latestStamp then
			return a.name < b.name;
		end
		return a.latestStamp > b.latestStamp
	end);
end

local function GetPlayersToDisplay()
	local temp = {};
	if PREP_UnlockContainer.display == DISPLAY_MET then
		local currentTime = time();
		for k, player in pairs(_playersMet) do
			if(currentTime - player.latestStamp < SAVE_TIME) then
				table.insert(temp, player);
			else
				break;
			end
		end
	elseif PREP_UnlockContainer.display == DISPLAY_LIKE then
		for k, player in pairs(_playersMet) do
			if (player.score > 0) then
				table.insert(temp, player);
			end
		end
	elseif PREP_UnlockContainer.display == DISPLAY_DISLIKE then
		for k, player in pairs(_playersMet) do
			if (player.score < 0) then
				table.insert(temp, player);
			end
		end
	end
		
	return temp;
end

local function DeleteOldNeutralPlayers()
	local currentTime = time();
	for i=#_playersMet,1,-1 do
		if currentTime - _playersMet[i].latestStamp > SAVE_TIME then
			if (_playersMet[i].score == 0) then
				table.remove(_playersMet, i);
			end
		else
			break;
		end
	end
end

function PREP_ShowUnlockedContent()
	
	-- Only update when the main window is open
	if (not PREP_UnlockContainer:IsShown()) then return; end
	
	ResetButtons();
	SortPlayerList();
	DeleteOldNeutralPlayers();
	UpdateShowButtons();
	
	PREP_PlayerDetails:Hide();
	if PREP_UnlockContainer.display == DISPLAY_DETAILS then
		PREP_PlayerDetails:Show();
	end
	
	local playersToShow = GetPlayersToDisplay();
	
	local faction = UnitFactionGroup("player");
	-- change neutral panda to horde because looks left... also FOR THE HORDE!
	faction = faction == "Neutral" and "Horde" or faction;
	local count = 1;
	local player = nil;
	local pageNr = PREP_UnlockContainer.CurrentPage;
	local start = (pageNr-1) * PLAYERS_PER_PAGE;
	local nrToShow = (#playersToShow-start) > PLAYERS_PER_PAGE and PLAYERS_PER_PAGE or #playersToShow - start;
	for i = start + 1, (start + nrToShow) do
		player = playersToShow[i];
			
		local button = _G["PREP_PlayerButton"..GetFullDoubleDigit(count)];
		button.player = player;

		button:Show();
		button.name:SetText(player.name);
		--button.subText:SetText(date("%c", player.latestStamp));
		button.iconClass:SetTexture("Interface/ICONS/ClassIcon_" .. string.gsub(player.class, " ", ""));
		local path = CUSTOMPATH .. "Race_" .. player.race .. "_" .. player.sex;
		path = player.race == "Pandaren" and path .. "_" .. faction or path;
		button.iconRace:SetTexture(path);
		
		if player.score > 0 then
			button.scorePositive:Show();
			button.upvote:SetNormalTexture("Interface/Buttons/Arrow-Up-Up");
		elseif player.score < 0 then
			button.scoreNegative:Show();
			button.downvote:SetNormalTexture("Interface/Buttons/Arrow-Down-Up");
		end
		
		button.editBox:SetText(player.note);
			
		count = count +1;
	end
	
	PREP_UpdateNavigation();

end



function PREP_ClearUnlockList()
	for i=#_playersMet,1,-1 do
		if _playersMet[i].score == 0 then
			table.remove(_playersMet, i);
		end
	end
	PREP_ShowUnlockedContent();
end

function PlayerRepAddon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("AceDBPlayerDB", _defaults);
end

function PlayerRepAddon:OnEnable()

	local currentTime = time();
	for k, player in ipairs(self.db.global.playersMet) do
		if player.score ~= 0 or currentTime - player.latestStamp < SAVE_TIME then
			if (player.score == nil) then
				player.score = 0;
			end
			table.insert(_playersMet, player);
		end
	end

	--[[
	_priceHistory = self.db.global.history
	_option_Use24h = self.db.global.use24h
	_lifetimeHighest = self.db.global.lifetimeHighest
	_lifetimeLowest = self.db.global.lifetimeLowest
	if self.db.global.isShown then
		TokenChart_Container:Show()
	end
	
	UpdateHistory()
	]]--
end



local L_PREP_LoadFrame = CreateFrame("FRAME", "PREP_LoadFrame"); 
PREP_LoadFrame:RegisterEvent("PLAYER_LEVEL_UP");
PREP_LoadFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
PREP_LoadFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
PREP_LoadFrame:RegisterEvent("ADDON_LOADED");
PREP_LoadFrame:RegisterEvent("PLAYER_LOGOUT");
PREP_LoadFrame:RegisterEvent("GROUP_JOINED");
PREP_LoadFrame:RegisterEvent("GROUP_ROSTER_UPDATE");
PREP_LoadFrame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

function PREP_LoadFrame:PLAYER_LEVEL_UP(level, hp, mp, talentPoints, strength, agility, stamina, intellect, spirit)
end

function PREP_LoadFrame:PLAYER_REGEN_DISABLED()
	PREP_AlertPopup:Hide();
	PREP_UnlockContainer:Hide();
end

function PREP_LoadFrame:PLAYER_REGEN_ENABLED()
	
	if _openedDuringCombat then
		ShowUnlockContainer();
		_openedDuringCombat = false;
	end
end

local function GetPlayerSave(name)
	for k, player in ipairs(_playersMet) do
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

local function CheckForNowPlayers()
	local count = 0;
	for k, player in ipairs(_newGroup) do
		if (not IsInCurrentGroup(player.name)) then
			count = count + 1;
			print(player.name .. " is new.");
		end
	end
	
	if count == 0 then
		print("No new players");
	end
	
	_currentGroup = {};
	for k, player in ipairs(_newGroup) do
		table.insert(_currentGroup, player);
	end
	_newGroup = {};
	
end

local function AddPlayerToList(unit)
	local temp = {};
	temp.name = GetUnitName(unit, true);
	-- add home realm if missing
	
	if temp.name == "Unknown" then
		print("Found an unknown");
	end
	
	if temp.name == "Unknown" or (unit ~= "player" and temp.name == GetUnitName("player", true)) then
		return;
	end
	temp.name = string.find(temp.name, "-") and temp.name or temp.name .. "-" .. GetRealmName();
	temp.class = UnitClass(unit);
	temp.sex = UnitSex(unit) == 2 and "Male" or "Female";
	temp.race = select(2, UnitRace(unit));
	temp.firstStamp = time();
	temp.latestStamp = time();
	temp.score = 0;
	local playerSave = GetPlayerSave(temp.name);
	if playerSave == nil then
		table.insert(_playersMet, temp);
	end
	
	table.insert(_newGroup, temp);
	
	PREP_ShowUnlockedContent();
end

local function AddInstance()
	print("Adding group");
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
	
	CheckForNowPlayers(newGroup);
end

function PREP_LoadFrame:GROUP_JOINED()
	AddInstance();
end

function PREP_LoadFrame:GROUP_ROSTER_UPDATE()
	AddInstance();
end

function PREP_LoadFrame:PLAYER_LOGOUT(loadedAddon)
	PREP_ShowHelpUnlocks(false);
	PlayerRepAddon.db.global.playersMet = _playersMet;

end

function PREP_LoadFrame:ADDON_LOADED(loadedAddon)
	if (loadedAddon ~= addonName) then return; end
	
	PREP_LoadFrame:UnregisterEvent("ADDON_LOADED")
	
	SetDateTimeFormat(true, true);
	PREP_CreateContainer();
	PREP_CreatePopup()
	CreateSpellbookIcon();
	
	_help:Initialise(PREP_UnlockContainer, _helpPlate);
	
	if (PlayerRepAddon.db.global.playersMet == nil) then
		PlayerRepAddon.db.global.playersMet = _playersMet;
	end
	
end

----------------------------------------
-- Slash Commands
----------------------------------------

SLASH_WIPSLASH1 = '/wip';
local function slashcmd(msg, editbox)
	if msg == 'options' then
		ShowUnlockContainer();
		PREP_UnlockContainerOptions:Show();
	elseif msg == "t" then
		AddPlayerToList("target");
	elseif msg == "db" then	
		print(_fuck);
		--PlayerRepAddon.db.global.playersMet = _playersMet;
	elseif msg == "c" then
		print("Printing List");
		for k1, player in ipairs(_playersMet) do
			for k, v in pairs(player) do
				print(k .. ": " .. v);
			end
			print("-----");
		end
	else
		ShowUnlockContainer();
	end
end
SlashCmdList["WIPSLASH"] = slashcmd
