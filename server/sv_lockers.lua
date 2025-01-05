local storedLockers = {}

local function addSocietyFunds(amount)
    if amount == 0 then return end

    if GetResourceState('Renewed-Banking') == 'started' then
        return exports['Renewed-Banking']:addAccountMoney(Config.WhitelistJob, amount)
    end

    if GetResourceState('qb-banking') == 'started' then
        return exports['qb-banking']:AddMoney(Config.WhitelistJob, amount, 'locker-sold')
    end

    if GetResourceState('esx_society') == 'started' then
        local society = exports.esx_society:GetSociety(Config.WhitelistJob)
        if society then
            return TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account) account.addMoney(amount) end)
        end
    end

    lib.print.error('No society resource found, add it yourself in sv_lockers.lua. Line 4.')
end

local function giveLockerKey(name, cid)
    if name and cid then
        local hasKeys = lib.table.contains(storedLockers[name].keyholders, cid)
        if hasKeys then
            return false, locale('person_has_keys')
        end
        storedLockers[name].keyholders[#storedLockers[name].keyholders + 1] = cid
        return MySQL.prepare.await('UPDATE lockers SET keyholders = ? WHERE name = ?', {json.encode(storedLockers[name].keyholders), name})
    end
end

local function removeLockerKey(name, cid)
    if name and cid then
        for i = 1, #storedLockers[name].keyholders do 
            if cid == storedLockers[name].keyholders[i] then
                table.remove(storedLockers[name].keyholders, i)
                break
            end
        end        
        return MySQL.prepare.await('UPDATE lockers SET keyholders = ? WHERE name = ?', {json.encode(storedLockers[name].keyholders), name})
    end
end

local function cacheDatabase()
    local result = MySQL.query.await('SELECT * from lockers')
    if result and result[1] then
        for _, data in pairs(result) do
            local location = json.decode(data.coords)
            storedLockers[data.name] = {
                citizenid = data.citizenid,
                name = data.name,
                owned = data.owned,
                label = data.label,
                coords = vec3(location.x, location.y, location.z),
                player = data.player,
                price = tonumber(data.price),
                storage = tonumber(data.storage),
                slots = tonumber(data.slots),
                keyholders = json.decode(data.keyholders)
            }

            if data.owned then
                exports.ox_inventory:RegisterStash(data.name, data.label, tonumber(data.slots), tonumber(data.storage) * 1000, nil, nil, vec3(location.x, location.y, location.z))
            end
        end
        SetTimeout(2000, function() -- Need a delay here. This is for cases where the resource gets restarted on a live server.
            TriggerClientEvent('randol_lockers:client:createAllLockers', -1, storedLockers)
        end)
    end
end


local function canOwnLocker(cid)
    for _, v in pairs(storedLockers) do
        if v.citizenid == cid then
            return false
        end
    end
    return true
end

RegisterNetEvent('randol_lockers:server:createLocker', function(data, pos)
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    local job = GetPlayerJob(player)
    
    if Config.WhitelistJob ~= job then return end

    if storedLockers[data.lockerName] then 
        return DoNotification(src, locale('locker_exists'), 'error')
    end
    
    local success = MySQL.insert.await('INSERT INTO lockers (citizenid, name, label, coords, player, price, storage, slots, keyholders) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        '', data.lockerName, data.lockerLabel, json.encode(pos), '', data.lockerPrice, data.lockerStorage, data.lockerSlots, json.encode({})})
    if success then
        local newData = { citizenid = '', name = data.lockerName, owned = false, label = data.lockerLabel, coords = pos, player = '', price = data.lockerPrice, storage = data.lockerStorage, slots = data.lockerSlots, keyholders = {}}
        storedLockers[data.lockerName] = newData
        DoNotification(src, locale('locker_created'):format(data.lockerLabel), 'success')
        TriggerClientEvent('randol_lockers:client:addNewLocker', -1, newData)
    end
end)

RegisterNetEvent('randol_lockers:server:purchaseAttempt', function(data)
    if not data then return end
    local src = source
    local player = GetPlayer(src)

    if not player then return end

    local cid = GetPlyIdentifier(player)
    local result = canOwnLocker(cid)

    if not result then
        return DoNotification(src, locale('already_own_locker'), 'error')
    end

    if not storedLockers[data.name] then return end

    local locker = storedLockers[data.name]

    if locker.owned then
        return DoNotification(src, locale('locker_taken'), 'error')
    end
    
    local bankBalance = GetAccountBalance(player, 'bank')
    local price = tonumber(locker.price)

    if bankBalance < price then
        return DoNotification(src, locale('not_enough_bank'), 'error')
    end

    if locker.label and locker.name and locker.price then
        lib.callback('randol_lockers:client:confirmation', src, function(success)
            if success then
                local plyName = GetCharacterName(player)
                local keyholders = { cid }
                local updatedSQL = MySQL.update.await('UPDATE lockers SET citizenid = ?, owned = ?, player = ?, keyholders = ? WHERE name = ?', {cid, true, plyName, json.encode(keyholders), locker.name})
                if updatedSQL then
                    locker.citizenid = cid
                    locker.owned = true
                    locker.player = plyName
                    locker.keyholders[#locker.keyholders + 1] = cid
                    storedLockers[locker.name] = locker
                    RemoveMoney(player, 'bank', locker.price, 'locker-buy')
                    addSocietyFunds(locker.price)
                    exports.ox_inventory:RegisterStash(locker.name, locker.label, tonumber(locker.slots), tonumber(locker.storage) * 1000, nil, nil, locker.coords)
                    TriggerClientEvent('randol_lockers:client:lockerPurchased', -1, storedLockers[locker.name])
                    DoNotification(src, locale('you_purchased'):format(locker.label, price), 'success')
                end
            end
        end, locker.label, locker.name, locker.price)
    end
end)

RegisterNetEvent('randol_lockers:server:sellLocker', function(data)
    local src = source
    local player = GetPlayer(src)
    local cid = GetPlyIdentifier(player)

    if not player or not storedLockers[data.name] then return end

    local locker = storedLockers[data.name]
    if not locker.owned or locker.citizenid ~= cid then return end

    local price = math.ceil(locker.price * Config.Percentage)
    local plyName = GetCharacterName(player)
    local updatedSQL = MySQL.update.await('UPDATE lockers SET citizenid = ?, owned = ?, player = ?, keyholders = ? WHERE name = ?', {'', false, '', json.encode({}), locker.name})
    if updatedSQL then
        locker.citizenid = ''
        locker.owned = false
        locker.player = ''
        locker.keyholders = {}
        storedLockers[locker.name] = locker
        AddMoney(player, 'bank', price, 'locker-sold')
        DoNotification(src, locale('you_sold'):format(price))
        exports.ox_inventory:ClearInventory(data.name)
        TriggerClientEvent('randol_lockers:client:lockerPurchased', -1, storedLockers[locker.name])
    end
end)

RegisterNetEvent('randol_lockers:server:addKeyholder', function(name, id)
    local src = source
    local player = GetPlayer(src)
    local cid = GetPlyIdentifier(player)

    if not player or not storedLockers[name] then return end

    local locker = storedLockers[name]
    if not locker.owned or locker.citizenid ~= cid then return end

    local target = GetPlayer(id)
    local targetcid = GetPlyIdentifier(target)
    local success, msg = giveLockerKey(name, targetcid)
    if not success then
        return DoNotification(src, msg, 'error')
    end

    TriggerClientEvent('randol_lockers:client:lockerPurchased', src, storedLockers[name])
    TriggerClientEvent('randol_lockers:client:lockerPurchased', id, storedLockers[name])
    DoNotification(src, locale('gave_keys'), 'success')
    DoNotification(id, locale('got_keys'), 'success')
end)

RegisterNetEvent('randol_lockers:server:revokeKeyholder', function(name, targetcid)
    local src = source
    local player = GetPlayer(src)
    local cid = GetPlyIdentifier(player)

    if not player or not storedLockers[name] then return end

    local locker = storedLockers[name]
    if not locker.owned or locker.citizenid ~= cid then return end

    local success = removeLockerKey(name, targetcid)
    if not success then return end

    TriggerClientEvent('randol_lockers:client:lockerPurchased', src, storedLockers[name])
    DoNotification(src, locale('revoked_keys'), 'success')

    local target = GetByIdentifier(targetcid)
    if target then
        local id = GetPlayerSource(target)
        TriggerClientEvent('randol_lockers:client:lockerPurchased', id, storedLockers[name])
        DoNotification(id, locale('keys_revoked'), 'error')
    end
end)

RegisterNetEvent('randol_lockers:server:removeLocker', function(name)
    local src = source
    local player = GetPlayer(src)
    local cid = GetPlyIdentifier(player)
    local job = GetPlayerJob(player)

    if not player or Config.WhitelistJob ~= job or not storedLockers[name] then return end

    local result = MySQL.query.await('DELETE FROM lockers WHERE name = ?', {name})
    if result then
        storedLockers[name] = nil
        exports.ox_inventory:ClearInventory(name)
        DoNotification(src, locale('locker_del_success'):format(name), 'success')
        TriggerClientEvent('randol_lockers:client:lockerRemoved', -1, name)
    end
end)

lib.addCommand(Config.CreateLockerCommand, {
    help = '',
}, function(source)
    local player = GetPlayer(source)
    if not player then return end

    local job = GetPlayerJob(player)
    if Config.WhitelistJob ~= job then return end
    TriggerClientEvent('randol_lockers:client:createNew', source)
end)

function OnPlayerLoaded(src)
    SetTimeout(3000, function()
        if next(storedLockers) then
            TriggerClientEvent('randol_lockers:client:createAllLockers', src, storedLockers)
        end
    end)
end

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
        MySQL.query.await(
            [=[
            CREATE TABLE IF NOT EXISTS lockers (
                id INT(11) NOT NULL AUTO_INCREMENT,
                citizenid VARCHAR(60) DEFAULT NULL,
                name VARCHAR(255) DEFAULT NULL,
                owned BOOLEAN DEFAULT FALSE,
                label VARCHAR(50) DEFAULT NULL,
                coords TEXT DEFAULT NULL,
                player VARCHAR(50) DEFAULT NULL,
                price BIGINT DEFAULT NULL,
                storage BIGINT DEFAULT NULL,
                slots BIGINT DEFAULT NULL,
                keyholders TEXT NULL DEFAULT NULL COLLATE 'utf8mb3_general_ci',
                PRIMARY KEY (id) USING BTREE,
                KEY citizenid (citizenid) USING BTREE
            ) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
            ]=]
        )
        cacheDatabase()
	end
end)