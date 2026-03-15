#include <amxmodx>
#include <fakemeta>

new const PLUGIN_NAME[] = "Distance_Prediction"
new const PLUGIN_VERSION[] = "1.0.0"
new const PLUGIN_AUTHOR[] = "7yPh00N"

new Float:g_JumpStartTime[33]
new Float:g_JumpStartOrigin[33][3]
new bool:g_InAir[33]

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
}

public client_connect(id)
{
    g_InAir[id] = false
}

public fw_PlayerPreThink(id)
{
    if (!is_user_alive(id))
    {
        g_InAir[id] = false
        return FMRES_IGNORED
    }

    new flags = pev(id, pev_flags)
    new bool:onGround = !!(flags & FL_ONGROUND)
    new Float:currTime = get_gametime()

    if (!onGround && !g_InAir[id])
    {
        g_InAir[id] = true
        g_JumpStartTime[id] = currTime
        pev(id, pev_origin, g_JumpStartOrigin[id])
    }

    if (onGround && g_InAir[id])
    {
        g_InAir[id] = false
    }

    if (g_InAir[id])
    {
        new Float:elapsed = currTime - g_JumpStartTime[id]
        new Float:remaining = 0.73 - elapsed
        
        if (remaining <= 0.0)
        {
            return FMRES_IGNORED
        }

        new Float:currOrigin[3]
        new Float:velocity[3]
        pev(id, pev_origin, currOrigin)
        pev(id, pev_velocity, velocity)

        new Float:predX = currOrigin[0] + velocity[0] * remaining
        new Float:predY = currOrigin[1] + velocity[1] * remaining

        new Float:dx = predX - g_JumpStartOrigin[id][0]
        new Float:dy = predY - g_JumpStartOrigin[id][1]
        new Float:totalDistance = floatsqroot(dx*dx + dy*dy) + 32

        set_dhudmessage(255, 80, 0,
                        -1.0, -1.0,
                        0,
                        0.0,
                        0.011,
                        0.0,
                        0.0)

        show_dhudmessage(id, "%.1f", totalDistance)
    }

    return FMRES_IGNORED
}