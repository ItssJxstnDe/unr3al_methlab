lib.callback.register('unr3al_methlab:server:isLabOwned', function(source, methlabId)
    local returnval = 0
    local response = MySQL.single.await('SELECT `owned` FROM `unr3al_methlab` WHERE `id` = ?', {methlabId})
    if response then
        if response.owned == 1 then
            returnval = 1
        end
    end
    return returnval
end)

lib.callback.register('unr3al_methlab:server:buyLab', function(source, methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
    local xPlayer = player(src)
	if not DoesEntityExist(entity) or currentlab[src] ~= nil then return end
    
    local canBuy = true
    local missingItems = {}
    for itenName, itemCount in pairs(Config.Methlabs[methlabId].Purchase.Price) do
        local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
        if item < itemCount then
            canBuy = false
            table.insert(missingItems, {itenName, itemCount - item})
        end
    end
    if canBuy then
        local owner, owner2 = nil, nil
        if Config.Framework == 'ESX' then
            owner = xPlayer.getJob().name
            owner2 = xPlayer.getIdentifier()
        elseif Config.Framework == 'qb' then
            owner = xPlayer.PlayerData.job.name
            owner2 = xPlayer.Functions.GetIdentifier
        end
        local response = MySQL.query.await('SELECT COUNT(id) FROM unr3al_methlab WHERE owner = ? OR owner = ?', {owner, owner2})
        if response[1]["COUNT(id)"] < Config.MaxLabs then
            for itemName, itemCount in pairs(Config.Methlabs[methlabId].Purchase.Price) do
                exports.ox_inventory:RemoveItem(src, itemName, itemCount, false, false, true)
            end
            local newOwner
            if Config.Methlabs[methlabId].Purchase.Type == 'society' then
                if Config.Framework == 'ESX' then
                    newOwner = xPlayer.getJob().name
                elseif Config.Framework == 'qb' then
                    newOwner = xPlayer.PlayerData.job.name
                end
            elseif Config.Methlabs[methlabId].Purchase.Type == 'player' then
                if Config.Framework == 'ESX' then
                    newOwner = xPlayer.getIdentifier()
                elseif Config.Framework == 'qb' then
                    newOwner = xPlayer.Functions.GetIdentifier
                end
            end
            local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET owned = 1, locked = 0, owner = ? WHERE id = ?', {
                newOwner, methlabId
            })
            if updateOwner == 1 then
                Config.Notification(src, Config.Noti.success, Locales[Config.Locale]['BoughtLab'])
                TriggerEvent('unr3al_methlab:server:enter', methlabId, netId, src)
            end
        else
            Config.Notification(src, Config.Noti.error, Locales[Config.Locale]['ToMuchLabsBought'])
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

lib.callback.register('unr3al_methlab:server:canBuyAnotherLab', function(source)
    local src = source
    local xPlayer = player(src)
    local owner, owner2 = nil, nil
    if Config.Framework == 'ESX' then
        owner = xPlayer.getJob().name
        owner2 = xPlayer.getIdentifier()
    elseif Config.Framework == 'qb' then
        owner = xPlayer.PlayerData.job.name
        owner2 = xPlayer.Functions.GetIdentifier
    end
    local response = MySQL.query.await('SELECT COUNT(id) FROM unr3al_methlab WHERE owner = ? OR owner = ?', {owner, owner2})
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

lib.callback.register('unr3al_methlab:server:getConfig', function(source)
    return Config
end)