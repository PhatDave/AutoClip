#NoEnv
#Warn
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent
#Hotstring r

SetBatchLines, -1

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
        if !this.Get(entry.Command) {
            this.entries.Insert(entry)
        }
    }

    Remove(command) {
        delEntry := this.Get(command)
        this.entries.Remove(delEntry)
        delEntry.Disable()
        this.SaveAllToFile()
    }

    Get(command) {
        for k, v in this.entries {
            if v.Command == command {
                return v
            }
        }
        return 0
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
        return this
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

    ; Maybe one day do proper GUI instead of tray?
    TidyString() {
        output := ""
        output .= this.Command
        while (StrLen(output) < 16)
            output .= " "
        output .= this.Content
        while (StrLen(output) < 16 + 64)
            output .= " "
        output .= this.Enabled
        return output
    }
}


global entries := new AllEntries()
entries.ReadFile()

new Entry("test", "test123", entries).Enable()
new Entry("test1", "testasd", entries).Enable()
new Entry("test2", "test1gfg", entries).Enable()
new Entry("test3", "test1fga3", entries).Enable()

; asd1 := RegExMatch("asdfasfg$<asd, 2, 1, 4, 5$>", "\$<[(\d*\w*)+\,?\s*]+\$>", test123, 1)
; dfsajdh := new Entry("test", "test2")
; dfsajdh.PadCommand()
; tooltip, asd1

AddMacroTray() {
    Gui, Show
}

OpenRemoveMenu() {
    Menu, macroMenu, Add
    Menu, macroMenu, DeleteAll
    for k, v in entries.entries {
        output := v.TidyString()
        Menu, macroMenu, Add, %output%, RemoveMacro
    }
    Menu, macroMenu, Show
}

OpenModMenu() {
    Menu, modMenu, Add
    Menu, modMenu, DeleteAll
    for k, v in entries.entries {
        output := v.TidyString()
        Menu, modMenu, Add, %output%, ModMacro
    }
    Menu, modMenu, Show
}

ModMacro() {
    modCommand := StrSplit(A_ThisMenuItem, " ")[1]
    modEntry := entries.Get(modCommand)
    modContent := modEntry.Content
    modCommand := RegExReplace(modCommand, ":o:", "")
    if (modEntry) {
        Gui, Show
        ControlSetText, Edit1, %modCommand%, ahk_class AutoHotkeyGUI
        ControlSetText, Edit2, %modContent%, ahk_class AutoHotkeyGUI
        entries.Remove(modCommand)
    }
}

RemoveMacro() {
    entries.Remove(StrSplit(A_ThisMenuItem, " ")[1])
}

Reload() {
    reload
}

MakeTrayMenu() {
    Menu, Tray, Add, Add Macro, AddMacroTray
    Menu, Tray, Add, Remove Macro, OpenRemoveMenu
    Menu, Tray, Add, Modify Macro, OpenModMenu
    Menu, Tray, Add, Reload, Reload
}

MakeTrayMenu()

; Gui
global vGUICommand := ""
global vGUIContent := ""
Gui, Add, Text,, Enter the command to trigger clip
Gui, Add, Edit, r1 w300 vGUICommand
Gui, Add, Text,, Enter the clip to be pasted
Gui, Add, Edit, r1 w300 vGUIContent
; Gui, Show

HandleInput(command, content) {
    if (StrLen(command) > 0 && StrLen(content) > 0) {
        new Entry(command, content, entries).Enable()
        ControlSetText, Edit1,
        ControlSetText, Edit2,
    }
}

~Enter::
    if (WinActive("ahk_class AutoHotkeyGUI")) {
        Gui, Submit
        HandleInput(GUICommand, GUIContent)
    }
return

GuiClose:
    Gui, Submit
    HandleInput(GUICommand, GUIContent)
return

+!c::
    Send, ^c
    Sleep, 20
    Run, https://www.google.com/search?q=%clipboard%
return