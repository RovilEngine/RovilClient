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
-- Set at compile time
local CompilerData = game:GetService("HttpService"):JSONDecode([[%builddata%]])
local Version = CompilerData.Version or "Build"
-- +1'd because the first byte denotes the script type
local Offset = (tonumber(CompilerData.Offset) or 0) + 1
local ExecArgs = CompilerData.Arguments or {}
-- Argumentss passed to the main script
local CompilerOptions = { Version, ExecArgs, Offset, nil }
-- Parent our script to nil temporarily
script.Parent = nil
-- Load the "meat" of our package
local MainModule = script:WaitForChild(".main")
local Main = require(MainModule)
-- Since we have the functions loaded into memory, we can now get rid of that old thing!
MainModule:Destroy()
-- Run the funny code with some *weird* error handling
xpcall(Main, function(...)
    -- Non thread-halting error handling
    -- Bad practice!
    local Msg = table.concat({"[Rovil/ClientInitializer]:", ...}, " ")
    task.spawn(function()
        local TS = game:GetService("TestService")
        TS:Check(false, Msg)
        TS:Message("Stack Begin")
        TS:Message("Stack End")
    end)
end, unpack(CompilerOptions))
-- Kill this script!
script:Destroy()
-- P.S. the scripts loaded into their own threads will continue to run, even after this script is loooong gone
-- P.P.S. the only way ~~i know of~~ to access these threads is through the lua/c register or hooking the garbage collector
-- P.P.P.S. that is """really""" hard to do and no exploiter wants to do that just to hack in a lego game