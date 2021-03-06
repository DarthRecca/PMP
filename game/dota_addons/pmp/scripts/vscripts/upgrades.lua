animations = {
	["undead_pimpery"]	= ACT_DOTA_SPAWN,
	["peon_pimpery"] 	= ACT_DOTA_SPAWN,
	["human_pimpery"]	= ACT_DOTA_ATTACK,
	["skeleton_pimpery"]	= ACT_DOTA_CAST_ABILITY_1,
	["night_elf_pimpery"]	= ACT_DOTA_CAST_ABILITY_2,
	["blood_elf_pimpery"]	= ACT_DOTA_CAST_ABILITY_1,
	["goblin_pimpery"]	= ACT_DOTA_CAST_ABILITY_1,
	["treant_pimpery"]	= ACT_DOTA_CAST_ABILITY_5,
	["demon_pimpery"]	= ACT_DOTA_ATTACK,
}

-- This is called after a unit upgrade is purchased
function UpgradeFinished( event )
	local caster = event.caster
	local ability = event.ability
	local pID = caster:GetPlayerOwnerID()
	local lumberCost = ability:GetSpecialValueFor("lumber_cost") or 0
	local goldCost = ability:GetLevelSpecialValueFor("gold_cost", ability:GetLevel()-1) or 0

	if not PlayerHasEnoughGold(pID, goldCost) then
		return
	end

	if not PlayerHasEnoughLumber(pID, lumberCost) then
		return
	end

	ModifyGold(pID, -goldCost)
	ModifyLumber(pID, -lumberCost)

	-- Different animations for pimperies
	local anim = animations[caster:GetUnitName()]
	caster:StartGesture(anim)

	local upgrade_level = tonumber(event.Level)
	local upgrade_name = event.Name
	if upgrade_name == "racial" then
		local race = GetRace(caster)
		upgrade_name = race.."_racial"
	end

	-- Replace with the next level
	if ability:IsItem() then
		Sounds:EmitSoundOnClient( pID, "Announcer.Upgrade.Pimp" )

		local old_slot = GetItemSlot(caster, ability)
		ability:RemoveSelf()

		-- Add a new item rank if possible
		if upgrade_level < 5 then
			local next_rank = upgrade_level + 1
			local new_item_name = "item_upgrade_"..upgrade_name..next_rank
			local new_item = CreateItem(new_item_name, caster, caster)
			caster:AddItem(new_item)
			local new_slot = GetItemSlot(caster, new_item)
			caster:SwapItems(old_slot, new_slot)
		end
	else
		local old_ability_name = ability:GetAbilityName()
		local next_rank = upgrade_level + 1
		local new_ability_name = "upgrade_"..upgrade_name..next_rank

		caster:AddAbility(new_ability_name)

		local new_ability = caster:FindAbilityByName(new_ability_name)
		if new_ability then
			caster:SwapAbilities(new_ability_name, old_ability_name, true, false)
			caster:RemoveAbility(old_ability_name)

			--print("New Rank: "..new_ability_name)
			new_ability:SetLevel(new_ability:GetMaxLevel())
			--new_ability:StartCooldown(1)

			Sounds:PlayUpgradeSound(pID, upgrade_name)
		else
			--print("Max Rank of "..upgrade_name.." reached!")

			-- Add a filler ability showing the last rank has been reached
			local filler_name = "upgrade_"..upgrade_name.."_final"
			local final = TeachAbility(caster,filler_name ,1)
			caster:SwapAbilities(filler_name, old_ability_name, true, false)			
			
			ability:SetLevel(0)

			Sounds:PlayUpgradeSoundMax(pID, upgrade_name)
		end
	end

	FireGameEvent( 'ability_values_force_check', { player_ID = pID })
	PMP:SetUpgrade(pID, upgrade_name, upgrade_level)
end

