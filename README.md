# Autoclip

### Heavily inspired by skrommel's AutoClip

Short and simple script that can be used to input preset text on hotkey

Hotkeys and text they input can be configured by right clicking the AHK icon in the system tray

Hotkeys are also saved (and can be changed if brave enough) in Macros.txt

## Example usage

Adding a macro with a command `mypw` and clip `MyVerySecurePassword` would make it so whenever `mypw` was entered `MyVerySecurePassword` would appear instead (the command has to be followed by a space or enter or , or .)

## Macros.txt

File contains all user defined macros

Their commands and contents can be altered but the format must be respected

`:o:<command>|<clip>`, with omitting < and >