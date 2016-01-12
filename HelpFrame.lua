
local addonName, _addonData = ...;

local _help = _addonData.help;

local HELP_BUTTON_NORMAL_SIZE = 46;

local function ShowTooltip(tut)
	tut.tooltip:Show();
	tut.box:Hide();
	tut.glowFrame:Show();
end

local function HideTooltip(tut)
	tut.tooltip:Hide();
	tut.box:Show();
	tut.glowFrame:Hide();
end

local function CreateButtonAnimation(self)
	self.animGroup_Show = self:CreateAnimationGroup();
	self.animGroup_Show.translate = self.animGroup_Show:CreateAnimation("Translation");
	self.animGroup_Show.translate:SetSmoothing("IN");
	self.animGroup_Show.alpha = self.animGroup_Show:CreateAnimation("Alpha");
	self.animGroup_Show.alpha:SetChange(-1);
	self.animGroup_Show.alpha:SetSmoothing("IN");
	self.animGroup_Show.parent = self;
end

local function ShowButtonAnimation(self)
	if self.animGroup_Show == nil then
		CreateButtonAnimation(self)
	end
	local point, relative, relPoint, xOff, yOff = self:GetPoint();
	self.animGroup_Show.translate:SetOffset( (-1*xOff), (-1*yOff) );
	self.animGroup_Show.translate:SetDuration(0.5);
	self.animGroup_Show.alpha:SetDuration(0.5);
	self.animGroup_Show:Play(true);
end

function _help:Initialise(parent, data)
	PREP_HelpFrame:SetParent(parent);
	PREP_HelpFrame:ClearAllPoints();
	PREP_HelpFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", data.FramePos.x, data.FramePos.y);
	PREP_HelpFrame:SetSize(data.FrameSize.width, data.FrameSize.height);

	PREP_HelpFrame.tutorials = {};
	
	for k, v in ipairs(data) do
	
		local subData = data[k];
		local temp = {}
		
		temp.box = CreateFrame("frame" , "PREP_HelpFrame_Box"..k , parent , "PREP_HelpBoxTemplate");
		temp.box:ClearAllPoints();
		temp.box:SetPoint("TOPLEFT", parent, "TOPLEFT", subData.HighLightBox.x, subData.HighLightBox.y);
		temp.box:SetSize(subData.HighLightBox.width, subData.HighLightBox.height);
		
		temp.glowFrame = CreateFrame("frame" , "PREP_HelpFrame_GlowFrame"..k , parent , "PREP_HelpGlowFrameTemplate");
		temp.glowFrame:ClearAllPoints();
		temp.glowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", subData.HighLightBox.x, subData.HighLightBox.y);
		temp.glowFrame:SetSize(subData.HighLightBox.width, subData.HighLightBox.height);
		
		temp.button = CreateFrame("frame" , "PREP_HelpFrame_Button"..k , parent , "PREP_HelpButtonTemplate");
		temp.button:ClearAllPoints();
		temp.button:SetPoint("TOPLEFT", parent, "TOPLEFT", subData.ButtonPos.x, subData.ButtonPos.y);
		temp.button:SetSize(HELP_BUTTON_NORMAL_SIZE, HELP_BUTTON_NORMAL_SIZE);
		temp.button:SetScript("OnShow", function(self) ShowButtonAnimation(self) end);

		temp.tooltip = CreateFrame("frame" , "PREP_HelpFrame_Tooltip"..k , parent , "PREP_HelpTooltipTemplate");
		temp.tooltip:ClearAllPoints();
		temp.tooltip:SetPoint("TOP", temp.button, "BOTTOM", 0, -10);
		temp.tooltip.Text:SetText(subData.ToolTipText);
		temp.tooltip:SetHeight(temp.tooltip.Text:GetHeight()+20);
		
		temp.button:SetScript("OnEnter", function() ShowTooltip(temp) end);
		temp.button:SetScript("OnLeave", function() HideTooltip(temp) end);
	
		table.insert(PREP_HelpFrame.tutorials, temp);
	end
	
	PREP_HelpFrame:Hide();
	
end

function _help:ShowTutorial()
	PREP_HelpFrame:Show();
	
	for k, v in ipairs(PREP_HelpFrame.tutorials) do
		v.box:Show();
		v.button:Show();
	end
end

function _help:HideTutorial()
	PREP_HelpFrame:Hide();
	
	for k, v in ipairs(PREP_HelpFrame.tutorials) do
		v.box:Hide();
		v.button:Hide();
	end
end