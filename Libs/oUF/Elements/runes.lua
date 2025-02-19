--[[
# Element: Runes

Handles the visibility and updating of Death Knight's runes.

## Widget

Runes - An `table` holding `StatusBar`s.

## Sub-Widgets

.bg - A `Texture` used as a background. It will inherit the color of the main StatusBar.

## Notes

A default texture will be applied if the sub-widgets are StatusBars and don't have a texture set.

## Options

.colorSpec - Use `self.colors.runes[specID]` to color the bar based on player's spec. `specID` is defined by the return
             value of [GetSpecialization](http://wowprogramming.com/docs/api/GetSpecialization.html) (boolean)
.sortOrder - Sorting order. Sorts by the remaining cooldown time, 'asc' - from the least cooldown time remaining (fully
             charged) to the most (fully depleted), 'desc' - the opposite (string?)['asc', 'desc']

## Sub-Widgets Options

.multiplier - Used to tint the background based on the main widgets R, G and B values. Defaults to 1 (number)[0-1]

## Examples

    local Runes = {}
    for index = 1, 6 do
        -- Position and size of the rune bar indicators
        local Rune = CreateFrame('StatusBar', nil, self)
        Rune:SetSize(120 / 6, 20)
        Rune:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', index * 120 / 6, 0)

        Runes[index] = Rune
    end

    -- Register with oUF
    self.Runes = Runes
--]]

if(select(2, UnitClass('player')) ~= 'DEATHKNIGHT') then return end

local _, ns = ...
local oUF = ns.oUF

local runemap = { 1, 2, 5, 6, 3, 4 }

local function onUpdate(self, elapsed)
	local duration = self.duration + elapsed
	self.duration = duration
	self:SetValue(duration)
end

local function UpdateColor(self, event, rid, alt)
	local element = self.Runes
	local rune = element[runemap[rid]]
	local index = GetRuneType(rid) or alt
	local colors = self.colors.runes[index or 1]

	local r, g, b = colors[1], colors[2], colors[3]

	rune:SetStatusBarColor(r, g, b)

	local bg = rune.bg
	if(bg) then
		local mu = bg.multiplier or 1
		bg:SetVertexColor(r * mu, g * mu, b * mu)
	end

	--[[ Callback: Runes:PostUpdateColor(r, g, b)
	Called after the element color has been updated.

	* self - the Runes element
	* r    - the red component of the used color (number)[0-1]
	* g    - the green component of the used color (number)[0-1]
	* b    - the blue component of the used color (number)[0-1]
	--]]
	if(element.PostUpdateColor) then
		element:PostUpdateColor(r, g, b)
	end
end

local function ColorPath(self, ...)
	--[[ Override: Runes.UpdateColor(self, event, ...)
	Used to completely override the internal function for updating the widgets' colors.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	(self.Runes.UpdateColor or UpdateColor) (self, ...)
end

local function Update(self, event)
	local element = self.Runes

	local rune, start, duration, runeReady
	for index, runeID in next, runemap do
		rune = element[index]
		if(not rune) then break end

		if(UnitHasVehicleUI('player')) then
			rune:Hide()
		else
			start, duration, runeReady = GetRuneCooldown(runeID)
			if(runeReady) then
				rune:SetMinMaxValues(0, 1)
				rune:SetValue(1)
				rune:SetScript('OnUpdate', nil)
			elseif(start) then
				rune.duration = GetTime() - start
				rune:SetMinMaxValues(0, duration)
				rune:SetValue(0)
				rune:SetScript('OnUpdate', onUpdate)
			end

			rune:Show()
		end
	end

	--[[ Callback: Runes:PostUpdate(runemap)
	Called after the element has been updated.

	* self    - the Runes element
	* runemap - the ordered list of runes' indices (table)
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(runemap)
	end
end

local function Path(self, ...)
	--[[ Override: Runes.Override(self, event, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	(self.Runes.Override or Update) (self, ...)
end

local function AllPath(...)
	Path(...)
end

local function ForceUpdate(element)
	Path(element.__owner, 'ForceUpdate')

	for i = 1, #element do
		ColorPath(element.__owner, nil, i, math.floor((i+1)/2))
	end
end

local function Enable(self, unit)
	local element = self.Runes
	if(element and UnitIsUnit(unit, 'player')) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		for i = 1, #element do
			local rune = element[i]
			if(rune:IsObjectType('StatusBar') and not (rune:GetStatusBarTexture() or rune:GetStatusBarAtlas())) then
				rune:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
			ColorPath(self, nil, i, math.floor((i+1)/2))
		end

		self:RegisterEvent('RUNE_TYPE_UPDATE', ColorPath, true)
		self:RegisterEvent('RUNE_POWER_UPDATE', Path, true)

		return true
	end
end

local function Disable(self)
	local element = self.Runes
	if(element) then
		for i = 1, #element do
			element[i]:Hide()
		end

		self:UnregisterEvent('RUNE_TYPE_UPDATE', ColorPath)
		self:UnregisterEvent('RUNE_POWER_UPDATE', Path)
	end
end

oUF:AddElement('Runes', AllPath, Enable, Disable)