#include <amxmodx>
#include <fakemeta>

#define MOVETYPE_FLY 5

new const PLUGIN_NAME[] = "Distance Prediction"
new const PLUGIN_VERSION[] = "1.3.2"
new const PLUGIN_AUTHOR[] = "7yPh00N"
new const g_ColorNames[8][] = { "Yellow", "Orange", "Red", "Green", "Blue", "Cyan", "Pink", "White" }
new const g_ColorValues[8][3] = {
    {255, 255, 0}, {255, 80, 0}, {255, 20, 20}, {20, 255, 20},
    {20, 20, 255}, {20, 255, 150}, {255, 70, 120}, {255, 255, 255}
}
new bool:g_Enabled = true
new bool:g_ShowRealTime = true
new bool:g_ShowBest = true
new bool:g_SonarEnabled = true
new Float:g_Gravity
new g_HudR = 255, g_HudG = 255, g_HudB = 0
new Float:g_RealTimeY = -1.0
new Float:g_RealTimeHoldTime = 0.011
new Float:g_StatsX = -1.0
new Float:g_StatsY = 0.25
new bool:g_LandingEnabled
new g_SuccessRectIndex
new g_FailRectIndex
new g_ColorTarget
new g_JumpTypeIndex = 1
new Float:g_JumpStartOrigin[33][3]
new Float:g_GroundZ[33]
new Float:g_InitialPredicted[33]
new Float:g_StrafeMaxDistance[33][32]
new g_StrafeCount[33]
new Float:g_CurrentStrafeAngle[33]
new bool:g_JumpActive[33]
new bool:g_StatsDisplayed[33]
new bool:g_UseUpperRect[33]
new Float:g_PredX[33]
new Float:g_PredY[33]
new Float:g_PredZ[33]
new bool:g_PreJumpActive[33]
new Float:g_PreJumpTime[33]
new Float:g_PreJumpGroundZ[33]
new Float:g_PreJumpOriginZ[33]
new g_ThresholdReached[33]
new g_FlashFrames[33]
new bool:g_JumpFirstFrame[33]
new bool:g_DuckStart[33]
new Float:g_PrevOrigin[33][3]
new Float:g_Thresholds[5][32]
new g_ThresholdCounts[5]
new Float:g_CurrentThresholds[32]
new g_CurrentThresholdCount
new g_BeamSprite
new g_PrevMoveType[33]
new const MENU_MAIN[] = "PredMainMenu"
new const MENU_JUMPTYPE[] = "JumpTypeMenu"
new const MENU_COLOR[] = "ColorMenu"
new const MENU_REALTIME_Y[] = "RealTimeMenu"
new const MENU_STATS_POS[] = "BestPredMenu"
new const MENU_LANDING[] = "LandingAreaMenu"
new Float:g_TakeoffFuser2[33]
new Float:g_LadderOrigin[33][3]
new Float:g_LadderVelocity[33][3]
new bool:g_LDJFirstFrameUsed[33]

