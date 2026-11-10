-- hyprland.lua
-- Root entry point — mirrors the old hyprland.conf source= chain.
-- Each file is require()'d in the same order as before.

require("UserConfigs/vars")
require("UserConfigs/autoStart")
require("UserConfigs/general")
require("UserConfigs/decoration")
require("UserConfigs/animations")
require("UserConfigs/layouts")
require("UserConfigs/input")
require("UserConfigs/misc")
require("UserConfigs/keybinds")
require("UserConfigs/windowRules")
require("monitors")
require("workspaces")
