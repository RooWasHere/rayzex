--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

--// Variables
local localPlayer = Players.LocalPlayer
local mainHandler = { instance = nil, senv = nil }
local namecall = nil
local waitTable = {}
local toggle = {
    using = false,
    blocking = { false, 0, 0 },
    dashing = { false },
    healing = { false },
    grappling = { false }
}

local activeStat = {
    def = { func = nil, upvalue = 0 },
    mvt = { func = nil, upvalue = 0 },
}

--// Animation
local TPanimSets = ReplicatedStorage.animationSets.TPanimSets
TPanimSets.global.shove.AnimationId = TPanimSets["2H"].final.AnimationId
TPanimSets.global.run.AnimationId = TPanimSets.global.runOLD.AnimationId
TPanimSets.global.low_walk.AnimationId = TPanimSets.global.runOLD.AnimationId
TPanimSets.global.low_idle.AnimationId = TPanimSets.global.idle.AnimationId

--// Functions
function spawnItem(itemName, slot)
    local inventory = getupvalue(mainHandler.senv.start_dual_wield, 3)
    local function spawn(use)
        if inventory[slot][1] ~= itemName then
            if workspace.InteractablesNoDel:FindFirstChild("Personal Workbench") ~= nil then
                repeat
                    ReplicatedStorage.Interactables.interaction:FireServer(workspace.InteractablesNoDel["Personal Workbench"], "buybaseupgrade", _G.serverKey)
                    RunService.Heartbeat:Wait()
                until workspace.InteractablesNoDel:FindFirstChild("Workbench") ~= nil
            end

            local workbench = workspace.InteractablesNoDel:FindFirstChild("Workbench") or workspace.Interactables:FindFirstChild("Workbench")
            if workbench:FindFirstChild("stats") == nil then
                return
            end

            ReplicatedStorage.Interactables.interaction:FireServer(workbench, "workbenchblueprint" .. itemName, _G.playerKey)
            repeat RunService.Heartbeat:Wait() until workbench.stats.blueprint.Value == itemName

            ReplicatedStorage.Interactables.interaction:FireServer(workbench, "workbench", _G.playerKey)

            local self = nil
            self = workspace.WeaponDrops.ChildAdded:Connect(function(item)
                if item.Name == itemName and (item:GetPivot().Position - workbench:GetPivot().Position).Magnitude <= 20 then
                    if inventory[slot][1] ~= "Fist" then
                        inventory[slot] = {"Fist", false, nil}
                    end

                    local lastPosition = localPlayer.Character:GetPivot()
                    repeat
                        localPlayer.Character:PivotTo(item:GetPivot() + Vector3.new(0, 5, 0))
                        workspace.ServerStuff.claimItem:InvokeServer(item)

                        RunService.Heartbeat:Wait()
                    until localPlayer.Character.valids:FindFirstChild(itemName) ~= nil

                    local animSet = nil
                    for _, v in pairs(ReplicatedStorage.animationSets.TPanimSets:GetChildren()) do
                        if v.Name == require(workspace.ServerStuff.Statistics.W_STATISTICS)[itemName].animset then
                            animSet = v
                        end
                    end

                    repeat
                        if use == nil then
                            workspace.ServerStuff.getTPWeapon:FireServer(itemName, animSet, "Fist", item, true)
                        else
                            workspace.ServerStuff.getTPWeapon:FireServer(itemName, animSet, "Fist", item, false)
                        end

                        RunService.Heartbeat:Wait()
                    until workspace.WeaponDrops:FindFirstChild(item) == nil

                    localPlayer.Character:PivotTo(lastPosition)
                    inventory[slot] = {itemName, false, nil}

                    self:Disconnect(); self = nil
                end
            end)
        end
    end

    for index, value in pairs(require(workspace.ServerStuff.Statistics.W_STATISTICS)) do
        if string.match(string.lower(index), string.lower(itemName)) ~= nil then
            itemName = index

            local use = nil
            if value.weapontype == "Item" or value.weapontype == "Bow" or value.weapontype == "Gun" then
                if ReplicatedStorage.Weapons:FindFirstChild(index) then
                    use = ReplicatedStorage.Weapons[index].ammo.Value
                end

                if slot == nil then
                    for inventorySlot, content in pairs(inventory) do
                        if inventorySlot ~= 1 and content[1] == "Fist" then
                            slot = inventorySlot
                            break
                        end
                    end
                end
            end

            if localPlayer.Character.valids:FindFirstChild(itemName) ~= nil then
                inventory[slot] = {itemName, false, use}
            else
                spawn(use)
            end

            repeat RunService.Heartbeat:Wait() until inventory[slot][1] == itemName and localPlayer.PlayerGui.mainHUD:FindFirstChild("InventoryFrame") ~= nil
            mainHandler.senv.invmanage("updatehud")

            break
        end
    end
