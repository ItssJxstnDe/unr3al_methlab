local currentlab = {}

--Finished
RegisterNetEvent('unr3al_methlab:server:enter', function(methlabId, netId, source)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
	if not DoesEntityExist(entity) then print("noentity") return end

    local response = MySQL.single.await('SELECT locked FROM unr3al_methlab WHERE id = ?', {methlabId}).locked
    if response == 0 then
        SetPlayerRoutingBucket(src, methlabId)
        xPlayer.setCoords(vector3(997.24, -3200.67, -36.39))
        print("set entity coords")
        currentlab[src] = methlabId
    else
        TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.error, Strings.LabLocked)
    end
end)

--Finished
RegisterNetEvent('unr3al_methlab:server:leave', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
	if not DoesEntityExist(entity) then return end
    SetPlayerRoutingBucket(src, 0)
    local coords = Config.Methlabs[currentlab[src]].Coords
    xPlayer.setCoords(vector3(coords.x, coords.y, coords.z))
    currentlab[src] = nil
end)

--Finished
RegisterNetEvent('unr3al_methlab:server:openStorage', function(netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end
    exports.ox_inventory:forceOpenInventory(src, 'stash', 'Methlab_Storage_'..currentlab[src])
end)

RegisterNetEvent('unr3al_methlab:server:upgradeStorage', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end

    local storageLevel = MySQL.single.await('SELECT `storage` FROM `unr3al_methlab` WHERE `id` = ?', {methlabId}).storage
    if storageLevel == #Config.Upgrades.Storage then return end
    local canBuy = true
    for itenName, itemCount in pairs(Config.Upgrades.Storage[storageLevel+1].Price) do
        if canBuy then
            local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
            if item < itemCount then
                canBuy = false
            end
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
            TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.UpgradedStorage)
        end
    else
        return
    end
end)

RegisterNetEvent('unr3al_methlab:server:upgradeSecurity', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end

    local securityLevel = MySQL.single.await('SELECT `security` FROM `unr3al_methlab` WHERE `id` = ?', {methlabId}).security
    if securityLevel == #Config.Upgrades.Security then return end
    local canBuy = true
    for itenName, itemCount in pairs(Config.Upgrades.Security[securityLevel+1].Price) do
        if canBuy then
            local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
            if item < itemCount then
                canBuy = false
            end
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
            TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.UpgradedSecurity)
        end



    else
        return
    end
end)

RegisterNetEvent('unr3al_methlab:server:locklab', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) then return end
    local labId = methlabId
    if currentlab[src] ~= nil then
        labId = currentlab[src]
    end
    local response = MySQL.single.await('SELECT locked FROM unr3al_methlab WHERE id = ?', {methlabId}).locked
    local newlocked = 1
    if response == 1 then
        newlocked = 0
        TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.UnlockedLab)
    else
        TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.LockedLab)
    end
    print(response)
    local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET locked = ? WHERE id = ?', {
        newlocked, labId
    })


end)





lib.callback.register('unr3al_methlab:server:isLabOwned', function(source, methlabId)

--     CREATE TABLE IF NOT EXISTS `unr3al_methlab` (
--   `id` INT NOT NULL AUTO_INCREMENT,
--   `owned` INT NOT NULL DEFAULT 0,
--   `owner` VARCHAR(45) NULL,
--   `locked` INT NULL DEFAULT 1,
--   `storage` INT NOT NULL DEFAULT 1,
--   `security` INT NOT NULL DEFAULT 1,
--   PRIMARY KEY (`id`))


    print("currentlab: "..methlabId)
    local returnval = 0
    local response = MySQL.single.await('SELECT `owned` FROM `unr3al_methlab` WHERE `id` = ?', {methlabId})
    if response then
        if response.owned == 1 then
            returnval = 1
        end
        print("Owned: "..response.owned)
    end
    return returnval
end)

lib.callback.register('unr3al_methlab:server:buyLab', function(source, methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] ~= nil then return end
    
    local canBuy = true
    for itenName, itemCount in pairs(Config.Methlabs[methlabId].Purchase.Price) do
        if canBuy then
            local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
            if item < itemCount then
                canBuy = false
            end
        end
    end
    local owner = ESX.GetPlayerFromId(src).getJob().name
    local owner2 = ESX.GetPlayerFromId(src).getIdentifier()
    local response = MySQL.query.await('SELECT COUNT(id) FROM unr3al_methlab WHERE owner = ? OR owner = ?', {owner, owner2})
    print(response[1]["COUNT(id)"])
    if response[1]["COUNT(id)"] < Config.MaxLabs and canBuy then
        for itemName, itemCount in pairs(Config.Methlabs[methlabId].Purchase.Price) do
            exports.ox_inventory:RemoveItem(src, itemName, itemCount, false, false, true)
        end
        local newOwner
        if Config.Methlabs[methlabId].Purchase.Type == 'society' then
            newOwner = ESX.GetPlayerFromId(src).getJob().name
        else
            newOwner = ESX.GetPlayerFromId(src).getIdentifier()
        end
        local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET owned = 1, locked = 0, owner = ? WHERE id = ?', {
            newOwner, methlabId
        })
        if updateOwner == 1 then
            TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.BoughtLab)
            TriggerEvent('unr3al_methlab:server:enter', methlabId, netId, src)
        end
    else
        TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.error, Strings.CantBuy)
    end
end)

lib.callback.register('unr3al_methlab:server:canBuyAnotherLab', function(source)
    local src = source
    local owner = ESX.GetPlayerFromId(src).getJob().name
    local owner2 = ESX.GetPlayerFromId(src).getIdentifier()
    local response = MySQL.query.await('SELECT COUNT(id) FROM unr3al_methlab WHERE owner = ? OR owner = ?', {owner, owner2})
    print(response[1]["COUNT(id)"])
    if response[1]["COUNT(id)"] < Config.MaxLabs then
        return true
    else
        return false
    end
end)

lib.callback.register('unr3al_methlab:server:getStorage', function(source, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end
    return MySQL.single.await('SELECT `storage` FROM `unr3al_methlab` WHERE `id` = ?', {currentlab[src]}).storage
end)

lib.callback.register('unr3al_methlab:server:getSecurity', function(source, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end
    return MySQL.single.await('SELECT `security` FROM `unr3al_methlab` WHERE `id` = ?', {currentlab[src]}).security
end)








RegisterCommand("setlab", function(source, args)
    local src = source
    currentlab[src] = args[1] or 1
end, true)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() == resourceName) then
        local response = MySQL.query.await('SELECT * FROM unr3al_methlab')
        for methlabId in pairs(Config.Methlabs) do
            if not response[methlabId] then
                local id = MySQL.insert.await('INSERT INTO unr3al_methlab (id) VALUES (?)', {
                    methlabId
                })
            end
        end
        
        for methlabId in pairs(Config.Methlabs) do

            local inventory = exports.ox_inventory:GetInventory('Methlab_Storage_'..methlabId, false)
            if not inventory then

                local methLab = MySQL.single.await('SELECT storage FROM unr3al_methlab WHERE id = ?', {methlabId})
                exports.ox_inventory:RegisterStash('Methlab_Storage_'..methlabId, 'Methlab storage', Config.Upgrades.Storage[methLab.storage].Slots, Config.Upgrades.Storage[methLab.storage].MaxWeight, false)
                print("Registered stash for lab:"..methlabId)
            else
                print("Already registered stash")
            end
        end
    end
end)