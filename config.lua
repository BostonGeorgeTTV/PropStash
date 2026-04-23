Config = {}

Config.Debug = false
Config.Framework = 'auto' -- auto | esx | qb | qbox
Config.TargetDistance = 2.0
Config.MetadataKey = '__propstash'
Config.DefaultMoneyAccount = 'cash' -- ESX: money/bank/black_money | QB/Qbox: cash/bank/crypto
Config.DefaultPublicAccess = true
Config.ManagerBypassPrice = true
Config.StrictPlayerOnlyTransfers = true

---@class PropStashAllowedItem
---@field minPrice number?
---@field maxPrice number?
---@field defaultPrice number?
---@field label string?

---@class PropStashAccess
---@field jobs table<string, number>?            -- jobName = minGrade
---@field gangs table<string, number>?           -- qb/qbox gangName = minGrade
---@field groups table<string, boolean|number>?  -- ESX group / QB permission / Qbox group
---@field licenses table<string, boolean>?       -- FiveM license identifier
---@field citizenids table<string, boolean>?     -- citizenid (qb/qbox)
---@field identifiers table<string, boolean>?    -- ESX char identifier or custom unique id

---@class PropStashZone
---@field id string?
---@field coords vector3
---@field size vector3?
---@field rotation number?
---@field debug boolean?
---@field drawSprite boolean?

---@class PropStashTarget
---@field mode 'model'|'boxzone'|'both'?
---@field model number|string|Array<number|string>?
---@field distance number?
---@field icon string?
---@field openLabel string?
---@field pricesLabel string?
---@field manageLabel string?
---@field zones PropStashZone[]?
---@field size vector3?
---@field rotation number?
---@field debug boolean?
---@field drawSprite boolean?

---@class PropStashDefinition
---@field label string
---@field target PropStashTarget?
---@field targetLabel string?        -- legacy fallback
---@field pricesLabel string?        -- legacy fallback
---@field manageLabel string?        -- legacy fallback
---@field icon string?               -- legacy fallback
---@field model number|string|Array<number|string>? -- legacy fallback
---@field slots number
---@field maxWeight number
---@field moneyAccount string?
---@field publicAccess boolean?
---@field managerBypassPrice boolean?
---@field manageAccess PropStashAccess
---@field allowedItems table<string, PropStashAllowedItem>

---@type table<string, PropStashDefinition>
Config.Stashes = {
    news_display = {
        label = 'Espositore Giornali',
        target = {
            mode = 'model', -- model | boxzone | both
            model = `prop_news_disp_01a`,
            distance = 2.0,
            icon = 'fa-solid fa-newspaper',
            openLabel = 'Apri espositore',
            pricesLabel = 'Vedi prezzi',
            manageLabel = 'Gestisci prezzi',

            -- Esempio opzionale se vuoi aggiungere anche box zone:
            -- mode = 'both',
            -- zones = {
            --     {
            --         id = 'weazel_frontdesk',
            --         coords = vec3(-598.84, -929.88, 23.86),
            --         size = vec3(1.8, 1.2, 2.2),
            --         rotation = 0.0,
            --         debug = false,
            --     }
            -- }
        },
        slots = 1,
        maxWeight = 5000,
        moneyAccount = 'money', -- ESX: money/bank/black_money | QB/Qbox: cash/bank/crypto
        publicAccess = true, -- se true, chiunque può accedere senza permessi, altrimenti solo chi è specificato in manageAccess
        managerBypassPrice = true, -- se true, i manager possono bypassare i prezzi e vendere al prezzo di default
        manageAccess = {
            jobs = {
                police = 0,
            },
            groups = {
                --admin = true,
            },
            licenses = {
                -- ['license:xxxxxxxxxxxxxxxx'] = true,
            },
            citizenids = {
                -- ['ABC12345'] = true,
            },
            identifiers = {
                -- ['char1:xxxxxxxxxxxxxxxx'] = true,
            }
        },
        allowedItems = {
            newspaper = {
                minPrice = 0,
                maxPrice = 250,
                defaultPrice = 0,
                label = 'Giornale',
            },
        },
    },
}