end

function damage(character, damage)
    if character:FindFirstChildOfClass("Humanoid").Health <= 0 then
        return
    end

    local changeToRevolver = coroutine.create(function()
        local originalPerk = localPlayer.Character:FindFirstChild("current_perk").Value
        if originalPerk ~= nil and originalPerk ~= "revolver" then
            workspace.ServerStuff.changeStats:InvokeServer("changeclass", "revolver")
            coroutine.yield()
            workspace.ServerStuff.changeStats:InvokeServer("changeclass", originalPerk)
        end
    end)
    coroutine.resume(changeToRevolver)

    local activestat = require(workspace.ServerStuff.Statistics.CLASS_STATISTICS).revolver.activestats
    activestat._revolver_damage = activestat.revolver_damage
    activestat._revolver_headshot_multi = activestat.revolver_headshot_multi
    activestat.revolver_damage = damage
    activestat.revolver_headshot_multi = 0

    workspace.ServerStuff.dealDamage:FireServer("revolver_shot", { character, damage }, _G.serverKey, _G.playerKey)
    coroutine.resume(changeToRevolver)

    activestat.revolver_damage = activestat._revolver_damage
    activestat.revolver_headshot_multi = activestat._revolver_headshot_multi
    activestat._revolver_damage = nil
    activestat._revolver_headshot_multi = nil
end

function getActiveStat()
    if mainHandler.senv.maingui:FindFirstChild("devbox") == nil then
        local devbox = Instance.new("Frame")
        devbox.Size = UDim2.new(0, 0)
        devbox.BackgroundTransparency = 0
        devbox.BorderSizePixel = 0
        devbox.Parent = mainHandler.senv.maingui
        devbox.Name = "devbox"

        local devlabel1 = Instance.new("TextLabel")
        devlabel1.Size = UDim2.new(0, 0)
        devlabel1.BackgroundTransparency = 0
        devlabel1.BorderSizePixel = 0
        devlabel1.TextSize = 0
        devlabel1.Parent = devbox
        devlabel1.Name = "devlabel1"

        local devlabel2 = Instance.new("TextLabel")
        devlabel2.Size = UDim2.new(0, 0)
        devlabel2.BackgroundTransparency = 0
        devlabel2.BorderSizePixel = 0
        devlabel2.TextSize = 0
        devlabel2.Parent = devbox
        devlabel2.Name = "devlabel2"

        local devlabel3 = Instance.new("TextLabel")
        devlabel3.Size = UDim2.new(0, 0)
        devlabel3.BackgroundTransparency = 0
        devlabel3.BorderSizePixel = 0
        devlabel3.TextSize = 0
        devlabel3.Parent = devbox
        devlabel3.Name = "devlabel3"

        while devlabel1.Text == "" or devlabel2.Text == "" or devlabel3.Text == "" do
            RunService.Heartbeat:Wait()
        end
    end

    local found = false
    while found == false do
        for _, functions in pairs(getreg()) do
            if type(functions) == "function" and getfenv(functions).script and getfenv(functions).script == mainHandler.instance then
                local upvalues = getupvalues(functions)

                for i, v in pairs(upvalues) do
                    if type(v) == "number" then
                        if tostring(v) == string.sub(mainHandler.senv.maingui.devbox.devlabel1.Text, 7, -1) or tostring(v) == string.sub(mainHandler.senv.maingui.devbox.devlabel2.Text, 7, -1) or tostring(v) == string.sub(mainHandler.senv.maingui.devbox.devlabel3.Text, 14, -1) then
                            local random = math.random(-20, -10)
                            local old = v

                            setupvalue(functions, i, random)
                            RunService.Heartbeat:Wait()

                            if string.sub(mainHandler.senv.maingui.devbox.devlabel2.Text, 7, -1) == tostring(random) then
                                activeStat.def = {
                                    func = functions,
                                    upvalue = i,
                                }

                                found = true
                            end

                            if string.sub(mainHandler.senv.maingui.devbox.devlabel3.Text, 14, -1) == tostring(random) then
                                activeStat.mvt = {
                                    func = functions,
                                    upvalue = i,
                                }

                                found = true
                            end

                            setupvalue(functions, i, old)
                        end
                    end
                end
            end
        end

        RunService.Heartbeat:Wait()
    end
