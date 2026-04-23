PropStash = PropStash or {}

local M = {}

function M.debug(...)
    if not Config.Debug then return end
    print('^3[propstash]^7', ...)
end

function M.cloneTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, nested in pairs(value) do
        copy[key] = M.cloneTable(nested)
    end

    return copy
end

function M.round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function M.getStashRuntimeId(stashKey)
    return ('propstash:%s'):format(stashKey)
end

function M.isPropStashRuntimeId(runtimeId)
    return type(runtimeId) == 'string' and runtimeId:find('^propstash:') ~= nil
end

function M.getStashKeyFromRuntimeId(runtimeId)
    if type(runtimeId) ~= 'string' then return nil end
    return runtimeId:match('^propstash:([^:]+)$')
end

function M.normalizeInventoryRef(inventory)
    if type(inventory) == 'table' then
        return inventory.id or inventory.name or inventory.owner
    end

    return inventory
end

function M.getPriceMetadata(metadata)
    metadata = metadata or {}
    local internal = metadata[Config.MetadataKey]

    if type(internal) == 'table' then
        return tonumber(internal.price) or 0
    end

    if type(internal) == 'number' then
        return tonumber(internal) or 0
    end

    return nil
end

function M.injectInternalMetadata(originalMetadata, price)
    local metadata = M.cloneTable(originalMetadata or {})
    metadata[Config.MetadataKey] = {
        price = M.round(math.max(0, tonumber(price) or 0))
    }
    return metadata
end

function M.cleanMetadata(metadata)
    local clean = M.cloneTable(metadata or {})
    clean[Config.MetadataKey] = nil
    return clean
end

function M.getAllowedItemConfig(stashConfig, itemName)
    if not stashConfig or not stashConfig.allowedItems then return nil end
    return stashConfig.allowedItems[itemName]
end

function M.isAllowedItem(stashConfig, itemName)
    return M.getAllowedItemConfig(stashConfig, itemName) ~= nil
end

function M.normalizePrice(stashConfig, itemName, price)
    local itemConfig = M.getAllowedItemConfig(stashConfig, itemName)
    if not itemConfig then return nil end

    local minPrice = itemConfig.minPrice or 0
    local maxPrice = itemConfig.maxPrice or 99999999
    local fallback = itemConfig.defaultPrice or 0
    local normalized = M.round(math.max(minPrice, math.min(maxPrice, tonumber(price) or fallback)))

    return normalized
end

function M.isPriceValid(stashConfig, itemName, price)
    local itemConfig = M.getAllowedItemConfig(stashConfig, itemName)
    if not itemConfig then return false end

    local value = tonumber(price)
    if not value then return false end

    local minPrice = itemConfig.minPrice or 0
    local maxPrice = itemConfig.maxPrice or 99999999

    return value >= minPrice and value <= maxPrice
end

function M.formatItemLabel(slotData, stashConfig)
    if slotData.metadata and slotData.metadata.label then
        return slotData.metadata.label
    end

    local itemConfig = stashConfig and stashConfig.allowedItems and stashConfig.allowedItems[slotData.name]
    if itemConfig and itemConfig.label then
        return itemConfig.label
    end

    return slotData.label or slotData.name
end

function M.getSlotPrice(stashConfig, slotData)
    if not slotData then return 0 end

    local price = M.getPriceMetadata(slotData.metadata)
    if price ~= nil then
        return price
    end

    return M.normalizePrice(stashConfig, slotData.name, nil) or 0
end

function M.findStashConfigByRuntimeId(runtimeId)
    local stashKey = M.getStashKeyFromRuntimeId(runtimeId)
    if not stashKey then return nil end

    return stashKey, Config.Stashes[stashKey]
end

PropStash.Utils = M
