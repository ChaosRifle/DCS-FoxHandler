--FoxHandler
--requires: tableIO and ChaosTools
--requires config file containing: MissionName, FilePath

--local saveDataSubfolder = 'saves/'
--local saveNamePrefix = MissionName .. '_'


FoxUsers = {}
--main
if not FileExists(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_B_Players.lua' })) then
    TableSave(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_B_Players.lua' }), {})
end
if not FileExists(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_B_AI.lua' })) then
    TableSave(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_B_AI.lua' }), {})
end
if not FileExists(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_R_Players.lua' })) then
    TableSave(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_R_Players.lua' }), {})
end
if not FileExists(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_R_AI.lua' })) then
    TableSave(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_R_AI.lua' }), {})
end


local FoxHandler = {}
local B_Players = TableLoad(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_B_Players.lua' }))
local B_AI = TableLoad(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_B_AI.lua' }))
local R_players = TableLoad(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_R_Players.lua' }))
local R_AI = TableLoad(table.concat({ FilePath, saveDataSubfolder, saveNamePrefix, 'FoxHandler_R_AI.lua' }))
--FoxUsers[ucid].tx = true
--FoxUsers[ucid].rx = false --currently unused, here for ref.



local playerName = Unit.getPlayerName(event.initiator)
if playerName then
    local playerList = net.get_player_list()
    local playerInfo = nil
    for x = 1, #playerList, 1 do
        playerInfo = net.get_player_info(playerList[x])
        if playerInfo.name == playerName then
            break
        end
    end
end



function FoxHandler:onEvent(event)
    if event.id == world.event.S_EVENT_SHOT then
        local unitName = event.initiator:getName()
        local wpCat = event.weapon:getDesc().category
        local wpMisCat = event.weapon:getDesc().MissileCategory
        local wpGuideType = event.weapon:getDesc().GuidanceType
        local tgt = event.weapon:getTarget()
        --check to see if unit is active player if not skip
        if wpMisCat == weapon.MissileCategory.AAM and wpGuideType == wpGuideType.RADAR_ACTIVE then
            if tgt then
                env.info(playerName, ' Fox 3 at ', tgt)
            else
                env.info(playerName, ' Maddog!')
            end
        elseif wpMisCat == weapon.MissileCategory.AAM and wpGuideType == wpGuideType.RADAR_SEMIACTIVE then
            if tgt then
                env.info(playerName, ' Fox 2 at ', tgt)
            else
                env.info(playerName, ' Maddog!')
            end
        elseif wpMisCat == weapon.MissileCategory.AAM and wpGuideType == wpGuideType.RADAR_PASSIVE then
            env.info(playerName, ' has fired a Fox 1!')
        elseif wpMisCat == weapon.MissileCategory.CRUISE and wpGuideType == wpGuideType.RADAR_PASSIVE then
            env.info(playerName, ' Magnum!')
        elseif wpMisCat == weapon.MissileCategory.ANIT_SHIP then
            env.info(playerName, ' Bruiser!')
        elseif wpMisCat == weapon.MissileCategory.OTHER then
            env.info(playerName, ' Rifle!')
        else
            env.info(playerName, 'rifle!')
        end
    elseif event.id == world.event.S_EVENT_MARK_ADDED then -- marker commands                                           -- IDENTICAL TO S_EVENT_MARK_ADDED, S_EVENT_MARK_CHANGE
        -- Event = {
        --     id = 25,
        --     idx = number markId,
        --     time = Abs time,
        --     initiator = Unit,
        --     coalition = number coalitionId,
        --     groupID = number groupId,
        --     text = string markText,
        --     pos = vec3
        --    }
    elseif event.id == world.event.S_EVENT_MARK_CHANGE then -- marker commands                                          -- IDENTICAL TO S_EVENT_MARK_ADDED, S_EVENT_MARK_CHANGE
        -- Event = {
        --     id = 26,
        --     idx = number markId,
        --     time = Abs time,
        --     initiator = Unit,
        --     coalition = number coalitionId,
        --     groupID = number groupId,
        --     text = string markText,
        --     pos = vec3
        --    }
        if text == 'foxhandler tx enable' then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName then
                local playerInfo = GetPlayerInfo(playerName)
                FoxUsers[playerInfo.ucid].tx = true
                trigger.action.removeMark(event.idx) --delete the message from being seen by other people, as it was a command.
            end
        end
    end
end

--[[local msg = {
        id = 'TransmitMessage',
        params = {
            duration = 5,
            subtitle = "Radio Message",
            loop = false,
            file = ".wav",
        }
    }
    playerName:getController():setCommand(msg)]]

world.addEventHandler(FoxHandler)


