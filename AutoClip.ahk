﻿#NoEnv
#Warn
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent
#Hotstring r

SetBatchLines, -1

global hotstrings := {}

; b64Encode and b64Decode stolen from https://github.com/jNizM/AHK_Scripts
b64Encode(string)
{
    size := 100
    VarSetCapacity(bin, StrPut(string, "UTF-8")) && len := StrPut(string, &bin, "UTF-8") - 1 
    if !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", 0, "uint*", size))
        throw Exception("CryptBinaryToString failed", -1)
    VarSetCapacity(buf, size << 1, 0)
    if !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", &buf, "uint*", size))
        throw Exception("CryptBinaryToString failed", -1)
    return StrGet(&buf)
}

b64Decode(string)
{
    size := 100
    if !(DllCall("crypt32\CryptStringToBinary", "ptr", &string, "uint", 0, "uint", 0x1, "ptr", 0, "uint*", size, "ptr", 0, "ptr", 0))
        throw Exception("CryptStringToBinary failed", -1)
    VarSetCapacity(buf, size, 0)
    if !(DllCall("crypt32\CryptStringToBinary", "ptr", &string, "uint", 0, "uint", 0x1, "ptr", &buf, "uint*", size, "ptr", 0, "ptr", 0))
        throw Exception("CryptStringToBinary failed", -1)
    return StrGet(&buf, size, "UTF-8")
}

class AllEntries {
    static entries := []

    Insert(entry) {
        if !this.Contains(entry) {
            this.entries.Insert(entry)
        }
    }

    Contains(entry) {
        for k, v in this.entries {
            if v.Command == entry.Command {
                return true
            }
        }
        return false
    }

    SaveAllToFile() {
        file := FileOpen("Macros.txt", "W")
        for k, v in this.entries {
            entryString := b64Encode(v.ToString())
            file.write(entryString)
        }
        file.close()
    }

    ReadFile() {
        IfNotExist, Macros.txt
            FileAppend,, Macros.txt
        FileRead, macros, Macros.txt
        for index, macro in StrSplit(macros, "`n") {
            if (StrLen(macro) > 3) {
                macro := b64Decode(macro)
                tempData := StrSplit(macro, "|")
                if (tempData.Length() == 3) {
                    rcommand := tempData[1]
                    rcontent := tempData[2]
                    enabled := tempData[3]
                    newentry := new Entry(rcommand, rcontent, this)
                    if enabled == "1"
                        newentry.Enable()
                    else
                        newentry.Disable()
                }
            }
        }
    }
}

Class Entry {
    static parent := 0
    static globalEntryList := 0

    Command {
        get {
            return this._command
        }
        set {
            this._command := value
            this.globalEntryList.SaveAllToFile()
        }
    }

    Content {
        get {
            return this._content
        }
        set {
            this._content := value
            this.globalEntryList.SaveAllToFile()
        }
    }

    Enabled {
        get {
            return this._enabled
        }
        set {
            this._enabled := value
            HotString(this.Command, this.content, this._enabled)
            this.globalEntryList.SaveAllToFile()
        }
    }

    __New(command, content, globalEntryList) {
        this.globalEntryList := globalEntryList
        this.Command := this.PadCommand(command)
        this.Content := content
        this.Enabled := 0
        allEntries.Insert(this)
    }

    PadCommand(command) {
        if (!InStr(command, ":o:")) {
            command := ":o:" . command
        }
        return command
    }

    Enable() {
        this.Enabled := 1
    }

    Disable() {
        this.Enabled := 0
    }

    ToString() {
        return this.Command . "|" . this.Content . "|" . this.enabled
    }

    FromString() {

    }
}


entries := new AllEntries()
entries.ReadFile()

testOOP := new Entry("test", "test123", entries)
testOOP := new Entry("test1", "testasd", entries)
testOOP := new Entry("test2", "test1gfg", entries)
testOOP := new Entry("test3", "test1fga3", entries)
testOOP.Enable()

; asd1 := RegExMatch("asdfasfg$<asd, 2, 1, 4, 5$>", "\$<[(\d*\w*)+\,?\s*]+\$>", test123, 1)
; dfsajdh := new Entry("test", "test2")
; dfsajdh.PadCommand()
; tooltip, asd1


; @Deprecated
PadCommand(command) {
    if (!InStr(command, ":o:")) {
        command := ":o:" . command
    }
    return command
}

AddMacro(command, content) {
    if (InStr(Content, "$<") && InStr(Content, "$>")) {
        test := RegExMatch(Content, "$<%d+,%d+,%d+$>")
    }
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
        if (StrLen(macro) > 3) {
            macro := b64Decode(macro)
            tempData := StrSplit(macro, "|")
            if (tempData.Length() == 2) {
                commandButRead := tempData[1]
                contentButRead := tempData[2]
                contentButRead := RegExReplace(contentButRead, "\s+$", "")
                AddMacro(commandButRead, contentButRead)
            }
        }
    }
}

UpdateFile() {
    file := FileOpen("Macros.txt", "W")
    for k, v in hotstrings {
        file.write(b64Encode(k . "|" . v . "`n"))
    }
    file.close()
}

AddMacroTray() {
    Gui, Show
}

RemoveMacro() {
    item := StrSplit(A_ThisMenuItem, " ")[1]
    if (hotstrings.HasKey(item)) {
        Hotstring(item, hotstrings[item], "Off")
        hotstrings.Remove(item)
        UpdateFile()
    }
}

OpenRemoveMenu() {
    Menu, macroMenu, Add
    Menu, macroMenu, DeleteAll
    for k, v in hotstrings {
        Menu, macroMenu, Add, %k%        %v%, RemoveMacro
    }
    Menu, macroMenu, Show
}

ModMacro() {
    item := StrSplit(A_ThisMenuItem, " ")[1]
    if (hotstrings.HasKey(item)) {
        Gui, Show
        command2 := RegExReplace(item, ":o:", "")
        content2 := hotstrings[item]
        ControlSetText, Edit1, %command2%, ahk_class AutoHotkeyGUI
        ControlSetText, Edit2, %content2%, ahk_class AutoHotkeyGUI
        hotstrings.Remove(item)
    }
}

OpenModMenu() {
    Menu, modMenu, Add
    Menu, modMenu, DeleteAll
    for k, v in hotstrings {
        Menu, modMenu, Add, %k%         %v%, ModMacro
    }
    Menu, modMenu, Show
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
    ; Menu, Tray, Add, Oepn Macro List (file), OpenMacros
    Menu, Tray, Add, ModifyMacro, OpenModMenu
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

GuiClose:
    Gui, Submit
    if (StrLen(Command) > 0 && StrLen(Content) > 0) {
        AddMacro(Command, Content)
        ControlSetText, Edit1,
        ControlSetText, Edit2,
    }
return

+!c::
    Send, ^c
    Sleep, 20
    Run, https://www.google.com/search?q=%clipboard%
return