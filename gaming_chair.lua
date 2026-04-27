local _S = {
    active = true,
    maxRange = 50000,
    maxFOV = 20,
    scale = 10,
    rotSpeed = 30,
    smooth = 1,

    aimMode = false,
    fovRadius = 150,
    debugTarget = nil,
    lastNDown = false,
    lastAttackDown = false
}

local function GetHeadPos(ply)
    local boneIndex = ply:LookupBone("ValveBiped.Bip01_Head1")
    if boneIndex then
        local bonePos = ply:GetBonePosition(boneIndex)
        if bonePos then return bonePos end
    end

    return ply:EyePos()
end

local function IsVisible(fromPos, toPos, ignoreEnt)
    local tr = util.TraceLine({
        start = fromPos,
        endpos = toPos,
        filter = ignoreEnt,
        mask = MASK_SOLID_BRUSHONLY
    })

    return not tr.Hit
end

local function GetScreenDistFromCenter(pos)
    local screenPos = pos:ToScreen()
    if not screenPos.visible then return math.huge end

    local cx, cy = ScrW() / 2, ScrH() / 2
    local dx = screenPos.x - cx
    local dy = screenPos.y - cy

    return math.sqrt(dx * dx + dy * dy)
end

local function GetClosestTargetToCrosshair()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return nil end

    local eyePos = lp:EyePos()
    local nearest = nil
    local bestDist = math.huge

    for _, ply in ipairs(player.GetAll()) do
        if ply == lp then continue end
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
        if lp:GetPos():Distance(ply:GetPos()) > _S.maxRange then continue end

        if _Kyle_Buildmode and _Kyle_Buildmode[ply] and _Kyle_Buildmode[ply].build then
            continue
        end

        local headPos = GetHeadPos(ply)

        local checkPoints = {
            headPos,
            ply:GetPos() + Vector(0, 0, 40),
            ply:GetPos() + Vector(0, 0, 10)
        }

        local visible = false

        for _, point in ipairs(checkPoints) do
            if IsVisible(eyePos, point, lp) then
                visible = true
                break
            end
        end

        if not visible then continue end

        local screenDist = GetScreenDistFromCenter(headPos)
        if screenDist > _S.fovRadius then continue end

        if screenDist < bestDist then
            bestDist = screenDist
            nearest = ply
        end
    end

    return nearest
end

local function DrawCircleOutline(x, y, radius, thickness, color)
    surface.SetDrawColor(color)
    draw.NoTexture()

    for i = 0, 360, 2 do
        local rad1 = math.rad(i)
        local rad2 = math.rad(i + 2)

        surface.DrawPoly({
            {
                x = x + math.cos(rad1) * (radius - thickness),
                y = y + math.sin(rad1) * (radius - thickness)
            },
            {
                x = x + math.cos(rad1) * radius,
                y = y + math.sin(rad1) * radius
            },
            {
                x = x + math.cos(rad2) * radius,
                y = y + math.sin(rad2) * radius
            },
            {
                x = x + math.cos(rad2) * (radius - thickness),
                y = y + math.sin(rad2) * (radius - thickness)
            }
        })
    end
end

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
        surface.DrawOutlinedRect(_x - _w / 2, _y, _w, _h, 2)

        surface.SetDrawColor(20, 20, 20, 160)
        surface.DrawRect(_x - _w / 2 - 8, _y, 5, _h)

        local _hp = _t:Health()
        local _mhp = _t:GetMaxHealth() or 100
        local _rat = math.Clamp(_hp / _mhp, 0, 1)

        local _c = _rat > 0.6 and Color(40, 220, 60)
            or (_rat > 0.3 and Color(240, 200, 40)
            or Color(240, 60, 60))

        surface.SetDrawColor(_c)
        surface.DrawRect(_x - _w / 2 - 8, _y + (_h - _h * _rat), 5, _h * _rat)

        draw.SimpleText(
            string.format("%s | %d | %dm", _t:Nick(), _hp, math.Round(_dist)),
            "DermaDefault",
            _x,
            _y + _h + 6,
            Color(240, 240, 240, 230),
            TEXT_ALIGN_CENTER
        )
    end
end

