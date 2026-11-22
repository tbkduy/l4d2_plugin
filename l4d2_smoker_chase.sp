/**
 * L4D2 - Smoker Chase After Tongue Break
 *
 * Sau khi lưỡi của Smoker (bot) bị đứt / nhả ra, Smoker sẽ lao về phía
 * survivor (nạn nhân vừa rồi, hoặc survivor gần nhất) rồi cào (melee).
 * Trong lúc di chuyển, nếu gặp vật cản thấp phía trước hoặc bị kẹt
 * (gần như không di chuyển được) thì Smoker sẽ nhảy qua (crouch-jump).
 * Nếu phía trước là tường cao không nhảy qua được, Smoker sẽ né sang ngang.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION  "1.0.0"

#define TEAM_SURVIVOR   2
#define TEAM_INFECTED   3
#define ZC_SMOKER       1

#define OBSTACLE_NONE   0
#define OBSTACLE_JUMP   1   // vật cản thấp, nhảy qua được
#define OBSTACLE_WALL   2   // tường cao, phải né

public Plugin myinfo =
{
    name        = "[L4D2] Smoker Chase After Tongue Break",
    author      = "Claude",
    description = "Smoker bot chases and scratches survivors after its tongue breaks, jumping over obstacles",
    version     = PLUGIN_VERSION,
    url         = ""
};

ConVar g_cvEnable;
ConVar g_cvDuration;
ConVar g_cvMeleeRange;
ConVar g_cvMaxRange;
ConVar g_cvStopOnReady;
ConVar g_cvRetarget;
ConVar g_cvStuckDist;
ConVar g_cvStuckTime;
ConVar g_cvJumpHeight;
ConVar g_cvLookAhead;

bool  g_bChasing[MAXPLAYERS + 1];
int   g_iTargetUserId[MAXPLAYERS + 1];
float g_fChaseStart[MAXPLAYERS + 1];
float g_fNextStuckCheck[MAXPLAYERS + 1];
float g_vLastPos[MAXPLAYERS + 1][3];
int   g_iStuckCount[MAXPLAYERS + 1];
float g_fStrafeEnd[MAXPLAYERS + 1];
float g_fStrafeDir[MAXPLAYERS + 1];
float g_fNextJump[MAXPLAYERS + 1];
float g_fDuckEnd[MAXPLAYERS + 1];
bool  g_bMeleeToggle[MAXPLAYERS + 1];

int g_iOffsNextActivation = -1;

// ============================================================================
// Khởi tạo
// ============================================================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();
    if (engine != Engine_Left4Dead2 && engine != Engine_Left4Dead)
    {
        strcopy(error, err_max, "Plugin chỉ hỗ trợ Left 4 Dead / Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    CreateConVar("l4d2_smoker_chase_version", PLUGIN_VERSION, "Phiên bản plugin", FCVAR_NOTIFY | FCVAR_DONTRECORD);

    g_cvEnable      = CreateConVar("l4d2_smoker_chase_enable",      "1",     "1 = Bật plugin, 0 = Tắt", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvDuration    = CreateConVar("l4d2_smoker_chase_duration",    "15.0",  "Thời gian tối đa (giây) Smoker đuổi theo survivor. 0 = không giới hạn", FCVAR_NOTIFY, true, 0.0);
    g_cvMeleeRange  = CreateConVar("l4d2_smoker_chase_melee_range", "75.0",  "Khoảng cách (unit) để bắt đầu cào", FCVAR_NOTIFY, true, 30.0, true, 200.0);
    g_cvMaxRange    = CreateConVar("l4d2_smoker_chase_max_range",   "1500.0","Bỏ đuổi nếu survivor xa hơn khoảng này. 0 = không giới hạn", FCVAR_NOTIFY, true, 0.0);
    g_cvStopOnReady = CreateConVar("l4d2_smoker_chase_stop_ready",  "1",     "1 = Dừng đuổi khi lưỡi hồi xong (để Smoker kéo lại), 0 = Đuổi tiếp", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvRetarget    = CreateConVar("l4d2_smoker_chase_retarget",    "1",     "1 = Nếu nạn nhân chết/không hợp lệ thì đuổi survivor gần nhất", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvStuckDist   = CreateConVar("l4d2_smoker_chase_stuck_dist",  "10.0",  "Di chuyển ít hơn khoảng này trong 1 lần kiểm tra thì coi là bị kẹt", FCVAR_NOTIFY, true, 1.0);
    g_cvStuckTime   = CreateConVar("l4d2_smoker_chase_stuck_time",  "0.3",   "Chu kỳ (giây) kiểm tra bị kẹt", FCVAR_NOTIFY, true, 0.1, true, 2.0);
    g_cvJumpHeight  = CreateConVar("l4d2_smoker_chase_jump_height", "56.0",  "Độ cao vật cản tối đa (unit) mà Smoker sẽ thử nhảy qua", FCVAR_NOTIFY, true, 20.0, true, 120.0);
    g_cvLookAhead   = CreateConVar("l4d2_smoker_chase_look_ahead",  "40.0",  "Khoảng nhìn trước (unit) để phát hiện vật cản", FCVAR_NOTIFY, true, 10.0, true, 150.0);

    AutoExecConfig(true, "l4d2_smoker_chase");

    HookEvent("tongue_release", Event_TongueRelease);
    HookEvent("tongue_grab",    Event_TongueGrab);
    HookEvent("player_death",   Event_PlayerDeath);
    HookEvent("player_spawn",   Event_PlayerSpawn);
    HookEvent("round_start",    Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end",      Event_RoundStart, EventHookMode_PostNoCopy);

    g_iOffsNextActivation = FindSendPropInfo("CBaseAbility", "m_nextActivationTimer");
}

public void OnMapStart()
{
    ResetAll();
}

public void OnClientDisconnect(int client)
{
    StopChase(client);
}

// ============================================================================
// Event
// ============================================================================

public void Event_TongueRelease(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue)
        return;

    int smoker = GetClientOfUserId(event.GetInt("userid"));
    if (!IsBotSmoker(smoker))
        return;

    StartChase(smoker, event.GetInt("victim"));
}

public void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
    // Smoker kéo được người khác -> ngừng đuổi
    StopChase(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    StopChase(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    StopChase(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetAll();
}

// ============================================================================
// Điều khiển bot
// ============================================================================

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!g_bChasing[client])
        return Plugin_Continue;

    if (!g_cvEnable.BoolValue || !IsBotSmoker(client) || IsSmokerPinning(client))
    {
        StopChase(client);
        return Plugin_Continue;
    }

    float now = GetGameTime();

    // Hết thời gian đuổi
    float duration = g_cvDuration.FloatValue;
    if (duration > 0.0 && now - g_fChaseStart[client] >= duration)
    {
        StopChase(client);
        return Plugin_Continue;
    }

    // Lưỡi đã hồi -> trả quyền điều khiển cho AI để kéo lại
    if (g_cvStopOnReady.BoolValue && now - g_fChaseStart[client] > 1.0 && IsTongueReady(client))
    {
        StopChase(client);
        return Plugin_Continue;
    }

    int target = GetChaseTarget(client);
    if (target == 0)
    {
        StopChase(client);
        return Plugin_Continue;
    }

    float myPos[3], tgtPos[3];
    GetClientAbsOrigin(client, myPos);
    GetClientAbsOrigin(target, tgtPos);

    float dist = GetVectorDistance(myPos, tgtPos);
    float maxRange = g_cvMaxRange.FloatValue;
    if (maxRange > 0.0 && dist > maxRange)
    {
        StopChase(client);
        return Plugin_Continue;
    }

    // ---- Quay mặt về phía survivor ----
    float eye[3], aim[3], dir[3], ang[3];
    GetClientEyePosition(client, eye);
    aim = tgtPos;
    aim[2] += IsIncapped(target) ? 15.0 : 40.0;
    MakeVectorFromPoints(eye, aim, dir);
    GetVectorAngles(dir, ang);
    if (ang[0] > 180.0)
        ang[0] -= 360.0;
    ang[2] = 0.0;

    angles[0] = ang[0];
    angles[1] = ang[1];
    angles[2] = 0.0;
    TeleportEntity(client, NULL_VECTOR, ang, NULL_VECTOR);

    // ---- Di chuyển thẳng về phía trước ----
    vel[0] = 450.0;
    vel[1] = 0.0;
    buttons |= IN_FORWARD;
    buttons &= ~(IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);

    bool onGround = (GetEntityFlags(client) & FL_ONGROUND) != 0;

    if (dist <= g_cvMeleeRange.FloatValue)
    {
        // ---- Đủ gần: cào liên tục (nhấn/nhả IN_ATTACK2 xen kẽ) ----
        g_bMeleeToggle[client] = !g_bMeleeToggle[client];
        if (g_bMeleeToggle[client])
            buttons |= IN_ATTACK2;
        else
            buttons &= ~IN_ATTACK2;

        // Đang đứng cào thì không tính là bị kẹt
        CopyVector(myPos, g_vLastPos[client]);
        g_fNextStuckCheck[client] = now + g_cvStuckTime.FloatValue;
        g_iStuckCount[client] = 0;
        return Plugin_Changed;
    }

    // ---- Đang né sang ngang để thoát kẹt ----
    if (now < g_fStrafeEnd[client])
    {
        vel[1] = g_fStrafeDir[client] * 450.0;
        buttons |= (g_fStrafeDir[client] > 0.0) ? IN_MOVERIGHT : IN_MOVELEFT;
    }

    bool wantJump = false;

    // ---- Phát hiện vật cản phía trước ----
    if (onGround)
    {
        int obstacle = CheckObstacle(client, myPos, ang[1]);
        if (obstacle == OBSTACLE_JUMP)
        {
            wantJump = true;
        }
        else if (obstacle == OBSTACLE_WALL && now >= g_fStrafeEnd[client])
        {
            StartStrafe(client, now, 0.6);
        }
    }

    // ---- Kiểm tra bị kẹt (gần như không di chuyển) ----
    if (now >= g_fNextStuckCheck[client])
    {
        float moved = HorizontalDistance(myPos, g_vLastPos[client]);
        if (moved < g_cvStuckDist.FloatValue)
        {
            g_iStuckCount[client]++;
            wantJump = true;

            // Nhảy mấy lần vẫn kẹt -> né sang ngang
            if (g_iStuckCount[client] >= 3)
            {
                StartStrafe(client, now, 0.75);
                g_iStuckCount[client] = 0;
            }
        }
        else
        {
            g_iStuckCount[client] = 0;
        }

        CopyVector(myPos, g_vLastPos[client]);
        g_fNextStuckCheck[client] = now + g_cvStuckTime.FloatValue;
    }

    // ---- Nhảy (crouch-jump để vượt vật cản cao hơn) ----
    if (wantJump && onGround && now >= g_fNextJump[client])
    {
        buttons |= IN_JUMP;
        g_fNextJump[client] = now + 0.6;
        g_fDuckEnd[client]  = now + 0.45;
    }

    if (!onGround && now < g_fDuckEnd[client])
        buttons |= IN_DUCK;

    return Plugin_Changed;
}

// ============================================================================
// Hàm hỗ trợ
// ============================================================================

void StartChase(int smoker, int victimUserId)
{
    float now = GetGameTime();

    g_bChasing[smoker]        = true;
    g_iTargetUserId[smoker]   = victimUserId;
    g_fChaseStart[smoker]     = now;
    g_fNextStuckCheck[smoker] = now + g_cvStuckTime.FloatValue;
    g_iStuckCount[smoker]     = 0;
    g_fStrafeEnd[smoker]      = 0.0;
    g_fNextJump[smoker]       = 0.0;
    g_fDuckEnd[smoker]        = 0.0;
    g_bMeleeToggle[smoker]    = false;
    GetClientAbsOrigin(smoker, g_vLastPos[smoker]);
}

void StopChase(int client)
{
    if (client < 1 || client > MaxClients)
        return;

    g_bChasing[client]      = false;
    g_iTargetUserId[client] = 0;
    g_iStuckCount[client]   = 0;
    g_fStrafeEnd[client]    = 0.0;
}

void ResetAll()
{
    for (int i = 1; i <= MaxClients; i++)
        StopChase(i);
}

void StartStrafe(int client, float now, float time)
{
    g_fStrafeEnd[client] = now + time;
    g_fStrafeDir[client] = (GetURandomInt() % 2 == 0) ? 1.0 : -1.0;
}

int GetChaseTarget(int smoker)
{
    int target = GetClientOfUserId(g_iTargetUserId[smoker]);
    if (IsValidChaseTarget(target))
        return target;

    if (!g_cvRetarget.BoolValue)
        return 0;

    // Tìm survivor gần nhất
    float myPos[3], pos[3];
    GetClientAbsOrigin(smoker, myPos);

    int best = 0;
    float bestDist = 0.0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidChaseTarget(i))
            continue;

        GetClientAbsOrigin(i, pos);
        float d = GetVectorDistance(myPos, pos);
        if (best == 0 || d < bestDist)
        {
            best = i;
            bestDist = d;
        }
    }

    g_iTargetUserId[smoker] = (best != 0) ? GetClientUserId(best) : 0;
    return best;
}

bool IsValidChaseTarget(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return false;
    if (GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
        return false;
    if (HasEntProp(client, Prop_Send, "m_isHangingFromLedge") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
        return false;
    return true;
}

bool IsBotSmoker(int client)
{
    return client > 0 && client <= MaxClients
        && IsClientInGame(client)
        && IsFakeClient(client)
        && GetClientTeam(client) == TEAM_INFECTED
        && IsPlayerAlive(client)
        && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_SMOKER
        && !GetEntProp(client, Prop_Send, "m_isGhost");
}

bool IsSmokerPinning(int client)
{
    return HasEntProp(client, Prop_Send, "m_tongueVictim")
        && GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0;
}

bool IsIncapped(int client)
{
    return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

bool IsTongueReady(int client)
{
    if (g_iOffsNextActivation <= 0)
        return false;

    int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (ability <= MaxClients || !IsValidEntity(ability))
        return false;

    // CountdownTimer: [vtable][m_duration][m_timestamp]
    float timestamp = GetEntDataFloat(ability, g_iOffsNextActivation + 8);
    return timestamp <= GetGameTime();
}

void CopyVector(const float src[3], float dst[3])
{
    dst[0] = src[0];
    dst[1] = src[1];
    dst[2] = src[2];
}

float HorizontalDistance(const float a[3], const float b[3])
{
    float dx = a[0] - b[0];
    float dy = a[1] - b[1];
    return SquareRoot(dx * dx + dy * dy);
}

/**
 * Dò vật cản phía trước theo hướng yaw.
 *  - Trace thấp (trên độ cao bậc thang) bị chặn, trace cao trống -> vật cản nhảy qua được
 *  - Cả hai đều bị chặn -> tường
 */
