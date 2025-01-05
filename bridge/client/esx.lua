if GetResourceState('es_extended') ~= 'started' then return end

Config = lib.load('shared')
ESX = exports['es_extended']:getSharedObject()
local PlayerData = {}

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    ESX.PlayerLoaded = true
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    table.wipe(PlayerData)
    ESX.PlayerLoaded = false
    onPlayerUnload()
end)

function hasPlyLoaded()
    return ESX.PlayerLoaded
end

function DoNotification(text, nType)
    lib.notify({ title = "Notification", description = text, type = nType, })
end

function GetPlayerJob()
    return PlayerData.job.name
end

function GetJobGrade()
    return PlayerData.job.grade
end

function GetJobLabel(job)
    return PlayerData.job.label
end

function GetPlyCid()
    return PlayerData.identifier
end

function hasItem(item)
    local count = exports.ox_inventory:Search('count', item)
    return count and count > 0
end

AddEventHandler('esx:setPlayerData', function(key, value)
	PlayerData[key] = value
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
end)

AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() ~= res or not hasPlyLoaded() then return end
    PlayerData = ESX.PlayerData
end)