end

local function start()
    for _, instance in ipairs(localPlayer.Backpack:GetChildren()) do
        if instance:IsA("LocalScript") and instance.Name ~= "ClickDetectorScript" then
            repeat
                mainHandler.instance = instance
                mainHandler.senv = getsenv(mainHandler.instance)
                RunService.Heartbeat:Wait()
            until mainHandler.senv.afflictstatus ~= nil and mainHandler.senv.unloadgun ~= nil and mainHandler.senv.ration_system_handler ~= nil

            for index, upvalue in ipairs(getupvalues(mainHandler.senv.afflictstatus)) do
                if typeof(upvalue) == "number" then
                    for _, key in pairs(getrenv()._G) do
                        if upvalue == key then
                            _G.serverKey = upvalue
                        end
                    end
                end

                if upvalue == _G.serverKey then
                    _G.playerKey = getupvalue(mainHandler.senv.afflictstatus, index + 1)
                    break
                end
            end
        end
    end

    spawnItem("RBHammer", 1)
    getActiveStat()

    workspace.ServerStuff.dropAmmo:FireServer("scrap", 90)
    _G.connection[5] = workspace.Interactables.ChildAdded:Connect(function(instance)
        if instance.Name == "Salvage Pack" then
            repeat RunService.Heartbeat:Wait() until instance:FindFirstChild("stats") ~= nil
            if instance.stats.scrap.Value == 90 then
                ReplicatedStorage.Interactables.interaction:FireServer(instance, "getScrap", _G.serverKey)
                _G.connection[5]:Disconnect()
            end
        end
    end)

    setupvalue(activeStat.mvt.func, activeStat.mvt.upvalue, 9)

    local ammo = getupvalues(mainHandler.senv.unloadgun)[7]
    ammo.Small = 200
    ammo.Shells = 200
    ammo.Long = 200
    ammo.Short = 200
    ammo.Heavy = 200
    ammo.Medium = 200
    ammo.Light = 200

    local ration = mainHandler.senv.ration_system_handler
    ration.Soda = 25
    ration.Bottle = 25
    ration.Beans = 50
    ration.MRE = 50
    ration.hunger = math.huge
    ration.thirst = math.huge

    _G.connection[3] = RunService.RenderStepped:Connect(function()
        if workspace.GamemodeStuff:FindFirstChild("outerGas") ~= nil then
            workspace.GamemodeStuff.outerGas:Destroy()
        end
    end)

game.Players.LocalPlayer.Character.Humanoid.Died:Connect(function()
workspace.ServerStuff.playAudio:FireServer({"AGENT", "hvt"}, "hvt3", workspace)
workspace.ServerStuff.playAudio:FireServer({"AGENT", "hvt"}, "hvt3", workspace)
workspace.ServerStuff.dropAmmo:FireServer("scrap", 550)
for i=1,5 do
workspace.ServerStuff.dropAmmo:FireServer("rations", "Soda")
workspace.ServerStuff.dropAmmo:FireServer("rations", "Bottle")
workspace.ServerStuff.dropAmmo:FireServer("rations", "Beans")
workspace.ServerStuff.dropAmmo:FireServer("rations", "Bottle")
end
wait(0.45)
local playerAnimation = game.Players.LocalPlayer.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.animationSets.TPanimSets["global"].fallen)
playerAnimation.Priority = Enum.AnimationPriority.Action
playerAnimation:Play()
playerAnimation:AdjustSpeed(0.65)
task.wait(2.5)
for i=1,30 do
local playerAnimation = game.Players.LocalPlayer.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.animationSets.TPanimSets["global"].fallen)
playerAnimation.Priority = Enum.AnimationPriority.Action
playerAnimation:Play()
playerAnimation.TimePosition = 1.65
playerAnimation:AdjustSpeed(0.45)
task.wait(0.5)
end
end)
end

--// Set up
if _G.connection ~= nil then
    for _, connection in ipairs(_G.connection) do
        connection:Disconnect()
    end
