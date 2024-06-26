currentlab = {}
player = nil

if Config.Framework == 'ESX' then
    ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
end

function player(src)
    if Config.Framework == 'ESX' then
        return ESX.GetPlayerFromId(src)
    elseif Config.Framework == 'qb' then
        return QBCore.Functions.GetPlayer(src)
    end
end
function getPlayerName(src)
    if Config.Framework == 'ESX' then
        return ESX.GetPlayerFromId(src).getName()
    elseif Config.Framework == 'qb' then
        return QBCore.Functions.GetPlayer(src).PlayerData.name
    end
    
end

--Finished
RegisterNetEvent('unr3al_methlab:server:enter', function(methlabId, netId, source)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] ~= nil then
        Unr3al.Logging('info', 'Player '..getPlayerName(src)..' tried to enter Lab'..methlabId..' without perms')
        return
    end
    local response = MySQL.single.await('SELECT locked FROM unr3al_methlab WHERE id = ?', {methlabId})
    if response.locked == 0 then
        SetPlayerRoutingBucket(src, methlabId)
        SetEntityCoords(entity, 997.24, -3200.67, -36.39, true, false, false, false)
        currentlab[src] = methlabId
    else
        Config.Notification(src, Config.Noti.error, Locales[Config.Locale]['LabLocked'])
    end
end)

--Finished
RegisterNetEvent('unr3al_methlab:server:leave', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then
        Unr3al.Logging('info', 'Player '..getPlayerName(src)..' tried to leave Lab'..methlabId..' without perms')
        return
    end
    SetPlayerRoutingBucket(src, 0)
    local coords = Config.Methlabs[currentlab[src]].Coords
    SetEntityCoords(entity, coords.x, coords.y, coords.z, true, false, false, false)
    currentlab[src] = nil
end)

--Finished
RegisterNetEvent('unr3al_methlab:server:openStorage', function(netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then
        Unr3al.Logging('info', 'Player '..getPlayerName(src)..' tried to open storage without perms')
        return
    end
    exports.ox_inventory:forceOpenInventory(src, 'stash', 'Methlab_Storage_'..currentlab[src])
end)

--Finished
RegisterNetEvent('unr3al_methlab:server:upgradeStorage', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then
        Unr3al.Logging('info', 'Player '..getPlayerName(src)..' tried to upgrade storage of Lab '..methlabId..' without perms')
        return
    end

    local storageLevel = MySQL.single.await('SELECT `storage` FROM `unr3al_methlab` WHERE `id` = ?', {methlabId}).storage
    if storageLevel == #Config.Upgrades.Storage then return end
    local canBuy = true
    local missingItems = {}
    for itenName, itemCount in pairs(Config.Upgrades.Storage[storageLevel+1].Price) do
        local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
        if item < itemCount then
            canBuy = false
            table.insert(missingItems, {itenName, itemCount - item})
        end
    end
    if canBuy then
        for itemName, itemCount in pairs(Config.Upgrades.Storage[storageLevel+1].Price) do
            exports.ox_inventory:RemoveItem(src, itemName, itemCount, false, false, true)
        end
        local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET storage = ? WHERE id = ?', {
            storageLevel+1, methlabId
        })
        if updateOwner == 1 then
            exports.ox_inventory:RegisterStash('Methlab_Storage_'..methlabId, 'Methlab storage', Config.Upgrades.Storage[storageLevel+1].Slots, Config.Upgrades.Storage[storageLevel+1].MaxWeight, false)
            Config.Notification(src, Config.Noti.success, Locales[Config.Locale]['UpgradedStorage'])
        end
    else
        local itemarray = {}
        for i, item in ipairs(missingItems) do
            local itemData = exports.ox_inventory:GetItem(src, item[1], nil, false).label
            local itemString = string.format("%sx %s", item[2], itemData)
            table.insert(itemarray, itemString)
        end
        local joinedItems = table.concat(itemarray, ", ")
        local notification = Locales[Config.Locale]['MissingResources']..joinedItems
        Config.Notification(src, Config.Noti.error, notification)
    end
end)

