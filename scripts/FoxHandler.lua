-- FoxHandler
-- requires: tableIO, ChaosTools, Mist for scheduleFunction
-- requires config file containing: MissionName, FilePath, TACCOM, TACCOMModulation
local version = '0.6.4'


-- default config, not recommended to change this. If you want something different, overwrite it with the respective public variable prefixed LifeHanderConfig_ as pointed out above
local mizFilepath =  [[l10n\DEFAULT\foxhandler\]] --[[l10n\DEFAULT\tusk_onstation.wav]]
local saveDataSubfolder = [[saves\]]
local saveDataPrefix = ''
if FoxHandlerConfig_TxPower == nil then FoxHandlerConfig_TxPower = 100 end --in watts to set range to be heard
if FoxHandlerConfig_ShackSplash == nil then FoxHandlerConfig_ShackSplash = true end  --call shacks and splashes?
if FoxHandlerConfig_NonRocketWeapons == nil then FoxHandlerConfig_NonRocketWeapons = true end  --pickle, paveway, pig, etc
if FoxHandlerConfig_RxOptional == nil then FoxHandlerConfig_RxOptional = false end  --FIXME eventually, this should be removed entirely to always allow users to not recieve. this exists to bypass rewriting radioTransmitCalloutData() for the time being
if FoxHandlerConfig_MinimumTimeBetweenCallouts == nil then FoxHandlerConfig_MinimumTimeBetweenCallouts = 15 end --seconds


-- load config data if it exists
do
    if FoxHandlerConfig_saveDataSubfolder then
        saveDataSubfolder = FoxHandlerConfig_saveDataSubfolder
    end
    if FoxHandlerConfig_saveDataPrefix then --for making the settings mission specific instead of server wide, typically this is undesirable so would be set to '' and not modified. MissionName or '' are typically the two entries desired
        saveDataPrefix = FoxHandlerConfig_saveDataPrefix
    end
end


-- first boot prep
if not FileExists(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'})) then
    local playerlist = net.get_player_list()
    local serverSpectatorInfo = net.get_player_info(playerlist[1])
    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), {[serverSpectatorInfo.ucid] = {
        ['name'] = serverSpectatorInfo.name,
        ['va'] = 'chaos',
        ['tx'] = false, --manual disable for turning off all tx comms output from this user
        ['callsign'] = 'watcher',
        ['shackSplash'] = true, --manual disable for turning off shack or splash tx comms output from this user
        ['lastLaunchCalloutTime'] = '0', --time
        ['lastShackSplashCalloutTime'] = '0', --time
        ['lastLaunchType'] = 'typename?', --possible future use for x2 x3 x4 callouts for repeated launches
        ['serverObserver'] = true
    }})
end
if not FileExists(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataRx.lua'})) then
    local playerlist = net.get_player_list()
    local serverSpectatorInfo = net.get_player_info(playerlist[1])
    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataRx.lua'}), {[serverSpectatorInfo.ucid] = {
        ['name'] = serverSpectatorInfo.name,
        ['rx'] = false,
        ['side'] = coalition.side.NEUTRAL,
        ['unit'] = 'unit id_ for transmission to be sent to. updated by birth events',
        ['serverObserver'] = true
    }})
end


-- functions
local function transmitRadioCalloutData(output, initiatorCoalition, outputString, displayTime, txPoint, ucid)
    if output == true then
        catString = table.concat(outputString)
        if FoxHandlerConfig_RxOptional == true then
            for key, value in pairs(foxDataRx) do                                                   --FIXME rework this to use net.get_player_list() for optimized search, as well as check unit position to be close enough to have heard the radio call at all. this also does not work currently as requires unitid
                if value.rx == true and value.side == initiatorCoalition then
                    trigger.action.outTextForUnit(value.unit, catString, displayTime)
                end
            end
        else
            trigger.action.outTextForCoalition(initiatorCoalition, catString, displayTime)
        end

        local radioCalloutFile = table.concat({ mizFilepath, voiceActor[foxDataTx[ucid].va], [[main\]], filename, '.wav' })
        trigger.action.radioTransmission(radioCalloutFile, txPoint, TACCOMModulation[initiatorCoalition + 1], false, TACCOM[initiatorCoalition + 1], txPower, '')
        if foxDataTx[ucid].callsign then
            if voiceActors[foxDataTx[ucid].va] and voiceActors[foxDataTx[ucid].va].callsignsAvailable[string.lower(foxDataTx[ucid].callsign)] then
                callsignFile = table.concat({ mizFilepath, voiceActor[foxDataTx[ucid].va], [[\callsigns\]], voiceActors[foxDataTx[ucid].va].callsignsAvailable[string.lower(foxDataTx[ucid].callsign)], '.wav' })
                local delay = 1.5 --delay by fileToPlayPlaytimeLength --FIXME this should be dynamic, probably based on file playtime length - this could be done by embedding a file with that data. TEST this actually takes and parses decimal values
                mist.scheduleFunction(trigger.action.radioTransmission(), {callsignFile, txPoint, TACCOMModulation[initiatorCoalition + 1], false, TACCOM[initiatorCoalition + 1], txPower, ''}, timer.getTime() + delay)
            end
        end
    end
