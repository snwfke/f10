# Usage

This document covers all documented areas of f10. You can alternatively access documentation by
using a Lua-based LSP, IDE, or referencing the source code.

## Creating a command

What makes f10 so powerful is how easy and simple it is to create commands.
Add a new declaration in your script like so:

```lua
Options.test = {
    description = "my test command",
    flags = nil
}
```

The `Options` table represents a command schema, containing any potential parameters and choices.
The key `test` is used to denote the command's name, Lua will only support alphanumerics with underscore, simplifying potential edge cases for input pattern checking. The inner entry `description` is required, while `flags` is not.

## Creating a command with arguments

Going further into command creation, we can also intake parameters, or **arguments** as variables
to handle for our command. An example of such a command would be *[grunt](https://github.com/snwfke/grunt)'s* `UnitGroup:pop(colour, is_flare)`:

> [!NOTE]
> This is to help further illustrate the concept, you do not need to define this.
> Furthermore, the ellipsis operator (...) imitates where more code would be present.

```lua
function UnitGroup:pop(colour, is_flare)
    local colour = colour:sub(1, 1):upper() .. colour:sub(2):lower()
    
    ...

    if is_flare then
        ...
    end
end
```

We can create our own command callback function that accepts flags as arguments:

```lua
-- Context is a class that is exposed from f10, it is a singleton wrapper class
-- that handles parsing and commands, e.g. help().
function Context:test(foo, bar)
    if foo ~= "bar" then
        foo = "baz"
    else
        local baz = "baz"
        foo = bar
        bar = baz
    end
end
```

The f10 CLI is designed to only accept **one positional argument**: the command name, and should not be mistaken for *keyword arguments*; which is what `flags` are. Just like with a command name, the key to the entry denotes the flag's
naming:

```lua
Options.test = {
    description = "my test command",
    flags = {
        -- we don't recommend using any type, but it will default to string
        foo = { type = "any", description = "foo flag", choices = nil, default = nil },
        bar = {
            type = "any",
            description = "bar flag",
            choices = { "abc", 123, 7 },
            default = 7
        }
    }
}
```

## Executing a command

When you want to execute a command, you can use the following code for creating a real-time
mission event handler, which will also track map markers in the multiplayer server:

```lua
-- This just needs to be defined somewhere, and specifically empty
local EventHandler = {}

function EventHandler:onEvent(event)
    if event.id == world.event.S_EVENT_MARK_ADDED then
        print("new marker created: &s", event.text)
    end

    if event.id == world.event.S_EVENT_MARK_CHANGE then
        print("marker changed: &s", event.text)
    end

    -- in this example, the command only executes after the map marker is deleted.
    if event.id == world.event.S_EVENT_MARK_REMOVED and event.text ~= "" then
        -- this gives us a Context class, with unit, (name) command, (name) and args (flags)
        cli = f10Cli(event.text)

        -- as long as the command name is detected, you can call methods from Context
        -- you can also define your own Context functions if you want to program behaviour
        if cli.command == "test" then
            playerGroupID = event.initiator:getGroup():getID()
            -- playerGroupID, message, duration
            trigger.action.outTextForGroup(
                playerGroupID,
                cli:test(cli.args.foo, cli.args.bar),
                5
            )
        end
    end
end
```