stock Float:CalcTimeToLand(Float:z0, Float:vz0, Float:targetZ, Float:grav)
{
    if (grav <= 0.0)
        return 0.0
    // SBJ & SCJ (FOG1)
    if (floatabs(z0 - targetZ) < 0.001)
    {
        if (vz0 <= 0.0)
            return 0.0
        // t = 2 * vz0 / grav
        return (2.0 * vz0) / grav
    }
    new Float:a = -0.5 * grav
    new Float:b = vz0
    new Float:c = z0 - targetZ
    new Float:disc = b * b - 4.0 * a * c
    if (disc < 0.0)
        return 0.0
    new Float:sqrtD = floatsqroot(disc)
    new Float:t1 = (-b + sqrtD) / (2.0 * a)
    new Float:t2 = (-b - sqrtD) / (2.0 * a)
    // 排除0解，取非0解正根
    const Float:EPS = 0.0001
    new Float:result = 0.0
    if (t1 > EPS)
        result = t1
    if (t2 > EPS && (result == 0.0 || t2 < result))
        result = t2
    return result
}
public plugin_precache()
{
    g_BeamSprite = precache_model("sprites/laserbeam.spr")
    precache_generic("sound/7yPh00N/blip1.wav")
    precache_sound("7yPh00N/blip1.wav")
}
public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
    g_Gravity = get_cvar_float("sv_gravity")
    LoadSettings()
    register_clcmd("say /dps", "cmd_predmenu")
    register_clcmd("say_team /dps", "cmd_predmenu")
    register_clcmd("say dps", "cmd_predmenu")
    register_clcmd("say_team dps", "cmd_predmenu")
    register_clcmd("say /ljpred", "cmd_set_lj")
    register_clcmd("say /hjpred", "cmd_set_lj")
    register_clcmd("say /cjpred", "cmd_set_cj")
    register_clcmd("say /scjpred", "cmd_set_cj")
    register_clcmd("say /dcjpred", "cmd_set_dcj")
    register_clcmd("say /wjpred", "cmd_set_dcj")
    register_clcmd("say /sbjpred", "cmd_set_sbj")
    register_clcmd("say /bjpred", "cmd_set_bj")
    register_clcmd("say /ldjpred", "cmd_set_ldj")
    register_clcmd("say /rtpredhud", "cmd_toggle_realtime")
    register_clcmd("say /bestpredhud", "cmd_toggle_best")
    register_clcmd("say /landingpred", "cmd_toggle_landing")
    register_clcmd("say /distpred", "cmd_toggle_enabled")
    register_clcmd("say /sonar", "cmd_toggle_sonar")
    register_menucmd(register_menuid(MENU_MAIN), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_predmenu")
    register_menucmd(register_menuid(MENU_JUMPTYPE), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), "handle_jumptype")
    register_menucmd(register_menuid(MENU_COLOR), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_colormenu")
    register_menucmd(register_menuid(MENU_REALTIME_Y), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_realtime_y")
    register_menucmd(register_menuid(MENU_STATS_POS), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_stats_pos")
    register_menucmd(register_menuid(MENU_LANDING), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), "handle_landingmenu")
}
stock UpdateCurrentThresholds()
{
    new type
    switch (g_JumpTypeIndex)
    {
        case 1: type = 0
        case 2: type = 1
        case 3: type = 2
        case 6: type = 4
        default: type = 3
    }
    g_CurrentThresholdCount = g_ThresholdCounts[type]
    for (new i = 0; i < g_CurrentThresholdCount; i++)
        g_CurrentThresholds[i] = g_Thresholds[type][i]
}
public cmd_set_lj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex = 1;
    UpdateCurrentThresholds();
    client_print_color(id, id, "^4[7yPh00N]^1 Jump Type: ^3LJ / HJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_cj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex = 2;
    UpdateCurrentThresholds();
    client_print_color(id, id, "^4[7yPh00N]^1 Jump Type: ^3CJ / SCJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_dcj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex = 3;
    UpdateCurrentThresholds();
    client_print_color(id, id, "^4[7yPh00N]^1 Jump Type: ^3DCJ / WJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_sbj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex = 4;
    UpdateCurrentThresholds();
    client_print_color(id, id, "^4[7yPh00N]^1 Jump Type: ^3SBJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_bj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex = 5;
    UpdateCurrentThresholds();
    client_print_color(id, id, "^4[7yPh00N]^1 Jump Type: ^3BJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_ldj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex = 6;
    UpdateCurrentThresholds();
    client_print_color(id, id, "^4[7yPh00N]^1 Jump Type: ^3LDJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_realtime(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_ShowRealTime = !g_ShowRealTime;
    client_print_color(id, id, "^4[7yPh00N]^1 Real-Time Prediction: %s", g_ShowRealTime ? "^3ON" : "^3OFF");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_best(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_ShowBest = !g_ShowBest;
    client_print_color(id, id, "^4[7yPh00N]^1 Best Predicted Distance: %s", g_ShowBest ? "^3ON" : "^3OFF");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_landing(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_LandingEnabled = !g_LandingEnabled;
    client_print_color(id, id, "^4[7yPh00N]^1 Landing Area Prediction: %s", g_LandingEnabled ? "^3ON" : "^3OFF");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_enabled(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_Enabled = !g_Enabled;
    client_print_color(id, id, "^4[7yPh00N]^1 Distance Prediction Plugin: %s", g_Enabled ? "^3ON" : "^3OFF");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_sonar(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_SonarEnabled = !g_SonarEnabled;
    client_print_color(id, id, "^4[7yPh00N]^1 Sonar: %s", g_SonarEnabled ? "^3ON" : "^3OFF");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public client_connect(id)
{
    g_JumpActive[id] = false
    g_StatsDisplayed[id] = false
    g_StrafeCount[id] = 0
    g_CurrentStrafeAngle[id] = -1.0
    g_InitialPredicted[id] = 0.0
    g_GroundZ[id] = 0.0
    g_UseUpperRect[id] = false
    g_PredX[id] = 0.0
    g_PredY[id] = 0.0
    g_PredZ[id] = 0.0
    g_PreJumpActive[id] = false
    g_PreJumpTime[id] = 0.0
    g_PreJumpGroundZ[id] = 0.0
    g_PreJumpOriginZ[id] = 0.0
    g_ThresholdReached[id] = 0
    g_FlashFrames[id] = 0
    g_JumpFirstFrame[id] = false
    g_DuckStart[id] = false
    g_PrevOrigin[id][0] = 0.0
    g_PrevOrigin[id][1] = 0.0
    g_PrevOrigin[id][2] = 0.0
    g_TakeoffFuser2[id] = 0.0
    g_PrevMoveType[id] = 0
    g_LadderOrigin[id][0] = 0.0
    g_LadderOrigin[id][1] = 0.0
    g_LadderOrigin[id][2] = 0.0
    g_LadderVelocity[id][0] = 0.0
    g_LadderVelocity[id][1] = 0.0
    g_LadderVelocity[id][2] = 0.0
    g_LDJFirstFrameUsed[id] = false
    for(new i = 0; i < 32; i++)
        g_StrafeMaxDistance[id][i] = 0.0
}
public cmd_predmenu(id)
{
    if (!is_user_connected(id))
        return
    show_predmenu(id)
}
stock show_predmenu(id)
{
    new text[512]
    formatex(text, charsmax(text), "\rDistance Prediction Settings^n^n")
    formatex(text, charsmax(text), "%s\yMade by 7yPh00N^n^n", text)
    if (g_Enabled)
        formatex(text, charsmax(text), "%s\r1. \wEnable Plugin - \yON^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \wEnable Plugin - \rOFF^n", text)
 
    if (g_SonarEnabled)
        formatex(text, charsmax(text), "%s\r2. \wEnable Sonar - \yON^n", text)
    else
        formatex(text, charsmax(text), "%s\r2. \wEnable Sonar - \rOFF^n", text)
 
    formatex(text, charsmax(text), "%s\r3. \wJump Type^n", text)
    formatex(text, charsmax(text), "%s\r4. \wHUD Color^n", text)
    formatex(text, charsmax(text), "%s\r5. \wReal-Time Prediction^n", text)
    formatex(text, charsmax(text), "%s\r6. \wBest Predicted Distance^n", text)
    formatex(text, charsmax(text), "%s\r7. \wLanding Area Prediction^n^n", text)
    formatex(text, charsmax(text), "%s\r8. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wExit", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_MAIN)
}
public handle_predmenu(id, key)
{
    switch (key)
    {
        case 0: { g_Enabled = !g_Enabled; show_predmenu(id); }
        case 1: { g_SonarEnabled = !g_SonarEnabled; show_predmenu(id); }
        case 2: show_jumptypemenu(id)
        case 3: { g_ColorTarget = 0; show_colormenu(id, 0); }
        case 4: show_realtime_ymenu(id)
        case 5: show_stats_pos_menu(id)
        case 6: show_landingmenu(id)
        case 7: { SaveSettings(id); show_predmenu(id); }
        case 9: return
    }
}
stock show_landingmenu(id)
{
    new text[512]
    formatex(text, charsmax(text), "\rLanding Area Prediction^n^n")
    if (g_LandingEnabled)
        formatex(text, charsmax(text), "%s\r1. \wEnable Landing Area Prediction - \yON^n^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \wEnable Landing Area Prediction - \rOFF^n^n", text)
    formatex(text, charsmax(text), "%s\r2. \wColor 01 - %s%s^n", text, g_LandingEnabled ? "\y" : "\r", g_ColorNames[g_SuccessRectIndex])
    formatex(text, charsmax(text), "%s\r3. \wColor 02 - %s%s^n^n", text, g_LandingEnabled ? "\y" : "\r", g_ColorNames[g_FailRectIndex])
    formatex(text, charsmax(text), "%s\r4. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wBack", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), text, -1, MENU_LANDING)
}
public handle_landingmenu(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    switch (key)
    {
        case 0: { g_LandingEnabled = !g_LandingEnabled; show_landingmenu(id); }
        case 1: { g_ColorTarget = 1; show_colormenu(id, 1); }
        case 2: { g_ColorTarget = 2; show_colormenu(id, 2); }
        case 3: { SaveSettings(id); show_landingmenu(id); }
    }
}
stock show_jumptypemenu(id)
{
    new text[512]
    formatex(text, charsmax(text), "\rJump Type^n^n")
    formatex(text, charsmax(text), "%s\r1. \wLJ / HJ%s^n", text, g_JumpTypeIndex == 1 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r2. \wCJ / SCJ%s^n", text, g_JumpTypeIndex == 2 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r3. \wDCJ / WJ%s^n", text, g_JumpTypeIndex == 3 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r4. \wSBJ%s^n", text, g_JumpTypeIndex == 4 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r5. \wBJ%s^n", text, g_JumpTypeIndex == 5 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r6. \wLDJ%s^n^n", text, g_JumpTypeIndex == 6 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r7. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wBack", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), text, -1, MENU_JUMPTYPE)
}
public handle_jumptype(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    if (key == 6) { SaveSettings(id); show_jumptypemenu(id); return; }
    if (key >= 0 && key <= 5)
    {
        g_JumpTypeIndex = key + 1
        UpdateCurrentThresholds()
    }
    show_jumptypemenu(id)
}
stock show_colormenu(id, target)
{
    new text[1024]
    new title[64]
    if (target == 0)
        formatex(title, charsmax(title), "HUD Color")
    else if (target == 1)
        formatex(title, charsmax(title), "Color 01")
    else if (target == 2)
        formatex(title, charsmax(title), "Color 02")
    formatex(text, charsmax(text), "\r%s^n^n", title)
    for(new i = 0; i < 8; i++)
    {
        new bool:is_current = false
        if (target == 0)
            is_current = (g_HudR == g_ColorValues[i][0] && g_HudG == g_ColorValues[i][1] && g_HudB == g_ColorValues[i][2])
        else if (target == 1)
            is_current = (i == g_SuccessRectIndex)
        else if (target == 2)
            is_current = (i == g_FailRectIndex)
    
        formatex(text, charsmax(text), "%s\r%d. \w%s (%d,%d,%d)%s^n",
                 text, i+1, g_ColorNames[i],
                 g_ColorValues[i][0], g_ColorValues[i][1], g_ColorValues[i][2],
                 is_current ? " \y[Current]" : "")
    }
    formatex(text, charsmax(text), "%s^n\r9. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wBack", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_COLOR)
}
public handle_colormenu(id, key)
{
    if (key == 9)
    {
        if (g_ColorTarget == 0)
            show_predmenu(id)
        else
            show_landingmenu(id)
        return;
    }
    if (key >= 0 && key <= 7)
    {
        if (g_ColorTarget == 0)
        {
            g_HudR = g_ColorValues[key][0]
            g_HudG = g_ColorValues[key][1]
            g_HudB = g_ColorValues[key][2]
        }
        else if (g_ColorTarget == 1)
            g_SuccessRectIndex = key
        else if (g_ColorTarget == 2)
            g_FailRectIndex = key
    
        show_colormenu(id, g_ColorTarget)
    }
    else if (key == 8)
    {
        SaveSettings(id);
        show_colormenu(id, g_ColorTarget);
    }
}
stock show_realtime_ymenu(id)
{
    new text[512]
    formatex(text, charsmax(text), "\rReal-Time Prediction^n^n")
    if (g_ShowRealTime)
        formatex(text, charsmax(text), "%s\r1. \wShow Real-Time Prediction - \yON^n^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \wShow Real-Time Prediction - \rOFF^n^n", text)
    if (floatabs(g_RealTimeY + 1.0) < 0.001)
        formatex(text, charsmax(text), "%s[Current]: Y = Center^n", text)
    else
        formatex(text, charsmax(text), "%s[Current]: Y = %.2f^n", text, g_RealTimeY)
    formatex(text, charsmax(text), "%s[Current]: Hold Time = %.3f^n^n", text, g_RealTimeHoldTime)
    formatex(text, charsmax(text), "%s\r2. \wY - 0.01 (Up)^n", text)
    formatex(text, charsmax(text), "%s\r3. \wY + 0.01 (Down)^n", text)
    formatex(text, charsmax(text), "%s\r4. \yY = Center^n^n", text)
    formatex(text, charsmax(text), "%s\r5. \wHold Time - 0.001^n", text)
    formatex(text, charsmax(text), "%s\r6. \wHold Time + 0.001^n", text)
    formatex(text, charsmax(text), "%s\r7. \yDefault Hold Time^n^n", text)
    formatex(text, charsmax(text), "%s\r8. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wBack", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_REALTIME_Y)
}
public handle_realtime_y(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    switch (key)
    {
        case 0: { g_ShowRealTime = !g_ShowRealTime; show_realtime_ymenu(id); }
        case 1:
        {
            g_RealTimeY -= 0.01;
            if (g_RealTimeY != -1.0 && (g_RealTimeY < 0.0 || g_RealTimeY > 1.0))
                g_RealTimeY = 0.0;
            show_realtime_ymenu(id);
        }
        case 2:
        {
            g_RealTimeY += 0.01;
            if (g_RealTimeY != -1.0 && (g_RealTimeY < 0.0 || g_RealTimeY > 1.0))
                g_RealTimeY = 0.0;
            show_realtime_ymenu(id);
        }
        case 3: { g_RealTimeY = -1.0; show_realtime_ymenu(id); }
        case 4:
        {
            g_RealTimeHoldTime -= 0.001;
            if (g_RealTimeHoldTime < 0.001) g_RealTimeHoldTime = 0.001;
            show_realtime_ymenu(id);
        }
        case 5:
        {
            g_RealTimeHoldTime += 0.001;
            if (g_RealTimeHoldTime > 5.0) g_RealTimeHoldTime = 5.0;
            show_realtime_ymenu(id);
        }
        case 6: { g_RealTimeHoldTime = 0.011; show_realtime_ymenu(id); }
        case 7: { SaveSettings(id); show_realtime_ymenu(id); }
    }
}
stock show_stats_pos_menu(id)
{
    new text[512]
    formatex(text, charsmax(text), "\rBest Predicted Distance^n^n")
    if (g_ShowBest)
        formatex(text, charsmax(text), "%s\r1. \wShow Best Predicted Distance - \yON^n^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \wShow Best Predicted Distance - \rOFF^n^n", text)
    new x_display[16], y_display[16]
    if (floatabs(g_StatsX + 1.0) < 0.001)
        formatex(x_display, charsmax(x_display), "Center")
    else
        formatex(x_display, charsmax(x_display), "%.2f", g_StatsX)
    if (floatabs(g_StatsY + 1.0) < 0.001)
        formatex(y_display, charsmax(y_display), "Center")
    else
        formatex(y_display, charsmax(y_display), "%.2f", g_StatsY)
    formatex(text, charsmax(text), "%s[Current]: X = %s, Y = %s^n^n", text, x_display, y_display)
    formatex(text, charsmax(text), "%s\r2. \wX - 0.01 (Left)^n", text)
    formatex(text, charsmax(text), "%s\r3. \wX + 0.01 (Right)^n", text)
    formatex(text, charsmax(text), "%s\r4. \wY - 0.01 (Up)^n", text)
    formatex(text, charsmax(text), "%s\r5. \wY + 0.01 (Down)^n", text)
    formatex(text, charsmax(text), "%s\r6. \yX = Center^n", text)
    formatex(text, charsmax(text), "%s\r7. \yY = Center^n^n", text)
    formatex(text, charsmax(text), "%s\r8. \yDefault Position (X = Center, Y = 0.25)^n^n", text)
    formatex(text, charsmax(text), "%s\r9. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wBack", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_STATS_POS)
}
public handle_stats_pos(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    if (key == 0)
    {
        g_ShowBest = !g_ShowBest;
        show_stats_pos_menu(id);
        return;
    }
    else if (key == 1) {
        g_StatsX -= 0.01;
        if (g_StatsX != -1.0 && (g_StatsX < 0.0 || g_StatsX > 1.0))
            g_StatsX = 0.0;
    }
    else if (key == 2) {
        g_StatsX += 0.01;
        if (g_StatsX != -1.0 && (g_StatsX < 0.0 || g_StatsX > 1.0))
            g_StatsX = 0.0;
    }
    else if (key == 3) {
        g_StatsY -= 0.01;
        if (g_StatsY != -1.0 && (g_StatsY < 0.0 || g_StatsY > 1.0))
            g_StatsY = 0.0;
    }
    else if (key == 4) {
        g_StatsY += 0.01;
        if (g_StatsY != -1.0 && (g_StatsY < 0.0 || g_StatsY > 1.0))
            g_StatsY = 0.0;
    }
    else if (key == 5) {
        g_StatsX = -1.0;
    }
    else if (key == 6) {
        g_StatsY = -1.0;
    }
    else if (key == 7) {
        g_StatsX = -1.0;
        g_StatsY = 0.25;
        show_stats_pos_menu(id);
        return;
    }
    else if (key == 8) {
        SaveSettings(id);
        show_stats_pos_menu(id);
        return;
    }
    show_stats_pos_menu(id)
}
stock LoadSettings()
{
    new configsdir[64]
    get_localinfo("amxx_configsdir", configsdir, charsmax(configsdir))
    new szFile[128]
    formatex(szFile, charsmax(szFile), "%s/distance_prediction.ini", configsdir)
    g_Enabled = true
    g_ShowRealTime = true
    g_ShowBest = true
    g_SonarEnabled = true
    g_JumpTypeIndex = 1
    g_HudR = 255; g_HudG = 255; g_HudB = 0
    g_RealTimeY = -1.0
    g_RealTimeHoldTime = 0.011
    g_StatsX = -1.0
    g_StatsY = 0.25
    g_LandingEnabled = true
    g_SuccessRectIndex = 6
    g_FailRectIndex = 5
    g_ColorTarget = 0
    // LJ / HJ
    g_ThresholdCounts[0] = 27
    g_Thresholds[0][0] = 240.0; g_Thresholds[0][1] = 245.0; g_Thresholds[0][2] = 250.0; g_Thresholds[0][3] = 253.0;
    g_Thresholds[0][4] = 255.0; g_Thresholds[0][5] = 257.0; g_Thresholds[0][6] = 259.0; g_Thresholds[0][7] = 261.0;
    g_Thresholds[0][8] = 263.0; g_Thresholds[0][9] = 265.0; g_Thresholds[0][10] = 267.0; g_Thresholds[0][11] = 269.0;
    g_Thresholds[0][12] = 271.0; g_Thresholds[0][13] = 273.0; g_Thresholds[0][14] = 275.0; g_Thresholds[0][15] = 277.0;
    g_Thresholds[0][16] = 279.0; g_Thresholds[0][17] = 281.0; g_Thresholds[0][18] = 283.0; g_Thresholds[0][19] = 285.0;
    g_Thresholds[0][20] = 287.0; g_Thresholds[0][21] = 289.0; g_Thresholds[0][22] = 291.0; g_Thresholds[0][23] = 293.0;
    g_Thresholds[0][24] = 295.0; g_Thresholds[0][25] = 297.0; g_Thresholds[0][26] = 299.0;
    // CJ / SCJ
    g_ThresholdCounts[1] = 21
    g_Thresholds[1][0] = 250.0; g_Thresholds[1][1] = 255.0; g_Thresholds[1][2] = 260.0; g_Thresholds[1][3] = 265.0;
    g_Thresholds[1][4] = 267.0; g_Thresholds[1][5] = 269.0; g_Thresholds[1][6] = 271.0; g_Thresholds[1][7] = 273.0;
    g_Thresholds[1][8] = 275.0; g_Thresholds[1][9] = 277.0; g_Thresholds[1][10] = 279.0; g_Thresholds[1][11] = 281.0;
    g_Thresholds[1][12] = 283.0; g_Thresholds[1][13] = 285.0; g_Thresholds[1][14] = 287.0; g_Thresholds[1][15] = 289.0;
    g_Thresholds[1][16] = 291.0; g_Thresholds[1][17] = 293.0; g_Thresholds[1][18] = 295.0; g_Thresholds[1][19] = 297.0;
    g_Thresholds[1][20] = 299.0;
    // DCJ / WJ
    g_ThresholdCounts[2] = 19
    g_Thresholds[2][0] = 250.0; g_Thresholds[2][1] = 255.0; g_Thresholds[2][2] = 260.0; g_Thresholds[2][3] = 265.0;
    g_Thresholds[2][4] = 270.0; g_Thresholds[2][5] = 272.0; g_Thresholds[2][6] = 274.0; g_Thresholds[2][7] = 276.0;
    g_Thresholds[2][8] = 278.0; g_Thresholds[2][9] = 280.0; g_Thresholds[2][10] = 282.0; g_Thresholds[2][11] = 284.0;
    g_Thresholds[2][12] = 286.0; g_Thresholds[2][13] = 288.0; g_Thresholds[2][14] = 290.0; g_Thresholds[2][15] = 292.0;
    g_Thresholds[2][16] = 294.0; g_Thresholds[2][17] = 296.0; g_Thresholds[2][18] = 298.0;
    // SBJ / BJ
    g_ThresholdCounts[3] = 19
    g_Thresholds[3][0] = 230.0; g_Thresholds[3][1] = 235.0; g_Thresholds[3][2] = 240.0; g_Thresholds[3][3] = 245.0;
    g_Thresholds[3][4] = 247.0; g_Thresholds[3][5] = 249.0; g_Thresholds[3][6] = 251.0; g_Thresholds[3][7] = 253.0;
    g_Thresholds[3][8] = 255.0; g_Thresholds[3][9] = 257.0; g_Thresholds[3][10] = 259.0; g_Thresholds[3][11] = 261.0;
    g_Thresholds[3][12] = 263.0; g_Thresholds[3][13] = 265.0; g_Thresholds[3][14] = 267.0; g_Thresholds[3][15] = 269.0;
    g_Thresholds[3][16] = 271.0; g_Thresholds[3][17] = 273.0; g_Thresholds[3][18] = 275.0;
    // LDJ
    g_ThresholdCounts[4] = 27
    g_Thresholds[4][0] = 150.0; g_Thresholds[4][1] = 160.0; g_Thresholds[4][2] = 170.0; g_Thresholds[4][3] = 180.0;
    g_Thresholds[4][4] = 190.0; g_Thresholds[4][5] = 195.0; g_Thresholds[4][6] = 200.0; g_Thresholds[4][7] = 205.0;
    g_Thresholds[4][8] = 210.0; g_Thresholds[4][9] = 215.0; g_Thresholds[4][10] = 220.0; g_Thresholds[4][11] = 225.0;
    g_Thresholds[4][12] = 230.0; g_Thresholds[4][13] = 235.0; g_Thresholds[4][14] = 240.0; g_Thresholds[4][15] = 245.0;
    g_Thresholds[4][16] = 250.0; g_Thresholds[4][17] = 255.0; g_Thresholds[4][18] = 260.0; g_Thresholds[4][19] = 265.0;
    g_Thresholds[4][20] = 270.0; g_Thresholds[4][21] = 275.0; g_Thresholds[4][22] = 280.0; g_Thresholds[4][23] = 285.0;
    g_Thresholds[4][24] = 290.0; g_Thresholds[4][25] = 295.0; g_Thresholds[4][26] = 300.0;
    if (!file_exists(szFile))
    {
        SaveSettings(0)
        UpdateCurrentThresholds()
        return
    }
    new data[128], len
    if (read_file(szFile, 0, data, charsmax(data), len))
    {
        trim(data)
        if (!equal(data, "// distance_prediction.ini"))
        {
            SaveSettings(0)
            UpdateCurrentThresholds()
            return
        }
    }
    new line = 0
    while (read_file(szFile, line, data, charsmax(data), len))
    {
        trim(data)
        if (line == 0 || data[0] == 0 || data[0] == '/') { line++; continue; }
        new key[32], arg1[32], arg2[32], arg3[32]
        new count = parse(data, key, charsmax(key), arg1, charsmax(arg1), arg2, charsmax(arg2), arg3, charsmax(arg3))
        if (count >= 1)
        {
            if (equal(key, "enable_plugin") && count >= 2)
                g_Enabled = (str_to_num(arg1) == 1)
            else if (equal(key, "enable_sonar") && count >= 2)
                g_SonarEnabled = (str_to_num(arg1) == 1)
            else if (equal(key, "jump_type") && count >= 2)
            {
                g_JumpTypeIndex = str_to_num(arg1)
                if (g_JumpTypeIndex < 1 || g_JumpTypeIndex > 6)
                    g_JumpTypeIndex = 1
            }
            else if (equal(key, "hud_color") && count >= 4)
            {
                new rr = str_to_num(arg1), gg = str_to_num(arg2), bb = str_to_num(arg3)
                if (rr>=0&&rr<=255 && gg>=0&&gg<=255 && bb>=0&&bb<=255)
                {
                    g_HudR = rr; g_HudG = gg; g_HudB = bb
                }
            }
            else if (equal(key, "hud_realtime_y") && count >= 2)
            {
                g_RealTimeY = str_to_float(arg1)
                if (g_RealTimeY < -2.0 || g_RealTimeY > 2.0)
                    g_RealTimeY = -1.0
            }
            else if (equal(key, "hud_realtime_holdtime") && count >= 2)
            {
                new Float:val = str_to_float(arg1)
                if (val >= 0.0 && val <= 5.0)
                    g_RealTimeHoldTime = val
            }
            else if (equal(key, "enable_realtime_hud") && count >= 2)
                g_ShowRealTime = (str_to_num(arg1) == 1)
            else if (equal(key, "hud_best_pos") && count >= 3)
            {
                new Float:fx = str_to_float(arg1)
                new Float:fy = str_to_float(arg2)
                if (fx >= -2.0 && fx <= 2.0) g_StatsX = fx
                if (fy >= -2.0 && fy <= 2.0) g_StatsY = fy
            }
            else if (equal(key, "enable_best_hud") && count >= 2)
                g_ShowBest = (str_to_num(arg1) == 1)
            else if (equal(key, "enable_landingpred") && count >= 2)
                g_LandingEnabled = (str_to_num(arg1) == 1)
            else if (equal(key, "landingpred_color_succ") && count >= 4)
            {
                new rr = str_to_num(arg1), gg = str_to_num(arg2), bb = str_to_num(arg3)
                if (rr>=0&&rr<=255 && gg>=0&&gg<=255 && bb>=0&&bb<=255)
                {
                    g_SuccessRectIndex = 6
                    for (new i = 0; i < 8; i++)
                    {
                        if (g_ColorValues[i][0] == rr && g_ColorValues[i][1] == gg && g_ColorValues[i][2] == bb)
                        {
                            g_SuccessRectIndex = i
                            break
                        }
                    }
                }
            }
            else if (equal(key, "landingpred_color_fail") && count >= 4)
            {
                new rr = str_to_num(arg1), gg = str_to_num(arg2), bb = str_to_num(arg3)
                if (rr>=0&&rr<=255 && gg>=0&&gg<=255 && bb>=0&&bb<=255)
                {
                    g_FailRectIndex = 5
                    for (new i = 0; i < 8; i++)
                    {
                        if (g_ColorValues[i][0] == rr && g_ColorValues[i][1] == gg && g_ColorValues[i][2] == bb)
                        {
                            g_FailRectIndex = i
                            break
                        }
                    }
                }
            }
            else if (equal(key, "lj_hj_thresholds"))
            {
                g_ThresholdCounts[0] = 0
                new remaining[512]
                new pos = contain(data, key) + strlen(key)
                if (data[pos] == ' ') pos++
                copy(remaining, charsmax(remaining), data[pos])
                new token[16]
                while (remaining[0])
                {
                    strtok(remaining, token, charsmax(token), remaining, charsmax(remaining), ' ', 1)
                    trim(token)
                    if (token[0] && g_ThresholdCounts[0] < 32)
                        g_Thresholds[0][g_ThresholdCounts[0]++] = str_to_float(token)
                }
            }
            else if (equal(key, "cj_scj_thresholds"))
            {
                g_ThresholdCounts[1] = 0
                new remaining[512]
                new pos = contain(data, key) + strlen(key)
                if (data[pos] == ' ') pos++
                copy(remaining, charsmax(remaining), data[pos])
                new token[16]
                while (remaining[0])
                {
                    strtok(remaining, token, charsmax(token), remaining, charsmax(remaining), ' ', 1)
                    trim(token)
                    if (token[0] && g_ThresholdCounts[1] < 32)
                        g_Thresholds[1][g_ThresholdCounts[1]++] = str_to_float(token)
                }
            }
            else if (equal(key, "dcj_wj_thresholds"))
            {
                g_ThresholdCounts[2] = 0
                new remaining[512]
                new pos = contain(data, key) + strlen(key)
                if (data[pos] == ' ') pos++
                copy(remaining, charsmax(remaining), data[pos])
                new token[16]
                while (remaining[0])
                {
                    strtok(remaining, token, charsmax(token), remaining, charsmax(remaining), ' ', 1)
                    trim(token)
                    if (token[0] && g_ThresholdCounts[2] < 32)
                        g_Thresholds[2][g_ThresholdCounts[2]++] = str_to_float(token)
                }
            }
            else if (equal(key, "sbj_bj_thresholds"))
            {
                g_ThresholdCounts[3] = 0
                new remaining[512]
                new pos = contain(data, key) + strlen(key)
                if (data[pos] == ' ') pos++
                copy(remaining, charsmax(remaining), data[pos])
                new token[16]
                while (remaining[0])
                {
                    strtok(remaining, token, charsmax(token), remaining, charsmax(remaining), ' ', 1)
                    trim(token)
                    if (token[0] && g_ThresholdCounts[3] < 32)
                        g_Thresholds[3][g_ThresholdCounts[3]++] = str_to_float(token)
                }
            }
            else if (equal(key, "ladder_thresholds"))
            {
                g_ThresholdCounts[4] = 0
                new remaining[512]
                new pos = contain(data, key) + strlen(key)
                if (data[pos] == ' ') pos++
                copy(remaining, charsmax(remaining), data[pos])
                new token[16]
                while (remaining[0])
                {
                    strtok(remaining, token, charsmax(token), remaining, charsmax(remaining), ' ', 1)
                    trim(token)
                    if (token[0] && g_ThresholdCounts[4] < 32)
                        g_Thresholds[4][g_ThresholdCounts[4]++] = str_to_float(token)
                }
            }
        }
        line++
    }
    UpdateCurrentThresholds()
}
stock SaveSettings(id=0)
{
    new configsdir[64]
    get_localinfo("amxx_configsdir", configsdir, charsmax(configsdir))
    new szFile[128]
    formatex(szFile, charsmax(szFile), "%s/distance_prediction.ini", configsdir)
    new fp = fopen(szFile, "wt")
    if (fp)
    {
        fprintf(fp, "// distance_prediction.ini^n")
        fprintf(fp, "^n")
        fprintf(fp, "// General Settings^n")
        fprintf(fp, "enable_plugin %d^n", g_Enabled ? 1 : 0)
        fprintf(fp, "enable_sonar %d^n", g_SonarEnabled ? 1 : 0)
        fprintf(fp, "jump_type %d^n", g_JumpTypeIndex)
        fprintf(fp, "^n")
        fprintf(fp, "// HUD Settings^n")
        fprintf(fp, "hud_color %d %d %d^n", g_HudR, g_HudG, g_HudB)
        fprintf(fp, "hud_realtime_y %.6f^n", g_RealTimeY)
        fprintf(fp, "hud_realtime_holdtime %.6f^n", g_RealTimeHoldTime)
        fprintf(fp, "enable_realtime_hud %d^n", g_ShowRealTime ? 1 : 0)
        fprintf(fp, "hud_best_pos %.6f %.6f^n", g_StatsX, g_StatsY)
        fprintf(fp, "enable_best_hud %d^n", g_ShowBest ? 1 : 0)
        fprintf(fp, "^n")
        fprintf(fp, "// Landing Prediction Settings^n")
        fprintf(fp, "enable_landingpred %d^n", g_LandingEnabled ? 1 : 0)
        fprintf(fp, "landingpred_color_succ %d %d %d^n", g_ColorValues[g_SuccessRectIndex][0], g_ColorValues[g_SuccessRectIndex][1], g_ColorValues[g_SuccessRectIndex][2])
        fprintf(fp, "landingpred_color_fail %d %d %d^n", g_ColorValues[g_FailRectIndex][0], g_ColorValues[g_FailRectIndex][1], g_ColorValues[g_FailRectIndex][2])
        fprintf(fp, "^n")
        fprintf(fp, "// Sound Thresholds^n")
        fprintf(fp, "lj_hj_thresholds")
        for (new i = 0; i < g_ThresholdCounts[0]; i++)
            fprintf(fp, " %.0f", g_Thresholds[0][i])
        fprintf(fp, "^n")
        fprintf(fp, "cj_scj_thresholds")
        for (new i = 0; i < g_ThresholdCounts[1]; i++)
            fprintf(fp, " %.0f", g_Thresholds[1][i])
        fprintf(fp, "^n")
        fprintf(fp, "dcj_wj_thresholds")
        for (new i = 0; i < g_ThresholdCounts[2]; i++)
            fprintf(fp, " %.0f", g_Thresholds[2][i])
        fprintf(fp, "^n")
        fprintf(fp, "sbj_bj_thresholds")
        for (new i = 0; i < g_ThresholdCounts[3]; i++)
            fprintf(fp, " %.0f", g_Thresholds[3][i])
        fprintf(fp, "^n")
        fprintf(fp, "ladder_thresholds")
        for (new i = 0; i < g_ThresholdCounts[4]; i++)
            fprintf(fp, " %.0f", g_Thresholds[4][i])
        fprintf(fp, "^n")
        fclose(fp)
   
        if (id != 0)
            client_print_color(id, id, "^4[7yPh00N]^1 Settings Saved in ^4distance_prediction.ini")
    }
    else
    {
        if (id != 0)
            client_print_color(id, print_team_red, "^3[7yPh00N] Save Failed!!")
    }
}
// Strafe判定
stock Float:GetMoveAngle(id)
{
    new buttons = pev(id, pev_button)
    new bool:left = !!(buttons & IN_MOVELEFT)
    new bool:right = !!(buttons & IN_MOVERIGHT)
    new bool:front = !!(buttons & IN_FORWARD)
    new bool:back = !!(buttons & IN_BACK)
    if ((left && right) || (front && back))
        return -1.0
    new Float:dx = 0.0, Float:dy = 0.0
    if (right) dx = 1.0
    else if (left) dx = -1.0
    if (front) dy = 1.0
    else if (back) dy = -1.0
    if (dx == 0.0 && dy == 0.0)
        return -1.0
    new Float:angle = floatatan2(dy, dx, radian)
    angle = angle * (180.0 / 3.14159265358979323846)
    if (angle < 0.0) angle += 360.0
    return angle
}
stock Float:GetGroundZInRectangle(id, Float:origin[3])
{
    static const Float:offsets[5][2] = {
        {0.0, 0.0}, {-16.0, 16.0}, {16.0, 16.0}, {16.0, -16.0}, {-16.0, -16.0}
    }
    new Float:highestZ = -9999.0
    new Float:start[3], Float:end[3]
    for (new i = 0; i < 5; i++)
    {
        start[0] = origin[0] + offsets[i][0]
        start[1] = origin[1] + offsets[i][1]
        start[2] = origin[2] + 1.0
   
        end[0] = start[0]
        end[1] = start[1]
        end[2] = start[2] - 100.0
   
        new tr = create_tr2()
        engfunc(EngFunc_TraceLine, start, end, 1, id, tr)
   
        new Float:frac
        get_tr2(tr, 4, frac)
   
        if (frac < 1.0)
        {
            new Float:hit[3]
            get_tr2(tr, 5, hit)
            if (hit[2] > highestZ)
                highestZ = hit[2]
        }
        free_tr2(tr)
    }
    if (highestZ == -9999.0)
        highestZ = origin[2]
    return highestZ
}
stock bool:CheckGroundMatch(id, Float:predX, Float:predY, Float:targetZ)
{
    static const Float:offsets[5][2] = {
        {0.0, 0.0}, {-16.0, 16.0}, {16.0, 16.0}, {16.0, -16.0}, {-16.0, -16.0}
    }
    new Float:start[3], Float:end[3]
    for (new i = 0; i < 5; i++)
    {
        start[0] = predX + offsets[i][0]
        start[1] = predY + offsets[i][1]
        start[2] = targetZ + 1.0
   
        end[0] = start[0]
        end[1] = start[1]
        end[2] = start[2] - 100.0
   
        new tr = create_tr2()
        engfunc(EngFunc_TraceLine, start, end, 1, id, tr)
   
        new Float:frac
        get_tr2(tr, 4, frac)
   
        if (frac < 1.0)
        {
            new Float:hit[3]
            get_tr2(tr, 5, hit)
            if (floatabs(hit[2] - targetZ) <= 1.0)
            {
                free_tr2(tr)
                return true
            }
        }
        free_tr2(tr)
    }
    return false
}
stock StartJump(id, bool:ducking)
{
    clear_strafe_stats(id)
    g_JumpActive[id] = true
    g_StatsDisplayed[id] = false
    g_UseUpperRect[id] = false
    g_JumpFirstFrame[id] = true
    g_DuckStart[id] = ducking
    pev(id, pev_origin, g_JumpStartOrigin[id])
    new Float:vel[3]
    pev(id, pev_velocity, vel)
    new Float:horiz = floatsqroot(vel[0]*vel[0] + vel[1]*vel[1])
    new Float:offset
    if (g_JumpTypeIndex == 2 || g_JumpTypeIndex == 4)
        offset = -18.0
    else
        offset = ducking ? 0.0 : -18.0
    // SBJ/BJ使用第一次起跳瞬间的玩家Z坐标作为起跳高度基准
    new Float:startZ
    if (g_JumpTypeIndex == 4 || g_JumpTypeIndex == 5)
        startZ = g_PreJumpOriginZ[id]
    else
        startZ = g_JumpStartOrigin[id][2]
    new Float:targetZ = startZ + offset
    new Float:vz0 = floatsqroot(2.0 * g_Gravity * 45.0)
    if (g_JumpTypeIndex == 4 || g_JumpTypeIndex == 5)
    {
        new Float:fuser2 = g_TakeoffFuser2[id]
        new Float:factor = (100.0 - (fuser2 - 10.0) * 0.001 * 19.0) * 0.01
        vz0 *= factor
    }
    new Float:z0_for_calc = g_JumpStartOrigin[id][2]
    if (ducking && g_JumpTypeIndex == 4)
        z0_for_calc += 18.0
    new Float:t_initial = CalcTimeToLand(z0_for_calc, vz0, targetZ, g_Gravity)
    if (t_initial <= 0.0)
        t_initial = 0.732
    // LDJ不用加32，其他跳跃类型需要加32作为hitbox补偿
    if (g_JumpTypeIndex == 6)
        g_InitialPredicted[id] = horiz * t_initial
    else
        g_InitialPredicted[id] = horiz * t_initial + 32.0
    g_StrafeCount[id] = 0
    g_CurrentStrafeAngle[id] = -1.0
    for(new i = 0; i < 32; i++)
        g_StrafeMaxDistance[id][i] = 0.0
     
    g_ThresholdReached[id] = 0
    g_FlashFrames[id] = 0
}
public fw_PlayerPreThink(id)
{
    if (!g_Enabled)
    {
        if (g_JumpActive[id])
        {
            g_JumpActive[id] = false;
            g_StatsDisplayed[id] = false;
            g_PreJumpActive[id] = false;
            g_PreJumpTime[id] = 0.0;
            g_TakeoffFuser2[id] = 0.0;
        }
        return FMRES_IGNORED;
    }
    if (!is_user_alive(id))
    {
        g_JumpActive[id] = false
        g_StatsDisplayed[id] = false
        g_PreJumpActive[id] = false;
        g_PreJumpTime[id] = 0.0;
        g_TakeoffFuser2[id] = 0.0;
        return FMRES_IGNORED
    }
    new Float:currOrigin[3]
    pev(id, pev_origin, currOrigin)
    if (g_PrevOrigin[id][0] != 0.0 || g_PrevOrigin[id][1] != 0.0 || g_PrevOrigin[id][2] != 0.0)
    {
        new Float:delta = vector_distance(currOrigin, g_PrevOrigin[id])
        // 单帧位移超过50（读点）时重置
        if (delta > 50.0 && g_JumpActive[id])
        {
            if (!g_StatsDisplayed[id] && g_InitialPredicted[id] > 0.0)
            {
                g_StatsDisplayed[id] = true;
                show_strafe_stats(id);
            }
            g_JumpActive[id] = false;
            g_PreJumpActive[id] = false;
            g_PreJumpTime[id] = 0.0;
            g_TakeoffFuser2[id] = 0.0;
        }
    }
    g_PrevOrigin[id] = currOrigin
    new flags = pev(id, pev_flags)
    new bool:onGround = !!(flags & FL_ONGROUND)
    new buttons = pev(id, pev_button)
    new oldbuttons = pev(id, pev_oldbuttons)
    if ((buttons & IN_JUMP) && !(oldbuttons & IN_JUMP) && onGround)
    {
        new bool:isLJ = (g_JumpTypeIndex <= 3);
        new bool:ducking = !!(pev(id, pev_flags) & FL_DUCKING)
     
        if (isLJ)
        {
            StartJump(id, ducking);
            g_GroundZ[id] = GetGroundZInRectangle(id, currOrigin);
        }
        else
        {
            if (!g_PreJumpActive[id])
            {
                g_PreJumpActive[id] = true;
                g_PreJumpTime[id] = get_gametime();
                g_PreJumpGroundZ[id] = GetGroundZInRectangle(id, currOrigin);
                g_PreJumpOriginZ[id] = currOrigin[2];
            }
            else
            {
                if (get_gametime() - g_PreJumpTime[id] <= 0.8)
                {
                    new Float:fuser2
                    pev(id, pev_fuser2, fuser2)
                    g_TakeoffFuser2[id] = fuser2
                    StartJump(id, ducking);
                    g_GroundZ[id] = g_PreJumpGroundZ[id];
                    g_PreJumpActive[id] = false;
                    g_PreJumpTime[id] = 0.0;
                }
                else
                {
                    g_PreJumpTime[id] = get_gametime();
                    g_PreJumpGroundZ[id] = GetGroundZInRectangle(id, currOrigin);
                    g_PreJumpOriginZ[id] = currOrigin[2];
                }
            }
        }
    }
 
    // 当玩家离开梯子时视为起跳
    if (g_JumpTypeIndex == 6)
    {
        new movetype = pev(id, pev_movetype);
        new bool:onLadderNow = (movetype == MOVETYPE_FLY);
        new bool:prevOnLadder = (g_PrevMoveType[id] == MOVETYPE_FLY);
        // 记录玩家在梯子上的位置与速度（最后一帧）
        if (onLadderNow)
        {
            g_LadderOrigin[id][0] = currOrigin[0];
            g_LadderOrigin[id][1] = currOrigin[1];
            g_LadderOrigin[id][2] = currOrigin[2];
            pev(id, pev_velocity, g_LadderVelocity[id]);
        }
        if (prevOnLadder && !onLadderNow && !onGround && !g_JumpActive[id])
        {
            clear_strafe_stats(id)
            g_JumpActive[id] = true
            g_StatsDisplayed[id] = false
            g_UseUpperRect[id] = false
            g_JumpFirstFrame[id] = true
            g_DuckStart[id] = !!(pev(id, pev_flags) & FL_DUCKING)
            g_LDJFirstFrameUsed[id] = false
            // 使用玩家停留在梯子上的最后位置作为起跳点
            g_JumpStartOrigin[id][0] = g_LadderOrigin[id][0];
            g_JumpStartOrigin[id][1] = g_LadderOrigin[id][1];
            g_JumpStartOrigin[id][2] = g_LadderOrigin[id][2];
            g_GroundZ[id] = GetGroundZInRectangle(id, g_JumpStartOrigin[id]);
            // 使用玩家停留在梯子上的最后速度
            new Float:horiz = floatsqroot(g_LadderVelocity[id][0]*g_LadderVelocity[id][0] + g_LadderVelocity[id][1]*g_LadderVelocity[id][1])
            new Float:vz0 = g_LadderVelocity[id][2]
            new Float:targetZ = g_GroundZ[id] + 18.0
            new Float:z0_for_calc = g_JumpStartOrigin[id][2]
            new Float:t_initial = CalcTimeToLand(z0_for_calc, vz0, targetZ, g_Gravity)
            if (t_initial <= 0.0)
                t_initial = 0.732
            // LDJ不用加32
            g_InitialPredicted[id] = horiz * t_initial
            g_StrafeCount[id] = 0
            g_CurrentStrafeAngle[id] = -1.0
            for(new i = 0; i < 32; i++)
                g_StrafeMaxDistance[id][i] = 0.0
            g_ThresholdReached[id] = 0
            g_FlashFrames[id] = 0
        }
        g_PrevMoveType[id] = movetype
    }
 
    if (g_JumpActive[id])
    {
        // 如果在跳跃过程中检测到onground状态，提前结束预测
        if (onGround && !g_JumpFirstFrame[id])
        {
            if (!g_StatsDisplayed[id] && g_InitialPredicted[id] > 0.0)
            {
                g_StatsDisplayed[id] = true;
                show_strafe_stats(id);
            }
            g_JumpActive[id] = false;
            g_PreJumpActive[id] = false;
            g_PreJumpTime[id] = 0.0;
            g_TakeoffFuser2[id] = 0.0;
            g_LDJFirstFrameUsed[id] = false;
            return FMRES_IGNORED;
        }
        new Float:velocity[3]
        pev(id, pev_velocity, velocity)
  
        new Float:targetZ;
        if (g_JumpTypeIndex == 6)
        {
            targetZ = g_GroundZ[id] + 18.0;
        }
        else
        {
            new Float:offset
            if (g_JumpTypeIndex == 4 || g_JumpTypeIndex == 5)
                offset = -18.0
            else
                offset = g_DuckStart[id] ? 0.0 : -18.0
            new Float:startZ
            if (g_JumpTypeIndex == 4 || g_JumpTypeIndex == 5)
                startZ = g_PreJumpOriginZ[id]
            else
                startZ = g_JumpStartOrigin[id][2]
            targetZ = startZ + offset
        }
        new Float:vz_for_calc = velocity[2];
        new Float:horiz_vel_x = velocity[0];
        new Float:horiz_vel_y = velocity[1];
        if (g_JumpFirstFrame[id])
        {
            if (g_JumpTypeIndex == 6) // LDJ使用玩家在梯子上的最后一帧速度
            {
                vz_for_calc = g_LadderVelocity[id][2];
                horiz_vel_x = g_LadderVelocity[id][0];
                horiz_vel_y = g_LadderVelocity[id][1];
            }
            else
            {
                vz_for_calc = floatsqroot(2.0 * g_Gravity * 45.0);
                if (g_JumpTypeIndex == 4 || g_JumpTypeIndex == 5)
                {
                    new Float:fuser2 = g_TakeoffFuser2[id]
                    new Float:factor = (100.0 - fuser2 * 0.001 * 19.0) * 0.01
                    vz_for_calc *= factor
                }
            }
            g_JumpFirstFrame[id] = false
        }
        new Float:remaining = CalcTimeToLand(currOrigin[2], vz_for_calc, targetZ, g_Gravity)
        if (remaining < 0.0) remaining = 0.0
        new Float:predX = currOrigin[0] + horiz_vel_x * remaining
        new Float:predY = currOrigin[1] + horiz_vel_y * remaining
        new Float:dx = predX - g_JumpStartOrigin[id][0]
        new Float:dy = predY - g_JumpStartOrigin[id][1]
        new Float:totalDistance = floatsqroot(dx*dx + dy*dy)
        // LDJ不加32，其他跳跃类型加32
        if (g_JumpTypeIndex != 6)
            totalDistance += 32.0
  
        // LDJ第一帧直接显示初始预测结果
        if (g_JumpTypeIndex == 6 && !g_LDJFirstFrameUsed[id])
        {
            totalDistance = g_InitialPredicted[id];
            g_LDJFirstFrameUsed[id] = true;
        }
  
        g_PredX[id] = predX
        g_PredY[id] = predY
        g_PredZ[id] = g_GroundZ[id]
        if (remaining > 0.0)
        {
            if (g_ShowRealTime)
            {
                if (g_FlashFrames[id] > 0)
                {
                    set_dhudmessage(255, 255, 255, -1.0, g_RealTimeY, 0, 0.0, g_RealTimeHoldTime, 0.0, 0.0);
                    g_FlashFrames[id]--;
                }
                else
                {
                    set_dhudmessage(g_HudR, g_HudG, g_HudB, -1.0, g_RealTimeY, 0, 0.0, g_RealTimeHoldTime, 0.0, 0.0);
                }
                show_dhudmessage(id, "%.2f", totalDistance)
            }
      
            if (g_LandingEnabled)
            {
                g_UseUpperRect[id] = CheckGroundMatch(id, predX, predY, g_GroundZ[id])
                DrawPredictionRect(id, predX, predY, g_GroundZ[id], g_UseUpperRect[id])
            }
            if (!onGround)
            {
                if (g_SonarEnabled)
                {
                    for (new i = 0; i < g_CurrentThresholdCount; i++)
                    {
                        if (!(g_ThresholdReached[id] & (1 << i)) && totalDistance >= g_CurrentThresholds[i])
                        {
                            g_ThresholdReached[id] |= (1 << i);
                            emit_sound(id, CHAN_AUTO, "7yPh00N/blip1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
                            g_FlashFrames[id] = 3;
                        }
                    }
                }
             
                new Float:currAngle = GetMoveAngle(id)
          
                if (currAngle >= 0.0)
                {
                    if (g_CurrentStrafeAngle[id] < 0.0)
                    {
                        g_StrafeCount[id]++
                        if (g_StrafeCount[id] > 31) g_StrafeCount[id] = 31
                        g_CurrentStrafeAngle[id] = currAngle
                        g_StrafeMaxDistance[id][g_StrafeCount[id]] = totalDistance
                    }
                    else
                    {
                        new Float:diff = floatabs(currAngle - g_CurrentStrafeAngle[id])
                        if (diff > 180.0) diff = 360.0 - diff
                  
                        if (diff > 45.0)
                        {
                            g_StrafeCount[id]++
                            if (g_StrafeCount[id] > 31) g_StrafeCount[id] = 31
                            g_CurrentStrafeAngle[id] = currAngle
                            g_StrafeMaxDistance[id][g_StrafeCount[id]] = totalDistance
                        }
                        else if (totalDistance > g_StrafeMaxDistance[id][g_StrafeCount[id]])
                            g_StrafeMaxDistance[id][g_StrafeCount[id]] = totalDistance
                    }
                }
                else if (g_StrafeCount[id] > 0 && totalDistance > g_StrafeMaxDistance[id][g_StrafeCount[id]])
                    g_StrafeMaxDistance[id][g_StrafeCount[id]] = totalDistance
            }
        }
        else if (onGround && !g_StatsDisplayed[id] && g_InitialPredicted[id] > 0.0)
        {
            g_StatsDisplayed[id] = true
            show_strafe_stats(id)
            g_JumpActive[id] = false
            g_PreJumpActive[id] = false;
            g_PreJumpTime[id] = 0.0;
            g_TakeoffFuser2[id] = 0.0;
            g_LDJFirstFrameUsed[id] = false;
        }
    }
    return FMRES_IGNORED
}
stock clear_strafe_stats(id)
{
    set_hudmessage(0, 0, 0, -1.0, 0.25, 0, 0.0, 0.0, 0.0, 0.0, 4)
    show_hudmessage(id, "")
}
stock show_strafe_stats(id)
{
    if (g_StrafeCount[id] <= 0)
        return
    new text[1024]
    format(text, charsmax(text), "Best Predicted Distance:^n")
    for(new i = 1; i <= g_StrafeCount[id]; i++)
    {
        new Float:this_max = g_StrafeMaxDistance[id][i]
        new Float:delta = (i == 1) ? (this_max - g_InitialPredicted[id]) : (this_max - g_StrafeMaxDistance[id][i-1])
        new sign[8] = ""
        if (delta >= 0.0) sign = "+"
        format(text, charsmax(text), "%sStrafe %02d: %.1f (%s%.1f)^n", text, i, this_max, sign, delta)
    }
    if (g_ShowBest)
    {
        set_hudmessage(g_HudR, g_HudG, g_HudB, g_StatsX, g_StatsY, 0, 0.0, 999999.0, 0.0, 0.0, 4)
        show_hudmessage(id, text)
    }
    client_print(id, print_console, "Best Predicted Distance:")
    for(new i = 1; i <= g_StrafeCount[id]; i++)
    {
        new Float:this_max = g_StrafeMaxDistance[id][i]
        new Float:delta = (i == 1) ? (this_max - g_InitialPredicted[id]) : (this_max - g_StrafeMaxDistance[id][i-1])
        new sign_char = (delta >= 0.0) ? '+' : '-'
        new Float:abs_delta = floatabs(delta)
        client_print(id, print_console, "Strafe %02d: %.3f (%c%.3f)", i, this_max, sign_char, abs_delta)
    }
}
stock DrawPredictionRect(id, Float:predX, Float:predY, Float:predZ, bool:useUpperRect)
{
    new Float:half = 16.0
    new idx = useUpperRect ? g_FailRectIndex : g_SuccessRectIndex
    new r = g_ColorValues[idx][0]
    new g = g_ColorValues[idx][1]
    new b = g_ColorValues[idx][2]
    new Float:tl[3], Float:tr[3], Float:br[3], Float:bl[3]
    tl[0] = predX - half; tl[1] = predY + half; tl[2] = predZ + 0.1
    tr[0] = predX + half; tr[1] = predY + half; tr[2] = predZ + 0.1
    br[0] = predX + half; br[1] = predY - half; br[2] = predZ + 0.1
    bl[0] = predX - half; bl[1] = predY - half; bl[2] = predZ + 0.1
    DrawBeamLine(id, tl, tr, r, g, b)
    DrawBeamLine(id, tr, br, r, g, b)
    DrawBeamLine(id, br, bl, r, g, b)
    DrawBeamLine(id, bl, tl, r, g, b)
}
stock DrawBeamLine(id, Float:start[3], Float:end[3], r, g, b)
{
    message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
    write_byte(TE_BEAMPOINTS)
    engfunc(EngFunc_WriteCoord, start[0])
    engfunc(EngFunc_WriteCoord, start[1])
    engfunc(EngFunc_WriteCoord, start[2])
    engfunc(EngFunc_WriteCoord, end[0])
    engfunc(EngFunc_WriteCoord, end[1])
    engfunc(EngFunc_WriteCoord, end[2])
    write_short(g_BeamSprite)
    write_byte(0)
    write_byte(0)
    write_byte(1)
    write_byte(3)
    write_byte(0)
    write_byte(r)
    write_byte(g)
    write_byte(b)
    write_byte(255)
    write_byte(0)
    message_end()
}