function RepairBuildings( event )
    local caster = event.caster -- Garage
    local ability = event.ability
    local repair_percent = ability:GetSpecialValueFor("repair_percent") * 0.01
    RegainHealthPercent(caster, repair_percent)

    local hero = caster:GetOwner()
    if hero then
        hero.repairs_used = hero.repairs_used + 1

        local towers = hero.towers
        for k,tower in pairs(towers) do
            if IsValidAlive(tower) then
                RegainHealthPercent(tower, repair_percent)
            end
        end

        local shop = hero.shop
        if IsValidAlive(shop) then
            RegainHealthPercent(shop, repair_percent)
        end
    end
end

function RegainHealthPercent( unit, percentage )
    if unit:GetHealthDeficit() > 0 then
        local health_gain = math.min(unit:GetMaxHealth() * percentage, unit:GetHealthDeficit())
        unit:Heal(health_gain, unit)
        PopupHealing(unit, health_gain)
    end
end

function HoldPeons( event )
    local caster = event.caster
    caster.HoldingPeons = true
    caster.held_units = 0
end

function ReleasePeons( event )
    local caster = event.caster
    local position = caster:GetAbsOrigin()
    local hero = caster:GetOwner()
    local playerID = caster:GetPlayerOwnerID()

    -- Update spawn position to the current active outpost
    local activeOutpost = GetActiveOutpost(playerID)
    if activeOutpost then
        position = activeOutpost:GetAbsOrigin()
    end

    -- Spawn count of stored peons and leaders
    local playSound = true
    caster:RemoveModifierByName("modifier_hold_peons")
    for _,unit in pairs(hero.units) do
        if IsValidAlive(unit) and unit:HasModifier("modifier_hide") then
            if playSound then
                playSound = false
                Sounds:PlaySoundSet(playerID, unit, DOTA_UNIT_ORDER_ATTACK_MOVE)
            end

            ShowPropWearables(unit)
            unit:RemoveNoDraw()
            unit:RemoveModifierByName("modifier_hide")

            unit:SetOwner(hero)
            unit:SetControllableByPlayer(playerID, true)
            FindClearSpaceForUnit(unit, position, true)
            unit:MoveToPositionAggressive(caster.rally_point)

            if IsLeaderUnit(unit) and not unit:HasAbility("goblin_attack") then
                ApplyModifier(unit, "modifier_disable_autoattack")
            end
        end
    end

    caster.HoldingPeons = false
    caster.held_units = 0
end

-- Go to each barricade map point and place an extra random crate model on top
function BuildBarricades( event )
    print("Build Barricades")

    local Barricades = GameRules.Barricades

    local caster = event.caster
    local hero = caster:GetOwner()
    local teamNumber = caster:GetTeamNumber()

    if hero then
        hero.barricades_used = hero.barricades_used + 1
    end

    local randomN = Barricades["Random"]
    for k,position in pairs(hero.barricade_positions) do
        local nBarricade = tostring(RandomInt(1, randomN))
        local randPos = position+RandomVector(RandomInt(-70,70))
        local barricade = CreateUnitByName("barricade", randPos, false, hero, hero, teamNumber)
        barricade:SetModel(Barricades[nBarricade]["Model"])
        barricade:SetModelScale(Barricades[nBarricade]["Scale"])
        barricade:SetAngles(0, RandomInt(0,360), 0)
        barricade:SetAbsOrigin(GetGroundPosition(randPos, barricade))
        barricade:SetOwner(hero)
        table.insert(hero.barricades, barricade)
    end

    -- If more than 5 sets of barricades (20), announce the "Heavy" barricade
    local barricadeCount = 0
    for k,v in pairs(hero.barricades) do
        if IsValidAlive(v) then
            barricadeCount = barricadeCount + 1
        end
    end

    if barricadeCount > 20 then
        Sounds:EmitSoundOnClient(hero:GetPlayerID(), "Announcer.Buildings.Barricades.Heavy")
    else
        Sounds:EmitSoundOnClient(hero:GetPlayerID(), "Announcer.Buildings.Barricades")
    end
end

-- Barricades take 2 hits to destroy
function BarricadeHit( event )
    local caster = event.caster

    if not caster.hit then
        caster.hit = 1
        caster:SetHealth(1)
    else
        caster:ForceKill(true)
        ParticleManager:CreateParticle("particles/newplayer_fx/npx_tree_break.vpcf", PATTACH_ABSORIGIN, caster)
    end
end

-- Do stuff when a super peon leaves base
function LeaveBase( trigger )
    local activator = trigger.activator
    if activator and IsSuperPeon(activator) and IsValidAlive(activator) then
        print("Super Peon leaving the base")     
        local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_life_stealer/life_stealer_infest_emerge_bloody_low.vpcf", PATTACH_CUSTOMORIGIN, activator)
        ParticleManager:SetParticleControl(particle, 0, activator:GetAbsOrigin())
        activator:ForceKill(true)
        activator:AddNoDraw()
    end
end

function Rotate( event )
    local garage = event.caster
    local value = event.Value

    garage:SetAngles(0,-value,0)
end