--[[
    Copyright (C) 2026 snwfke

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
]]

--- @class Options
--- @field public help table
--- @field public move table
--- Represents the "options" (commands) to an AI unit group.
--- 
--- A command is a key-value pair of a command name to a table with the following fields:
--- - `description` (string): A description of the command.
--- - `flags` (table?): An optional table of flags that modify the behavior of the command.
---   The specific flags and their effects are determined by the implementation of the AI unit group.
--- 
--- A flag is a key-value pair of a word or letter to a table with the following fields:
--- - `type` (string): The type of the flag, which can be `"boolean"`, `"number"`, or `"string"`. If you use
---   `"any"`, it will always convert to `"string"`.
--- - `description` (string): A description of the flag.
--- - `choices` (table?): An optional table of choices that the command can take for one or multiple flags.
--- - `default` (any?): An optional default value for the command, which may be used if no specific choice is made.
---   The data type of `default` must match `type`.
--- 
--- Adding a new command is as simple as declaraing a new table entry:
--- ```lua
--- Options.foo = {
---   description = "Description of the new command.",
---   flags = {
---     -- Example flag
---     x = { type = "number", description = "An example --x= flag that takes a number." },
---   },
---   choices = nil,
---   default = nil
--- }
local Options = {
  -- Represents a "help" command. While a CLI would be commonly used for controlling AI, this is a common command
  -- that can be used in various contexts, such as a GUI or a voice-controlled interface.
  help = {
    description = "Display help information about the AI unit group.",
    flags = nil,
  },
  -- Represents a "move" command, which instructs an AI unit group to move to a specified location.
  move = {
    description = "Move an AI unit group to a specified location.",
    flags = {
      s = { type = "number", description = "Unit movement speed (in knots)", choices = nil, default = 9 },
      t = {
        type = "string",
        description = "Type of surface to move on. (e.g. onroad, offroad)",
        choices = { "onroad", "offroad" },
        default = "offroad",
      },
      f = {
        type = "string",
        description = "Type of formation to use while moving. (e.g. line, wedge)",
        choices = {
          -- there are many, but these are just examples
          "cone",
          "column",
          "diamond",
          "vee",
        },
        default = "column",
      }
    },
  },
}

--- @class Context
--- @field public unit string
--- @field public command string
--- @field public args table
--- Represents the context state for a CLI command response. Context is for holding the parsed information from a CLI
--- command input, including the unit, command, and any flags.
--- 
--- The `Context` class has the following fields:
local Context = {}
Context.__index = Context

--- Creates a new instance of `Context` as a singleton.
function Context:new()
  local self = setmetatable({}, Context)
  return self
end

--- Parses a string as a CLI commands and populates `Context` with extracted values.
function Context:parse(input)
  -- splits a string into tokens based on a specified delimiter. it returns a slice of strings.
  local function splitString(source, delimiter)
    local result = {}
    local text = tostring(source or "")
    local pattern = "([^" .. delimiter .. "]+)"

    for token in text:gmatch(pattern) do
      table.insert(result, token)
    end

    return result
  end

  -- very important step: we need to make sure flag values match the expected type defined in the command schema.
  -- this function will convert the string value from the CLI input into the appropriate type regardless of how the user entered it.
  -- gotta be foolproof!
  local function sanitiseFlagValue(value, typeName)
    if typeName == "number" then
      return tonumber(value) or value

    elseif typeName == "boolean" then
      if value == "false" or value == "0" then
        return false
      end
      return true

    elseif typeName == "string" or typeName == "any" then
      return tostring(value)

    elseif typeName == "nil" then
      return nil
    end

    return tostring(value)
  end

  -- if a flag is provided without an explicit value (e.g. --key or -k), use a schema default if available.
  local function defaultFlagValue(typeName)
    if typeName == "boolean" then
      return true
    elseif typeName == "number" then
      return 0
    elseif typeName == "string" or typeName == "any" then
      return ""
    elseif typeName == "nil" then
      return nil
    end

    return true
  end

  -- when a value is missing, we expect there to be a default value in the command schema.
  local function resolveDefaultChoice(key, flagDef)
    if flagDef then
      if flagDef.default ~= nil then
        return flagDef.default
      elseif type(flagDef.choices) == "table" and #flagDef.choices > 0 then
        return flagDef.choices[1]
      end
    end

    return defaultFlagValue(flagDef and flagDef.type or "any")
  end

  -- validates that the provided choice for a flag is within the allowed choices defined in the command schema.
  -- if none are found, it returns true by default.
  local function validateChoice(value, flagDef)
    if type(flagDef) ~= "table" or type(flagDef.choices) ~= "table" then
      return true
    end

    for _, choice in ipairs(flagDef.choices) do
      if choice == value then
        return true
      end
    end

    return false
  end

  -- this is the holy grail of the parser - it takes the tokens found after the command and treats them as flags.
  -- something to note is that there is only 1 command supported per input, and all flags must come after the command.
  -- this is a design choice to keep the parser simple and unambiguous.
  local function parseArguments(tokens, command)
    local parsed = {}
    local schema = Options[command] and Options[command].flags or {}
    local pendingKey = nil

    -- time and space complexity is O(n) where n is the number of tokens after the command
    for _, token in ipairs(tokens) do
      if token:sub(1, 2) == "--" then
        if pendingKey then
          local pendingDef = schema[pendingKey]
          parsed[pendingKey] = resolveDefaultChoice(pendingKey, pendingDef)
          pendingKey = nil
        end

        -- in regex we trust
        local flagPart = token:sub(3)
        local key, value = flagPart:match("([^=]+)=?(.*)")
        local flagDef = schema[key]
        local flagType = (flagDef and flagDef.type) or "any"

        if flagPart:find("=") then
          if flagDef and not validateChoice(value, flagDef) then
            error("Invalid choice '" .. tostring(value) .. "' for flag '" .. tostring(key) .. "'")
          end
          parsed[key] = sanitiseFlagValue(value, flagType)
        else
          parsed[key] = resolveDefaultChoice(key, flagDef)
        end
      elseif token:sub(1, 1) == "-" then
        if pendingKey then
          local pendingDef = schema[pendingKey]
          parsed[pendingKey] = resolveDefaultChoice(pendingKey, pendingDef)
        end

        local key = token:sub(2)
        pendingKey = key
      elseif pendingKey then
        local pendingDef = schema[pendingKey]
        local flagType = (pendingDef and pendingDef.type) or "any"

        if pendingDef and not validateChoice(token, pendingDef) then
          error("Invalid choice '" .. tostring(token) .. "' for flag '" .. tostring(pendingKey) .. "'")
        end

        parsed[pendingKey] = sanitiseFlagValue(token, flagType)
        pendingKey = nil
      end
    end

    if pendingKey then
      local pendingDef = schema[pendingKey]
      parsed[pendingKey] = resolveDefaultChoice(pendingKey, pendingDef)
    end

    return parsed
  end

  local tokens = splitString(input or "", " ")
  local unit = tokens[1]

  local command
  local params = {}
  if tokens[2] and Options[tokens[2]] then
    command = tokens[2]
    for i = 3, #tokens do
      table.insert(params, tokens[i])
    end
  end

  -- this seems silly, but it allows us to keep the parsing logic separate and focused on just the flags, which is where most of the complexity actually lies!
  local parsedArgs = command and parseArguments(params, command) or {}

  -- the actual passed args. when we use this in an argument signature, we only care about args for flags.
  self.unit = unit
  self.command = command
  self.args = parsedArgs

  return self
end

--- A helper method for cleaning up the context state if needed. In Lua, this is unnecessary due to dynamic memory allocation and garbage collection,
--- but it can be useful for reusing a variable without worrying about many singletons.
function Context:destroy()
  self.unit = nil
  self.command = nil
  self.args = nil
  self = nil
  return self
end

function Context:help()
  local helpText = "Available commands: (disappears in 15 seconds)\n"

  for cmd, details in pairs(Options) do
    helpText = helpText .. "\n  " .. cmd .. ": " .. details.description .. "\n"

    if details.flags then
      for flag, flagDetails in pairs(details.flags) do
        helpText = helpText .. "\n    --" .. flag .. " (" .. flagDetails.type .. "): " .. flagDetails.description .. "\n"
        
        if flagDetails.choices then
          helpText = helpText .. "    Choices: (" .. table.concat(flagDetails.choices, ", ") .. ")\n"
        end
        
        if flagDetails.default ~= nil then
          helpText = helpText .. "    Default: " .. tostring(flagDetails.default) .. "\n"
        end
      end
    end
  end

  return helpText
end

function Context:move(ctx)
  -- this is where the actual logic for executing the "move" command would go, using the parsed context.
  -- for example, you might have something like:
  -- ctx.args.s for speed, ctx.args.t for terrain type, and ctx.args.f for formation.
  -- you would then use these values to control the AI unit group's movement behavior accordingly.
end

--- Builds a CLI context from a given input string.
--- 
--- The `input` string is expected to be in the format: `<unit> <command> [flags]`, where:
--- - `<unit>` is a required identifier for the AI unit group, (either a name or an ID)
--- - `<command>` is the name of the command to execute, (e.g., "move")
--- - and `[flags]` are optional flags that modify the behavior of the command, which cannot be positional arguments.
--- 
--- Flags can only be in the form of `--key=value`, or `--key` for truthy conditions. This function will extract the unit, command,
--- and flags from the input string and store them in `Context`. It will also handle default values for
--- flags, based on the command's schema defined in the `Options` table.
function f10Cli(input)
  return Context:new():parse(input)
end

local function runTests()
  local c = f10Cli("emb-5593 move --s=12 --t=onroad --f")
  assert(c.unit == "emb-5593")
  assert(c.command == "move")
  assert(c.args.s == 12)
  assert(c.args.t == "onroad")
  assert(c.args.f == "column")

  local c2 = f10Cli("Unit move --flag")
  assert(c2.unit == "Unit")
  assert(c2.command == "move")
  assert(c2.args.flag == "")

  local c3 = f10Cli("Unit-1234 help")
  assert(c3.unit == "Unit-1234")
  assert(c3.command == "help")

  print("Context parser regression tests passed")
end

if ... == nil then
  runTests()
end

return {
  Context = Context -- it helps to know what the preliminary args look like at least
}