--Finished, only needs raid integration
RegisterNetEvent('unr3al_methlab:server:upgradeSecurity', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then
        Unr3al.Logging('info', 'Player '..getPlayerName(src)..' tried to upgrade security of Lab '..methlabId..' without perms')
        return
    end

    local securityLevel = MySQL.single.await('SELECT `security` FROM `unr3al_methlab` WHERE `id` = ?', {methlabId}).security
    if securityLevel == #Config.Upgrades.Security then return end

    local canBuy = true
    local missingItems = {}
    for itenName, itemCount in pairs(Config.Upgrades.Security[securityLevel+1].Price) do
        local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
        if item < itemCount then
            canBuy = false
            table.insert(missingItems, {itenName, itemCount - item})
        end
    end

    if canBuy then
        for itemName, itemCount in pairs(Config.Upgrades.Security[securityLevel+1].Price) do
            exports.ox_inventory:RemoveItem(src, itemName, itemCount, false, false, true)
        end
        local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET security = ? WHERE id = ?', {
            securityLevel+1, methlabId
        })
        if updateOwner == 1 then
            Config.Notification(src, Config.Noti.success, Locales[Config.Locale]['UpgradedSecurity'])
        end
    else
        local itemarray = {}
        for i, item in ipairs(missingItems) do
            local itemData = exports.ox_inventory:GetItem(src, item[1], nil, false).label
            local itemString = string.format("%sx %s", item[2], itemData)
            table.insert(itemarray, itemString)
        end
        local joinedItems = table.concat(itemarray, ", ")
        local notification = Locales[Config.Locale]['MissingResources']..joinedItems
        Config.Notification(src, Config.Noti.error, notification)
    end
end)

--Finished
RegisterNetEvent('unr3al_methlab:server:locklab', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
    local xPlayer = player(src)
    if not DoesEntityExist(entity) then
        Unr3al.Logging('info', 'Player '..getPlayerName(src)..' tried to lock Lab'..methlabId..' without perms')
        return
    end
    local labId = methlabId
    if currentlab[src] ~= nil then
        labId = currentlab[src]
    end
    local isOwner = MySQL.single.await('SELECT owner FROM unr3al_methlab WHERE id = ?', {methlabId}).owner
    local possibleOwner, possibleOwner2 = nil, nil
    if Config.Framework == 'ESX' then
        possibleOwner = xPlayer.getJob().name
        possibleOwner2 = xPlayer.getIdentifier()
    elseif Config.Framework == 'qb' then
        possibleOwner = xPlayer.PlayerData.job.name
        possibleOwner2 = xPlayer.Functions.GetIdentifier
    end


    if isOwner == possibleOwner or isOwner == possibleOwner2 then
        local response = MySQL.single.await('SELECT locked FROM unr3al_methlab WHERE id = ?', {methlabId}).locked
        local newlocked = 1
        if response == 1 then
            newlocked = 0
            Config.Notification(src, Config.Noti.success, Locales[Config.Locale]['UnlockedLab'])

        else
            Config.Notification(src, Config.Noti.success, Locales[Config.Locale]['LockedLab'])
        end
        local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET locked = ? WHERE id = ?', {
            newlocked, labId
        })
    else
        Config.Notification(src, Config.Noti.error, Locales[Config.Locale]['CantLockLab'])

    end
end)

if Config.Framework == 'ESX' then
    --Finished
    AddEventHandler('esx:playerLoaded',function(source, xPlayer, isNew)
        local src = source
        if xPlayer and not isNew then
            local response = MySQL.single.await('SELECT id FROM unr3al_methlab_people WHERE identifier = @identifier', {
                ['@identifier'] = xPlayer.identifier
            })
            if response ~= nil then
                currentlab[src] = response.id
                MySQL.query.await('DELETE FROM unr3al_methlab_people WHERE identifier = @identifier', {
                    ['@identifier'] = xPlayer.identifier
                })
            end
        end
    end)

    --Finished
    RegisterNetEvent('esx:playerDropped', function(playerId, reason)
        local src = playerId
        local xPlayer = player(src)
        if currentlab[src] ~= nil then
            local lab = currentlab[src]
            local id = MySQL.insert.await('INSERT INTO unr3al_methlab_people (id, identifier) VALUES (?, ?)', {
                currentlab[src], xPlayer.identifier,
            })
            currentlab[src] = nil
        end
    end)
end


