#NoEnv
#Warn
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent
#Hotstring r

global hotstrings := {}

PadCommand(command) {
    if (!InStr(command, ":o:")) {
        command := ":o:" . command
    }
    return command
}

AddMacro(command, content) {
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
            AddMacro(commandButRead, contentButRead)
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

AddMacroTray() {
    Gui, Show
}

RemoveMacro() {
    if (hotstrings.HasKey(A_ThisMenuItem)) {
        Hotstring(A_ThisMenuItem, hotstrings[A_ThisMenuItem], "Off")
        hotstrings.Remove(A_ThisMenuItem)
        UpdateFile()
    }
}

OpenRemoveMenu() {
    Menu, macroMenu, Add
    Menu, macroMenu, DeleteAll
    for k, v in hotstrings {
        Menu, macroMenu, Add, %k%, RemoveMacro
    }
    Menu, macroMenu, Show
}

OpenMacros() {
    Run, edit "Macros.txt"
}

Reload() {
    reload
}

MakeTrayMenu() {
    Menu, Tray, Add, Add Macro, AddMacroTray
    Menu, Tray, Add, Remove Macro, OpenRemoveMenu
    Menu, Tray, Add, Oepn Macro List (file), OpenMacros
    Menu, Tray, Add, Reload, Reload
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
; #IfWinActive ahk_class AutoHotkeyGUI
~Enter::
    if (WinActive("ahk_class AutoHotkeyGUI")) {
        Gui, Submit
        AddMacro(Command, Content)
        ControlSetText, Edit1,
        ControlSetText, Edit2,
    }
return