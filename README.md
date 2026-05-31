<h1>
    <svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 512 512"><!--!Font Awesome Free v7.2.0 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2026 Fonticons, Inc.--><g color="white"><path d="M128 32l32 0c17.7 0 32 14.3 32 32l0 32-96 0 0-32c0-17.7 14.3-32 32-32zm64 96l0 320c0 17.7-14.3 32-32 32L32 480c-17.7 0-32-14.3-32-32l0-59.1c0-34.6 9.4-68.6 27.2-98.3 13.7-22.8 22.5-48.2 25.8-74.6L60.5 156c2-16 15.6-28 31.8-28l99.8 0zm227.8 0c16.1 0 29.8 12 31.8 28L459 216c3.3 26.4 12.1 51.8 25.8 74.6 17.8 29.7 27.2 63.7 27.2 98.3l0 59.1c0 17.7-14.3 32-32 32l-128 0c-17.7 0-32-14.3-32-32l0-320 99.8 0zM320 64c0-17.7 14.3-32 32-32l32 0c17.7 0 32 14.3 32 32l0 32-96 0 0-32zm-32 64l0 160-64 0 0-160 64 0z" fill="currentColor"/></g></svg>
    f10
    <img src="https://img.shields.io/badge/lua-5.5.0-darkblue" />
</h1>

**f10** is a simple, robust & easily modifiable ME CLI[^1] for AI — <i>using the F10 map</i>.

Inspired by military real-time strategy games, f10 is designed to be a plug-and-play solution for developers to add map marker commands to singleplayer or multiplayer missions.

[^1]: This is the abbreviation for a [command-line interface](https://en.wikipedia.org/wiki/Command-line_interface), majorly responsible
for allowing developers to execute commands on any given system.

## Features

<img align="left" src="https://github.com/user-attachments/assets/d221101a-e7a5-4de0-9ce8-265c8752a875" />
<ul><ul>
    <b>Simple to learn.</b><br/>
    f10 is built to cater towards the inexperienced, this tooling has been battle-tested across many multiplayer servers.<br/>
    <a href="/">Learn more →</a>
</ul></ul>

<img align="left" src="https://github.com/user-attachments/assets/0935fbf4-ddf4-4421-a2ac-1db48c472b03" />
<ul><ul>
    <b>Behaviour you can expect.</b><br/>
    The CLI has been thoroughly documented for you to better understand its nature, including the parser. Basic and minimal examples can also be found for AI behaviour, e.g. movement.
</ul></ul>

<img align="left" src="https://github.com/user-attachments/assets/fce48889-d2ef-4ca3-a3af-b01a4e750847" />
<ul><ul>
    <b>Scalable & modular.</b><br/>
    f10's structure is scaled by the desired behaviour and modularised in command-to-schema translation,
    allowing it to be used as a cookie-cutter template.<br/>
    <a href="/"> Learn more →</a>
</ul></ul>

## Getting started

> [!WARNING]
> If you're updating the script, you must re-add the file and then save the mission.

When defining your mission triggers, add the following condition and action:

![Mission Editor Trigger GUI menu with 1 ONCE ON MISSION START, DO SCRIPT FILE "snwfke_f10.lua"](image.png)

You may now add a separate `DO SCRIPT` action, or include another `DO SCRIPT FILE`. Here is a basic example of working with the ME environment:

```lua
local EventHandler = {}

function EventHandler:onEvent(event)
    -- in this example, the commands only apply after the map marker is deleted.
    if event.id == world.event.S_EVENT_MARK_REMOVED and event.text ~= "" then
        -- this gives us a Context class, with unit, (name) command, (name) and args (flags)
        cli = f10Cli(event.text)

        -- as long as the command name is detected, you can call methods from Context
        -- you can also define your own Context functions if you want to program behaviour
        if cli.command == "help" then
            playerGroupID = event.initiator:getGroup():getID()
            trigger.action.outTextForGroup(playerGroupID, cli:help(), 15)
        end
    end
end
```