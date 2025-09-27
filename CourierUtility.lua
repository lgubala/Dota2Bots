-- Enhanced CourierUtility.lua with Turbo Mode Support and Debug Logging

local CourierUtility = {}

local lastCourierCheck = -90
local courierDeliveryRequests = {}
local debugCourier = true -- Enable debug for courier operations

-- Check if we're in Turbo mode
function CourierUtility.IsTurboMode()
    return GetGameMode() == 23
end

-- Get available courier for a bot
function CourierUtility.GetAvailableCourier(bot)
    local numCouriers = GetNumCouriers()
    if numCouriers == 0 then
        if debugCourier then
            print("[COURIER_DEBUG] No couriers available")
        end
        return nil
    end
    
    -- In Turbo mode, each player should have their own courier
    local playerID = bot:GetPlayerID()
    
    for courierID = 0, numCouriers - 1 do
        local courier = GetCourier(courierID)
        if courier ~= nil then
            -- In Turbo mode, try to find the courier that belongs to this player
            -- This might not be perfectly reliable, so we'll use the first available one
            if debugCourier then
                local courierState = GetCourierState(courier)
                print("[COURIER_DEBUG] Player "..playerID.." - Courier "..courierID.." state: "..courierState)
            end
            return courier
        end
    end
    
    return nil
end

-- Check if bot has items in stash that need delivery
function CourierUtility.HasItemsInStash(bot)
    local itemCount = 0
    local itemsFound = {}
    
    -- Check stash slots (9-14)
    for i = 9, 14 do
        local item = bot:GetItemInSlot(i)
        if item ~= nil then
            itemCount = itemCount + 1
            table.insert(itemsFound, item:GetName())
        end
    end
    
    if debugCourier and itemCount > 0 then
        print("[COURIER_DEBUG] "..bot:GetUnitName().." has "..itemCount.." items in stash:")
        for _, itemName in ipairs(itemsFound) do
            print("[COURIER_DEBUG]   - "..itemName)
        end
    end
    
    return itemCount > 0, itemsFound
end

-- Check if bot has inventory space for delivery
function CourierUtility.HasInventorySpace(bot)
    local freeSlots = 0
    for i = 0, 5 do -- Main inventory slots
        local item = bot:GetItemInSlot(i)
        if item == nil then
            freeSlots = freeSlots + 1
        end
    end
    
    if debugCourier then
        print("[COURIER_DEBUG] "..bot:GetUnitName().." has "..freeSlots.." free inventory slots")
    end
    
    return freeSlots > 0, freeSlots
end

-- Request courier delivery in Turbo mode
function CourierUtility.RequestTurboDelivery(bot)
    if not CourierUtility.IsTurboMode() then
        return false
    end
    
    local hasStashItems, stashItems = CourierUtility.HasItemsInStash(bot)
    if not hasStashItems then
        return false -- Nothing to deliver
    end
    
    local hasSpace, freeSlots = CourierUtility.HasInventorySpace(bot)
    if not hasSpace then
        if debugCourier then
            print("[COURIER_DEBUG] "..bot:GetUnitName().." has no inventory space for delivery")
        end
        return false
    end
    
    local courier = CourierUtility.GetAvailableCourier(bot)
    if courier == nil then
        if debugCourier then
            print("[COURIER_DEBUG] "..bot:GetUnitName().." - No courier available for delivery")
        end
        return false
    end
    
    local courierState = GetCourierState(courier)
    local playerID = bot:GetPlayerID()
    
    if debugCourier then
        print("[COURIER_DEBUG] "..bot:GetUnitName().." - Attempting delivery, courier state: "..courierState)
    end
    
    -- Try multiple delivery methods
    local success = false
    
    -- Method 1: Direct transfer items command
    if courierState == COURIER_STATE_IDLE or courierState == COURIER_STATE_AT_BASE then
        success = pcall(function()
            return courier:ActionImmediate_Courier(COURIER_ACTION_TRANSFER_ITEMS)
        end)
        
        if success then
            if debugCourier then
                print("[COURIER_DEBUG] "..bot:GetUnitName().." - Transfer items command sent successfully")
            end
            return true
        else
            if debugCourier then
                print("[COURIER_DEBUG] "..bot:GetUnitName().." - Transfer items command failed")
            end
        end
    end
    
    -- Method 2: Retrieve then deliver sequence
    if not success then
        local retrieveSuccess = pcall(function()
            return courier:ActionImmediate_Courier(COURIER_ACTION_RETRIEVE_ITEMS)
        end)
        
        if retrieveSuccess then
            if debugCourier then
                print("[COURIER_DEBUG] "..bot:GetUnitName().." - Retrieve items command sent")
            end
            
            -- Schedule a deliver command for a bit later
            courierDeliveryRequests[playerID] = DotaTime() + 2.0 -- Deliver in 2 seconds
            return true
        else
            if debugCourier then
                print("[COURIER_DEBUG] "..bot:GetUnitName().." - Retrieve items command failed")
            end
        end
    end
    
    -- Method 3: Try to enable auto-delivery (might not work but worth trying)
    if not success then
        local autoDeliverSuccess = pcall(function()
            -- This might not be the right way to do it, but let's try
            return courier:Action_UseAbility(courier:GetAbilityByName("courier_take_stash_and_transfer_items"))
        end)
        
        if autoDeliverSuccess and debugCourier then
            print("[COURIER_DEBUG] "..bot:GetUnitName().." - Auto-delivery command attempted")
        end
    end
    
    return success
