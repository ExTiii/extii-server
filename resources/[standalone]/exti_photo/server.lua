-- EX_Tii photo camera (admins only)
--   /cam x y z lookX lookY lookZ [fov]   camera at x y z, looking at lookX lookY lookZ (you are hidden, frozen there)
--   /cam ped x y z heading               stand at x y z facing heading, normal camera behind you
--   /cam off                             back to normal
lib.addCommand('cam', {
    help = 'كاميرا التصوير (للإدارة): /cam x y z lookX lookY lookZ [fov]  أو  /cam ped x y z heading  أو  /cam off',
    params = {
        -- no types: these are numbers or the words off / ped
        { name = 'a', help = 'x / off / ped', optional = true },
        { name = 'b', help = 'y', optional = true },
        { name = 'c', help = 'z', optional = true },
        { name = 'd', help = 'look x', optional = true },
        { name = 'e', help = 'look y', optional = true },
        { name = 'f', help = 'look z', optional = true },
        { name = 'g', help = 'fov', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('exti_photo:cam', source, args.a, args.b, args.c, args.d, args.e, args.f, args.g)
end)