end
_G.connection = {}

start()

--// Keybinds
_G.connection[1] = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent == true then
        return
    end

    if localPlayer.Character ~= nil then
        if input.KeyCode == Enum.KeyCode.R then
            if localPlayer.Character:FindFirstChild("hasPrimary") ~= nil and localPlayer.Character.hasPrimary:FindFirstChild("RBHammer") ~= nil then
                if toggle.using == true then
                    return
                end

                toggle.blocking[1] = true

                getupvalue(mainHandler.senv.drop_slide, 1).action = true
                getupvalue(mainHandler.senv.drop_slide, 1).blocking = true
                getupvalue(mainHandler.senv.drop_slide, 1).cancombo = false
                
                workspace.ServerStuff.playAudio:FireServer({ "general" }, "blockraise", localPlayer.Character.PrimaryPart)
                workspace.ServerStuff.initiateblock:FireServer(_G.serverKey, true)

                toggle.blocking[4] = localPlayer.Character.Humanoid.Animator:LoadAnimation(ReplicatedStorage.animationSets.TPanimSets["2H"].bulletblock)
                toggle.blocking[4].Priority = Enum.AnimationPriority.Action
                toggle.blocking[4]:Play(.1)
                toggle.blocking[4].TimePosition = .3
                toggle.blocking[4]:AdjustSpeed(0)

                toggle.blocking[5] = workspace.CurrentCamera.FPArms.AC.Animator:LoadAnimation(ReplicatedStorage.animationSets["1HS"].block)
                toggle.blocking[5].Priority = Enum.AnimationPriority.Action
                toggle.blocking[5]:Play(.15)
                toggle.blocking[5]:AdjustSpeed(0)

                toggle.blocking[2] = localPlayer.Character.Humanoid.Health
                toggle.blocking[3] = getupvalue(activeStat.def.func, activeStat.def.upvalue)

                setupvalue(activeStat.def.func, activeStat.def.upvalue, math.huge)

                toggle.blocking[6] = localPlayer.Character.Humanoid.HealthChanged:Connect(function(health)
                    if health < toggle.blocking[2] then
                        if toggle.blocking[2] - health >= 10 then
                            local integral = math.modf((toggle.blocking[2] - localPlayer.Character.Humanoid.Health) / 8)
                            for _ = 1, integral do
                                workspace.ServerStuff.dealDamage:FireServer("lazarusheal", 8, _G.serverKey, _G.playerKey)
                            end

                            if toggle.blocking[2] - (integral * 8) > 0 then
                                workspace.ServerStuff.dealDamage:FireServer("lazarusheal", (toggle.blocking[2] - localPlayer.Character.Humanoid.Health) - (integral * 8), _G.serverKey, _G.playerKey)
                            end
                        end
                        workspace.ServerStuff.applyGore:FireServer("gunricochet", localPlayer.Character, localPlayer, { localPlayer.Character.hasPrimary.MMachete:GetPivot().Position })
                    end
                end)
            end
        end

        if input.KeyCode == Enum.KeyCode.J then
            if toggle.healing[1] == true or toggle.using == true then
                return
            end
            toggle.healing[1] = true
            toggle.using = true

            getupvalue(mainHandler.senv.drop_slide, 1).action = true
            getupvalue(mainHandler.senv.drop_slide, 1).using_perk = true

            local startupAnimation = workspace.CurrentCamera.FPArms.AC.Animator:LoadAnimation(ReplicatedStorage.animationSets.global.stun)
            startupAnimation.Priority = Enum.AnimationPriority.Action

            local serumAnimation = localPlayer.Character.Humanoid.Animator:LoadAnimation(ReplicatedStorage.animationSets.TPanimSets.global.perk_calamity)
            serumAnimation.Priority = Enum.AnimationPriority.Action

            local viewmodelAnimation = workspace.CurrentCamera.FPArms.AC.Animator:LoadAnimation(ReplicatedStorage.animationSets.global.perk_calamity)
            viewmodelAnimation.Priority = Enum.AnimationPriority.Action

            local serum = ReplicatedStorage.perkAbilities.calamserum:Clone()
            local perk = localPlayer.Character:FindFirstChild("current_perk").Value

            coroutine.wrap(function()
                workspace.ServerStuff.changeStats:InvokeServer("changeclass", "berz")
            end)

            _G.connection[3] = startupAnimation.KeyframeReached:Connect(function(keyframeName)
                if keyframeName == "Stop" then
                    startupAnimation:AdjustSpeed(0)
                end
            end)
            startupAnimation:Play(.1)
            task.wait(.2)

            startupAnimation:Stop()
            _G.connection[3]:Disconnect()

            serum.Cap.Transparency = 0
            task.delay(.12, function()
                workspace.ServerStuff.playAudio:FireServer({"perks"}, "calamity_stim", localPlayer.Character.PrimaryPart)
                task.delay(.1, function()
                    serum.CapWeld:Destroy()
                    RunService.Heartbeat:Wait()
                    serum.Cap.Velocity = serum.Cap.CFrame.UpVector * 20
                end)
            end)

            workspace.ServerStuff.playAudio:FireServer({"weapons", "2HB"}, "draw", localPlayer.PlayerGui)
            serumAnimation:Play(.1)

            workspace.ServerStuff.handlePerkVisibility:FireServer("calamserum")

            local motor6D = Instance.new("Motor6D")
            motor6D.Part0 = workspace.CurrentCamera.FPArms.LeftArm.LUpperArm
            motor6D.Part1 = serum
            motor6D.Parent = serum
            serum.Parent = workspace.CurrentCamera

            _G.connection[4] = viewmodelAnimation.KeyframeReached:Connect(function(keyframeName)
                if keyframeName == "activate_Perk" then
                    workspace.ServerStuff.playAudio:FireServer({"ai"}, "healfx", localPlayer.Character.PrimaryPart)

                    repeat
                        workspace.ServerStuff.dealDamage:FireServer("Regeneration", nil, _G.serverKey, _G.playerKey)
                        RunService.Heartbeat:Wait()
                    until localPlayer.Character.Humanoid.Health >= localPlayer.Character.Humanoid.MaxHealth
                    _G.connection[4]:Disconnect()
                end
            end)

            viewmodelAnimation:Play(.03)
            viewmodelAnimation.Stopped:Wait()

            getupvalue(mainHandler.senv.drop_slide, 1).action = false
            getupvalue(mainHandler.senv.drop_slide, 1).using_perk = false
            toggle.using = false

            workspace.ServerStuff.handlePerkVisibility:FireServer("hide_perk")
            serum:Destroy()

            coroutine.wrap(function()
                workspace.ServerStuff.changeStats:InvokeServer("changeclass", perk)
            end)

            task.wait(45)
            toggle.healing[1] = false
        end

        if input.KeyCode == Enum.KeyCode.Q then
        localPlayer.Character.HumanoidRootPart.Anchored = true
        local playerAnimation = game.Players.LocalPlayer.Character.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.animationSets.TPanimSets["2H"].final)
        playerAnimation.Priority = Enum.AnimationPriority.Action
        playerAnimation:Play()
        task.wait(0.1)
        workspace.ServerStuff.playAudio:FireServer({"weapons", "2H"}, "chargeswing", game.Players.LocalPlayer.Character.HumanoidRootPart)
        localPlayer.Character.HumanoidRootPart.Anchored = false
        end
        
        if input.KeyCode == Enum.KeyCode.E then
        local playerAnimation = game.Players.LocalPlayer.Character.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.animationSets.TPanimSets["2H"].grapple)
        playerAnimation.Priority = Enum.AnimationPriority.Action
        playerAnimation:Play()
        playerAnimation:AdjustSpeed(0.75)
        task.wait(0.3)
        workspace.ServerStuff.playAudio:FireServer({"general"}, "shove", game.Players.LocalPlayer.Character.HumanoidRootPart)
        end
        
        if input.KeyCode == Enum.KeyCode.V then
            localPlayer.Character.HumanoidRootPart.Anchored = true
            workspace.ServerStuff.playAudio:FireServer({"shadow"}, "chainbreak", workspace)
            workspace.ServerStuff.playAudio:FireServer({"shadow"}, "chainbreak", workspace)
            local playerAnimation = localPlayer.Character.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.animationSets.TPanimSets["global"].fallen)
            playerAnimation.Priority = Enum.AnimationPriority.Action
            playerAnimation:Play()
            playerAnimation:AdjustSpeed(0.65)
            task.wait(2.5)
            for i=1,30 do
            local playerAnimation = localPlayer.Character.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.animationSets.TPanimSets["global"].fallen)
            playerAnimation.Priority = Enum.AnimationPriority.Action
            playerAnimation:Play()
            playerAnimation.TimePosition = 1.65
            playerAnimation:AdjustSpeed(0.45)
            task.wait(0.5)
            end
            workspace.ServerStuff.playAudio:FireServer({"gamemode"}, "juggernaut", workspace)
            local playerAnimation = localPlayer.Character.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.animationSets.TPanimSets["special"].getup)
            playerAnimation.Priority = Enum.AnimationPriority.Action
            playerAnimation:Play()
            game:GetService("StarterGui"):SetCore("SendNotification",{
            Title = "Rayzen",
            Text = "WAKE UP.",
            })
            task.wait(1.2)
            localPlayer.Character.HumanoidRootPart.Anchored = false
        end

        if input.KeyCode == Enum.KeyCode.B then
        workspace.ServerStuff.deathPlay:FireServer()
        end
    end
