#include <amxmodx>
#include <fakemeta>

new const PLUGIN_NAME[] = "Distance Prediction"
new const PLUGIN_VERSION[] = "1.3.1"
new const PLUGIN_AUTHOR[] = "7yPh00N"

new const g_ColorNames[8][] = { "黄色", "橙色", "红色", "绿色", "蓝色", "青色", "粉色", "白色" }
new const g_ColorValues[8][3] = {
    {255, 255, 0}, {255, 80, 0}, {255, 20, 20}, {20, 255, 20},
    {20, 20, 255}, {20, 255, 150}, {255, 70, 120}, {255, 255, 255}
}

new bool:g_Enabled[33]
new bool:g_ShowRealTime[33]
new bool:g_ShowBest[33]
new bool:g_SonarEnabled[33]
new Float:g_Gravity
new g_HudR[33], g_HudG[33], g_HudB[33]
new Float:g_RealTimeY[33]
new Float:g_RealTimeHoldTime[33]
new Float:g_StatsX[33]
new Float:g_StatsY[33]
new bool:g_LandingEnabled[33]
new g_SuccessRectIndex[33]
new g_FailRectIndex[33]
new g_ColorTarget[33]

new g_JumpTypeIndex[33]
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
new g_ThresholdReached[33]
new g_FlashFrames[33]
new bool:g_JumpFirstFrame[33]
new bool:g_DuckStart[33]

new Float:g_PrevOrigin[33][3]
new Float:g_Thresholds[4][32]
new g_ThresholdCounts[4]
new Float:g_CurrentThresholds[33][32]
new g_CurrentThresholdCount[33]

new g_BeamSprite

new const MENU_MAIN[] = "PredMainMenu"
new const MENU_JUMPTYPE[] = "JumpTypeMenu"
new const MENU_COLOR[] = "ColorMenu"
new const MENU_REALTIME_Y[] = "RealTimeMenu"
new const MENU_STATS_POS[] = "BestPredMenu"
new const MENU_LANDING[] = "LandingAreaMenu"