-- Hero global upgrades
function PimpUpgrade( event )
	local hero = event.caster
	local playerID = hero:GetPlayerID()
	local ability = event.ability
	local level = ability:GetLevel()
	local ability_name = ability:GetAbilityName()

	hero.Upgrades[ability_name] = level

	-- Go through units and update stacks
	local Units = GetPlayerUnits(playerID)
	for _,unit in pairs(Units) do
		PMP:ApplyModifierUpgradeStacks(unit, ability_name, level)
	end

	local Towers = GetPlayerTowers(playerID)
	for _,tower in pairs(Towers) do
		PMP:ApplyModifierUpgradeStacks(tower, ability_name, level)
	end

	-- Add garage damage
	local garage = hero.garage
	if IsValidAlive(garage) then
		PMP:ApplyModifierUpgradeStacks(garage, ability_name, level)
	end

	-- Buff outposts
	local Outposts = GetPlayerOutposts(playerID)
	for _,outpost in pairs(Outposts) do
		if IsValidAlive(outpost) and outpost:GetPlayerOwnerID() == playerID then
			PMP:ApplyModifierUpgradeStacks(outpost, ability_name, level)
		end
	end
end

function PMP:SetUpgrade( playerID, name, level )
	local upgrades = PMP:GetUpgradeList(playerID)

	if string.match(name,"racial") then
		level = level + 1
		name = "racial"
	end
	upgrades[name] = level

	--print("SetUpgrade: "..name.." Level "..level)

	local Units = GetPlayerUnits(playerID)

	-- Apply the upgrade to all units
	for _,unit in pairs(Units) do
		if IsValidAlive(unit) then
			-- Speed upgrades are applied to all units
			if name == "wings" or name == "health" then
				PMP:ApplyUpgrade(unit, name, level)
			else
				if not IsLeaderUnit(unit) or (unit:HasAbility("goblin_attack") or unit:HasAbility("demon_evasion")) then
					PMP:ApplyUpgrade(unit, name, level)
				end
			end

			-- Health increases unit model scale
			if name == "health" then
				local original_scale = GetOriginalModelScale(unit)
				local increase = 0.1*math.log(tonumber(level+1),2)+level*0.002
				unit:SetModelScale(original_scale+increase)
			end
		end
	end

	-- Health also applies to buildings
	local Buildings = GetPlayerBuildings(playerID)
	if name == "health" then
		for _,unit in pairs(Buildings) do
			PMP:ApplyUpgrade(unit, name, level)
		end
	end	

	-- Wearable cosmetic upgrades apply to the pimpery too
	local Pimpery = GetPlayerShop(playerID)
	if IsValidAlive(Pimpery) and slotUpgrades[name] then
		PMP:UpdateWearablesOnSlot(Pimpery, name, level)
	end

	-- Armor and Regen to outposts
	if name == "pimp_regen" or name == "pimp_armor" then
		local Outposts = GetPlayerOutposts(playerID)
		for _,unit in pairs(Outposts) do
			--print("SetUpgrade!!!!! OUTPOST")
			PMP:ApplyUpgrade(unit, name, level)
		end
	end
end

function PMP:GetUpgradeList( playerID )
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	return hero.Upgrades
end

function PMP:GetUpgradeLevel( playerID, name )
	local upgrades = PMP:GetUpgradeList(playerID)
	return upgrades[name] or 0
end


-- OnEntitySpawned, check its name and apply upgrades for the player that owns it
function PMP:ApplyUpgrade(unit, name, level)
	if not IsValidAlive(unit) then return end
	if name == "racial" then
		local race = GetRace(unit)
		name = race.."_"..name
	end
	local ability = unit:FindAbilityByName(name)

	if ability then
		ability:SetLevel(level)
	else
		local ability = TeachAbility(unit, name, level)
		if not ability then
			PMP:ApplyModifierUpgrade(unit, name, level)		
			PMP:UpdateWearablesOnSlot(unit, name, level)
		end

		if name == "quiver" then
			PMP:UpdateProjectile(unit, level)
		end
    end

	AdjustAbilityLayout(unit)
end

function PMP:UpdateProjectile(unit, level)
	local quiverTable = GetWearablesForSlot("quiver")
	local projectileTable = quiverTable['projectile']
	local newProjectile = projectileTable[tostring(level)]

	if newProjectile then
		unit:SetRangedProjectileName(newProjectile)
	end