end

local function addTargetData(target, outputString)
    if target ~= nil then
        outputString[#outputString + 1] = ' '
        outputString[#outputString + 1] = target.getTypeName()
    end
    return outputString
end


-- init
local foxDataTx = TableLoad(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}) )
local foxDataRx = TableLoad(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataRx.lua'}) )

do  --clean last launcch times for all users at start, as time is from mission start, in seconds
    for key, value in pairs(foxDataTx) do
        value.lastLaunchCalloutTime = 0
        value.lastShackSplashCalloutTime = 0
        value.lastLaunchType = ''
    end
    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), foxDataTx)
end

local voiceActors = {
    ['chaos'] = { ['va'] = 'chaos', ['gender'] = 'm', ['enum'] = 1, ['callsignsAvailable'] = { 'graaf' } },
    ['m1'] = { ['va'] = 'chaos', ['gender'] = 'm', ['enum'] = 1, ['callsignsAvailable'] = { 'graaf' } },

    ['rain'] = { ['va'] = 'rain', ['gender'] = 'f', ['enum'] = 1, ['callsignsAvailable'] = { 'anna', 'graaf', 'jedi' } },
    ['f1'] = { ['va'] = 'rain', ['gender'] = 'f', ['enum'] = 1, ['callsignsAvailable'] = { 'anna', 'graaf', 'jedi' } }
}

