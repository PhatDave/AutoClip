#NoEnv
#Warn
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent
#Hotstring r

; Hotstring(":o:eml", "kosmodiskclassic0@gmail.com")

global hotstrings := {}

PadCommand(commandButLocal) {
    commandButLocal := ":o:" . commandButLocal
    return commandButLocal
}

AddHotstring(command, content) {
    command := PadCommand(command)
    if (!hotstrings.HasKey(command)) {
        hotstrings[command] := content
        HotString(command, content)
        UpdateFile()
    }
}

ReadFile() {
    IfNotExist, Macros.txt
        FileAppend,, Macros.txt
    FileRead, macros, Macros.txt
    for index, macro in StrSplit(macros, "`n") {
        tempData := StrSplit(macro, "|")
        if (tempData.Length() == 2) {
            commandButRead := tempData[1]
            contentButRead := tempData[2]
            AddHotstring(commandButRead, contentButRead)
        }
    }
}

UpdateFile() {
    file := FileOpen("Macros.txt", "W")
    for k, v in hotstrings {
        file.write(k . "|" . v . "`n")
    }
    file.close()
}

AddMacro() {
    tooltip, ok
}

MakeTrayMenu() {
    Menu, Tray, Add, Add Macro, AddMacro
    Menu, Tray, Add, Remove Macro, OpenRemoveMenu
}

ReadFile()
MakeTrayMenu()

; Gui
global vCommand := ""
global vContent := ""
Gui, Add, Text,, Enter the command to trigger clip
Gui, Add, Edit, r1 w300 vCommand
Gui, Add, Text,, Enter the clip to be pasted
Gui, Add, Edit, r1 w300 vContent
; Gui, Show

; Gui enter submit
#IfWinActive ahk_class AutoHotkeyGUI
*Enter::
    Gui, Submit
    AddHotstring(Command, Content)
return

F5::reload return