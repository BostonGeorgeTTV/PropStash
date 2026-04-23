local Utils = PropStash.Utils

local function notify(description, notifyType)
    lib.notify({
        description = description,
        type = notifyType or 'inform'
    })
end

RegisterNetEvent('propstash:client:notify', function(description, notifyType)
    notify(description, notifyType)
end)

RegisterNetEvent('propstash:client:openStash', function(runtimeId)
    exports.ox_inventory:openInventory('stash', runtimeId)
end)

local function buildReadOnlyPriceMenu(runtimeId)
    local data = lib.callback.await('propstash:server:getPriceListing', false, runtimeId)
    if not data then
        return notify('Non puoi vedere questo stash.', 'error')
    end

    local options = {}

    if #data.items == 0 then
        options[#options + 1] = {
            title = 'Nessun item disponibile',
            description = 'Lo stash è vuoto in questo momento.',
            icon = 'fa-regular fa-folder-open',
            readOnly = true,
        }
    else
        for _, item in ipairs(data.items) do
            local priceText = item.price > 0 and ('Prezzo: %s'):format(item.price) or 'Gratis'
            options[#options + 1] = {
                title = ('%s x%s'):format(item.label, item.count),
                description = priceText,
                icon = item.price > 0 and 'fa-solid fa-tag' or 'fa-solid fa-gift',
                readOnly = true,
            }
        end
    end

    local contextId = ('propstash_prices_%s'):format(runtimeId)

    lib.registerContext({
        id = contextId,
        title = ('Prezzi - %s'):format(data.label),
        canClose = true,
        options = options,
    })

    lib.showContext(contextId)
end

local function buildManagePriceMenu(runtimeId)
    local data = lib.callback.await('propstash:server:getManageListing', false, runtimeId)
    if not data then
        return notify('Non sei autorizzato a gestire i prezzi.', 'error')
    end

    local options = {}

    if #data.items == 0 then
        options[#options + 1] = {
            title = 'Nessun item disponibile',
            description = 'Apri lo stash e trascina dentro gli item consentiti.',
            icon = 'fa-regular fa-folder-open',
            readOnly = true,
        }
    else
        for _, item in ipairs(data.items) do
            options[#options + 1] = {
                title = ('%s x%s'):format(item.label, item.count),
                description = ('Prezzo attuale: %s | Min: %s | Max: %s'):format(item.price, item.minPrice, item.maxPrice),
                icon = 'fa-solid fa-tags',
                onSelect = function()
                    local input = lib.inputDialog(('Prezzo - %s'):format(item.label), {
                        {
                            type = 'number',
                            label = 'Nuovo prezzo unitario',
                            description = 'Metti 0 per renderlo gratis',
                            default = item.price,
                            min = item.minPrice,
                            max = item.maxPrice,
                            step = 1,
                            required = true,
                        }
                    })

                    if not input then return end
                    TriggerServerEvent('propstash:server:setPrice', runtimeId, item.slot, input[1])
                    Wait(150)
                    buildManagePriceMenu(runtimeId)
                end
            }
        end
    end

    local contextId = ('propstash_manage_%s'):format(runtimeId)

    lib.registerContext({
        id = contextId,
        title = ('Gestione prezzi - %s'):format(data.label),
        canClose = true,
        options = options,
    })

    lib.showContext(contextId)
end

local function getTargetConfig(stashConfig)
    local target = stashConfig.target or {}
    local zones = target.zones or stashConfig.locations or {}
    local hasZones = zones and #zones > 0
    local mode = target.mode

    if not mode then
        if hasZones and (target.model or stashConfig.model) then
            mode = 'both'
        elseif hasZones then
            mode = 'boxzone'
        else
            mode = 'model'
        end
    end

    return {
        mode = mode,
        model = target.model or stashConfig.model,
        distance = target.distance or Config.TargetDistance,
        icon = target.icon or stashConfig.icon or 'fa-solid fa-box-open',
        openLabel = target.openLabel or stashConfig.targetLabel or stashConfig.label,
        pricesLabel = target.pricesLabel or stashConfig.pricesLabel or 'Vedi prezzi',
        manageLabel = target.manageLabel or stashConfig.manageLabel or 'Gestisci prezzi',
        zones = zones,
        zoneDefaults = {
            size = target.size,
            rotation = target.rotation,
            debug = target.debug,
            drawSprite = target.drawSprite,
        }
    }
end

local function buildTargetOptions(runtimeId, targetConfig)
    local distance = targetConfig.distance

    return {
        {
            name = ('%s:open'):format(runtimeId),
            icon = targetConfig.icon,
            label = targetConfig.openLabel,
            distance = distance,
            onSelect = function()
                TriggerServerEvent('propstash:server:requestOpen', runtimeId)
            end
        },
        {
            name = ('%s:prices'):format(runtimeId),
            icon = 'fa-solid fa-list',
            label = targetConfig.pricesLabel,
            distance = distance,
            onSelect = function()
                buildReadOnlyPriceMenu(runtimeId)
            end
        },
        {
            name = ('%s:manage'):format(runtimeId),
            icon = 'fa-solid fa-tags',
            label = targetConfig.manageLabel,
            distance = distance,
            onSelect = function()
                buildManagePriceMenu(runtimeId)
            end
        }
    }
end

local function registerModelTarget(stashKey, runtimeId, targetConfig)
    if not targetConfig.model then
        print(('[propstash] %s: target.mode=%s ma manca target.model'):format(stashKey, targetConfig.mode))
        return
    end

    exports.ox_target:addModel(targetConfig.model, buildTargetOptions(runtimeId, targetConfig))
end

local function registerBoxZoneTargets(stashKey, runtimeId, targetConfig)
    if not targetConfig.zones or #targetConfig.zones == 0 then
        print(('[propstash] %s: target.mode=%s ma non ci sono target.zones'):format(stashKey, targetConfig.mode))
        return
    end

    for index, zone in ipairs(targetConfig.zones) do
        exports.ox_target:addBoxZone({
            name = ('propstash:%s:zone:%s'):format(stashKey, zone.id or index),
            coords = zone.coords,
            size = zone.size or targetConfig.zoneDefaults.size or vec3(1.5, 1.5, 2.0),
            rotation = zone.rotation or targetConfig.zoneDefaults.rotation or 0.0,
            debug = zone.debug,
            drawSprite = zone.drawSprite,
            options = buildTargetOptions(runtimeId, targetConfig),
        })
    end
end

CreateThread(function()
    for stashKey, stashConfig in pairs(Config.Stashes) do
        local runtimeId = Utils.getStashRuntimeId(stashKey)
        local targetConfig = getTargetConfig(stashConfig)

        if targetConfig.mode == 'model' or targetConfig.mode == 'both' then
            registerModelTarget(stashKey, runtimeId, targetConfig)
        end

        if targetConfig.mode == 'boxzone' or targetConfig.mode == 'both' then
            registerBoxZoneTargets(stashKey, runtimeId, targetConfig)
        end
    end
end)