local uniqueVoiceActors = {}
local uniqueVoiceActorsString = ''
do
    local uniqueVoiceActorsPrep = {}
    for key, value in pairs(voiceActors) do
        uniqueVoiceActorsPrep[value.va] = true
    end
    uniqueVoiceActors = {}
    for key, value in pairs(uniqueVoiceActorsPrep) do
        table.insert(uniqueVoiceActors, #uniqueVoiceActors + 1, key)
    end
    uniqueVoiceActorsString = table.concat(uniqueVoiceActors, ', ')
end


-- execution
local foxHandler = {}

function foxHandler:onEvent(event)
    if event.id == world.event.S_EVENT_SHOT then
--         Event = {
--             id = 1,
--             time = Time,
--             initiator = Unit,
--             weapon = Weapon
--         }

        if Object.getCategory(event.initiator) == Object.Category.UNIT then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local currentTime = timer.getTime()
                if playerInfo ~= nil and foxDataTx[playerInfo.ucid] and foxDataTx[playerInfo.ucid].tx == true and voiceActors[foxDataTx[playerInfo.ucid].va] and currentTime - foxDataTx[playerInfo.ucid].lastLaunchCalloutTime > FoxHandlerConfig_MinimumTimeBetweenCallouts then --playerInfo can be nil for SP. bugfix
                    local txPoint = Object.getPoint(event.initiator)
                    local weaponDesc = weapon.getDesc()
                    local target = weapon.getTarget() -- could be nil
                    local initiatorCoalition = Object.getCoalition(event.initiator)
                    local output = false
                    local filename = ''
                    local outputString = {}
                    local callsign = nil
                    if foxDataTx[playerInfo.ucid].callsign ~= nil or foxDataTx[playerInfo.ucid].callsign ~= '' then
                        outputString[#outputString + 1] = foxDataTx[playerInfo.ucid].callsign
                        outputString[#outputString + 1] = ', '
                        callsign = foxDataTx[playerInfo.ucid].callsign
                    end
                    if weaponDesc.category == Weapon.Category.MISSILE then
                        if weaponDesc.MissileCategory == weapon.MissileCategory.AAM then --fox
                            if weaponDesc.GuidanceType == Weapon.GuidanceType.RADAR_ACTIVE then
                                if target == nil then
                                    output = true
                                    filename = 'maddog'
                                    outputString[#outputString + 1] = 'Mad Dog'
                                else
                                    output = true
                                    filename = 'fox3'
                                    outputString[#outputString + 1] = 'Fox 3'
                                    outputString = addTargetData(target, outputString)
                                end
                            elseif weaponDesc.GuidanceType == Weapon.GuidanceType.RADAR_SEMI_ACTIVE then
                                output = true
                                filename = 'fox1'
                                outputString[#outputString + 1] = 'Fox 1'
                                outputString = addTargetData(target, outputString)
                            elseif weaponDesc.GuidanceType == Weapon.GuidanceType.IR
                                output = true
                                filename = 'fox2'
                                outputString[#outputString + 1] = 'Fox 2'
                                outputString = addTargetData(target, outputString)
                            else --what is this missile??!
                                output = true
                                filename = 'rifle'
                                outputString[#outputString + 1] = 'Fox... huh??'
                                outputString = addTargetData(target, outputString)
                            end
                        elseif weaponDesc.MissileCategory == weapon.MissileCategory.CRUISE then
                            if weaponDesc.GuidanceType == Weapon.GuidanceType.wpGuideType.RADAR_PASSIVE then
                                output = true
                                filename = 'magnum'
                                outputString[#outputString + 1] = 'Magnum'
                                outputString = addTargetData(target, outputString)
                            elseif weaponDesc.GuidanceType == Weapon.GuidanceType.INS
                                output = true
                                filename = 'longrifle'
                                outputString[#outputString + 1] = 'Long Rifle'
                                outputString = addTargetData(target, outputString)
                            else --what is this missile??!
                                output = true
                                filename = 'rifle'
                                outputString[#outputString + 1] = '... what did I just fire??'
                                outputString = addTargetData(target, outputString)
                            end
                        elseif weaponDesc.MissileCategory == weapon.MissileCategory.ANIT_SHIP then
                            output = true
                            filename = 'bruiser'
                            outputString[#outputString + 1] = 'Bruiser'
                            outputString = addTargetData(target, outputString)
                        elseif weaponDesc.MissileCategory == weapon.MissileCategory.SAM then
                            output = false
                        elseif weaponDesc.MissileCategory == weapon.MissileCategory.BM then --what is this???
                            output = true
                            filename = 'rifle'
                            outputString[#outputString + 1] = 'the heck is a BM?'
                            outputString = addTargetData(target, outputString)
                        elseif weaponDesc.MissileCategory == weapon.MissileCategory.OTHER then
                            output = true
                            filename = 'rifle'
                            outputString[#outputString + 1] = 'other...'
                            outputString = addTargetData(target, outputString)
                        else --unknown missile category
                            output = true
                            filename = 'rifle'
                            outputString[#outputString + 1] = 'this wasnt an other but somehow is a something...'
                            outputString = addTargetData(target, outputString)
                        end
                    elseif weaponDesc.category == Weapon.Category.ROCKET then
                        output = true
                        filename = 'rifle'
                        outputString[#outputString + 1] = 'Rifle'
                        outputString = addTargetData(target, outputString)
                    elseif weaponDesc.category == Weapon.Category.BOMB and FoxHandlerConfig_NonRocketWeapons == true then
                        if weaponDesc.GuidanceType == Weapon.GuidanceType.wpGuideType.INS then
                            output = true
                            filename = 'pickle'
                            outputString[#outputString + 1] = 'Pickle'
                        elseif weaponDesc.GuidanceType == Weapon.GuidanceType.wpGuideType.LASER then
                            output = true
                            filename = 'paveway'
                            outputString[#outputString + 1] = 'Paveway'
                        else
                            output = true
                            filename = 'pickle'
                            outputString[#outputString + 1] = 'I dont know what kind of bomb that was...'
                            outputString = addTargetData(target, outputString)
                        end
                    end
                    transmitRadioCalloutData(output, initiatorCoalition, outputString, 3, txPoint, playerInfo.ucid)
                end
            else -- ai unit

            end
        end
    elseif event.id == world.event.S_EVENT_KILL then
--         Event = {
--             id = 29,
--             time = Time,
--             initiator = Unit,
--             weapon = Weapon,
--             target = Unit,
--             weapon_name = string,
--         }

        if FoxHandlerConfig_ShackSplash == true then
            if Object.getCategory(event.initiator) == Object.Category.UNIT then
                local playerName = Unit.getPlayerName(event.initiator)
                if playerName ~= nil then
                    local playerInfo = GetPlayerInfo(playerName)
                    local currentTime = timer.getTime()
                    if playerInfo ~= nil and foxDataTx[playerInfo.ucid] and foxDataTx[playerInfo.ucid].shackSplash and foxDataTx[playerInfo.ucid].tx == true and voiceActors[foxDataTx[playerInfo.ucid].va] and currentTime - foxDataTx[playerInfo.ucid].lastShackSplashCalloutTime > FoxHandlerConfig_MinimumTimeBetweenCallouts then --playerInfo can be nil for SP. bugfix
                        local txPoint = Object.getPoint(event.initiator)
                        --local weaponDesc = weapon.getDesc()
                        local targetType = event.target:getDesc().category
                        local initiatorCoalition = Object.getCoalition(event.initiator)
                        local output = false
                        local outputString = {}
                        local callsign = nil
                        if foxDataTx[playerInfo.ucid].callsign ~= nil or foxDataTx[playerInfo.ucid].callsign ~= '' then
                            outputString[#outputString + 1] = foxDataTx[playerInfo.ucid].callsign
                            outputString[#outputString + 1] = ', '
                            callsign = foxDataTx[playerInfo.ucid].callsign
                        end

                        if targetType == Unit.Category.AIRPLANE or targetType == Unit.Category.HELICOPTER then
                            output = true
                            filename = 'splash'
                            outputString[#outputString + 1] = 'splash'
                            outputString = addTargetData(event.target, outputString)
                        elseif targetType == Unit.Category.GROUND_UNIT or targetType == Unit.Category.STRUCTURE then
                            output = true
                            filename = 'shack'
                            outputString[#outputString + 1] = 'shack'
                            outputString = addTargetData(event.target, outputString)
                        elseif targetType == Unit.Category.SHIP then
                            output = true
                            filename = 'splishsplash'
                            outputString[#outputString + 1] = 'splishsplash'
                            outputString = addTargetData(event.target, outputString)
                        else --should never be observed
                        end
                        transmitRadioCalloutData(output, initiatorCoalition, outputString, 3, txPoint, playerInfo.ucid)
                    end
                else --ai
                end
            end
        end
    elseif event.id == world.event.S_EVENT_BIRTH then --look into using ChaosTools dostring for MISSION_PlayerDataList to get the information required.
--         Event = {
--           id = 15,
--           time = Time,
--           initiator = Unit,
--         }

--         if Object.getCategory(event.initiator) == Object.Category.UNIT then -- bug workaround for static object spawns returning exists but somehow saying doesnt exist when operated on
--             local playerName = Unit.getPlayerName(event.initiator)
--             if playerName ~= nil then
--                 local playerInfo = GetPlayerInfo(playerName)
--                 if playerInfo ~= nil then -- SP has issue in GetPlayerInfo function where net.get_player_list() doesnt report the name given by Unit.getPlayerName() ("New callsign") so ultimately returns the init value, nil
--                     if not PlayersLives[playerInfo.ucid] then
--                         PlayersLives[playerInfo.ucid] = { ['lives'] = maxLives, ['name'] = playerInfo.name, ['lifeInsurance'] = false }
--                     else
--                         PlayersLives[playerInfo.ucid].name = playerInfo.name
--                     end
--                     --PlayersLives[playerInfo.ucid].lifeInsurance = false --last ditch to ensure insurance is set false before takeoff
--                     TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'LifeHandler_PlayersLives.lua'}), PlayersLives)


    elseif event.id == world.event.S_EVENT_MARK_ADDED or event.id == world.event.S_EVENT_MARK_CHANGE then --FIXME needs functions to add a user to the list of users that should transmit, or recieve ui text, as well as choose VA for tx
--         Event = {
--             id = 25 OR 26,
--             idx = number markId,
--             time = Abs time,
--             initiator = Unit,
--             coalition = number coalitionId,
--             groupID = number groupId,
--             text = string markText,
--             pos = vec3
--         }
        --local lowercaseEventText = string.lower(event.text)
        if string.match(event.text, '^callsign ') ~= nil then --^ means begins with
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataTx[playerInfo.ucid] then
                    local callsign = string.lower(event.text:gsub('^callsign ', ''))
                    foxDataTx[playerInfo.ucid].callsign = callsign
                    text = 'Foxhandler Callsign set to: ' .. callsign
                    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), foxDataTx)
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        elseif string.match(event.text, '^va ') ~= nil then --^ means begins with
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataTx[playerInfo.ucid] then
                    local va = string.lower(event.text:gsub('^va ', ''))
                    if voiceActors[va] then
                        foxDataTx[playerInfo.ucid].va = voiceActors[va].va
                        text = 'Foxhandler VA set to: ' .. voiceActors[va].va
                        TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), foxDataTx)
                    else
                        text = table.concat({'Foxhandler error: The VA you requested was not found. You requested: "', va, '". you can use the "list va" command to get available voice actors'})
                    end
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        elseif event.text == 'list va' then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataTx[playerInfo.ucid] then
                    text = 'available voice actors are: ' .. uniqueVoiceActorsString
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        elseif event.text == 'tx true' or event.text == 'tx on' or event.text == 'tx 1' then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataTx[playerInfo.ucid] then
                    foxDataTx[playerInfo.ucid].tx = true
                    text = 'Foxhandler Transmit: Enabled'
                    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), foxDataTx)
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        elseif event.text == 'tx false' or event.text == 'tx off' or event.text == 'tx 0' then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataTx[playerInfo.ucid] then
                    foxDataTx[playerInfo.ucid].tx = false
                    text = 'Foxhandler Transmit: Disabled'
                    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), foxDataTx)
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        elseif event.text == 'rx true' or event.text == 'rx on' or event.text == 'rx 1' then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataRx[playerInfo.ucid] then
                    foxDataRx[playerInfo.ucid].rx = true
                    text = 'Foxhandler Receive: Enabled'
                    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataRx.lua'}), foxDataRx)
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        elseif event.text == 'rx false' or event.text == 'rx off' or event.text == 'rx 0' then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataRx[playerInfo.ucid] then
                    foxDataRx[playerInfo.ucid].rx = false
                    text = 'Foxhandler Receive: Disabled'
                    if FoxHandlerConfig_RxOptional == false then
                        text = text .. '. Please note that this functionality is disabled by the server config. Your setting has been saved, however is overridden by the server config.'
                    end
                    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataRx.lua'}), foxDataRx)
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        elseif event.text == 'shacksplash true' or event.text == 'shacksplash on' or event.text == 'shacksplash 1' then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataTx[playerInfo.ucid] then
                    foxDataTx[playerInfo.ucid].shackSplash = true
                    text = 'Foxhandler shackSplash: Enabled'
                    if FoxHandlerConfig_ShackSplash == false then
                        text = text .. '. Please note that this functionality is disabled by the server config. Your setting has been saved, however is overridden by the server config.'
                    end
                    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), foxDataTx)
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        elseif event.text == 'shacksplash false' or event.text == 'shacksplash off' or event.text == 'shacksplash 0' then
            local playerName = Unit.getPlayerName(event.initiator)
            if playerName ~= nil then
                local playerInfo = GetPlayerInfo(playerName)
                local text = ''
                if foxDataTx[playerInfo.ucid] then
                    foxDataTx[playerInfo.ucid].shackSplash = false
                    text = 'Foxhandler shackSplash: Disabled'
                    TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), foxDataTx)
                else
                    text = 'Error: Could not find your UCID. Please report this occurance to server staff'
                end
                net.send_chat_to(text, playerInfo.id)
                trigger.action.outTextForUnit(Unit.getID(event.initiator), text, 20)
            end
            trigger.action.removeMark(event.idx)
        end





        if not FileExists(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'})) then
            local playerlist = net.get_player_list()
            local serverSpectatorInfo = net.get_player_info(playerlist[1])
            TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataTx.lua'}), {[serverSpectatorInfo.ucid] = {
                ['name'] = serverSpectatorInfo.name,
                ['va'] = 'chaos',
                ['tx'] = false, --manual disable for turning off all tx comms output from this user
                ['callsign'] = 'watcher',
                ['shackSplash'] = true, --manual disable for turning off shack or splash tx comms output from this user
                ['lastLaunchCalloutTime'] = '0', --time
                ['lastShackSplashCalloutTime'] = '0', --time
                ['lastLaunchType'] = 'typename?', --possible future use for x2 x3 x4 callouts for repeated launches
                ['serverObserver'] = true
            }})
        end
        if not FileExists(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataRx.lua'})) then
            local playerlist = net.get_player_list()
            local serverSpectatorInfo = net.get_player_info(playerlist[1])
            TableSave(table.concat({FilePath, saveDataSubfolder, saveDataPrefix, 'FoxHandler_foxDataRx.lua'}), {[serverSpectatorInfo.ucid] = {
                ['name'] = serverSpectatorInfo.name,
                ['rx'] = false,
                ['side'] = coalition.side.NEUTRAL,
                ['unit'] = 'unit id_ for transmission to be sent to. updated by birth events',
                ['serverObserver'] = true
            }})
        end

    end
end


--fox1
--fox2
--fox3
--magnum
--rifle
--maddog
--bruiser
--duck away
--splash
--shack

world.addEventHandler(foxHandler)
