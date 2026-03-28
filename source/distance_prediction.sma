#include <amxmodx>
#include <fakemeta>

new const PLUGIN_NAME[] = "Distance Prediction"
new const PLUGIN_VERSION[] = "1.1.0"
new const PLUGIN_AUTHOR[] = "7yPh00N"

new const Float:LJ_JUMP_TIME = 0.73227289328465705598
new const Float:SBJ_JUMP_TIME = 0.66085311074049502000 // kz_longjumps2
new const Float:BJ_JUMP_TIME  = 0.65389425396792266731 // kz_longjumps2

new const g_ColorNames[8][] = { "Yellow", "Orange", "Red", "Green", "Blue", "Cyan", "Pink", "White" }
new const g_ColorValues[8][3] = {
    {255, 255, 0}, {255, 80, 0}, {255, 20, 20}, {20, 255, 20}, 
    {20, 20, 255}, {20, 255, 150}, {255, 70, 120}, {255, 255, 255}
}

new bool:g_Enabled = true
new bool:g_ShowRealTime = true
new bool:g_ShowBest = true
new Float:g_JumpTime
new g_HudR = 255, g_HudG = 255, g_HudB = 0
new Float:g_RealTimeY = -1.0
new Float:g_StatsX = -1.0
new Float:g_StatsY = 0.25

new Float:g_JumpStartTime[33]
new Float:g_JumpStartOrigin[33][3]
new Float:g_InitialPredicted[33]
new Float:g_StrafeMaxDistance[33][32]
new g_StrafeCount[33]
new Float:g_CurrentStrafeAngle[33]
new bool:g_JumpActive[33]
new bool:g_StatsDisplayed[33]

new const MENU_MAIN[] = "PredMainMenu"
new const MENU_JUMPTYPE[] = "JumpTypeMenu"
new const MENU_COLOR[] = "ColorMenu"
new const MENU_REALTIME_Y[] = "RealTimeMenu"
new const MENU_STATS_POS[] = "BestPredMenu"

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
    
    LoadSettings()
    
    register_clcmd("say /predmenu", "cmd_predmenu")
    register_clcmd("say_team /predmenu", "cmd_predmenu")
    
    // Main Menu
    register_menucmd(register_menuid(MENU_MAIN), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), "handle_predmenu")
    // Jump Type
    register_menucmd(register_menuid(MENU_JUMPTYPE), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<9), "handle_jumptype")
    // Color
    register_menucmd(register_menuid(MENU_COLOR), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_colormenu")
    // Real-Time
    register_menucmd(register_menuid(MENU_REALTIME_Y), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), "handle_realtime_y")
    // Best
    register_menucmd(register_menuid(MENU_STATS_POS), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handle_stats_pos")
}

public client_connect(id)
{
    g_JumpActive[id] = false
    g_StatsDisplayed[id] = false
    g_StrafeCount[id] = 0
    g_CurrentStrafeAngle[id] = -1.0
    g_InitialPredicted[id] = 0.0
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
    formatex(text, charsmax(text), "\rDistance Prediction Menu^n^n")
    formatex(text, charsmax(text), "%s\yMade by 7yPh00N^n^n", text)
    if (g_Enabled)
        formatex(text, charsmax(text), "%s\r1. \wEnable Plugin - \yON^n", text)
    else
        formatex(text, charsmax(text), "%s\r1. \wEnable Plugin - \rOFF^n", text)
    formatex(text, charsmax(text), "%s\r2. \wJump Type^n", text)
    formatex(text, charsmax(text), "%s\r3. \wHUD Color^n", text)
    formatex(text, charsmax(text), "%s\r4. \wReal-Time Prediction^n", text)
    formatex(text, charsmax(text), "%s\r5. \wBest Predicted Distance^n^n", text)
    formatex(text, charsmax(text), "%s\r6. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wExit", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), text, -1, MENU_MAIN)
}

public handle_predmenu(id, key)
{
    switch (key)
    {
        case 0:
        {
            g_Enabled = !g_Enabled;
            show_predmenu(id);
        }
        case 1: show_jumptypemenu(id)
        case 2: show_colormenu(id)
        case 3: show_realtime_ymenu(id)
        case 4: show_stats_pos_menu(id)
        case 5: { SaveSettings(id); show_predmenu(id); }
        case 9: return
    }
}

