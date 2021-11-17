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
local Logging = {}
local Logger = {}
Logger.__index = Logger
local TestService = game:GetService("TestService")
local function ConcatArgs(...)
    local str = ""
    for _, V in ipairs({...}) do
        str = str .. " " .. tostring(V)
    end
    return str
end
function Logger:Print(...)
    -- I like consistency
    return print("TestService." .. self.Source.Name .. "(0):", ConcatArgs(self.Prefix, ...))
end
function Logger:Error(...)
    return TestService:Error(ConcatArgs(self.Prefix, ...), self.Source)
end
function Logger:Warn(...)
    return TestService:Warn(false, ConcatArgs(self.Prefix, ...), self.Source)
end
function Logger:Info(...)
    return TestService:Message(ConcatArgs(self.Prefix, ...), self.Source)
end
function Logging.new(Options)
    local self = setmetatable({}, Logger)
    self.Prefix = "[" .. (Options.Prefix or "Log") .. "]:"
    self.Source = Options.Source or script
    return self
end
return Logging