// 全局设置（从ini文件中加载默认设置，初始化到服务器中的每个玩家）
new bool:g_DefaultEnabled
new bool:g_DefaultShowRealTime
new bool:g_DefaultShowBest
new bool:g_DefaultSonarEnabled
new bool:g_DefaultLandingEnabled
new g_DefaultJumpTypeIndex
new g_DefaultHudR, g_DefaultHudG, g_DefaultHudB
new Float:g_DefaultRealTimeY
new Float:g_DefaultRealTimeHoldTime
new Float:g_DefaultStatsX
new Float:g_DefaultStatsY
new g_DefaultSuccessRectIndex
new g_DefaultFailRectIndex

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
    //precache_generic("sound/7yPh00N/blip1.wav")
    //precache_sound("7yPh00N/blip1.wav")
    precache_sound("fvox/blip.wav")
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
    register_clcmd("say /rtpredhud", "cmd_toggle_realtime")
    register_clcmd("say /bestpredhud", "cmd_toggle_best")
    register_clcmd("say /landingpred", "cmd_toggle_landing")
    register_clcmd("say /distpred", "cmd_toggle_enabled")
    register_clcmd("say /sonar", "cmd_toggle_sonar")
    register_menucmd(register_menuid(MENU_MAIN), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_predmenu")
    register_menucmd(register_menuid(MENU_JUMPTYPE), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), "handle_jumptype")
    register_menucmd(register_menuid(MENU_COLOR), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_colormenu")
    register_menucmd(register_menuid(MENU_REALTIME_Y), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_realtime_y")
    register_menucmd(register_menuid(MENU_STATS_POS), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_stats_pos")
    register_menucmd(register_menuid(MENU_LANDING), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), "handle_landingmenu")
}

stock UpdateCurrentThresholds(id)
{
    new type
    switch (g_JumpTypeIndex[id])
    {
        case 1: type = 0
        case 2: type = 1
        case 3: type = 2
        default: type = 3
    }
    g_CurrentThresholdCount[id] = g_ThresholdCounts[type]
    for (new i = 0; i < g_CurrentThresholdCount[id]; i++)
        g_CurrentThresholds[id][i] = g_Thresholds[type][i]
}

public cmd_set_lj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex[id] = 1;
    UpdateCurrentThresholds(id);
    client_print_color(id, id, "^4[7yPh00N]^1 跳跃类型已切换为: ^3LJ / HJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_cj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex[id] = 2;
    UpdateCurrentThresholds(id);
    client_print_color(id, id, "^4[7yPh00N]^1 跳跃类型已切换为: ^3CJ / SCJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_dcj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex[id] = 3;
    UpdateCurrentThresholds(id);
    client_print_color(id, id, "^4[7yPh00N]^1 跳跃类型已切换为: ^3DCJ / WJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_sbj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex[id] = 4;
    UpdateCurrentThresholds(id);
    client_print_color(id, id, "^4[7yPh00N]^1 跳跃类型已切换为: ^3SBJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_set_bj(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_JumpTypeIndex[id] = 5;
    UpdateCurrentThresholds(id);
    client_print_color(id, id, "^4[7yPh00N]^1 跳跃类型已切换为: ^3BJ");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}

public cmd_toggle_realtime(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_ShowRealTime[id] = !g_ShowRealTime[id];
    client_print_color(id, id, "^4[7yPh00N]^1 实时预测功能: %s", g_ShowRealTime[id] ? "^3开启" : "^3关闭");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_best(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_ShowBest[id] = !g_ShowBest[id];
    client_print_color(id, id, "^4[7yPh00N]^1 最佳预测距离统计功能: %s", g_ShowBest[id] ? "^3开启" : "^3关闭");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_landing(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_LandingEnabled[id] = !g_LandingEnabled[id];
    client_print_color(id, id, "^4[7yPh00N]^1 着陆区域/上板预测功能: %s", g_LandingEnabled[id] ? "^3开启" : "^3关闭");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_enabled(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_Enabled[id] = !g_Enabled[id];
    client_print_color(id, id, "^4[7yPh00N]^1 距离预测插件: %s", g_Enabled[id] ? "^3开启" : "^3关闭");
    SaveSettings(id);
    return PLUGIN_HANDLED;
}
public cmd_toggle_sonar(id)
{
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    g_SonarEnabled[id] = !g_SonarEnabled[id];
    client_print_color(id, id, "^4[7yPh00N]^1 声呐功能: %s", g_SonarEnabled[id] ? "^3开启" : "^3关闭");
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
    g_ThresholdReached[id] = 0
    g_FlashFrames[id] = 0
    g_JumpFirstFrame[id] = false
    g_DuckStart[id] = false
    g_PrevOrigin[id][0] = 0.0
    g_PrevOrigin[id][1] = 0.0
    g_PrevOrigin[id][2] = 0.0
    for(new i = 0; i < 32; i++)
        g_StrafeMaxDistance[id][i] = 0.0

    g_Enabled[id] = g_DefaultEnabled
    g_ShowRealTime[id] = g_DefaultShowRealTime
    g_ShowBest[id] = g_DefaultShowBest
    g_SonarEnabled[id] = g_DefaultSonarEnabled
    g_LandingEnabled[id] = g_DefaultLandingEnabled
    g_JumpTypeIndex[id] = g_DefaultJumpTypeIndex
    g_HudR[id] = g_DefaultHudR
    g_HudG[id] = g_DefaultHudG
    g_HudB[id] = g_DefaultHudB
    g_RealTimeY[id] = g_DefaultRealTimeY
    g_RealTimeHoldTime[id] = g_DefaultRealTimeHoldTime
    g_StatsX[id] = g_DefaultStatsX
    g_StatsY[id] = g_DefaultStatsY
    g_SuccessRectIndex[id] = g_DefaultSuccessRectIndex
    g_FailRectIndex[id] = g_DefaultFailRectIndex
    g_ColorTarget[id] = 0
    UpdateCurrentThresholds(id)
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
    formatex(text, charsmax(text), "\r距离预测插件设置菜单^n^n")
    formatex(text, charsmax(text), "%s\y插件作者: 7yPh00N^n^n", text)
    if (g_Enabled[id])
        formatex(text, charsmax(text), "%s\r1. \w插件状态 - \y开启^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \w插件状态 - \r关闭^n", text)
  
    if (g_SonarEnabled[id])
        formatex(text, charsmax(text), "%s\r2. \w声呐功能 - \y开启^n", text)
    else
        formatex(text, charsmax(text), "%s\r2. \w声呐功能 - \r关闭^n", text)
  
    formatex(text, charsmax(text), "%s\r3. \w选择跳跃类型^n", text)
    formatex(text, charsmax(text), "%s\r4. \w自定义HUD颜色^n", text)
    formatex(text, charsmax(text), "%s\r5. \w实时预测功能^n", text)
    formatex(text, charsmax(text), "%s\r6. \w最佳预测统计功能^n", text)
    formatex(text, charsmax(text), "%s\r7. \w着陆区域/上板预测功能^n^n", text)
    formatex(text, charsmax(text), "%s\r8. \y保存设置^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \w关闭菜单", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_MAIN)
}

public handle_predmenu(id, key)
{
    switch (key)
    {
        case 0: { g_Enabled[id] = !g_Enabled[id]; show_predmenu(id); }
        case 1: { g_SonarEnabled[id] = !g_SonarEnabled[id]; show_predmenu(id); }
        case 2: show_jumptypemenu(id)
        case 3: { g_ColorTarget[id] = 0; show_colormenu(id, 0); }
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
    formatex(text, charsmax(text), "\r着陆区域/上板预测功能^n^n")
    if (g_LandingEnabled[id])
        formatex(text, charsmax(text), "%s\r1. \w功能状态 - \y开启^n^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \w功能状态 - \r关闭^n^n", text)
 
    formatex(text, charsmax(text), "%s\r2. \w自定义失败颜色 - %s%s^n", text, g_LandingEnabled[id] ? "\y" : "\r", g_ColorNames[g_SuccessRectIndex[id]])
    formatex(text, charsmax(text), "%s\r3. \w自定义成功颜色 - %s%s^n^n", text, g_LandingEnabled[id] ? "\y" : "\r", g_ColorNames[g_FailRectIndex[id]])
    formatex(text, charsmax(text), "%s\r4. \y保存设置^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \w返回", text)
 
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), text, -1, MENU_LANDING)
}

public handle_landingmenu(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    switch (key)
    {
        case 0: { g_LandingEnabled[id] = !g_LandingEnabled[id]; show_landingmenu(id); }
        case 1: { g_ColorTarget[id] = 1; show_colormenu(id, 1); }
        case 2: { g_ColorTarget[id] = 2; show_colormenu(id, 2); }
        case 3: { SaveSettings(id); show_landingmenu(id); }
    }
}

stock show_jumptypemenu(id)
{
    new text[512]
    formatex(text, charsmax(text), "\r选择跳跃类型^n^n")
    formatex(text, charsmax(text), "%s\r1. \wLJ / HJ%s^n", text, g_JumpTypeIndex[id] == 1 ? " \y[当前]" : "")
    formatex(text, charsmax(text), "%s\r2. \wCJ / SCJ%s^n", text, g_JumpTypeIndex[id] == 2 ? " \y[当前]" : "")
    formatex(text, charsmax(text), "%s\r3. \wDCJ / WJ%s^n", text, g_JumpTypeIndex[id] == 3 ? " \y[当前]" : "")
    formatex(text, charsmax(text), "%s\r4. \wSBJ%s^n", text, g_JumpTypeIndex[id] == 4 ? " \y[当前]" : "")
    formatex(text, charsmax(text), "%s\r5. \wBhop Jump%s^n^n", text, g_JumpTypeIndex[id] == 5 ? " \y[当前]" : "")
    formatex(text, charsmax(text), "%s\r6. \y保存设置^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \w返回", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), text, -1, MENU_JUMPTYPE)
}

public handle_jumptype(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    if (key == 5) { SaveSettings(id); show_jumptypemenu(id); return; }
    if (key >= 0 && key <= 4)
    {
        g_JumpTypeIndex[id] = key + 1
        UpdateCurrentThresholds(id)
    }
    show_jumptypemenu(id)
}

stock show_colormenu(id, target)
{
    new text[1024]
    new title[64]
    if (target == 0)
        formatex(title, charsmax(title), "选择HUD颜色")
    else if (target == 1)
        formatex(title, charsmax(title), "选择成功颜色")
    else if (target == 2)
        formatex(title, charsmax(title), "选择失败颜色")
 
    formatex(text, charsmax(text), "\r%s^n^n", title)
 
    for(new i = 0; i < 8; i++)
    {
        new bool:is_current = false
        if (target == 0)
            is_current = (g_HudR[id] == g_ColorValues[i][0] && g_HudG[id] == g_ColorValues[i][1] && g_HudB[id] == g_ColorValues[i][2])
        else if (target == 1)
            is_current = (i == g_SuccessRectIndex[id])
        else if (target == 2)
            is_current = (i == g_FailRectIndex[id])
     
        formatex(text, charsmax(text), "%s\r%d. \w%s (%d,%d,%d)%s^n",
                 text, i+1, g_ColorNames[i],
                 g_ColorValues[i][0], g_ColorValues[i][1], g_ColorValues[i][2],
                 is_current ? " \y[当前]" : "")
    }
    formatex(text, charsmax(text), "%s^n\r9. \y保存设置^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \w返回", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_COLOR)
}

public handle_colormenu(id, key)
{
    if (key == 9)
    {
        if (g_ColorTarget[id] == 0)
            show_predmenu(id)
        else
            show_landingmenu(id)
        return;
    }
    if (key >= 0 && key <= 7)
    {
        if (g_ColorTarget[id] == 0)
        {
            g_HudR[id] = g_ColorValues[key][0]
            g_HudG[id] = g_ColorValues[key][1]
            g_HudB[id] = g_ColorValues[key][2]
        }
        else if (g_ColorTarget[id] == 1)
            g_SuccessRectIndex[id] = key
        else if (g_ColorTarget[id] == 2)
            g_FailRectIndex[id] = key
     
        show_colormenu(id, g_ColorTarget[id])
    }
    else if (key == 8)
    {
        SaveSettings(id);
        show_colormenu(id, g_ColorTarget[id]);
    }
}

stock show_realtime_ymenu(id)
{
    new text[512]
    formatex(text, charsmax(text), "\r实时预测功能^n^n")
    if (g_ShowRealTime[id])
        formatex(text, charsmax(text), "%s\r1. \w功能状态 - \y开启^n^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \w功能状态 - \r关闭^n^n", text)
    if (floatabs(g_RealTimeY[id] + 1.0) < 0.001)
        formatex(text, charsmax(text), "%s[当前位置]: Y = Center^n", text)
    else
        formatex(text, charsmax(text), "%s[当前位置]: Y = %.2f^n", text, g_RealTimeY[id])
    formatex(text, charsmax(text), "%s[当前]: HUD单帧持续时间 = %.3f^n^n", text, g_RealTimeHoldTime[id])
    formatex(text, charsmax(text), "%s\r2. \wY - 0.01 (向上)^n", text)
    formatex(text, charsmax(text), "%s\r3. \wY + 0.01 (向下)^n", text)
    formatex(text, charsmax(text), "%s\r4. \yY = Center^n^n", text)
    formatex(text, charsmax(text), "%s\r5. \wHUD单帧持续时间 - 0.001^n", text)
    formatex(text, charsmax(text), "%s\r6. \wHUD单帧持续时间 + 0.001^n", text)
    formatex(text, charsmax(text), "%s\r7. \y恢复默认HUD单帧持续时间^n^n", text)
    formatex(text, charsmax(text), "%s\r8. \y保存设置^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \w返回", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_REALTIME_Y)
}

public handle_realtime_y(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    switch (key)
    {
        case 0: { g_ShowRealTime[id] = !g_ShowRealTime[id]; show_realtime_ymenu(id); }
        case 1:
        {
            g_RealTimeY[id] -= 0.01;
            if (g_RealTimeY[id] != -1.0 && (g_RealTimeY[id] < 0.0 || g_RealTimeY[id] > 1.0))
                g_RealTimeY[id] = 0.0;
            show_realtime_ymenu(id);
        }
        case 2:
        {
            g_RealTimeY[id] += 0.01;
            if (g_RealTimeY[id] != -1.0 && (g_RealTimeY[id] < 0.0 || g_RealTimeY[id] > 1.0))
                g_RealTimeY[id] = 0.0;
            show_realtime_ymenu(id);
        }
        case 3: { g_RealTimeY[id] = -1.0; show_realtime_ymenu(id); }
        case 4:
        {
            g_RealTimeHoldTime[id] -= 0.001;
            if (g_RealTimeHoldTime[id] < 0.001) g_RealTimeHoldTime[id] = 0.001;
            show_realtime_ymenu(id);
        }
        case 5:
        {
            g_RealTimeHoldTime[id] += 0.001;
            if (g_RealTimeHoldTime[id] > 5.0) g_RealTimeHoldTime[id] = 5.0;
            show_realtime_ymenu(id);
        }
        case 6: { g_RealTimeHoldTime[id] = 0.011; show_realtime_ymenu(id); }
        case 7: { SaveSettings(id); show_realtime_ymenu(id); }
    }
}

stock show_stats_pos_menu(id)
{
    new text[512]
    formatex(text, charsmax(text), "\r最佳预测距离统计功能^n^n")
    if (g_ShowBest[id])
        formatex(text, charsmax(text), "%s\r1. \w功能状态 - \y开启^n^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \w功能状态 - \r关闭^n^n", text)
    new x_display[16], y_display[16]
    if (floatabs(g_StatsX[id] + 1.0) < 0.001)
        formatex(x_display, charsmax(x_display), "Center")
    else
        formatex(x_display, charsmax(x_display), "%.2f", g_StatsX[id])
    if (floatabs(g_StatsY[id] + 1.0) < 0.001)
        formatex(y_display, charsmax(y_display), "Center")
    else
        formatex(y_display, charsmax(y_display), "%.2f", g_StatsY[id])
    formatex(text, charsmax(text), "%s[当前位置]: X = %s, Y = %s^n^n", text, x_display, y_display)
    formatex(text, charsmax(text), "%s\r2. \wX - 0.01 (向左)^n", text)
    formatex(text, charsmax(text), "%s\r3. \wX + 0.01 (向右)^n", text)
    formatex(text, charsmax(text), "%s\r4. \wY - 0.01 (向上)^n", text)
    formatex(text, charsmax(text), "%s\r5. \wY + 0.01 (向下)^n", text)
    formatex(text, charsmax(text), "%s\r6. \yX = Center^n", text)
    formatex(text, charsmax(text), "%s\r7. \yY = Center^n^n", text)
    formatex(text, charsmax(text), "%s\r8. \y恢复默认位置 (X = Center, Y = 0.25)^n^n", text)
    formatex(text, charsmax(text), "%s\r9. \y保存设置^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \w返回", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_STATS_POS)
}

public handle_stats_pos(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    if (key == 0)
    {
        g_ShowBest[id] = !g_ShowBest[id];
        show_stats_pos_menu(id);
        return;
    }
    else if (key == 1) {
        g_StatsX[id] -= 0.01;
        if (g_StatsX[id] != -1.0 && (g_StatsX[id] < 0.0 || g_StatsX[id] > 1.0))
            g_StatsX[id] = 0.0;
    }
    else if (key == 2) {
        g_StatsX[id] += 0.01;
        if (g_StatsX[id] != -1.0 && (g_StatsX[id] < 0.0 || g_StatsX[id] > 1.0))
            g_StatsX[id] = 0.0;
    }
    else if (key == 3) {
        g_StatsY[id] -= 0.01;
        if (g_StatsY[id] != -1.0 && (g_StatsY[id] < 0.0 || g_StatsY[id] > 1.0))
            g_StatsY[id] = 0.0;
    }
    else if (key == 4) {
        g_StatsY[id] += 0.01;
        if (g_StatsY[id] != -1.0 && (g_StatsY[id] < 0.0 || g_StatsY[id] > 1.0))
            g_StatsY[id] = 0.0;
    }
    else if (key == 5) {
        g_StatsX[id] = -1.0;
    }
    else if (key == 6) {
        g_StatsY[id] = -1.0;
    }
    else if (key == 7) {
        g_StatsX[id] = -1.0;
        g_StatsY[id] = 0.25;
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

    g_DefaultEnabled = true
    g_DefaultShowRealTime = true
    g_DefaultShowBest = true
    g_DefaultSonarEnabled = true
    g_DefaultLandingEnabled = true
    g_DefaultJumpTypeIndex = 1
    g_DefaultHudR = 255; g_DefaultHudG = 255; g_DefaultHudB = 0
    g_DefaultRealTimeY = -1.0
    g_DefaultRealTimeHoldTime = 0.011
    g_DefaultStatsX = -1.0
    g_DefaultStatsY = 0.25
    g_DefaultSuccessRectIndex = 6
    g_DefaultFailRectIndex = 5

    for(new i=1; i<=32; i++)
    {
        g_Enabled[i] = g_DefaultEnabled
        g_ShowRealTime[i] = g_DefaultShowRealTime
        g_ShowBest[i] = g_DefaultShowBest
        g_SonarEnabled[i] = g_DefaultSonarEnabled
        g_LandingEnabled[i] = g_DefaultLandingEnabled
        g_JumpTypeIndex[i] = g_DefaultJumpTypeIndex
        g_HudR[i] = g_DefaultHudR
        g_HudG[i] = g_DefaultHudG
        g_HudB[i] = g_DefaultHudB
        g_RealTimeY[i] = g_DefaultRealTimeY
        g_RealTimeHoldTime[i] = g_DefaultRealTimeHoldTime
        g_StatsX[i] = g_DefaultStatsX
        g_StatsY[i] = g_DefaultStatsY
        g_SuccessRectIndex[i] = g_DefaultSuccessRectIndex
        g_FailRectIndex[i] = g_DefaultFailRectIndex
        g_ColorTarget[i] = 0
    }

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

    if (!file_exists(szFile))
    {
        SaveSettings(0)
        for(new i=1; i<=32; i++)
            UpdateCurrentThresholds(i)
        return
    }

    new data[128], len
    if (read_file(szFile, 0, data, charsmax(data), len))
    {
        trim(data)
        if (!equal(data, "// distance_prediction.ini"))
        {
            SaveSettings(0)
            for(new i=1; i<=32; i++)
                UpdateCurrentThresholds(i)
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
            {
                g_DefaultEnabled = (str_to_num(arg1) == 1)
                for(new i = 1; i <= 32; i++) g_Enabled[i] = g_DefaultEnabled
            }
            else if (equal(key, "enable_sonar") && count >= 2)
            {
                g_DefaultSonarEnabled = (str_to_num(arg1) == 1)
                for(new i = 1; i <= 32; i++) g_SonarEnabled[i] = g_DefaultSonarEnabled
            }
            else if (equal(key, "jump_type") && count >= 2)
            {
                g_DefaultJumpTypeIndex = str_to_num(arg1)
                if (g_DefaultJumpTypeIndex < 1 || g_DefaultJumpTypeIndex > 5)
                    g_DefaultJumpTypeIndex = 1
                for(new i = 1; i <= 32; i++) g_JumpTypeIndex[i] = g_DefaultJumpTypeIndex
            }
            else if (equal(key, "hud_color") && count >= 4)
            {
                new rr = str_to_num(arg1), gg = str_to_num(arg2), bb = str_to_num(arg3)
                if (rr>=0&&rr<=255 && gg>=0&&gg<=255 && bb>=0&&bb<=255)
                {
                    g_DefaultHudR = rr; g_DefaultHudG = gg; g_DefaultHudB = bb
                    for(new i = 1; i <= 32; i++)
                    {
                        g_HudR[i] = rr; g_HudG[i] = gg; g_HudB[i] = bb
                    }
                }
            }
            else if (equal(key, "hud_realtime_y") && count >= 2)
            {
                g_DefaultRealTimeY = str_to_float(arg1)
                if (g_DefaultRealTimeY < -2.0 || g_DefaultRealTimeY > 2.0)
                    g_DefaultRealTimeY = -1.0
                for(new i = 1; i <= 32; i++) g_RealTimeY[i] = g_DefaultRealTimeY
            }
            else if (equal(key, "hud_realtime_holdtime") && count >= 2)
            {
                new Float:val = str_to_float(arg1)
                if (val >= 0.0 && val <= 5.0)
                    g_DefaultRealTimeHoldTime = val
                for(new i = 1; i <= 32; i++) g_RealTimeHoldTime[i] = g_DefaultRealTimeHoldTime
            }
            else if (equal(key, "enable_realtime_hud") && count >= 2)
            {
                g_DefaultShowRealTime = (str_to_num(arg1) == 1)
                for(new i = 1; i <= 32; i++) g_ShowRealTime[i] = g_DefaultShowRealTime
            }
            else if (equal(key, "hud_best_pos") && count >= 3)
            {
                new Float:fx = str_to_float(arg1)
                new Float:fy = str_to_float(arg2)
                if (fx >= -2.0 && fx <= 2.0) g_DefaultStatsX = fx
                if (fy >= -2.0 && fy <= 2.0) g_DefaultStatsY = fy
                for(new i = 1; i <= 32; i++)
                {
                    g_StatsX[i] = g_DefaultStatsX
                    g_StatsY[i] = g_DefaultStatsY
                }
            }
            else if (equal(key, "enable_best_hud") && count >= 2)
            {
                g_DefaultShowBest = (str_to_num(arg1) == 1)
                for(new i = 1; i <= 32; i++) g_ShowBest[i] = g_DefaultShowBest
            }
            else if (equal(key, "enable_landingpred") && count >= 2)
            {
                g_DefaultLandingEnabled = (str_to_num(arg1) == 1)
                for(new i = 1; i <= 32; i++) g_LandingEnabled[i] = g_DefaultLandingEnabled
            }
            else if (equal(key, "landingpred_color_succ") && count >= 4)
            {
                new rr = str_to_num(arg1), gg = str_to_num(arg2), bb = str_to_num(arg3)
                if (rr>=0&&rr<=255 && gg>=0&&gg<=255 && bb>=0&&bb<=255)
                {
                    g_DefaultSuccessRectIndex = 6
                    for (new i = 0; i < 8; i++)
                    {
                        if (g_ColorValues[i][0] == rr && g_ColorValues[i][1] == gg && g_ColorValues[i][2] == bb)
                        {
                            g_DefaultSuccessRectIndex = i
                            break
                        }
                    }
                    for(new i = 1; i <= 32; i++) g_SuccessRectIndex[i] = g_DefaultSuccessRectIndex
                }
            }
            else if (equal(key, "landingpred_color_fail") && count >= 4)
            {
                new rr = str_to_num(arg1), gg = str_to_num(arg2), bb = str_to_num(arg3)
                if (rr>=0&&rr<=255 && gg>=0&&gg<=255 && bb>=0&&bb<=255)
                {
                    g_DefaultFailRectIndex = 5
                    for (new i = 0; i < 8; i++)
                    {
                        if (g_ColorValues[i][0] == rr && g_ColorValues[i][1] == gg && g_ColorValues[i][2] == bb)
                        {
                            g_DefaultFailRectIndex = i
                            break
                        }
                    }
                    for(new i = 1; i <= 32; i++) g_FailRectIndex[i] = g_DefaultFailRectIndex
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
        }
        line++
    }

    for(new i=1; i<=32; i++)
        UpdateCurrentThresholds(i)
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
        fprintf(fp, "enable_plugin %d^n", (id == 0 ? g_DefaultEnabled : g_Enabled[id]) ? 1 : 0)
        fprintf(fp, "enable_sonar %d^n", (id == 0 ? g_DefaultSonarEnabled : g_SonarEnabled[id]) ? 1 : 0)
        fprintf(fp, "jump_type %d^n", id == 0 ? g_DefaultJumpTypeIndex : g_JumpTypeIndex[id])
        fprintf(fp, "^n")

        fprintf(fp, "// HUD Settings^n")
        fprintf(fp, "hud_color %d %d %d^n", id == 0 ? g_DefaultHudR : g_HudR[id], id == 0 ? g_DefaultHudG : g_HudG[id], id == 0 ? g_DefaultHudB : g_HudB[id])
        fprintf(fp, "hud_realtime_y %.6f^n", id == 0 ? g_DefaultRealTimeY : g_RealTimeY[id])
        fprintf(fp, "hud_realtime_holdtime %.6f^n", id == 0 ? g_DefaultRealTimeHoldTime : g_RealTimeHoldTime[id])
        fprintf(fp, "enable_realtime_hud %d^n", (id == 0 ? g_DefaultShowRealTime : g_ShowRealTime[id]) ? 1 : 0)
        fprintf(fp, "hud_best_pos %.6f %.6f^n", id == 0 ? g_DefaultStatsX : g_StatsX[id], id == 0 ? g_DefaultStatsY : g_StatsY[id])
        fprintf(fp, "enable_best_hud %d^n", (id == 0 ? g_DefaultShowBest : g_ShowBest[id]) ? 1 : 0)
        fprintf(fp, "^n")

        fprintf(fp, "// Landing Prediction Settings^n")
        fprintf(fp, "enable_landingpred %d^n", (id == 0 ? g_DefaultLandingEnabled : g_LandingEnabled[id]) ? 1 : 0)
        fprintf(fp, "landingpred_color_succ %d %d %d^n", g_ColorValues[id == 0 ? g_DefaultSuccessRectIndex : g_SuccessRectIndex[id]][0], g_ColorValues[id == 0 ? g_DefaultSuccessRectIndex : g_SuccessRectIndex[id]][1], g_ColorValues[id == 0 ? g_DefaultSuccessRectIndex : g_SuccessRectIndex[id]][2])
        fprintf(fp, "landingpred_color_fail %d %d %d^n", g_ColorValues[id == 0 ? g_DefaultFailRectIndex : g_FailRectIndex[id]][0], g_ColorValues[id == 0 ? g_DefaultFailRectIndex : g_FailRectIndex[id]][1], g_ColorValues[id == 0 ? g_DefaultFailRectIndex : g_FailRectIndex[id]][2])
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

        fclose(fp)
    
        if (id != 0)
            client_print_color(id, id, "^4[7yPh00N]^1 设置已保存至 ^4distance_prediction.ini")
    }
    else
    {
        if (id != 0)
            client_print_color(id, print_team_red, "^3[7yPh00N] 设置保存失败")
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

    new Float:offset = ducking ? 0.0 : -18.0
    new Float:targetZ = g_JumpStartOrigin[id][2] + offset

    new Float:vz0 = floatsqroot(2.0 * g_Gravity * 45.0)

    new Float:t_initial = CalcTimeToLand(g_JumpStartOrigin[id][2], vz0, targetZ, g_Gravity)
    if (t_initial <= 0.0)
        t_initial = 0.732

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
    if (!g_Enabled[id])
    {
        if (g_JumpActive[id])
        {
            g_JumpActive[id] = false;
            g_StatsDisplayed[id] = false;
            g_PreJumpActive[id] = false;
            g_PreJumpTime[id] = 0.0;
        }
        return FMRES_IGNORED;
    }
    if (!is_user_alive(id))
    {
        g_JumpActive[id] = false
        g_StatsDisplayed[id] = false
        g_PreJumpActive[id] = false;
        g_PreJumpTime[id] = 0.0;
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
        }
    }

    g_PrevOrigin[id] = currOrigin

    new flags = pev(id, pev_flags)
    new bool:onGround = !!(flags & FL_ONGROUND)
    new buttons = pev(id, pev_button)
    new oldbuttons = pev(id, pev_oldbuttons)

    if ((buttons & IN_JUMP) && !(oldbuttons & IN_JUMP) && onGround)
    {
        new bool:isLJ = (g_JumpTypeIndex[id] <= 3);
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
            }
            else
            {
                if (get_gametime() - g_PreJumpTime[id] <= 0.8)
                {
                    StartJump(id, ducking);
                    g_GroundZ[id] = g_PreJumpGroundZ[id];
                    g_PreJumpActive[id] = false;
                    g_PreJumpTime[id] = 0.0;
                }
                else
                {
                    g_PreJumpTime[id] = get_gametime();
                    g_PreJumpGroundZ[id] = GetGroundZInRectangle(id, currOrigin);
                }
            }
        }
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
            return FMRES_IGNORED;
        }

        new Float:velocity[3]
        pev(id, pev_velocity, velocity)
   
        new Float:offset = g_DuckStart[id] ? 0.0 : -18.0
        new Float:targetZ = g_JumpStartOrigin[id][2] + offset

        new Float:vz_for_calc = velocity[2]
        if (g_JumpFirstFrame[id])
        {
            vz_for_calc = floatsqroot(2.0 * g_Gravity * 45.0)
            g_JumpFirstFrame[id] = false
        }

        new Float:remaining = CalcTimeToLand(currOrigin[2], vz_for_calc, targetZ, g_Gravity)
        if (remaining < 0.0) remaining = 0.0

        new Float:predX = currOrigin[0] + velocity[0] * remaining
        new Float:predY = currOrigin[1] + velocity[1] * remaining
        new Float:dx = predX - g_JumpStartOrigin[id][0]
        new Float:dy = predY - g_JumpStartOrigin[id][1]
        new Float:totalDistance = floatsqroot(dx*dx + dy*dy) + 32.0
   
        g_PredX[id] = predX
        g_PredY[id] = predY
        g_PredZ[id] = g_GroundZ[id]

        if (remaining > 0.0)
        {
            if (g_ShowRealTime[id])
            {
                if (g_FlashFrames[id] > 0)
                {
                    set_dhudmessage(255, 255, 255, -1.0, g_RealTimeY[id], 0, 0.0, g_RealTimeHoldTime[id], 0.0, 0.0);
                    g_FlashFrames[id]--;
                }
                else
                {
                    set_dhudmessage(g_HudR[id], g_HudG[id], g_HudB[id], -1.0, g_RealTimeY[id], 0, 0.0, g_RealTimeHoldTime[id], 0.0, 0.0);
                }
                show_dhudmessage(id, "%.2f", totalDistance)
            }
       
            if (g_LandingEnabled[id])
            {
                g_UseUpperRect[id] = CheckGroundMatch(id, predX, predY, g_GroundZ[id])
                DrawPredictionRect(id, predX, predY, g_GroundZ[id], g_UseUpperRect[id])
            }

            if (!onGround)
            {
                if (g_SonarEnabled[id])
                {
                    for (new i = 0; i < g_CurrentThresholdCount[id]; i++)
                    {
                        if (!(g_ThresholdReached[id] & (1 << i)) && totalDistance >= g_CurrentThresholds[id][i])
                        {
                            g_ThresholdReached[id] |= (1 << i);
                            //emit_sound(id, CHAN_AUTO, "7yPh00N/blip1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
                            emit_sound(id, CHAN_AUTO, "fvox/blip.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
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
        }
    }
    return FMRES_IGNORED
}

stock clear_strafe_stats(id)
{
    set_hudmessage(0, 0, 0, -1.0, 0.25, 0, 0.0, 0.0, 0.0, 0.0, 2)
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
    if (g_ShowBest[id])
    {
        set_hudmessage(g_HudR[id], g_HudG[id], g_HudB[id], g_StatsX[id], g_StatsY[id], 0, 0.0, 999999.0, 0.0, 0.0, 2)
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
    new idx = useUpperRect ? g_FailRectIndex[id] : g_SuccessRectIndex[id]
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