end)

_G.connection[2] = UserInputService.InputEnded:Connect(function(input, _)
    if input.KeyCode == Enum.KeyCode.R then
        if toggle.blocking[1] == true and toggle.blocking[4] ~= nil and toggle.blocking[5] ~= nil then
            toggle.blocking[1] = false

            getupvalue(mainHandler.senv.drop_slide, 1).action = false
            getupvalue(mainHandler.senv.drop_slide, 1).blocking = false
            getupvalue(mainHandler.senv.drop_slide, 1).cancombo = true

            workspace.ServerStuff.initiateblock:FireServer(_G.serverKey, false)

            toggle.blocking[4]:Stop(.1)
            toggle.blocking[5]:Stop(.15)

            toggle.blocking[6]:Disconnect()
            toggle.blocking[6] = nil

            setupvalue(activeStat.def.func, activeStat.def.upvalue, toggle.blocking[3])

            if localPlayer.Character.Humanoid.Health < toggle.blocking[2] then
                local integral = math.modf((toggle.blocking[2] - localPlayer.Character.Humanoid.Health) / 8)
                for _ = 1, integral do
                    workspace.ServerStuff.dealDamage:FireServer("lazarusheal", 8, _G.serverKey, _G.playerKey)
                end

                if toggle.blocking[2] - (integral * 8) > 0 then
                    workspace.ServerStuff.dealDamage:FireServer("lazarusheal", (toggle.blocking[2] - localPlayer.Character.Humanoid.Health) - (integral * 8), _G.serverKey, _G.playerKey)
                end
            end
        end
    end
end)

