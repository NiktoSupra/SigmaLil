local _S = {
    active = true,
    maxRange = 50000,
    maxFOV = 20,
    scale = 10,
    rotSpeed = 30,
    smooth = 1
}

local function _R()
    local _L = LocalPlayer()
    if not IsValid(_L) then return end
    for _, _t in ipairs(player.GetAll()) do
        if _t == _L or not IsValid(_t) or not _t:IsPlayer() or not _t:Alive() then continue end
        local _pos = _t:GetPos()
        local _mn, _mx = _t:GetRenderBounds()
        local _top = _pos + Vector(0, 0, _mx.z)
        local _bot = _pos + Vector(0, 0, _mn.z)
        local _sT = _top:ToScreen()
        local _sB = _bot:ToScreen()
        if not _sT.visible or not _sB.visible then continue end
        local _x, _y = _sT.x, _sT.y
        local _h = _sB.y - _sT.y
        local _w = _h * 0.45
        local _dist = _L:GetPos():Distance(_t:GetPos())
        if _dist > _S.maxRange then continue end
        surface.SetDrawColor(30, 180, 80, 220)
        surface.DrawOutlinedRect(_x - _w/2, _y, _w, _h, 2)
        surface.SetDrawColor(20, 20, 20, 160)
        surface.DrawRect(_x - _w/2 - 8, _y, 5, _h)
        local _hp = _t:Health()
        local _mhp = _t:GetMaxHealth() or 100
        local _rat = math.Clamp(_hp / _mhp, 0, 1)
        local _c = _rat > 0.6 and Color(40, 220, 60) or (_rat > 0.3 and Color(240, 200, 40) or Color(240, 60, 60))
        surface.SetDrawColor(_c)
        surface.DrawRect(_x - _w/2 - 8, _y + (_h - _h * _rat), 5, _h * _rat)
        draw.SimpleText(string.format("%s | %d | %dm", _t:Nick(), _hp, math.Round(_dist)), "DermaDefault", _x, _y + _h + 6, Color(240, 240, 240, 230), TEXT_ALIGN_CENTER)
    end
end

local function _F()
    local now = CurTime()
    local sc = _S.scale * (ScrH() / 1080.0)
    local cx, cy = ScrW()/2, ScrH()/2
    local base_ang = math.rad(now * _S.rotSpeed * -1)
    local rgbSpd = 2.5
    local r = math.floor((math.sin(now * rgbSpd) + 1) * 127.5)
    local g = math.floor((math.sin(now * rgbSpd + 2.0944) + 1) * 127.5)
    local b = math.floor((math.sin(now * rgbSpd + 4.1888) + 1) * 127.5)
    surface.SetDrawColor(r, g, b, 255)
    local thickOffset = 1
    for i = 0, 3 do
        local ang = base_ang + i * math.pi / -2
        local cos_a = math.cos(ang)
        local sin_a = math.sin(ang)
        local segments = {{0,0, 6*sc,0}, {6*sc,0, 6*sc,6*sc}}
        for _, seg in ipairs(segments) do
            local x1,y1,x2,y2 = seg[1],seg[2],seg[3],seg[4]
            local dx,dy = x2-x1, y2-y1
            local len = math.sqrt(dx*dx+dy*dy)
            if len == 0 then continue end
            local nx,ny = -dy/len, dx/len
            for t = -thickOffset, thickOffset, 1 do
                local ox,oy = nx*t, ny*t
                surface.DrawLine(cx + x1*cos_a - y1*sin_a + ox, cy + x1*sin_a + y1*cos_a + oy, cx + x2*cos_a - y2*sin_a + ox, cy + x2*sin_a + y2*cos_a + oy)
            end
        end
    end
end

local function _I()
    local _p = LocalPlayer()
    if not IsValid(_p) then return end
    local _str = string.format("SYS: %s | NET: %dms | NODES: %d | FRAME: %d", _p:Nick(), _p:Ping(), player.GetCount(), math.Round(1/FrameTime()))
    draw.SimpleText(_str, "DermaDefault", ScrW()-12, ScrH()-32, Color(180, 220, 255, 200), TEXT_ALIGN_RIGHT)
end

local function GetClosestToCrosshair()
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    local shootPos = lp:GetShootPos()
    -- Беремо кут прицілу напряму з cmd буде точніше, але тут використовуємо EyeAngles
    local curAng = lp:EyeAngles()
    local bestTarget = nil
    local bestFOV = _S.maxFOV
    for _, p in ipairs(player.GetAll()) do
        if not IsValid(p) or not p:IsPlayer() or not p:Alive() then continue end
        if p == lp then continue end
        if lp:GetPos():Distance(p:GetPos()) > _S.maxRange then continue end
        local bone = p:LookupBone("ValveBiped.Bip01_Head1")
        local headPos = bone and p:GetBonePosition(bone) or p:GetPos() + Vector(0, 0, 64)
        local targetAng = (headPos - shootPos):Angle()
        local fov = math.abs(math.AngleDifference(curAng.p, targetAng.p))
                  + math.abs(math.AngleDifference(curAng.y, targetAng.y))
        if fov < bestFOV then
            bestFOV = fov
            bestTarget = p
        end
    end
    return bestTarget
end

local function GetHeadPos(target)
    -- Спочатку пробуємо кістку
    local bone = target:LookupBone("ValveBiped.Bip01_Head1")
    if bone then
        local bonePos = target:GetBonePosition(bone)
        -- Перевіряємо чи кістка повертає адекватну позицію
        -- (має бути близько до GetPos() по XY але вище по Z)
        local basePos = target:GetPos()
        local diff = bonePos - basePos
        if diff.z > 10 and diff.z < 200 then
            return bonePos  -- кістка адекватна
        end
    end
    -- Fallback: беремо реальну висоту з render bounds
    local _, mx = target:GetRenderBounds()
    return target:GetPos() + Vector(0, 0, mx.z * 0.9)
end

hook.Add("CreateMove", "v_aimbot_logic", function(cmd)
    if not _S.active then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() or not cmd then return end

    if input.IsKeyDown(KEY_F) then
        local target = GetClosestToCrosshair()
        if not (target and IsValid(target) and target:Alive() and target ~= lp) then return end

        local headPos = GetHeadPos(target)
        local targetAng = (headPos - lp:GetShootPos()):Angle()

        targetAng.p = math.Clamp(targetAng.p, -89, 89)
        targetAng.y = targetAng.y % 360
        targetAng.r = 0

        cmd:SetViewAngles(targetAng)
    end
end)


hook.Add("HUDPaint", "v_overlay_render", function()
    if not _S.active then return end
    _R()
    _F()
    _I()
end)

concommand.Add("v_toggle", function()
    _S.active = not _S.active
    print("[v_overlay] " .. (_S.active and "ON" or "OFF"))
end)
