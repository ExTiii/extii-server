return {
    serverName = 'Server',
    defaultSpawn = vec4(-540.58, -212.02, 37.65, 208.88),
    notifyPosition = 'top-center', -- 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left'
    ---@type { name: string, amount: integer, metadata: fun(source: number): table }[]
    starterItems = { -- Character starting items
        -- EX_Tii: only the phone. The ID card is bought at city hall ($50) and the driving licences
        -- are earned at the driving school (exti_driveschool).
        { name = 'phone', amount = 1 },
    }
}