stock show_jumptypemenu(id)
{
    new text[512]
    new curr_type = 0
    if (floatabs(g_JumpTime - LJ_JUMP_TIME) < 0.001)
        curr_type = 1
    else if (floatabs(g_JumpTime - SBJ_JUMP_TIME) < 0.001)
        curr_type = 2
    else if (floatabs(g_JumpTime - BJ_JUMP_TIME) < 0.001)
        curr_type = 3
    
    formatex(text, charsmax(text), "\rJump Type^n^n")
    formatex(text, charsmax(text), "%s\r1. \wLJ/HJ/WJ/CJ/DCJ/SCJ%s^n", 
         text, curr_type == 1 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r2. \wStand-Up BJ%s^n", 
         text, curr_type == 2 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r3. \wBhop Jump%s^n^n", 
         text, curr_type == 3 ? " \y[Current]" : "")
    formatex(text, charsmax(text), "%s\r4. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wBack to Main Menu", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<9), text, -1, MENU_JUMPTYPE)
}

public handle_jumptype(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    
    switch (key)
    {
        case 0: g_JumpTime = LJ_JUMP_TIME
        case 1: g_JumpTime = SBJ_JUMP_TIME
        case 2: g_JumpTime = BJ_JUMP_TIME
        case 3: { SaveSettings(id); show_jumptypemenu(id); return; }
        case 4: { show_predmenu(id); return; }
    }
    show_jumptypemenu(id)
}

stock show_colormenu(id)
{
    new text[1024]
    formatex(text, charsmax(text), "\rHUD Color^n^n")
    for(new i = 0; i < 8; i++)
    {
        new bool:is_current = (g_HudR == g_ColorValues[i][0] && g_HudG == g_ColorValues[i][1] && g_HudB == g_ColorValues[i][2])
        formatex(text, charsmax(text), "%s\r%d. \w%s (%d,%d,%d)%s^n",
                 text, i+1, g_ColorNames[i],
                 g_ColorValues[i][0], g_ColorValues[i][1], g_ColorValues[i][2],
                 is_current ? " \y[Current]" : "")
    }
    formatex(text, charsmax(text), "%s^n\r9. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wBack to Main Menu", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), text, -1, MENU_COLOR)
}

public handle_colormenu(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    
    if (key >= 0 && key <= 7)
    {
        g_HudR = g_ColorValues[key][0]
        g_HudG = g_ColorValues[key][1]
        g_HudB = g_ColorValues[key][2]
        show_colormenu(id)
    }
    else if (key == 8)
    {
        SaveSettings(id);
        show_colormenu(id);
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
        formatex(text, charsmax(text), "%s[Current]: Y = Center^n^n", text)
    else
        formatex(text, charsmax(text), "%s[Current]: Y = %.2f^n^n", text, g_RealTimeY)
    formatex(text, charsmax(text), "%s\r2. \wY - 0.01 (Up)^n", text)
    formatex(text, charsmax(text), "%s\r3. \wY + 0.01 (Down)^n", text)
    formatex(text, charsmax(text), "%s\r4. \yY = Center^n^n", text)
    formatex(text, charsmax(text), "%s\r5. \ySave Settings^n^n", text)
    formatex(text, charsmax(text), "%s\r0. \wBack to Main Menu", text)
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), text, -1, MENU_REALTIME_Y)
}

