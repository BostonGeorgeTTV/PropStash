local Utils = PropStash.Utils
local ox_inventory = exports.ox_inventory

local RegisteredStashes = {}
local HookIds = {}

local function getStashData(runtimeId)
    runtimeId = Utils.normalizeInventoryRef(runtimeId)
    if not Utils.isPropStashRuntimeId(runtimeId) then return nil end

    local stashKey, stashConfig = Utils.findStashConfigByRuntimeId(runtimeId)
    if not stashKey or not stashConfig then return nil end

    return {
        key = stashKey,
        runtimeId = runtimeId,
        config = stashConfig,
    }
end

local function isManagerBypassEnabled(stashConfig)
    if stashConfig.managerBypassPrice ~= nil then
        return stashConfig.managerBypassPrice
    end

    return Config.ManagerBypassPrice
end

local function canUseStash(source, stashData)
    if not stashData then return false, false end

    local canManage = Bridge.CanManage(source, stashData.config.manageAccess)
    local publicAccess = stashData.config.publicAccess

    if publicAccess == nil then
        publicAccess = Config.DefaultPublicAccess
    end

    return publicAccess or canManage, canManage
end

local function ensureStashesRegistered()
    for stashKey, stashConfig in pairs(Config.Stashes) do
        local runtimeId = Utils.getStashRuntimeId(stashKey)

        if not RegisteredStashes[runtimeId] then
            ox_inventory:RegisterStash(
                runtimeId,
                stashConfig.label,
                stashConfig.slots,
                stashConfig.maxWeight,
                false,
                nil,
                nil
            )

            RegisteredStashes[runtimeId] = true
            Utils.debug('Registered stash', runtimeId)
        end
    end
end

local function getPriceListing(runtimeId)
    local stashData = getStashData(runtimeId)
    if not stashData then return nil end

    local items = ox_inventory:GetInventoryItems(runtimeId, false) or {}
    local results = {}

    for _, slotData in ipairs(items) do
        local itemConfig = Utils.getAllowedItemConfig(stashData.config, slotData.name)
        results[#results + 1] = {
            slot = slotData.slot,
            name = slotData.name,
            label = Utils.formatItemLabel(slotData, stashData.config),
            count = slotData.count,
            price = Utils.getSlotPrice(stashData.config, slotData),
            minPrice = itemConfig and itemConfig.minPrice or 0,
            maxPrice = itemConfig and itemConfig.maxPrice or 99999999,
        }
    end

    table.sort(results, function(a, b)
        if a.label == b.label then
            return a.slot < b.slot
        end

        return a.label < b.label
    end)

    return results
end

local function getPropStashSide(payload)
    local fromId = Utils.normalizeInventoryRef(payload.fromInventory)
    local toId = Utils.normalizeInventoryRef(payload.toInventory)
    local fromStash = getStashData(fromId)
    local toStash = getStashData(toId)

    return fromStash, toStash, fromId, toId
end

local function canCarryFromStash(source, slotData, count)
    if not slotData then return false end
    return ox_inventory:CanCarryItem(source, slotData.name, count, slotData.metadata)
end

local function denyMove(source, message)
    if source and message then
        Bridge.Notify(source, message, 'error')
    end

    return false
end