--Finished
RegisterNetEvent('unr3al_methlab:server:startprod', function(netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end
    local lab = currentlab[src]
    local recipe = Config.Methlabs[lab].Recipes
    local input = lib.callback.await('unr3al_methlab:client:getMethType', src, netId, recipe)
    if not input then return end
    if Config.Recipes[recipe][input] ~= nil then
        local canBuy = true
        local missingItems = {}
        for itenName, itemCount in pairs(Config.Recipes[recipe][input].Ingredients) do
            local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
            if item < itemCount then
                canBuy = false
                table.insert(missingItems, {itenName, itemCount - item})
            end
        end
        if canBuy then
            for itemName, itemCount in pairs(Config.Recipes[recipe][input].Ingredients) do
                exports.ox_inventory:RemoveItem(src, itemName, itemCount, false, false, true)
            end
            local animationComplete = lib.callback.await('unr3al_methlab:client:startAnimation', src, netId)
            if animationComplete then
                local count = math.random(Config.Recipes[recipe][input].Meth.Chance.Min, Config.Recipes[recipe][input].Meth.Chance.Max)
                exports.ox_inventory:AddItem(src, Config.Recipes[recipe][input].Meth.ItemName, count)
            else
                Config.Notification(src, Config.Noti.error, Locales[Config.Locale]['CanceledProduction'])

            end
        else
            local itemarray = {}
            for i, item in ipairs(missingItems) do
                local itemData = exports.ox_inventory:GetItem(src, item[1], nil, false).label
                local itemString = string.format("%sx %s", item[2], itemData)
                table.insert(itemarray, itemString)
            end
            local joinedItems = table.concat(itemarray, ", ")
            local notification = Locales[Config.Locale]['MissingResources']..joinedItems
            Config.Notification(src, Config.Noti.error, notification)
        end
    end
end)

RegisterNetEvent('unr3al_methlab:server:startSlurryRefinery', function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end

    local recipe = Config.Methlabs[currentlab[src]].Recipes
    local input = lib.callback.await('unr3al_methlab:client:getSlurryType', src, netId, recipe)
    if not input then return end
    local canBuy = true
    local missingItems = {}
    for itenName, itemCount in pairs(Config.Refinery[recipe][input].Ingredients) do
        local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
        if item < itemCount then
            canBuy = false
            table.insert(missingItems, {itenName, itemCount - item})
        end
    end
    if canBuy then
        for itenName, itemCount in pairs(Config.Refinery[recipe][input].Ingredients) do
            exports.ox_inventory:RemoveItem(src, itenName, itemCount, false, false, true)
        end
        local animationComplete = lib.callback.await('unr3al_methlab:client:startSlurryAnima', src, netId)
        if animationComplete then
            local count = math.random(Config.Refinery[recipe][input].Output.Chance.Min, Config.Refinery[recipe][input].Output.Chance.Max)
            exports.ox_inventory:AddItem(src, Config.Refinery[recipe][input].Output.ItemName, count)
        else
            Config.Notification(src, Config.Noti.error, Locales[Config.Locale]['CanceledProduction'])
        end
    else
        local itemarray = {}
        for i, item in ipairs(missingItems) do
            local itemData = exports.ox_inventory:GetItem(src, item[1], nil, false).label
            local itemString = string.format("%sx %s", item[2], itemData)
            table.insert(itemarray, itemString)
        end
        local joinedItems = table.concat(itemarray, ", ")
        local notification = Locales[Config.Locale]['MissingResources']..joinedItems
        Config.Notification(src, Config.Noti.error, notification)
    end
end)





if Config.Debug then
    RegisterCommand("setlab", function(source, args)
        local src = source
        currentlab[src] = 1
    end, true)
end

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() == resourceName) then
        local mainTableBuild = MySQL.query.await([[CREATE TABLE IF NOT EXISTS unr3al_methlab (
        `id` int(11) NOT NULL,
        `owned` int(11) NOT NULL DEFAULT 0,
        `owner` varchar(46) DEFAULT NULL,
        `locked` int(11) DEFAULT 1,
        `storage` int(11) NOT NULL DEFAULT 1,
        `security` int(11) NOT NULL DEFAULT 1
        )]])
        if mainTableBuild.warningStatus == 0 then
            Unr3al.Logging('info', 'Database Build for Lab table complete')
        else if mainTableBuild.warningStatus ~= 1 then
            Unr3al.Logging('error', 'Couldnt build Lab table')
        end end
        local response = MySQL.query.await('SELECT * FROM unr3al_methlab')
        for i, methlabId in ipairs(Config.Methlabs) do
            if not response[i] then
                local id = MySQL.insert.await('INSERT INTO unr3al_methlab (id) VALUES (?)', {
                    i
                })
                if id then
                    Unr3al.Logging('debug', 'Inserted data for lab '..i..' into Database')
                else
                    Unr3al.Logging('error', 'Couldnt insert data. Lab: '..i)
                end
            end
            local inventory = exports.ox_inventory:GetInventory('Methlab_Storage_'..i, false)
            if not inventory then
                local methLab = MySQL.single.await('SELECT storage FROM unr3al_methlab WHERE id = ?', {i})
                exports.ox_inventory:RegisterStash('Methlab_Storage_'..i, 'Methlab storage', Config.Upgrades.Storage[methLab.storage].Slots, Config.Upgrades.Storage[methLab.storage].MaxWeight, false)
                Unr3al.Logging('debug', 'Registered stash for lab:'..i)
            end
        end
        local secondaryTableBuild = MySQL.query.await([[CREATE TABLE IF NOT EXISTS unr3al_methlab_people (
        `id` int(11) NOT NULL,
        `identifier` varchar(46) DEFAULT NULL
        )]])
        if secondaryTableBuild.warningStatus == 0 then
            Unr3al.Logging('info', 'Database Build for secondary table complete')
        else if secondaryTableBuild.warningStatus ~= 1 then
            Unr3al.Logging('error', 'Couldnt build secondary table')
        end end
    end
end)