public handle_realtime_y(id, key)
{
    if (key == 9) { show_predmenu(id); return; }
    
    if (key == 0)
    {
        g_ShowRealTime = !g_ShowRealTime;
        show_realtime_ymenu(id);
        return;
    }
    else if (key == 1) {
        g_RealTimeY -= 0.01;
        if (g_RealTimeY != -1.0 && (g_RealTimeY < 0.0 || g_RealTimeY > 1.0))
            g_RealTimeY = 0.0;
    }
    else if (key == 2) {
        g_RealTimeY += 0.01;
        if (g_RealTimeY != -1.0 && (g_RealTimeY < 0.0 || g_RealTimeY > 1.0))
            g_RealTimeY = 0.0;
    }
    else if (key == 3) {
        g_RealTimeY = -1.0;
    }
    else if (key == 4) {
        SaveSettings(id);
        show_realtime_ymenu(id);
        return;
    }
    else if (key == 5) {
        show_predmenu(id);
        return;
    }
    show_realtime_ymenu(id)
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
    formatex(text, charsmax(text), "%s\r0. \wBack to Main Menu", text)
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

// ini读写
stock LoadSettings()
{
    new configsdir[64]
    get_localinfo("amxx_configsdir", configsdir, charsmax(configsdir))
    
    new szFile[128]
    formatex(szFile, charsmax(szFile), "%s/distance_prediction.ini", configsdir)
    
    // 默认值
    g_Enabled = true
    g_ShowRealTime = true
    g_ShowBest = true
    g_JumpTime = LJ_JUMP_TIME
    g_HudR = 255; g_HudG = 255; g_HudB = 0
    g_RealTimeY = -1.0
    g_StatsX = -1.0
    g_StatsY = 0.25
    
    if (file_exists(szFile))
    {
        new data[128], len, line = 0
        
        if (read_file(szFile, line, data, charsmax(data), len))
        {
            trim(data)
            new val = str_to_num(data)
            if (val == 0 || val == 1)
                g_Enabled = (val == 1)
            line++
        }
        // 跳跃类型编号
        if (read_file(szFile, line, data, charsmax(data), len))
        {
            trim(data)
            new type_id = str_to_num(data)
            switch (type_id)
            {
                case 1: g_JumpTime = LJ_JUMP_TIME
                case 2: g_JumpTime = SBJ_JUMP_TIME
                case 3: g_JumpTime = BJ_JUMP_TIME
                default: g_JumpTime = LJ_JUMP_TIME
            }
            line++
        }
        // R G B
        if (read_file(szFile, line, data, charsmax(data), len))
        {
            trim(data)
            new r[8], g[8], b[8]
            if (parse(data, r, charsmax(r), g, charsmax(g), b, charsmax(b)) >= 3)
            {
                new rr = str_to_num(r), gg = str_to_num(g), bb = str_to_num(b)
                if (rr>=0&&rr<=255 && gg>=0&&gg<=255 && bb>=0&&bb<=255)
                {
                    g_HudR = rr; g_HudG = gg; g_HudB = bb
                }
            }
            line++
        }
        // Real-Time Y
        if (read_file(szFile, line, data, charsmax(data), len))
        {
            trim(data)
            new Float:val = str_to_float(data)
            if (val >= -2.0 && val <= 2.0) g_RealTimeY = val
            line++
        }
        // Best X Y
        if (read_file(szFile, line, data, charsmax(data), len))
        {
            trim(data)
            new x[16], y[16]
            if (parse(data, x, charsmax(x), y, charsmax(y)) >= 2)
            {
                new Float:fx = str_to_float(x)
                new Float:fy = str_to_float(y)
                if (fx >= -2.0 && fx <= 2.0) g_StatsX = fx
                if (fy >= -2.0 && fy <= 2.0) g_StatsY = fy
            }
            line++
        }
        // Show Real-Time
        if (read_file(szFile, line, data, charsmax(data), len))
        {
            trim(data)
            new val = str_to_num(data)
            if (val == 0 || val == 1)
                g_ShowRealTime = (val == 1)
            line++
        }
        // Show Best
        if (read_file(szFile, line, data, charsmax(data), len))
        {
            trim(data)
            new val = str_to_num(data)
            if (val == 0 || val == 1)
                g_ShowBest = (val == 1)
        }
    }
    else
    {
        SaveSettings(0)
    }
}

stock SaveSettings(id=0)
{
    new configsdir[64]
    get_localinfo("amxx_configsdir", configsdir, charsmax(configsdir))
    
    new szFile[128]
    formatex(szFile, charsmax(szFile), "%s/distance_prediction.ini", configsdir)
    
    new type_id = 1
    if (floatabs(g_JumpTime - LJ_JUMP_TIME) < 0.001)
        type_id = 1
    else if (floatabs(g_JumpTime - SBJ_JUMP_TIME) < 0.001)
        type_id = 2
    else if (floatabs(g_JumpTime - BJ_JUMP_TIME) < 0.001)
        type_id = 3
    
    new fp = fopen(szFile, "wt")
    if (fp)
    {
        fprintf(fp, "%d^n", g_Enabled ? 1 : 0)
        fprintf(fp, "%d^n", type_id)
        fprintf(fp, "%d %d %d^n", g_HudR, g_HudG, g_HudB)
        fprintf(fp, "%.6f^n", g_RealTimeY)
        fprintf(fp, "%.6f %.6f^n", g_StatsX, g_StatsY)
        fprintf(fp, "%d^n", g_ShowRealTime ? 1 : 0)
        fprintf(fp, "%d^n", g_ShowBest ? 1 : 0)
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

// Stafe判定
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

stock StartJump(id)
{
    clear_strafe_stats(id)
   
    g_JumpActive[id] = true
    g_StatsDisplayed[id] = false
    g_JumpStartTime[id] = get_gametime()
    pev(id, pev_origin, g_JumpStartOrigin[id])
   
    new Float:vel[3]
    pev(id, pev_velocity, vel)
    new Float:horiz = floatsqroot(vel[0]*vel[0] + vel[1]*vel[1])
    g_InitialPredicted[id] = horiz * g_JumpTime + 32.0
   
    g_StrafeCount[id] = 0
    g_CurrentStrafeAngle[id] = -1.0
    for(new i = 0; i < 32; i++)
        g_StrafeMaxDistance[id][i] = 0.0
   
    remove_task(id)
    set_task(g_JumpTime, "DisplayJumpStats", id)
}

public fw_PlayerPreThink(id)
{
    if (!g_Enabled)
    {
        if (g_JumpActive[id])
        {
            g_JumpActive[id] = false;
            g_StatsDisplayed[id] = false;
        }
        return FMRES_IGNORED;
    }
    
    if (!is_user_alive(id))
    {
        g_JumpActive[id] = false
        g_StatsDisplayed[id] = false
        return FMRES_IGNORED
    }
   
    new flags = pev(id, pev_flags)
    new bool:onGround = !!(flags & FL_ONGROUND)
    new Float:currTime = get_gametime()
   
    new buttons = pev(id, pev_button)
    new oldbuttons = pev(id, pev_oldbuttons)
    if ((buttons & IN_JUMP) && !(oldbuttons & IN_JUMP) && onGround)
        StartJump(id)
   
    if (g_JumpActive[id])
    {
        new Float:elapsed = currTime - g_JumpStartTime[id]
        new Float:remaining = g_JumpTime - elapsed
        if (remaining < 0.0) remaining = 0.0
       
        new Float:currOrigin[3], Float:velocity[3]
        pev(id, pev_origin, currOrigin)
        pev(id, pev_velocity, velocity)
       
        new Float:predX = currOrigin[0] + velocity[0] * remaining
        new Float:predY = currOrigin[1] + velocity[1] * remaining
        new Float:dx = predX - g_JumpStartOrigin[id][0]
        new Float:dy = predY - g_JumpStartOrigin[id][1]
        new Float:totalDistance = floatsqroot(dx*dx + dy*dy) + 32.0
       
        if (!onGround && remaining > 0.0)
        {
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
       
        if (remaining > 0.0)
        {
            if (g_ShowRealTime)
            {
                set_dhudmessage(g_HudR, g_HudG, g_HudB, -1.0, g_RealTimeY, 0, 0.0, 0.011, 0.0, 0.0)
                show_dhudmessage(id, "%.1f", totalDistance)
            }
        }
        else if (!g_StatsDisplayed[id])
        {
            g_StatsDisplayed[id] = true
            show_strafe_stats(id)
            remove_task(id)
            g_JumpActive[id] = false
        }
    }
   
    return FMRES_IGNORED
}

public DisplayJumpStats(id)
{
    if (!is_user_connected(id)) return
    if (!g_StatsDisplayed[id])
    {
        g_StatsDisplayed[id] = true
        show_strafe_stats(id)
    }
    g_JumpActive[id] = false
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
