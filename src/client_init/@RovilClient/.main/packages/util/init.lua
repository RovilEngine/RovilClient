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
local Util = {}
function Util.InstructionsToBytecode(Instructions, Offset)
    local Bytecode = ""
    if Offset >= 1 then
      for I = 1, Offset do
        table.remove(Instructions, I)
      end
    end
    for Position, Instruction in ipairs(Instructions) do
      local Num = tonumber(Instruction)
      if Num then
		    Bytecode = Bytecode .. string.char(Num)
      else
        error("Unexpected instruction at position " .. tostring(Position))
      end
    end
    return Bytecode
end
function Util.ApplyEnv(From, To)
  for k, v in ipairs(From) do
    To[k] = v
  end
  return To
end
function Util.Wrap(Func)
  return function(...)
    return Func(...)
  end
end
function Util.OverwriteLogging(Env, Logger)
  function Env.info(...)
    return Logger:Info(...)
  end
  function Env.print(...)
    return Logger:Print(...)
  end
  function Env.error(...)
    return Logger:Error(...)
  end
  function Env.warn(...)
    return Logger:Warn(...)
  end
  function Env.assert(Condition, Message)
    if not pcall(assert, Condition) then
      return Logger:Error(Message or "assertion failed!")
    else
      return true
    end
  end
end
return Util