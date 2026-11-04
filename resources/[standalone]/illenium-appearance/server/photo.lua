-- EX_Tii photo tool (server side): /extiphotos starts it for the admin who typed it, and the pictures it
-- sends back are saved into web/ex/img/ of this resource. See client/photo.lua.

local RES = GetCurrentResourceName()
local DIR = "web/ex/img/"

local function allowed(src)
    return IsPlayerAceAllowed(src, "command.extiphotos")
end

-- only names the tool makes: m-c11-12, f-beard-3, p-20
local function cleanName(name)
    if type(name) ~= "string" or #name > 40 then return nil end
    if name:match("^[mf]%-[%a%d]+%-%d+$") or name:match("^p%-%d+$") then return name end
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC = {}
for i = 1, #B64 do DEC[B64:byte(i)] = i - 1 end
local function unbase64(s)
    s = s:gsub("[^%w%+/]", "")
    local out, n = {}, 0
    for i = 1, #s - 3, 4 do
        local a, b, c, d = DEC[s:byte(i)], DEC[s:byte(i + 1)], DEC[s:byte(i + 2)], DEC[s:byte(i + 3)]
        local v = a * 262144 + b * 4096 + c * 64 + d
        n = n + 1; out[n] = string.char(v >> 16, (v >> 8) & 255, v & 255)
    end
    local rest = #s % 4
    if rest == 2 then
        local a, b = DEC[s:byte(#s - 1)], DEC[s:byte(#s)]
        n = n + 1; out[n] = string.char((a * 4) + (b >> 4))
    elseif rest == 3 then
        local a, b, c = DEC[s:byte(#s - 2)], DEC[s:byte(#s - 1)], DEC[s:byte(#s)]
        local v = a * 4096 + b * 64 + c
        n = n + 1; out[n] = string.char(v >> 10, (v >> 2) & 255)
    end
    return table.concat(out)
end

lib.callback.register("illenium-appearance:server:photoHave", function(source, prefix, count)
    if not allowed(source) or type(prefix) ~= "string" or not prefix:match("^[%a%d%-]+$") then return {} end
    count = math.min(tonumber(count) or 0, 2000)
    local have = {}
    for i = 0, count - 1 do
        have[i + 1] = LoadResourceFile(RES, DIR .. prefix .. "-" .. i .. ".webp") ~= nil
    end
    return have
end)

RegisterNetEvent("illenium-appearance:server:photoSave", function(name, data)
    local src = source
    if not allowed(src) then return end
    name = cleanName(name)
    if not name or type(data) ~= "string" or #data > 400000 then return end
    local bin = unbase64(data)
    if #bin < 12 or bin:sub(1, 4) ~= "RIFF" or bin:sub(9, 12) ~= "WEBP" then return end
    if not SaveResourceFile(RES, DIR .. name .. ".webp", bin, #bin) then
        print(("^1[photo tool] could not save %s (does the folder %s exist?)^0"):format(name, DIR))
    end
end)

lib.addCommand("extiphotos", {
    help = "EX_Tii: صوّر قطع الملابس لشاشة المظهر (stop للإيقاف)",
    params = {
        { name = "gender", type = "string", help = "m أو f أو stop (اختياري)", optional = true },
        { name = "part", type = "string", help = "مثل c11 أو beard أو parents (اختياري)", optional = true },
    },
    restricted = "group.admin",
}, function(source, args)
    TriggerClientEvent("illenium-appearance:client:photoTool", source, args.gender, args.part)
end)