end

function PMP:UpdateWearablesOnSlot( unit, name, level )
	if not unit.prop_wearables then
		unit.prop_wearables = {}
	end

    local slot_table = GetWearablesForSlot(name)
    if slot_table then

        -- Handle Wearable changes
        local modelName = slot_table[tostring(level)]
        ChangeWearableInSlot(unit, name, modelName)
    end
end

function PMP:ApplyModifierUpgrade(unit, name, level)
	local targetModifierName = "modifier_"..name
	local modifiers = unit:FindAllModifiers()
	for i=0,#modifiers do
		local modifierName = unit:GetModifierNameByIndex(i)
		if StringStartsWith(modifierName, targetModifierName) then
			unit:RemoveModifierByName(modifierName)
		end
	end
	GameRules.UPGRADER:ApplyDataDrivenModifier(unit, unit, targetModifierName..level, {})
end

function PMP:ApplyModifierUpgradeStacks( unit, name, level )
	local hero = unit:GetOwner()
	local ability = hero:FindAbilityByName(name)

	-- Adjust regen for buildings
	if IsCustomBuilding(unit) and name == "pimp_regen" then
		name = "pimp_regen_building"
	end

	local modifierName = "modifier_"..name

	if unit:HasModifier(modifierName) then
		unit:SetModifierStackCount(modifierName, hero, level)
	else
		ability:ApplyDataDrivenModifier(hero, unit, modifierName, {})
		unit:SetModifierStackCount(modifierName, hero, level)
	end
end

-- Go through all the ugprades of the player and add them to a unit
function PMP:ApplyAllUpgrades(playerID, unit)
	local upgrades = PMP:GetUpgradeList(playerID)

	for name,level in pairs(upgrades) do
		if heroUpgrades[name] then
			if level ~= 0 then
				PMP:ApplyModifierUpgradeStacks(unit, name, level)
			end
		elseif level ~= 0 then
			-- Speed and Health upgrades are applied to all units
			if name == "wings" or name == "health" then
				PMP:ApplyUpgrade(unit, name, level)
			else
				if not IsLeaderUnit(unit) or (unit:HasAbility("goblin_attack") or unit:HasAbility("demon_evasion")) then
					PMP:ApplyUpgrade(unit, name, level)
				end
			end

			-- Health increases unit model scale
			if name == "health" then
				local original_scale = GetOriginalModelScale(unit)
				local increase = 0.1*math.log(tonumber(level+1),2)+level*0.002
				unit:SetModelScale(original_scale+increase)
			end
		end
	end
end

function PMP:ApplyOutpostUpgrades( playerID, unit )
	local upgrades = PMP:GetUpgradeList(playerID)

	for name,level in pairs(upgrades) do
		if heroUpgrades[name] then
			if level ~= 0 then
				PMP:ApplyModifierUpgradeStacks(unit, name, level)
			end
		end
	end
end

heroUpgrades = {["pimp_damage"]={},["pimp_armor"]={},["pimp_speed"]={},["pimp_regen"]={}}
slotUpgrades = {["weapon"]={},["second_weapon"]={},["helm"]={},["shield"]={},["wings"]={},["bow"]={},["quiver"]={}}
slots = {"weapon","second_weapon","helm","shield","wings","bow","quiver"}

function PMP:ResetAllUpgrades(playerID)
	local Units = GetPlayerUnits(playerID)
	for _,unit in pairs(Units) do
        for k,slot_name in pairs(slots) do
            ClearPropWearableSlot(unit, slot_name)

            local item_wearable = GetOriginalWearableInSlot(unit, slot_name)
            local default_wearable_name = GetDefaultWearableNameForSlot(unit, slot_name)
            if item_wearable and default_wearable_name then
                item_wearable:SetModel(default_wearable_name)
                item_wearable:RemoveEffects(EF_NODRAW)
            end
        end     
	end
end

function PMP:PrintUpgrades( playerID )
	local upgrades = PMP:GetUpgradeList(playerID)
	DeepPrintTable(upgrades)
end