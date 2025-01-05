return {
    WhitelistJob = 'realestate',
    Percentage = 0.25, -- Players get refunded 25% of the locker's original price when selling back. Don't go higher than 1.0
    CircleRadius = 0.6,
    AllowOutfitMenu = true,
    CreateLockerCommand = 'createnewlocker',
    SphereColor = { 
        94, 176, 242, 80, -- r, g, b, a
    },
    LineColor = {
        94, 176, 242, 80, -- r, g, b, a
    },
    ShowOutfitMenu = function()
        TriggerEvent('qb-clothing:client:openOutfitMenu')
        -- Replace with your clothing menu outfit event/export. The above supports qb-clothing and illenium-appearance.
    end,
}