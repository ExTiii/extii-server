-- EX_Tii admin helper: /savespot <name>
-- Saves where you are standing (and which way you face) so new locations can be added exactly.
-- The spots are written to qbx_garages/saved_spots.txt and printed in the server console.

lib.addCommand('savespot', {
    help = 'حفظ موقعك الحالي واتجاهك (للإدارة)',
    params = {
        { name = 'name', type = 'string', help = 'اسم الموقع، مثل sandy_office' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local line = ('%s = vec4(%.2f, %.2f, %.2f, %.2f)'):format(args.name, coords.x, coords.y, coords.z, heading)

    local resource = GetCurrentResourceName()
    local current = LoadResourceFile(resource, 'saved_spots.txt') or ''
    SaveResourceFile(resource, 'saved_spots.txt', current .. line .. '\n', -1)

    print('[savespot] ' .. line)
    exports.qbx_core:Notify(source, 'تم حفظ الموقع: ' .. args.name, 'success')
end)
