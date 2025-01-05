local findingSpot = false
local lockerData = {}
local lockerZones = {}
local MY_BLIP

local function getOwnedLockerBlip()
    local cid = GetPlyCid()
    for _, locker in pairs(lockerData) do
        if lib.table.contains(locker.keyholders, cid) then
            return { coords = locker.coords, label = locker.label }
        end
    end
end

local function createBlip(coords, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 50)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.75)
    SetBlipColour(blip, 37)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function refreshBlips()
    if MY_BLIP and DoesBlipExist(MY_BLIP) then
        RemoveBlip(MY_BLIP)
        MY_BLIP = nil
    end

    local blip = getOwnedLockerBlip()
    if blip then
        MY_BLIP = createBlip(blip.coords, blip.label)
    end
end

local function getNearbyServerIds()
    local inputList = {}
    for _, activePlayer in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(activePlayer)
        if #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) < 3.0 then
            local serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
            if serverId ~= cache.serverId then
                inputList[#inputList + 1] = { value = serverId, label = ('[%s]'):format(serverId), }
            end
        end
    end
    return inputList
end

local function viewKeyHolders(holders, name)
    local disp = {}

    for i = 1, #holders do 
        local cid = holders[i]
        local isDisabled = GetPlyCid() == cid
        disp[#disp + 1] = {
            title = cid,
            icon = 'fa-solid fa-user',
            disabled = isDisabled,
            description = isDisabled and locale('this_is_you') or locale('click_revoke'),
            onSelect = function()
                TriggerServerEvent('randol_lockers:server:revokeKeyholder', name, cid)
            end,
        }
    end

    disp[#disp + 1] = {
        title = locale('add_keyholder_title'),
        icon = 'fa-solid fa-plus',
        description = locale('add_holders_desc'),
        onSelect = function()
            local inputList = getNearbyServerIds()
    
            if #inputList == 0 then
                return DoNotification(locale('noone_close'), 'error')
            end
        
            local response = lib.inputDialog(locale('add_keyholder_title'), {
                { type = 'select', label = locale('nearby_plys'), required = true, icon = 'fa-solid fa-user', options = inputList},
            })

            if not response then return end
            TriggerServerEvent('randol_lockers:server:addKeyholder', name, response[1])
        end,
    }

    lib.registerContext({ id = 'view_key_h', title = locale('manage_keyholders'), menu = 'interact_locker', menu = 'view_curr_locker', options = disp })
    lib.showContext('view_key_h')
end

local function createLockers(data)
    lockerData = data
    for k,v in pairs(data) do
        lockerZones[v.name] = exports.ox_target:addSphereZone({
            coords = v.coords,
            radius = Config.CircleRadius,
            debug = Config.Debug,
            options = {
                {
                    icon = 'fa-solid fa-circle',
                    label = locale('view_locker'),
                    onSelect = function()
                        viewCurrentLocker(v.name)
                    end,
                    distance = 1.5,
                },
            },
        })
    end
    refreshBlips()
end

function onPlayerUnload()
    for k in pairs(lockerZones) do
        exports.ox_target:removeZone(lockerZones[k])
    end
    table.wipe(lockerZones)
    table.wipe(lockerData)
    if MY_BLIP and DoesBlipExist(MY_BLIP) then
        RemoveBlip(MY_BLIP)
        MY_BLIP = nil
    end
end

local function rotationToDirection(rotation)
    local adjustedRotation = vec3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
    local direction = vec3(-math.sin(adjustedRotation.z) * math.cos(adjustedRotation.x), math.cos(adjustedRotation.z) * math.cos(adjustedRotation.x), math.sin(adjustedRotation.x))
    return direction
end

local function raycastFromCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = rotationToDirection(cameraRotation)
    local destination = vec3(cameraCoord.x + direction.x * distance, cameraCoord.y + direction.y * distance, cameraCoord.z + direction.z * distance)

    local rayHandle = StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, -1, 1)
    local _, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)

    return hit, endCoords
end

local function findCoords()
    local hasCoords
    local coords
    local heightOffset = 0.0
    findingSpot = true

    lib.showTextUI(locale('instructions'), { position = 'left-center' })

    while findingSpot do
        Wait(0)

        local hit, markerPosition = raycastFromCamera(15.0)
        coords = (hit == 1 and markerPosition) or nil

        if coords then
            local position = GetEntityCoords(cache.ped)
            DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, Config.LineColor[1], Config.LineColor[2], Config.LineColor[3], Config.LineColor[4])
            DrawMarker(28, coords.x, coords.y, coords.z + heightOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.CircleRadius, Config.CircleRadius, Config.CircleRadius, Config.SphereColor[1], Config.SphereColor[2], Config.SphereColor[3], Config.SphereColor[4], false, false, 2, nil, nil, false)
        end

        if IsControlJustReleased(0, 191) and coords then
            hasCoords = vec3(coords.x, coords.y, coords.z + heightOffset)
            findingSpot = false
        elseif IsControlJustReleased(0, 177) then
            findingSpot = false
        elseif IsControlJustReleased(0, 15) then
            heightOffset += 0.1
        elseif IsControlJustReleased(0, 14) then
            heightOffset -= 0.1
        end
    end

    local isOpen, text = lib.isTextUIOpen()
    if isOpen and text == locale('instructions') then
        lib.hideTextUI()
    end
    return hasCoords
end

