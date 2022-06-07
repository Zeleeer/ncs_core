NCS:registerNetEvent("nowInGame", function()
    local _src <const> = source

    ---@param player NCSPlayer
    local function load(player)
        local needToCreateSkin <const> = (not (player.character.skin))
        local requireSpawn <const> = (not (NCSInternal.OneSync) and true or (GetEntityModel(GetPlayerPed(_src)) == 225514697))

        player.inGame = true
        player:setLastSource(_src)

        NCS:trace(("Player id ^2%s ^7(^2%s^7) is now ^2online ^7with character ^2%i ^7(^2%s^7)"):format(player.serverId, player.name, player.character.id, player.character:getFullName()))
        NCS:triggerEvent("playerNowInGame", _src, needToCreateSkin)

        player:onDataLoaded(function()
            player:sendData()
            if (needToCreateSkin) then
                player.character:warpToCharacterCustomization(requireSpawn)
            else
                player.character:initialize(requireSpawn)
            end
        end)

        MOD_Zones:subscribeToZones(player)
    end

    local function check()
        if (not (MOD_Players:exists(_src))) then
            API_Database:query("SELECT last_character_id FROM ncs_players WHERE player_identifier = @player_identifier", {
                ["@player_identifier"] = API_Player:getIdentifier(_src)
            }, function(rows)
                if (#rows <= 0) then
                    NCS:traceError(("Error while loading player %s: player is not registered"):format(API_Player:getIdentifier(_src)))
                    DropPlayer(_src, _Literals.ERROR_CRITICAL_HAPPENED)
                    return
                end

                local row <const> = rows[1]
                local characterId <const> = row.last_character_id

                if (not (characterId)) then
                    NCS:traceError(("Error while loading player %s: no character selected"):format(API_Player:getIdentifier(_src)))
                    DropPlayer(_src, _Literals.CONNECTION_ABORTED)
                    return
                end

                ---@type NCSPlayer
                local player = NCSPlayer(_src)
                player.inGame = true
                MOD_Players:set(_src, player)
                player:setCharacterByIdentifier(characterId, function(success)
                    if (not (success)) then
                        NCS:traceError(("Error while loading player %s: character %s not found"):format(API_Player:getIdentifier(_src), characterId))
                        DropPlayer(_src, _Literals.CONNECTION_ABORTED)
                        return
                    end
                    load(player)
                end)
            end)
            return
        end

        load(MOD_Players:get(_src))
    end

    if (not (NCS.ready)) then
        NCS:onReady(check)
        return
    end

    check()

    local isDead = 0
    local waitTime = 1000

    Wait(waitTime*5)
    if (MOD_Players:exists(_src)) then
        local player = MOD_Players:get(_src)
        if (player.character.isDead ~= 0) then
            NCS:triggerClientEvent("playerIsNowDeath", _src)
        end
    end

    while true do
        if (MOD_Players:exists(_src)) then
            local playerPed <const> = GetPlayerPed(_src)
            if ((GetEntityHealth(playerPed) <= 0) and (isDead == 0)) then
                waitTime = 100
                isDead = 1
                
                local sourceKillerEntity <const>, sourceDeathCause <const> = GetPedSourceOfDeath(playerPed), GetPedCauseOfDeath(playerPed)
                local playerDeathCoords <const> = GetEntityCoords(playerPed)
                if sourceKillerEntity ~= _src and sourceKillerEntity  ~= 0 then
                    local playerDeathData = {
                        ["playerDeathCoords"] = playerDeathCoords,
                        ["playerDeathCause"] = sourceDeathCause,
                        ["playerDeathTime"] = GetGameTimer(),
                        ["killerEntity"] = sourceKillerEntity
                    }
                    NCS:trace(("Player id ^2%s ^7(^2%s^7) as been killed by ^2%s ^7(^2%s^7)"):format(_src, MOD_Players:get(_src).name, sourceKillerEntity, MOD_Players:get(sourceKillerEntity).name), 3)
                    NCSCharacter:setDeathStatus(_src, isDead, playerDeathData)
                    TriggerEvent("playerIsNowDeath", _src, playerDeathData)
                else
                    local playerDeathData = {
                        ["playerDeathCoords"] = playerDeathCoords,
                        ["playerDeathCause"] = sourceDeathCause,
                        ["playerDeathTime"] = GetGameTimer(),
                        ["killerEntity"] = false
                    }
                    NCS:trace(("Player id ^2%s ^7(^2%s^7) died without killer"):format(_src, MOD_Players:get(_src).name), 3)
                    NCSCharacter:setDeathStatus(_src, isDead, playerDeathData)
                    NCS:triggerEvent("playerIsNowDeath", _src, playerDeathData)
                end
            elseif (GetEntityHealth(playerPed) >= 1) and (isDead == 1) then
                waitTime = 1000
                isDead = 0
            end
        end
        Wait(waitTime)
    end
end)