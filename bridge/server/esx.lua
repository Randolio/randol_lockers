if GetResourceState('es_extended') ~= 'started' then return end

Config = lib.load('shared')

ESX = exports['es_extended']:getSharedObject()

function GetPlayer(id)
    return ESX.GetPlayerFromId(id)
end

function DoNotification(src, text, nType)
    TriggerClientEvent('ox_lib:notify', src, { type = nType, description = text })
end

function GetPlyIdentifier(player)
    return player.identifier
end

function GetByIdentifier(cid)
    return ESX.GetPlayerFromIdentifier(cid)
end

function GetSourceFromIdentifier(cid)
    local player = ESX.GetPlayerFromIdentifier(cid)
    return player and player.source or false
end

function GetPlayerSource(player)
    return player.source
end

function GetCharacterName(player)
    return player.getName()
end

function GetPlyLicense(player)
    return ('license:%s'):format(ESX.GetIdentifier(player.source))
end

function GetPlayerJob(player)
    return player.job.name
end

function GetAccountBalance(player, account)
    return player.getAccount(account).money
end

function AddMoney(player, moneyType, amount)
    local account = moneyType == 'cash' and 'money' or moneyType
    player.addAccountMoney(account, amount)
end

function RemoveMoney(player, acc, amount)
    player.removeAccountMoney(acc, amount)
end

function hasItem(src, item)
    local count = exports.ox_inventory:Search(src, 'count', item)
    return count and count > 0
end

AddEventHandler('esx:playerLoaded', function(playerId, player)
    OnPlayerLoaded(playerId)
end)