int CheckObstacle(int client, const float pos[3], float yaw)
{
    float dirAng[3], fwd[3];
    dirAng[1] = yaw;
    GetAngleVectors(dirAng, fwd, NULL_VECTOR, NULL_VECTOR);

    float look = g_cvLookAhead.FloatValue;
    float mins[3] = { -14.0, -14.0, 0.0 };
    float maxs[3] = {  14.0,  14.0, 10.0 };
    float start[3], end[3];

    // Trace thấp: bỏ qua bậc thang (step size ~18)
    start = pos;
    start[2] += 20.0;
    end[0] = start[0] + fwd[0] * look;
    end[1] = start[1] + fwd[1] * look;
    end[2] = start[2];

    Handle tr = TR_TraceHullFilterEx(start, end, mins, maxs, MASK_PLAYERSOLID, TraceFilter_World, client);
    bool hitLow = TR_DidHit(tr);
    float normal[3];
    if (hitLow)
        TR_GetPlaneNormal(tr, normal);
    delete tr;

    if (!hitLow)
        return OBSTACLE_NONE;

    // Dốc đi lên được thì không cần nhảy
    if (normal[2] > 0.7)
        return OBSTACLE_NONE;

    // Trace cao: ngang độ cao có thể nhảy tới
    start[2] = pos[2] + g_cvJumpHeight.FloatValue;
    end[2]   = start[2];

    tr = TR_TraceHullFilterEx(start, end, mins, maxs, MASK_PLAYERSOLID, TraceFilter_World, client);
    bool hitHigh = TR_DidHit(tr);
    delete tr;

    return hitHigh ? OBSTACLE_WALL : OBSTACLE_JUMP;
}

public bool TraceFilter_World(int entity, int contentsMask, any data)
{
    if (entity == data)
        return false;

    // Bỏ qua người chơi
    if (entity >= 1 && entity <= MaxClients)
        return false;

    // Bỏ qua zombie thường và witch
    if (entity > MaxClients && IsValidEdict(entity))
    {
        char cls[32];
        GetEdictClassname(entity, cls, sizeof(cls));
        if (StrEqual(cls, "infected") || StrEqual(cls, "witch"))
            return false;
    }
    return true;
}