local function _F()
    local now = CurTime()
    local sc = _S.scale * (ScrH() / 1080.0)
    local cx, cy = ScrW() / 2, ScrH() / 2
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

        local segments = {
            {0, 0, 6 * sc, 0},
            {6 * sc, 0, 6 * sc, 6 * sc}
        }

        for _, seg in ipairs(segments) do
            local x1, y1, x2, y2 = seg[1], seg[2], seg[3], seg[4]
            local dx, dy = x2 - x1, y2 - y1
            local len = math.sqrt(dx * dx + dy * dy)

            if len == 0 then continue end

            local nx, ny = -dy / len, dx / len

            for t = -thickOffset, thickOffset, 1 do
                local ox, oy = nx * t, ny * t

                surface.DrawLine(
                    cx + x1 * cos_a - y1 * sin_a + ox,
                    cy + x1 * sin_a + y1 * cos_a + oy,
                    cx + x2 * cos_a - y2 * sin_a + ox,
                    cy + x2 * sin_a + y2 * cos_a + oy
                )
            end
        end
    end
end

local function _I()
    local _p = LocalPlayer()
    if not IsValid(_p) then return end

    local _str = string.format(
        "SYS: %s | NET: %dms | NODES: %d | FRAME: %d",
        _p:Nick(),
        _p:Ping(),
        player.GetCount(),
        math.Round(1 / FrameTime())
    )

    draw.SimpleText(
        _str,
        "DermaDefault",
        ScrW() - 12,
        ScrH() - 32,
        Color(180, 220, 255, 200),
        TEXT_ALIGN_RIGHT
    )
end


hook.Add("CreateMove", "v_aim_debug_logic", function(cmd)
    if not _S.active or not cmd then return end

    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end

    -- Toggle на N з debounce
    local nDown = input.IsKeyDown(KEY_N)

    if nDown and not _S.lastNDown then
        _S.aimMode = not _S.aimMode
        print("[v_overlay] aim debug " .. (_S.aimMode and "ON" or "OFF"))

        if not _S.aimMode then
            _S.debugTarget = nil
        end
    end

    _S.lastNDown = nDown

    if not _S.aimMode then return end

    local attackDown = bit.band(cmd:GetButtons(), IN_ATTACK) ~= 0
    local attackPressed = attackDown and not _S.lastAttackDown

    _S.lastAttackDown = attackDown

    -- Якщо ціль уже є і вона жива — тримаємо її
    if IsValid(_S.debugTarget) and _S.debugTarget:Alive() then
        -- Але якщо натиснув ЛКМ біля іншої цілі — пробуємо знайти нову
        if attackPressed then
            local newTarget = GetClosestTargetToCrosshair()

            if IsValid(newTarget) and newTarget ~= _S.debugTarget then
                _S.debugTarget = newTarget
            end
        end

        return
    end

    -- Якщо цілі немає/мертва — шукаємо тільки при новому натисканні ЛКМ
    if not attackPressed then return end

    local target = GetClosestTargetToCrosshair()

    if IsValid(target) then
        _S.debugTarget = target

        local headPos = GetHeadPos(target)
        local targetAng = (headPos - lp:EyePos()):Angle()

        -- Порожнє місце для дебагу.
        -- Тут НЕ викликається cmd:SetViewAngles(targetAng).
    end
end)

hook.Add("HUDPaint", "v_overlay_render", function()
    if not _S.active then return end

    _R()
    _F()
    _I()

    local cx, cy = ScrW() / 2, ScrH() / 2

    local ringColor = _S.aimMode
        and Color(100, 220, 255, 180)
        or Color(150, 150, 150, 70)

    DrawCircleOutline(cx, cy, _S.fovRadius, 2, ringColor)

    draw.SimpleText(
        "N AIM DEBUG: " .. (_S.aimMode and "ON" or "OFF"),
        "DermaDefaultBold",
        cx,
        cy + _S.fovRadius + 10,
        ringColor,
        TEXT_ALIGN_CENTER
    )

    if IsValid(_S.debugTarget) then
        local headPos = _S.debugTargetPos or GetHeadPos(_S.debugTarget)
        local screenPos = headPos:ToScreen()

        if screenPos.visible then
            surface.SetDrawColor(255, 80, 80, 230)
            surface.DrawLine(cx, cy, screenPos.x, screenPos.y)

            draw.SimpleText(
                _S.debugTarget:Nick(),
                "DermaDefaultBold",
                screenPos.x,
                screenPos.y - 16,
                Color(255, 80, 80, 230),
                TEXT_ALIGN_CENTER
            )
        end
    end
end)

concommand.Add("v_toggle", function()
    _S.active = not _S.active
    print("[v_overlay] " .. (_S.active and "ON" or "OFF"))
end)