workspace.ServerStuff.playAudio:FireServer({"holdout"}, "holdout_incoming", workspace)
wait(0.8)
workspace.ServerStuff.playAudio:FireServer({"AGENT", "heavy"}, "heavy1", workspace)
task.wait(3)
workspace.ServerStuff.playAudio:FireServer({"events"}, "missilearrive", workspace)
task.wait(3)
workspace.ServerStuff.playAudio:FireServer({"events"}, "shiparrive2", workspace)
task.wait(3.5)
workspace.ServerStuff.playAudio:FireServer({"gamemode"}, "dooropen", workspace)
task.wait(2)
local ohString1 = "player_ping"
local ohInstance2 = game.Workspace.activePlayers --this doesn't do anything
local ohInstance3 = nil -- same
local ohTable4 = {
    [1] = Vector3.new(21.761, 23.441, -8.3437), -- you can put in some positions
    [2] = "ALL CONTESTANTS WILL BE ELIMINATED.",
    [3] = 2 -- this handles the icon of ping, if 6 or higher icon will be hidden
}

workspace.ServerStuff.applyGore:FireServer(ohString1, ohInstance2, ohInstance3, ohTable4)
workspace.ServerStuff.playAudio:FireServer({"holdout", "boss_sounds"}, "sledge", workspace)
task.wait(3)
workspace.ServerStuff.playAudio:FireServer({"gamemode"}, "juggernaut", workspace)

_G.stats = {
    health    = 0,
    maxhealth = 0,
    stamina   = 100,
    name      = "Rayzen",
    imgs = {
        "7239401851",
        "7239401851",
        "7239401851",
        "7239401851",
        "7239401851",
    }, --ALWAYS MUST HAVE 5 STRINGS!
    items = {{{"Fists",true},{"Fists",false},{"Fists",false}}}
}


