--[[
           db          ad88
          d88b        d8"
         d8'`8b       88
        d8'  `8b    MM88MMM  ,adPPYba,
       d8YaaaaY8b     88    a8"     "8a
      d8""""""""8b    88    8b       d8
     d8'        `8b   88    "8a,   ,a8"
    d8'          `8b  88     `"YbbdP"'
--]]
-- [!] Declare required imports before module is destroyed
local Packages = script:WaitForChild("packages")
local LuaVM = require(Packages:WaitForChild("lua_vm"))
local Helpers = require(Packages:WaitForChild("util"))
local Logging = require(Packages:WaitForChild("logging"))
-- [!] To optimize speed, declare all functions within the coroutine scope
return coroutine.wrap(function(...)
    local Version, ExecArgs, Offset, CommonKey = ... -- TODO: security?
    local IsStableBuild = Version:match("%d+%.%d+%.%d+%.%d+$")
    local shared = setmetatable({}, {
        __metatable = "The metatable is locked"
    }) -- A blank slate, w/o an ~~accessable~~ metatable
    local ModuleIndex = {}
    local ProxyScript = Instance.new("LocalScript") -- identity theft
    ProxyScript.Name = "RovilEngine"
    ProxyScript.Parent = game:GetService("ReplicatedFirst")
    -- Logging logging logging
    local Log = Logging.new({
        Prefix = "Rovil/Client",
        Source = ProxyScript
    })
    -- Chop chop! We're on a schedule here, people
    local StartTick = tick()
    -- Debugging for testing builds of the engine
    local function WriteDebug(...)
        if not IsStableBuild then
            return Log:Info(..., "(@" .. tostring(tick() - StartTick) .. "s)")
        else
            -- TODO: Silently log debug info (on stable builds)
        end
    end
    -- Let e'eryone know we're starting up
    Log:Print("Client initialization begin")
    local Debris = game:GetService("Debris")
    -- Me when
    local LocalPlayer = game:GetService("Players").LocalPlayer
    -- This is the virtual environment we will apply to every script.
    -- The important thing here is the "shared" replacement.
    -- Because I have yet to figure out a way to support require()-ing modules,
    -- any + all oop/modular code will need to be fed through shared
    local VirtualEnv = {
        shared = shared,
        _G = _G,
        __debug = 0, __is_debug = 0,
        __release = 1,  __is_release = 1,
        __engine_version = Version,
        __is_stable_release = IsStableBuild, __is_stable = IsStableBuild
        -- TODO: Possibly add C interoperability? e.g. Classic lua_pushnumber/string/value
        -- would take a bit of VM modification but shouldn't be too hard
        -- can not think of a good usecase for this though, so it will sit on the backburner.
    }
    -- The funny function that actually loads our scripts into memory and runs them
    local function LoadScript(Script)
        local ScriptName = Script:GetFullName()
        if Script:IsA("ModuleScript") and Script.Name:match("^#") then -- A "#" delimiter at the beginning of a script's name means it was compiled
            local Instructions = require(Script)
            if typeof(Instructions) ~= "table" or #Instructions < 1 then -- EXTREMELY limited sanity check; better than nothing
                Log:Error(ScriptName, "flagged as compiled, but contains invalid/unreadable instructions")
            else
                WriteDebug("NOTICE: Preparing to load script \"" .. ScriptName .. "\"")
                local IsModule = Instructions[1] == 0
                if IsModule then
                    WriteDebug("NOTICE: Script \"" .. ScriptName .. "\" is a module")
                end
                local Success, Bytecode = pcall(Helpers.InstructionsToBytecode, Instructions, Offset)
                if Success and typeof(Bytecode) == "string" then -- Make sure bytecode exists
                    local Success, Func = pcall(LuaVM.LoadBytecode, Bytecode)
                    if Success and typeof(Func) == "function" then -- Make sure we got a function
                        -- Make a skeleton copy of the script
                        -- (except it's a LocalScript now lolol)
                        local SkeleScript = Instance.new("LocalScript")
                        SkeleScript.Name = Script.Name:gsub("^#", "")
                        SkeleScript.Parent = Script.Parent
                        -- Move the children of original to our copy
                        for _, Child in ipairs(Script:GetChildren()) do
                            pcall(function()
                                Child.Parent = SkeleScript
                            end)
                        end
                        -- Get rid of the original script
                        Debris:AddItem(Script, -1)
                        -- Set up custom logging for our script
                        local ScriptLogging = Logging.new({
                            Prefix = Script.Name,
                            Source = SkeleScript
                        })
                        -- Get the environment of our script's function
                        -- we will need to overwrite a few things
                        local ScriptEnv = getfenv(Func)
                        ScriptEnv.script = SkeleScript
                        ScriptEnv.require = function(module)
                            if typeof(module) == "Instance" and module:IsA("BaseScript") then
                                local ModuleName = module:GetFullName()
                                WriteDebug("Attempting to load module " .. ModuleName)
                                local index = ModuleIndex[ModuleName]
                                if type(index) ~= "nil" then
                                    return index
                                end
                            end
                            Log:Error(SkeleScript:GetFullName(), "attempted to require a non-existent script")
                            return nil
                        end
                        -- Overwrite the default logging functions (print, warn, et cetera) with our own
                        Helpers.OverwriteLogging(ScriptEnv, ScriptLogging)
                        if IsModule then
                            -- Add the module to our index so it can be used by other scripts
                            WriteDebug("NOTICE: Adding script \"" .. ScriptName .. "\" to ModuleIndex")
                            if not ModuleIndex[ScriptName] then
                                ModuleIndex[ScriptName] = ScriptEnv
                            else
                                Log:Warn("Duplicate module \"" .. ScriptName .. "\" will be ignored")
                            end
                        else
                            -- Apply the preset environment
                            Helpers.ApplyEnv(VirtualEnv, ScriptEnv)
                            -- Execute the script asynchronously
                            WriteDebug("NOTICE: Starting script \"" .. ScriptName .. "\" runtime")
                            coroutine.wrap(xpcall)(Func, function(Message)
                                Log:Error(SkeleScript:GetFullName(), "error during runtime")
                                Log:Error(Message)
                                Log:Info("Stack Begin")
                                Log:Info("Script '" .. SkeleScript:GetFullName() .. "'")
                                Log:Info("Stack End")
                            end, unpack(ExecArgs))
                        end
                    else
                        Log:Error(ScriptName, "failed to compile")
                        Log:Info(Func)
                    end
                else
                    Log:Error(ScriptName, "failed to parse instructions")
                    Log:Info(Bytecode)
                end
            end
        else
            --WriteDebug("NOTICE: Ignoring instance \"" .. ScriptName .. "\" because it is not a compiled script")
        end
    end
    -- Iterator function
    local function LoadScripts(Start, IsRecursive)
        if IsRecursive == nil then
            -- Egh, it was easier to make this true by default so here we are
            IsRecursive = true
        end
        for _, Script in ipairs(Start:GetChildren()) do
            LoadScript(Script) -- Load it up!
            if #Script:GetChildren() >= 1 and IsRecursive then
                LoadScripts(Script, true)
            end
        end
    end
    WriteDebug("CHECKPOINT_1")
    -- I'm """pretty""" confident that these are the only places I need to look for scripts
    -- I'm also confident that I will end up being wrong ¯\_(ツ)_/¯
    local SearchDirectories = { -- { <Instance>Location, <bool>Recursive? }
        { LocalPlayer:WaitForChild("PlayerScripts"), true },
        { LocalPlayer:WaitForChild("PlayerGui"), true },
        { LocalPlayer:WaitForChild("Backpack"), true },
        { game:GetService("ReplicatedFirst"), true }
    }
    -- THIS! This is why recursiveness is enabled by default!
    -- smh.
    LocalPlayer.CharacterAdded:Connect(LoadScripts)
    -- Just a quick sanity check, although this script definitely should be loaded before the character
    if typeof(LocalPlayer.Character) == "Instance" then
        WriteDebug("UNEXPECTED: Character exists before script; execution running behind")
        pcall(LoadScripts, LocalPlayer.Character, true) -- Can never be *too* careful
        -- Also, not error handling this because I don't really care
    end
    WriteDebug("CHECKPOINT_2")
    -- Load the things that we actually need to worry about
    for _, Dir in ipairs(SearchDirectories) do
        -- Load the scripts that are already there (technically a bit early)
        local Success, Error = pcall(LoadScripts, unpack(Dir)) -- Just in case
        if not Success then
            Log:Error(Error)
            Log:Info("Stack Begin")
            Log:Info("Stack End")
        end
        -- Watch for new scripts we may need to load as well
        Dir[1].DescendantAdded:Connect(LoadScript)
    end
    -- And we're done!
    if game:IsLoaded() then
        WriteDebug("UNEXPECTED: Game loaded before package runtime finished; execution running behind")
    end
    local ElapsedTicks = tostring(tick() - StartTick) -- How'd we do?
    Log:Print("Done! (took " .. ElapsedTicks .. "s)") -- I like knowing how fast my code is,,
    WriteDebug("CHECKPOINT_3")
    -- Pretty short for a script that runs other scripts, huh?
    WriteDebug("Package runtime completed successfully")
end)