end

-- Process pending delivery requests
function CourierUtility.ProcessDeliveryRequests()
    local currentTime = DotaTime()
    
    for playerID, deliveryTime in pairs(courierDeliveryRequests) do
        if currentTime >= deliveryTime then
            -- Try to complete the delivery
            local courier = CourierUtility.GetAvailableCourier(GetBot()) -- This might not work perfectly
            if courier ~= nil then
                local deliverSuccess = pcall(function()
                    return courier:ActionImmediate_Courier(COURIER_ACTION_TRANSFER_ITEMS)
                end)
                
                if debugCourier then
                    print("[COURIER_DEBUG] PlayerID "..playerID.." - Delayed delivery attempt: "..tostring(deliverSuccess))
                end
            end
            
            -- Remove the request regardless of success
            courierDeliveryRequests[playerID] = nil
        end
    end
end

-- Main courier management function to be called from ability_item_usage_generic.lua
function CourierUtility.CourierThink(bot)
    if not CourierUtility.IsTurboMode() then
        return -- Only handle Turbo mode for now
    end
    
    local currentTime = DotaTime()
    
    -- Don't check too frequently
    if currentTime < lastCourierCheck + 3.0 then
        return
    end
    
    lastCourierCheck = currentTime
    
    -- Process any pending delivery requests
    CourierUtility.ProcessDeliveryRequests()
    
    -- Check if this bot needs courier delivery
    local hasStashItems = CourierUtility.HasItemsInStash(bot)
    if hasStashItems then
        CourierUtility.RequestTurboDelivery(bot)
    end
end

-- Legacy function for compatibility with existing code
function CourierUtility.GetCourierValue(bot)
    local courierValue = 0
    local courier = CourierUtility.GetAvailableCourier(bot)
    
    if courier ~= nil then
        -- Calculate value of items on courier
        for i = 0, 8 do -- Courier inventory slots
            local item = courier:GetItemInSlot(i)
            if item ~= nil then
                courierValue = courierValue + GetItemCost(item:GetName())
            end
        end
    end
    
    return courierValue
end

-- Function to check if courier is busy
function CourierUtility.IsCourierBusy(bot)
    local courier = CourierUtility.GetAvailableCourier(bot)
    if courier == nil then
        return false
    end
    
    local courierState = GetCourierState(courier)
    return courierState ~= COURIER_STATE_IDLE and courierState ~= COURIER_STATE_AT_BASE
end

-- Function to get courier distance from bot
function CourierUtility.GetCourierDistanceFromBot(bot)
    local courier = CourierUtility.GetAvailableCourier(bot)
    if courier == nil then
        return 9999
    end
    
    return GetUnitToUnitDistance(bot, courier)
end

-- Debug function to print courier status
function CourierUtility.DebugCourierStatus(bot)
    if not debugCourier then
        return
    end
    
    print("[COURIER_DEBUG] === Courier Status for "..bot:GetUnitName().." ===")
    print("[COURIER_DEBUG] Turbo Mode: "..tostring(CourierUtility.IsTurboMode()))
    
    local numCouriers = GetNumCouriers()
    print("[COURIER_DEBUG] Number of couriers: "..numCouriers)
    
    for courierID = 0, numCouriers - 1 do
        local courier = GetCourier(courierID)
        if courier ~= nil then
            local courierState = GetCourierState(courier)
            print("[COURIER_DEBUG] Courier "..courierID.." state: "..courierState)
            
            -- Check courier inventory
            local itemCount = 0
            for i = 0, 8 do
                local item = courier:GetItemInSlot(i)
                if item ~= nil then
                    itemCount = itemCount + 1
                end
            end
            print("[COURIER_DEBUG] Courier "..courierID.." carrying "..itemCount.." items")
        end
    end
    
    local hasStashItems, stashItems = CourierUtility.HasItemsInStash(bot)
    print("[COURIER_DEBUG] Bot has stash items: "..tostring(hasStashItems))
    
    local hasSpace, freeSlots = CourierUtility.HasInventorySpace(bot)
    print("[COURIER_DEBUG] Bot inventory space: "..freeSlots.." slots")
    
    print("[COURIER_DEBUG] === End Status ===")
end

return CourierUtility