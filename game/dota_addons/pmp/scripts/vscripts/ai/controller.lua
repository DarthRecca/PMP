function AI:GroupUnits(playerID)
    local units = GetPlayerUnits(playerID)

    -- First, make sure the units are in a group
    if not AI:AreUnitsGrouped(playerID, units) then
        local pos = GetPlayerCityCenter(playerID).rally_point
        AI:AcquireWeakEnemy(playerID)
        AI:MoveUnitsInFormation(playerID, units, pos)

    else --Attack together
        local pos = GetPlayerCityCenter(playerID).rally_point
        local targetEnemy = AI:GetBotAttackTarget(playerID)
        if not targetEnemy or PlayerResource:GetSelectedHeroEntity(targetEnemy).lost then
            AI:AcquireWeakEnemy(playerID)
            return
        else
            local target = GetPlayerCityCenter( targetEnemy )
            if IsValidAlive(target) then
                pos = target:GetAbsOrigin()
            else
                AI:AcquireWeakEnemy(playerID)
                return
            end
        end

        AI:MoveUnitsInFormation(playerID, units, pos)
    end
end

function AI:MoveUnitAggresive(unit, target_pos)
    if IsInToolsMode() or AI:ActiveLog("Movement") then
        local color = PMP:ColorForTeam(unit:GetTeamNumber())
        DebugDrawLine(unit:GetAbsOrigin(), target_pos, color[1], color[2], color[3], true, 5)
        DebugDrawCircle(target_pos, Vector(color[1], color[2], color[3]), 255, 10, true, 5)
    end
    unit:MoveToPositionAggressive(target_pos)
end

function AI:MoveUnitsInFormation(playerID, units, target_pos)
    local gridPoints = GetGridAroundPoint(#units, target_pos)
    for k,unit in pairs(units) do
        if IsValidAlive(unit) then
            if unit:IsIdle() then
                AI:MoveUnitAggresive(unit, gridPoints[tonumber(k)])
            end
        end
    end
end

--sorta lazy check
function AI:AreUnitsGrouped(playerID, units)
    return GetFoodUsed(playerID) >= GetFoodLimit(playerID)*0.7
end

function AI:GetBotAttackTarget(playerID)
    return AI.Players[playerID].AttackTarget
end

function AI:SetBotAttackTarget(playerID, enemyPlayerID)
    AI.Players[playerID].AttackTarget = enemyPlayerID
end

function AI:AcquireWeakEnemy(playerID)
    local targetEnemy
    local teamNumber = PlayerResource:GetTeam(playerID)
    local origin = GetPlayerCityCenter(playerID):GetAbsOrigin()

    --[[Distance to nearby base is ~2.5k, ~3.6k in diagonal, ~5.7k to the other side, ~7.2k on cross diagonal
    Logic should be:
        If there is a target reachable on the side (first <3k, then <4k) attack the best of those
        If there isn't, find on the whole map
    --]]

    local thresholds = {3000,4000,6000,10000}
    local myKills = PlayerResource:GetKills(playerID)
    local targetKills = 99999
    for _,distance in pairs(thresholds) do
        local enemyList = AI:GetEnemiesBelowDistance(teamNumber, origin, distance)
        if #enemyList > 0 then
            for _,pID in pairs(enemyList) do
                local kills = PlayerResource:GetKills(pID)
                if kills < targetKills then
                    targetEnemy = pID
                    targetKills = kills
                end
            end
            break
        end
    end
    
    if targetEnemy then
        local targetDistance = (origin - PlayerResource:GetSelectedHeroEntity(targetEnemy):GetAbsOrigin()):Length2D()
        --AI:print("SetBotAttackTarget "..playerID..": ".. targetEnemy.." with "..targetKills.." kills at "..targetDistance.." distance","AcquireWeakEnemy")
        --AI:print(TEAM_NUMER_TO_COLOR[PlayerResource:GetTeam(playerID)].. " bot is attacking "..TEAM_NUMER_TO_COLOR[PlayerResource:GetTeam(targetEnemy)])
        AI:SetBotAttackTarget(playerID, targetEnemy)
    else
        AI:print("Something is wrong, no target found for "..playerID..", this shouldn't happen unless the game is over")
    end
end

function AI:GetEnemiesBelowDistance(teamNumber, origin, maxDistance)
    local list = {}
    for _,hero in pairs(GameRules.StillInGame) do
        local playerID = hero:GetPlayerID()
        if PlayerResource:GetTeam(playerID) ~= teamNumber then
            local distance = (origin - hero:GetAbsOrigin()):Length2D()
            if distance <= maxDistance then
                table.insert(list, playerID)
            end
        end
    end
    return list
end