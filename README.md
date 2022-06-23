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
    - UI also contains a search bar, search terms can be separated by a space and entries shown will include every word given

## Example usage

Adding a macro with a command `mypw` and clip `MyVerySecurePassword` would make it so whenever `mypw` was entered `MyVerySecurePassword` would appear instead (the command has to be followed by a space or enter or , or .)

## Advanced usage

Multiple linked macros can be added (Following `2.0.0`) that behave like a set of hotstrings loosely tied to the parent

For example you may want a set of macros whose commands are `mymacro<number>` where the number ranges from 1 to 10 with it's content matches `mycontent<number>`

To create a set of macros include `$<$>` in both the command and the content with the set of **values** in between the < and >, for example

```
myMacro$<1,2,3,4$>
myMacro$<i$>content
```

Would create 4 macros, `myMacro1`, `myMacro2`, `myMacro3`, `myMacro4` with contents of `myMacro1content`, `myMacro2content`, `myMacro3content`, `myMacro4content`

Notice `$<i$>` in content signifying the position where values from command are spliced in; multiple `$<i$>` may exist

Note: linked entries are **removed together** and can not be edit!
