if GetResourceState('qb-core') ~= 'started' then return end

Config = lib.load('shared')

QBCore = exports['qb-core']:GetCoreObject()

function GetPlayer(id)
    return QBCore.Functions.GetPlayer(id)
end

function DoNotification(src, text, nType)
    QBCore.Functions.Notify(src, text, nType)
end

function GetPlyIdentifier(player)
    return player.PlayerData.citizenid
end

function GetByIdentifier(cid)
    return QBCore.Functions.GetPlayerByCitizenId(cid)
end

function GetSourceFromIdentifier(cid)
    local player = QBCore.Functions.GetPlayerByCitizenId(cid)
    return player and player.PlayerData.source or false
end

function GetPlayerSource(player)
    return player.PlayerData.source
end

function GetCharacterName(player)
    return player.PlayerData.charinfo.firstname.. ' ' ..player.PlayerData.charinfo.lastname
end

function GetPlyLicense(player)
    return player.PlayerData.license
end

function GetPlayerJob(player)
    return player.PlayerData.job.name
end

function GetAccountBalance(player, account)
    return player.PlayerData.money[account]
end

function AddMoney(player, acc, amount, reason)
    player.Functions.AddMoney(acc, amount, reason)
end

function RemoveMoney(player, acc, amount, reason)
    player.Functions.RemoveMoney(acc, amount, reason)
end

function hasItem(src, item)
    local count = exports.ox_inventory:Search(src, 'count', item)
    return count and count > 0
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    OnPlayerLoaded(source)
end)