function viewCurrentLocker(name)
    local lockers = { id = 'view_curr_locker', title = locale('locker_context_title'), options = {} }
    local data = lockerData[name]
    local price = math.ceil(data.price * Config.Percentage)
    local ident = GetPlyCid()
    local job = GetPlayerJob()
    local isHolder = lib.table.contains(data.keyholders, ident)

    if not data.owned then
        lockers.options[#lockers.options + 1] = {
            title = data.label,
            icon = 'fa-solid fa-warehouse',
            description = locale('locker_info'):format(data.price, data.storage, data.slots),
            serverEvent = 'randol_lockers:server:purchaseAttempt',
            args = {label = data.label, name = data.name},
        }
    end

    if data.owned and (data.citizenid == ident or isHolder) then
        lockers.options[#lockers.options + 1] = {
            title = locale('access_storage'),
            icon = 'fa-solid fa-box-open',
            description = ('%s | %s'):format(data.label, data.player),
            onSelect = function()
                exports.ox_inventory:openInventory('stash', data.name)
            end,
        }

        if Config.AllowOutfitMenu then
            lockers.options[#lockers.options + 1] = {
                title = locale('outfit_menu'),
                icon = 'fa-solid fa-shirt',
                onSelect = Config.ShowOutfitMenu,
            }
        end
    end

    if data.owned and data.citizenid == ident then
        lockers.options[#lockers.options + 1] = {
            title = locale('sell_property_title'),
            icon = 'fa-solid fa-wallet',
            description = locale('locker_sell_prop'):format(price),
            event = 'randol_lockers:client:confirmSell',
            args = {label = data.label, name = data.name, refund = price},
        }

        lockers.options[#lockers.options + 1] = {
            title = locale('manage_keyholders'),
            description = locale('manage_holders_desc'),
            icon = 'key',
            arrow = true,
            onSelect = function()
                viewKeyHolders(data.keyholders, data.name)
            end,
        }
    end
    
    if data.owned and data.citizenid ~= ident and not isHolder then
        lockers.options[#lockers.options + 1] = {
            title = data.label,
            icon = 'fa-solid fa-warehouse',
            description = locale('locker_owned'),
            disabled = true,
        }
    end

    if Config.WhitelistJob == job then
        lockers.options[#lockers.options + 1] = {
            title = locale('locker_delete'):format(data.label),
            icon = 'fa-solid fa-xmark',
            onSelect = function()
                local confirmation = lib.alertDialog({
                    header = locale('del_header'),
                    content = locale('del_confirm'),
                    centered = true,
                    cancel = true
                })
                if confirmation == 'confirm' then
                    TriggerServerEvent('randol_lockers:server:removeLocker', data.name)
                end
            end,
        }
    end

    lib.registerContext(lockers)
    lib.showContext('view_curr_locker')
end

AddEventHandler('randol_lockers:client:confirmSell', function(data)
    if not data then return end
    local confirmation = lib.alertDialog({
        header = locale('sell_header'),
        content = locale('sell_confirm'):format(data.refund),
        centered = true,
        cancel = true
    })
    if confirmation == 'confirm' then
        TriggerServerEvent('randol_lockers:server:sellLocker', data)
    end
end)

RegisterNetEvent('randol_lockers:client:createAllLockers', function(data)
    if GetInvokingResource() or not hasPlyLoaded() then return end
    createLockers(data)
end)

RegisterNetEvent('randol_lockers:client:addNewLocker', function(data)
    if GetInvokingResource() or not hasPlyLoaded() then return end
    lockerData[data.name] = data
    lockerZones[data.name] = exports.ox_target:addSphereZone({
        coords = data.coords,
        radius = Config.CircleRadius,
        debug = Config.Debug,
        options = {
            {
                icon = 'fa-solid fa-circle',
                label = locale('view_locker'),
                onSelect = function()
                    viewCurrentLocker(data.name)
                end,
                distance = 1.5,
            },
        },
    })
    refreshBlips()
end)

RegisterNetEvent('randol_lockers:client:lockerRemoved', function(name)
    if GetInvokingResource() or not hasPlyLoaded() then return end
    if lockerData[name] then
        lockerData[name] = nil
    end
    if lockerZones[name] then
        exports.ox_target:removeZone(lockerZones[name])
        lockerZones[name] = nil
    end
    refreshBlips()
end)

RegisterNetEvent('randol_lockers:client:lockerPurchased', function(data)
    if GetInvokingResource() or not hasPlyLoaded() then return end
    if lockerData[data.name] then
        lockerData[data.name] = data
    end
    refreshBlips()
end)

lib.callback.register('randol_lockers:client:confirmation', function(label, name, price)
    local confirmation = lib.alertDialog({
        header = locale('purchase_header'),
        content = locale('purchase_confirm'):format(price),
        centered = true,
        cancel = true
    })

    return confirmation == 'confirm'
end)

RegisterNetEvent('randol_lockers:client:createNew', function()
    if GetInvokingResource() then return end
    local response = lib.inputDialog(locale('create_new_locker'), {
        { type = 'input', label = locale('new_lockername'), placeholder = locale('placeholder1'), description = locale('desc1'), required = true },
        { type = 'input', label = locale('new_lockerlabel'), placeholder = locale('placeholder2'), description = locale('desc2'), required = true},
        { type = 'number', label = locale('new_lockerprice'), description = locale('desc3'), required = true},
        { type = 'number', label = locale('new_storagesize'), description = locale('desc4'), required = true},
        { type = 'number', label = locale('new_numslots'), description = locale('desc5'), required = true},
    })
    if not response then return end
    local data = { lockerName = response[1], lockerLabel = response[2], lockerPrice = response[3], lockerStorage = response[4], lockerSlots = response[5], }
    local hasCoords = findCoords()
    if not hasCoords then return end
    local pos = vec3(hasCoords.x, hasCoords.y, hasCoords.z)
    TriggerServerEvent('randol_lockers:server:createLocker', data, pos)
end)