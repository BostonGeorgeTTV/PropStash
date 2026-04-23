Bridge = {}

local resourceStates = {
    esx = GetResourceState('es_extended') == 'started',
    qb = GetResourceState('qb-core') == 'started',
    qbox = GetResourceState('qbx_core') == 'started',
}

local Framework = nil
local ESX = nil
local QBCore = nil

local function detectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end

    if resourceStates.qbox then return 'qbox' end
    if resourceStates.qb then return 'qb' end
    if resourceStates.esx then return 'esx' end

    return nil
end

Framework = detectFramework()

if Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Framework == 'qb' or Framework == 'qbox' then
    QBCore = exports['qb-core']:GetCoreObject()
end

function Bridge.GetFramework()
    return Framework
end

function Bridge.GetPlayer(source)
    if Framework == 'esx' then
        return ESX.GetPlayerFromId(source)
    end

    if Framework == 'qb' then
        return QBCore.Functions.GetPlayer(source)
    end

    if Framework == 'qbox' then
        return exports.qbx_core:GetPlayer(source)
    end

    return nil
end

function Bridge.GetJob(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Framework == 'esx' then
        local job = player.getJob()
        return {
            name = job.name,
            grade = tonumber(job.grade) or 0,
            onDuty = job.onDuty,
        }
    end

    if Framework == 'qb' then
        local job = player.PlayerData.job or {}
        return {
            name = job.name,
            grade = tonumber(job.grade and job.grade.level or job.grade or 0) or 0,
            onDuty = job.onduty,
        }
    end

    if Framework == 'qbox' then
        local job = player.PlayerData.job or {}
        return {
            name = job.name,
            grade = tonumber(job.grade and job.grade.level or job.grade or 0) or 0,
            onDuty = job.onduty,
        }
    end

    return nil
end

function Bridge.GetGang(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Framework == 'qb' or Framework == 'qbox' then
        local gang = player.PlayerData.gang or {}
        return {
            name = gang.name,
            grade = tonumber(gang.grade and gang.grade.level or gang.grade or 0) or 0,
        }
    end

    return nil
end

function Bridge.GetIdentifiers(source)
    local player = Bridge.GetPlayer(source)
    local identifiers = {
        license = nil,
        citizenid = nil,
        identifier = nil,
    }

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:find('^license:') then
            identifiers.license = identifier
            break
        end
    end

    if not player then
        return identifiers
    end

    if Framework == 'esx' then
        identifiers.identifier = player.getIdentifier()
        return identifiers
    end

    if Framework == 'qb' then
        identifiers.citizenid = player.PlayerData.citizenid
        identifiers.identifier = player.PlayerData.citizenid
        return identifiers
    end

    if Framework == 'qbox' then
        identifiers.license = identifiers.license or player.PlayerData.license
        identifiers.citizenid = player.PlayerData.citizenid
        identifiers.identifier = player.PlayerData.citizenid
        return identifiers
    end

    return identifiers
end

function Bridge.HasJob(source, jobs)
    if not jobs or next(jobs) == nil then return false end

    local job = Bridge.GetJob(source)
    if not job then return false end

    local minGrade = jobs[job.name]
    if minGrade == nil then return false end

    return job.grade >= (tonumber(minGrade) or 0)
end

function Bridge.HasGang(source, gangs)
    if not gangs or next(gangs) == nil then return false end

    local gang = Bridge.GetGang(source)
    if not gang then return false end

    local minGrade = gangs[gang.name]
    if minGrade == nil then return false end

    return gang.grade >= (tonumber(minGrade) or 0)
end

function Bridge.HasGroup(source, groups)
    if not groups or next(groups) == nil then return false end

    if Framework == 'esx' then
        local player = Bridge.GetPlayer(source)
        if not player then return false end

        local currentGroup = player.getGroup()
        return groups[currentGroup] ~= nil and groups[currentGroup] ~= false
    end

    if Framework == 'qb' then
        for groupName, allowed in pairs(groups) do
            if allowed and QBCore.Functions.HasPermission(source, groupName) then
                return true
            end
        end

        return false
    end

    if Framework == 'qbox' then
        local qboxGroups = {}

        for groupName, minGrade in pairs(groups) do
            qboxGroups[groupName] = tonumber(minGrade) or 0
        end

        return exports.qbx_core:HasGroup(source, qboxGroups)
    end

    return false
end

function Bridge.HasIdentifierAccess(source, access)
    if not access then return false end

    local ids = Bridge.GetIdentifiers(source)

    if access.licenses and ids.license and access.licenses[ids.license] then
        return true
    end

    if access.citizenids and ids.citizenid and access.citizenids[ids.citizenid] then
        return true
    end

    if access.identifiers and ids.identifier and access.identifiers[ids.identifier] then
        return true
    end

    return false
end

function Bridge.CanManage(source, access)
    if not access then return false end

    if Bridge.HasIdentifierAccess(source, access) then
        return true
    end

    if Bridge.HasJob(source, access.jobs) then
        return true
    end

    if Bridge.HasGang(source, access.gangs) then
        return true
    end

    if Bridge.HasGroup(source, access.groups) then
        return true
    end

    return false
end

function Bridge.Notify(source, description, notifyType)
    TriggerClientEvent('propstash:client:notify', source, description, notifyType or 'inform')
end

function Bridge.GetMoney(source, account)
    local player = Bridge.GetPlayer(source)
    if not player then return 0 end

    account = account or Config.DefaultMoneyAccount

    if Framework == 'esx' then
        local accountData = player.getAccount(account)
        return accountData and accountData.money or 0
    end

    if Framework == 'qb' then
        return player.Functions.GetMoney(account) or 0
    end

    if Framework == 'qbox' then
        return exports.qbx_core:GetMoney(source, account) or 0
    end

    return 0
end

function Bridge.RemoveMoney(source, account, amount, reason)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    account = account or Config.DefaultMoneyAccount
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then return true end

    if Framework == 'esx' then
        if Bridge.GetMoney(source, account) < amount then
            return false
        end

        player.removeAccountMoney(account, amount, reason or 'propstash_purchase')
        return true
    end

    if Framework == 'qb' then
        return player.Functions.RemoveMoney(account, amount, reason or 'propstash_purchase')
    end

    if Framework == 'qbox' then
        return exports.qbx_core:RemoveMoney(source, account, amount, reason or 'propstash_purchase')
    end

    return false
end

function Bridge.AddMoney(source, account, amount, reason)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    account = account or Config.DefaultMoneyAccount
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then return true end

    if Framework == 'esx' then
        player.addAccountMoney(account, amount, reason or 'propstash_refund')
        return true
    end

    if Framework == 'qb' then
        return player.Functions.AddMoney(account, amount, reason or 'propstash_refund')
    end

    if Framework == 'qbox' then
        return exports.qbx_core:AddMoney(source, account, amount, reason or 'propstash_refund')
    end

    return false
end

CreateThread(function()
    if not Framework then
        print('^1[propstash]^7 Nessun framework supportato trovato. Imposta Config.Framework o verifica che il framework sia avviato.')
        return
    end

    print(('[propstash] Framework rilevato: %s'):format(Framework))
end)