if _G.runningonthegonamechanged==nil then 
_G.runningonthegonamechanged=true 
game:GetService("RunService").RenderStepped:Connect(function()
    workspace.ServerStuff.relayStats.OnClientInvoke=function()
        return{
            _G.stats.health,
            _G.stats.stamina,
            {["Bleed"]={["mainstats"]={["name"]="Bleed",["intensity"]=4,["icon"]=_G.stats.imgs[1],["dur"]=100000,["ints"]={1.75,1.5,1,0.75},["desc"]="Deals1damageevery1.75/1.5/1/0.75secondstotheopponentfor10seconds."},["effects"]={["maxduration"]=10,["currentduration"]=1598560464.4934,["currentpos"]=0,["ticks"]={1598560466.7909}}},["1Bleed"]={["mainstats"]={["name"]="1Bleed",["intensity"]=4,["icon"]=_G.stats.imgs[2],["dur"]=10,["ints"]={1.75,1.5,1,0.75},["desc"]="Deals1damageevery1.75/1.5/1/0.75secondstotheopponentfor10seconds."},["effects"]={["maxduration"]=10,["currentduration"]=1598560464.4934,["currentpos"]=0,["ticks"]={1598560466.7909}}},["2Bleed"]={["mainstats"]={["name"]="2Bleed",["intensity"]=4,["icon"]=_G.stats.imgs[3],["dur"]=10,["ints"]={1.75,1.5,1,0.75},["desc"]="Deals1damageevery1.75/1.5/1/0.75secondstotheopponentfor10seconds."},["effects"]={["maxduration"]=10,["currentduration"]=1598560464.4934,["currentpos"]=0,["ticks"]={1598560466.7909}}},["3Bleed"]={["mainstats"]={["name"]="3Bleed",["intensity"]=4,["icon"]=_G.stats.imgs[4],["dur"]=10,["ints"]={1.75,1.5,1,0.75},["desc"]="Deals1damageevery1.75/1.5/1/0.75secondstotheopponentfor10seconds."},["effects"]={["maxduration"]=10,["currentduration"]=1598560464.4934,["currentpos"]=0,["ticks"]={1598560466.7909}}},["4Bleed"]={["mainstats"]={["name"]="4Bleed",["intensity"]=4,["icon"]=_G.stats.imgs[5],["dur"]=10,["ints"]={1.75,1.5,1,0.75},["desc"]="Deals1damageevery1.75/1.5/1/0.75secondstotheopponentfor10seconds."},["effects"]={["maxduration"]=10,["currentduration"]=1598560464.4934,["currentpos"]=0,["ticks"]={1598560466.7909}}}},
            false,
            {
                _G.stats.speed,
                1,
                1
            },
            _G.stats.maxhealth,
            _G.stats.name,
            _G.stats.items}
        end;
    end)
end

local localPlayer2 = game:GetService("Players").LocalPlayer
local distance = 4

workspace.NoTarget.ChildAdded:Connect(function(instance)
    if instance.Name == "bloodfxtrail" then
        if (instance.CFrame.Position - localPlayer2.Character:GetPivot().Position).Magnitude <= distance then
            workspace.ServerStuff.applyGore:FireServer("gunricochet", localPlayer2.Character, localPlayer2, { instance.Position })
        end
    end
end)

--// Hooking
namecall = hookfunction(getrawmetatable(game).__namecall, newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "FireServer" then
        if self.Name == "dealDamage" then
            if typeof(args[1]) == "table" then
                if args[1][2] ~= nil and args[1][3] ~= "shove" then
                    coroutine.wrap(damage)(args[1][2], args[1][3])
                end
            end
        end

        if self.Name == "dealDamage" then
            if typeof(args[1]) == "table" then
                if args[1][3] ~= "shove" then
                    coroutine.wrap(damage)(args[1][2], 60)
                end
            end
        end

        if self.Name == "playAudio" then
            if args[1][1] == "movement_sounds" then
                return true
            end
        end
        
        if self.Name == "playAudio" and args[2] == "shove" then
             return true
        end
    end

        if self.Name == "initiateblock" then
            if toggle.blocking[1] == true and args[2] == false then
                return true
            end
        end

        if self.Name == "BREATHE" then
            return true
        end

    if method == "Kick" then
        return true
    end

    return namecall(self, ...)
end))