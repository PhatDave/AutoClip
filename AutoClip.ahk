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
        delEntry.Remove()
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

    GetIndex(command) {
        for k, v in this.entries {
            if v.Command == command {
                return k
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
                    parent := tempData[4]
                    newentry := new Entry(rcommand, rcontent, parent)
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
    parent := 0
    children := []

    Command {
        get {
            return this._command
        }
        set {
            this._command := value
            entries.SaveAllToFile()
        }
    }

    Content {
        get {
            return this._content
        }
        set {
            this._content := value
            entries.SaveAllToFile()
        }
    }

    ; Fix this tomorrow, make sure the regex changes object and makes new objects as children
    Enabled {
        get {
            return this._enabled
        }
        set {
            this._enabled := value
            HotString(this.Command, this.content, this._enabled)
            entries.SaveAllToFile()
        }
    }

    __New(command, content, parent:=0) {
        this.Command := this.PadCommand(command)
        this.Content := content
        this.CheckRegex()
        this.Enabled := 0
        this.AddParent(parent)
        allEntries.Insert(this)
        return this
    }

    AddParent(parentC) {
        if (parentC != 0) {
            parentO := entries.Get(parentC)
            this.parent := parentO
            this.parent.AddChild(this)
        }
    }

    GetParent() {
        if (this.parent != 0) {
            return this.parent.Command
        }
        return "0"
    }

    AddChild(child) {
        this.children.Insert(child)
    }

    CheckRegex() {
        if (RegExMatch(this.Command, "\$<.+\$>") > 0 && RegExMatch(this.Content, "\$<i\$>") > 0) {
            posO := RegExMatch(this.Command, "P)\$<[(\d*\w*)+\,?\s*]+\$>", lenO)
            match := SubStr(this.Command, posO + 2, lenO - 4)
            matches := this.GetAllMatches(match, "P)(\d*\w*\,*\s*)")
            matches := this.CleanUpMatches(matches)
        }
    }

    CleanUpMatches(matches) {
        for k, v in matches {
            matches[k] := RegExReplace(matches[k], "\,*", "")
            matches[k] := RegExReplace(matches[k], "^\s+", "")
            matches[k] := RegExReplace(matches[k], "\s+$", "")
        }
    }

    GetAllMatches(string, regex) {
        matches := []
        while (StrLen(string) > 0) {
            position := RegExMatch(string, regex, length)
            matches.Insert(SubStr(string, position, length))
            StringTrimLeft, string, string, length
        }
        return matches
    }

    Remove() {
        entries.entries.RemoveAt(entries.GetIndex(this.Command))
        if (this.parent != 0) {
            this.parent.Remove()
        }
        if (this.children.MaxIndex() > 0) {
            for k, v in this.children {
                v.parent := 0
                v.Remove()
            }
        }
        this.Disable()
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
        return this.Command . "|" . this.Content . "|" . this.enabled . "|" . this.GetParent()
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
        while (StrLen(output) < 16 + 64 + 4)
            output .= " "
        output .= RegExReplace(this.GetParent(), ":o:", "")
        return output
    }
}


global entries := new AllEntries()
entries.ReadFile()

new Entry("test$<1, 2, 3, bacd, fashg, fhidu78, ghauie$>", "test$<i$>")

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
        if (v.parent == 0 && v.children.MaxIndex() == "") {
            output := v.TidyString()
            Menu, modMenu, Add, %output%, ModMacro
        }
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
        new Entry(command, content).Enable()
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