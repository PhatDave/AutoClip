# Autoclip

### Heavily inspired by skrommel's AutoClip

Short and simple script that can be used to input preset text on hotkey

Hotkeys and text they input can be configured by right clicking the AHK icon in the system tray

Hotkeys are also saved (and can be changed if brave enough) in Macros.txt

## Interaction and the trey menu

Right clicking the appropriate AHK icon in the system trey will bring up several custom options

- Add Macro
    - Is used to add macros and brings up a UI whose usage is explained below
- Remove Macro
    - Brings up a menu of all active macros, clicking on any will disable that macro
- Modify Macro
    - Brings up the same UI used to add macros but the fields are filled with the macro that was clicked on and the user may edit those values, closing the UI or hitting enter in the UI will submit the changes and update the affected macro

## Example usage

Adding a macro with a command `mypw` and clip `MyVerySecurePassword` would make it so whenever `mypw` was entered `MyVerySecurePassword` would appear instead (the command has to be followed by a space or enter or , or .)

## Macros.txt

File contains all user defined macros

Their commands and contents can be altered but the format must be respected

`:o:<command>|<clip>`, with omitting < and >