local function registerHooks()
    if HookIds.openInventory then return end

    HookIds.openInventory = ox_inventory:registerHook('openInventory', function(payload)
        local stashData = getStashData(payload.inventoryId)
        if not stashData then return end

        local canUse = canUseStash(payload.source, stashData)
        if not canUse then
            return denyMove(payload.source, 'Non puoi aprire questo stash.')
        end
    end, {
        inventoryFilter = {
            '^propstash:'
        }
    })

    HookIds.swapItems = ox_inventory:registerHook('swapItems', function(payload)
        local fromStash, toStash = getPropStashSide(payload)
        if not fromStash and not toStash then return end

        local source = payload.source

        if payload.action == 'give' then
            return denyMove(source, 'Non puoi usare il give con questo stash.')
        end

        if fromStash and toStash then
            if fromStash.runtimeId ~= toStash.runtimeId then
                return denyMove(source, 'Non puoi spostare item tra prop stash diversi.')
            end

            if not Bridge.CanManage(source, fromStash.config.manageAccess) then
                return denyMove(source, 'Solo il personale autorizzato può riorganizzare questo stash.')
            end

            return
        end

        if toStash then
            if Config.StrictPlayerOnlyTransfers and (payload.fromType ~= 'player' or payload.toType ~= 'stash') then
                return denyMove(source, 'Puoi inserire item solo dal tuo inventario.')
            end

            if not Bridge.CanManage(source, toStash.config.manageAccess) then
                return denyMove(source, 'Non puoi depositare item in questo stash.')
            end

            local itemName = payload.fromSlot and payload.fromSlot.name
            if not itemName or not Utils.isAllowedItem(toStash.config, itemName) then
                return denyMove(source, 'Questo item non è consentito in questo stash.')
            end

            return
        end

        if fromStash then
            if Config.StrictPlayerOnlyTransfers and (payload.fromType ~= 'stash' or payload.toType ~= 'player') then
                return denyMove(source, 'Puoi prelevare item solo verso il tuo inventario.')
            end

            local canUse, canManage = canUseStash(source, fromStash)
            if not canUse then
                return denyMove(source, 'Non puoi prelevare da questo stash.')
            end

            local slotData = payload.fromSlot
            local count = math.floor(tonumber(payload.count) or 0)
            if not slotData or count <= 0 then
                return denyMove(source, 'Operazione non valida.')
            end

            if not canCarryFromStash(source, slotData, count) then
                return denyMove(source, 'Non hai spazio abbastanza nell’inventario.')
            end

            if canManage and isManagerBypassEnabled(fromStash.config) then
                return
            end

            local unitPrice = Utils.getSlotPrice(fromStash.config, slotData)
            local totalPrice = unitPrice * count
            if totalPrice <= 0 then
                return
            end

            local moneyAccount = fromStash.config.moneyAccount or Config.DefaultMoneyAccount
            if Bridge.GetMoney(source, moneyAccount) < totalPrice then
                return denyMove(source, ('Ti servono %s %s.'):format(totalPrice, moneyAccount))
            end

            if not Bridge.RemoveMoney(source, moneyAccount, totalPrice, ('Acquisto da %s'):format(fromStash.config.label)) then
                return denyMove(source, 'Pagamento fallito.')
            end

            TriggerEvent('propstash:server:purchase', source, fromStash.runtimeId, fromStash.key, slotData.name, count, totalPrice, moneyAccount)
            Bridge.Notify(source, ('Hai pagato %s %s per x%s %s.'):format(totalPrice, moneyAccount, count, Utils.formatItemLabel(slotData, fromStash.config)), 'success')
        end
    end, {
        inventoryFilter = {
            '^propstash:'
        }
    })
end

lib.callback.register('propstash:server:getPriceListing', function(source, runtimeId)
    local stashData = getStashData(runtimeId)
    if not stashData then return nil end

    local canUse = canUseStash(source, stashData)
    if not canUse then return nil end

    return {
        runtimeId = runtimeId,
        label = stashData.config.label,
        items = getPriceListing(runtimeId),
    }
end)

lib.callback.register('propstash:server:getManageListing', function(source, runtimeId)
    local stashData = getStashData(runtimeId)
    if not stashData then return nil end
    if not Bridge.CanManage(source, stashData.config.manageAccess) then return nil end

    return {
        runtimeId = runtimeId,
        label = stashData.config.label,
        items = getPriceListing(runtimeId),
    }
end)

RegisterNetEvent('propstash:server:requestOpen', function(runtimeId)
    local source = source
    local stashData = getStashData(runtimeId)
    if not stashData then return end

    local canUse = canUseStash(source, stashData)
    if not canUse then
        return Bridge.Notify(source, 'Non puoi aprire questo stash.', 'error')
    end

    TriggerClientEvent('propstash:client:openStash', source, runtimeId)
end)

RegisterNetEvent('propstash:server:setPrice', function(runtimeId, slot, newPrice)
    local source = source
    local stashData = getStashData(runtimeId)
    if not stashData then return end
    if not Bridge.CanManage(source, stashData.config.manageAccess) then return end

    slot = tonumber(slot)
    newPrice = math.floor(tonumber(newPrice) or -1)

    if not slot or newPrice < 0 then
        return Bridge.Notify(source, 'Prezzo non valido.', 'error')
    end

    local slotData = ox_inventory:GetSlot(runtimeId, slot)
    if not slotData then
        return Bridge.Notify(source, 'Item non disponibile.', 'error')
    end

    if not Utils.isAllowedItem(stashData.config, slotData.name) then
        return Bridge.Notify(source, 'Questo item non è configurato per questo stash.', 'error')
    end

    if not Utils.isPriceValid(stashData.config, slotData.name, newPrice) then
        return Bridge.Notify(source, 'Prezzo fuori limite per questo item.', 'error')
    end

    local removed, removeError = ox_inventory:RemoveItem(runtimeId, slotData.name, slotData.count, slotData.metadata, slot, false, true)
    if not removed then
        return Bridge.Notify(source, ('Aggiornamento prezzo fallito: %s'):format(removeError or 'errore sconosciuto'), 'error')
    end

    local newMetadata = Utils.injectInternalMetadata(Utils.cleanMetadata(slotData.metadata), newPrice)
    local added, addError = ox_inventory:AddItem(runtimeId, slotData.name, slotData.count, newMetadata)

    if not added then
        ox_inventory:AddItem(runtimeId, slotData.name, slotData.count, slotData.metadata)
        return Bridge.Notify(source, ('Aggiornamento prezzo fallito: %s'):format(addError or 'errore sconosciuto'), 'error')
    end

    Bridge.Notify(source, ('Prezzo aggiornato a %s.'):format(newPrice), 'success')
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() and resourceName ~= 'ox_inventory' then return end
    Wait(500)
    ensureStashesRegistered()
    registerHooks()
end)
