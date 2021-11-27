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
-- [!] "Secure" functions to circumvent __namecall hooking
-- --- Does not circumvent __index hooking
local function game_GetService(S)
	return game.GetService(game, S)
end
local function instance_FindFirstChild(I, C)
	return I.FindFirstChild(I, C)
end
local function instance_WaitForChild(I, C)
	task.wait()
	return instance_FindFirstChild(I, C) or instance_WaitForChild(I, C)
end
-- [!] Declare required imports before module is destroyed
local Packages = instance_WaitForChild(script, "packages")
local LuaVM = require(instance_WaitForChild(Packages, "lua_vm"))
local Helpers = require(instance_WaitForChild(Packages, "util"))
local Logging = require(instance_WaitForChild(Packages, "logging"))
-- [!] To optimize speed, declare all functions within the coroutine scope
return coroutine.wrap(function(...)
	local function ev_Connect(E, F)
		return E.Connect(E, F)
	end
	local function instance_IsA(I, A)
		return I.IsA(I, A)
	end
	local function instance_GetFullname(I)
		return I.GetFullName(I)
	end
	local function instance_GetChildren(I)
		return I.GetChildren(I)
	end
	local RunService = game_GetService("RunService")
	local Debris = game_GetService("Debris")
	local function debris_AddItem(...)
		return Debris.AddItem(Debris, ...)
	end
	local ReplicatedFirst = game_GetService("ReplicatedFirst")
	local Players = game_GetService("Players")
	local Version, ExecArgs, Offset, CommonKey = ... -- TODO: security?
	local IsStableBuild = Version:match("%d+%.%d+%.%d+%.%d+$") or not RunService.IsStudio(RunService)
	local shared = setmetatable({}, {
		__metatable = "The metatable is locked"
	}) -- A blank slate, w/o an ~~accessable~~ metatable
	local ModuleIndex = {}
	local ProxyScript = Instance.new("LocalScript") -- identity theft
	ProxyScript.Name = "RovilEngine"
	ProxyScript.Parent = ReplicatedFirst
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
	Log:Print("Client initialization begin")
	local LocalPlayer = Players.LocalPlayer
	-- This is the virtual environment we will apply to every script
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
	local function LoadScript(Script, ModulesOnly)
		local OldScriptName = Script.Name
		local ScriptName = instance_GetFullname(Script)
		if instance_IsA(Script, "ModuleScript") and (OldScriptName:match("^#") or OldScriptName:match("^*")) then -- # = LocalScript, * = ModuleScript
			local Instructions = require(Script)
			if typeof(Instructions) ~= "table" then -- EXTREMELY limited sanity check; better than nothing
				if #Instructions == 1 and Instructions[1] == 0 then
					Log:Error(ScriptName, "was not compiled due to an issue at build time")
					Log:Error("Please check within the script for further information")
				else
					Log:Error(ScriptName, "flagged as compiled, but contains invalid/unreadable instructions")
				end
			else
				WriteDebug("NOTICE: Preparing to load script \"" .. ScriptName .. "\"")
				local IsModule = OldScriptName:match("^*")
				if IsModule then
					WriteDebug("NOTICE: Script \"" .. ScriptName .. "\" is a module")
				else
					if ModulesOnly then
						WriteDebug("NOTICE: Skipping \"" .. ScriptName .. "\" because it is a module and the ModulesOnly flag has been set to true")
						return
					end
				end
				local Success, Bytecode = pcall(Helpers.InstructionsToBytecode, Instructions, Offset)
				if Success and typeof(Bytecode) == "string" then -- Make sure bytecode exists
					local Success, Func = pcall(LuaVM.LoadBytecode, Bytecode)
					if Success and typeof(Func) == "function" then -- Make sure we got a function
						-- Annoying fix for stuff
						local ScriptNameRaw do
							local OldName = OldScriptName
							OldScriptName = OldScriptName:sub(2)
							ScriptNameRaw = ScriptName
							OldScriptName = OldName
						end
						-- Make a skeleton copy of the script
						-- (except it's a LocalScript now lolol)
						local SkeleScript = Instance.new(IsModule and "ModuleScript" or "LocalScript")
						SkeleScript.Name = OldScriptName:sub(2)
						SkeleScript.Parent = Script.Parent
						-- Move the children of original to our copy
						for _, Child in ipairs(instance_GetChildren(Script)) do
							pcall(function()
								Child.Parent = SkeleScript
							end)
						end
						-- Get rid of the original script
						debris_AddItem(Script, -1)
						-- Set up custom logging for our script
						local ScriptLogging = Logging.new({
							Prefix = OldScriptName,
							Source = SkeleScript
						})
						-- Get the environment of our script's function
						-- we will need to overwrite a few things
						local ScriptEnv = getfenv(Func)
						ScriptEnv.script = SkeleScript
						ScriptEnv.require = function(Module)
							if typeof(Module) == "Instance" and instance_IsA(Module, "ModuleScript") then
								local ModuleName = instance_GetFullname(Module)
								WriteDebug("NOTICE: Attempting to load module " .. ModuleName)
								local ModuleFunc = ModuleIndex[ModuleName]
								if type(ModuleFunc) == "function" then
									local Success, Return = pcall(ModuleFunc)
									if Success then
										return Return
									else
										Log:Error(ModuleName, "error loading module")
										Log:Error(Return)
										Log:Info("Stack Begin")
										Log:Info("Script '" .. ModuleName .. "'")
										Log:Info("Script '" .. ScriptName .. "'")
										Log:Info("Stack End")
									end
								end
							else
								Log:Error(instance_GetFullname(SkeleScript), "attempted to require a non-existent script")
							end
							return nil
						end
						local SkeleScriptName = instance_GetFullname(SkeleScript)
						-- Overwrite the default logging functions (print, warn, et cetera) with our own
						Helpers.OverwriteLogging(ScriptEnv, ScriptLogging)
						if IsModule then
							-- Add the module to our index so it can be used by other scripts
							WriteDebug("NOTICE: Adding script \"" .. ScriptName .. "\" to ModuleIndex")
							if not ModuleIndex[instance_GetFullname(Script)] then
								ModuleIndex[ScriptNameRaw] = Func
							else
								Log:Warn("Duplicate module \"" .. ScriptName .. "\" will be ignored")
							end
						else
							-- Apply the preset environment
							Helpers.ApplyEnv(VirtualEnv, ScriptEnv)
							-- Execute the script asynchronously
							WriteDebug("NOTICE: Starting script \"" .. ScriptName .. "\" runtime")
							coroutine.wrap(xpcall)(Func, function(Message)
								Log:Error(SkeleScriptName, "error during runtime")
								Log:Error(Message)
								Log:Info("Stack Begin")
								Log:Info("Script '" .. SkeleScriptName .. "'")
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
	local function LoadScripts(Start, IsRecursive, ModulesOnly)
		if IsRecursive == nil then
			-- Egh, it was easier to make this true by default so here we are
			IsRecursive = true
		end
		for _, Script in ipairs(instance_GetChildren(Start)) do
			LoadScript(Script, ModulesOnly) -- Load it up!
			if #instance_GetChildren(Script) >= 1 and IsRecursive then
				LoadScripts(Script, true, ModulesOnly)
			end
		end
	end
	WriteDebug("CHECKPOINT_1")
	-- I'm """pretty""" confident that these are the only places I need to look for scripts
	-- I'm also confident that I will end up being wrong ¯\_(ツ)_/¯
	local SearchDirectories = { -- { <Instance>Location, <bool>Recursive? }
		{ instance_WaitForChild(LocalPlayer, "PlayerScripts"), true },
		{ instance_WaitForChild(LocalPlayer, "PlayerGui"), true },
		{ instance_WaitForChild(LocalPlayer, "Backpack"), true },
		{ game_GetService("ReplicatedFirst"), true }
	}
	local ModuleSearchDirectories = {
		unpack(SearchDirectories),
		{ game_GetService("Workspace"), true },
		{ game_GetService("Lighting"), true },
		{ game_GetService("ReplicatedStorage"), true },
		{ game_GetService("Chat"), true },
		{ game_GetService("StarterGui"), true }
	}
	-- THIS! This is why recursiveness is enabled by default!
	-- smh.
	ev_Connect(LocalPlayer.CharacterAdded, LoadScripts)
	-- Just a quick sanity check, although this script definitely should be loaded before the character
	if typeof(LocalPlayer.Character) == "Instance" then
		WriteDebug("UNEXPECTED: Character exists before script; execution running behind")
		pcall(LoadScripts, LocalPlayer.Character, true) -- Can never be *too* careful
		-- Also, not error handling this because I don't really care
	end
	WriteDebug("CHECKPOINT_2")
	-- Load the things that we actually need to worry about
	for _, SearchDir in ipairs({ { ModuleSearchDirectories, true }, { SearchDirectories, false } }) do
		local Search, ModulesOnly = unpack(SearchDir)
		for _, Dir in ipairs(Search) do
			-- Load the scripts that are already there (technically a bit early)
			local Success, Error = pcall(LoadScripts, Dir[1], Dir[2], ModulesOnly) -- Just in case
			if not Success then
				Log:Error(Error)
				Log:Info("Stack Begin")
				Log:Info("Stack End")
			end
			-- Watch for new scripts we may need to load as well
			ev_Connect(Dir[1].DescendantAdded, LoadScript)
		end
	end
	-- And we're done!
	if game.IsLoaded(game) then
		WriteDebug("UNEXPECTED: Game loaded before package runtime finished; execution running behind")
	end
	local ElapsedTicks = tostring(tick() - StartTick) -- How'd we do?
	Log:Print("Done! (took " .. ElapsedTicks .. "s)") -- I like knowing how fast my code is,,
	WriteDebug("CHECKPOINT_3")
	-- Pretty short for a script that runs other scripts, huh?
	WriteDebug("Package runtime completed successfully")
end)