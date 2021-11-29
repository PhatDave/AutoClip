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

global timer := 0
global currentDefaultUI := ""

Save() {
    SetTimer, SaveAllToFile, 20
}

SaveAllToFile() {
    file := FileOpen("Macros.txt", "W")
    for k, v in entries.entries {
        eString := v.ToString()
        entryString := b64Encode(eString)
        file.write(entryString)
    }
    file.close()
    SetTimer, SaveAllToFile, Off
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
        Save()
    }

    Get(command) {
        if (!InStr(command, ":o:")) {
            command := Entry.PadCommand(command)
        }
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

    ReadFile() {
        IfNotExist, Macros.txt
            FileAppend,, Macros.txt
        FileRead, macros, Macros.txt
        for index, macro in StrSplit(macros, "`n") {
            if (StrLen(macro) > 3) {
                macro := b64Decode(macro)
                tempData := StrSplit(macro, "|")
                rcommand := tempData[1]
                rcontent := this.FixContent(tempData[2])
                isenabled := tempData[3]
                if (isenabled == "")
                    isenabled := 1
                parent := this.Get(tempData[4])
                newentry := new Entry(rcommand, rcontent, parent)
                if (isenabled == 1) {
                    newentry.Enable()
                } else {
                    newentry.Disable()
                }
            }
        }
    }

    FixContent(content) {
        content := RegExReplace(content, "`n$`")
        ; Assuring backwards compatibility with 1.x
        content := RegExReplace(content, " ", "¨")
        ; content := RegExReplace(content, "\$spc\$", " ")
        return content
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
            Save()
        }
    }

    Content {
        get {
            outContent := RegExReplace(this._content, "¨", " ")
            return outContent
        }
        set {
            newValue := RegExReplace(value, "\s", "¨")
            this._content := newValue
            Save()
        }
    }

    Enabled {
        get {
            return this._enabled
        }
        set {
            this._enabled := value
            HotString(this.Command, this.Content, this._enabled)
            Save()
        }
    }

    __New(command, content, parent:=0) {
        this.Command := this.PadCommand(command)
        this.Content := content
        this.CheckRegex()
        this.Enabled := 0
        this.AddParent(parent)
        entries.Insert(this)
        return this
    }

    AddParent(parentO) {
        if (parentO != 0) {
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

            baseCommand := this.Command
            baseContent := this.Content

            pos := RegExMatch(this.Content, "P)\$<i\$>", len)
            this.Command := RegExReplace(this.Command, "\$<[(\d*\w*)+\,?\s*]+\$>", matches[1])
            this.Content := RegExReplace(this.Content, "\$<i\$>", matches[1])
            matches.RemoveAt(1)
            allEntries.Insert(this)

            for k, v in matches {
                newCommand := RegExReplace(baseCommand, "\$<[(\d*\w*)+\,?\s*]+\$>", v)
                newContent := RegExReplace(baseContent, "\$<i\$>", v)
                new Entry(newCommand, newContent, this).Enable()
            }
        }
    }

    CleanUpMatches(matches) {
        for k, v in matches {
            matches[k] := RegExReplace(matches[k], "\,*", "")
            matches[k] := RegExReplace(matches[k], "^\s+", "")
            matches[k] := RegExReplace(matches[k], "\s+$", "")
        }
        return matches
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

    Toggle() {
        if (this.Enabled) {
            this.Disable()
        } else {
            this.Enable()
        }
    }

    Enable() {
        this.Enabled := 1
    }

    Disable() {
        this.Enabled := 0
    }

    ToString() {
        debugC := this._content
        fuckoff := this.Content
        return this.Command . "|" . this._content . "|" . this.enabled . "|" . this.GetParent()
    }
    
    HasChildren() {
        index := this.children.MaxIndex()
        return index != ""
    }
}

Class UI {
    static UIs := {}
    isDefault := false
    name := ""

    SetDefault() {
        this.DisableAll()
        this.isDefault := true
        tempname := this.name
        if (StrLen(tempname) > 0) {
            Gui, %tempname%:Default
        }
    }

    DisableAll() {
        for k,v in this.UIs {
            v.isDefault := false
        }
    }

    GetDefault() {
        for k,v in this.UIs {
            if v.isDefault {
                return v
            }
        }
    }

    __New(name) {
        this.UIs.Insert(this)
        this.name := name
        Gui, New,, %name%
        this.SetDefault()
        this.Assemble()
    }

    Show() {
        this.SetDefault()
        Gui, Show
    }

    Hide() {
        this.SetDefault()
        Gui, Hide
    }
}

class MainUI extends UI {
    Assemble() {
        uiName := this.name

        Gui, %uiName%:Add, Text,, Enter the command to trigger clip
        Gui, %uiName%:Add, Edit, r1 w300
        Gui, %uiName%:Add, Text,, Enter the clip to be pasted
        Gui, %uiName%:Add, Edit, r1 w300
    }

    HandleInput() {
        uiName := this.name
        Gui, %uiName%:Submit
        Gui, %uiName%:Hide

        ControlGetText, commandI, Edit1
        ControlGetText, contentI, Edit2
        if (StrLen(commandI) > 0 && StrLen(contentI) > 0) {
            new Entry(commandI, contentI).Enable()
            GuiControl,, Edit1,
            GuiControl,, Edit2,
        }
    }

    DisplayEntry(entry) {
        if (entry) {
            this.Show()

            command := RegExReplace(entry.command, ":o:", "")
            content := entry.content

            uiName := this.name
            GuiControl,, Edit1, %command%
            GuiControl,, Edit2, %content%
        }
    }
}

class EditUI extends UI {
    Assemble() {
        uiName := this.name

        Gui, %uiName%:Add, ListView, -Multi w600 h600, Command|Content|Enabled
    }

    HandleInput() {
        if (this.isDefault) {
            uiName := this.name
            Gui, %uiName%:Hide
            this.SetDefault()
            ; Gui, %uiName%:Default

            selectedRow := LV_GetNext()
            LV_GetText(command, selectedRow, 1)
            LV_GetText(content, selectedRow, 2)
            LV_GetText(enabled, selectedRow, 3)

            modEntry := entries.Get(command)
            MainUIO.DisplayEntry(modEntry)
            entries.Remove(command)
        }
    }

    SetAll() {
        this.SetDefault()

        LV_Delete()
        for k, v in entries.entries {
            if (!v.parent && !v.HasChildren()) {
                LV_Add("", RegExReplace(v.Command, ":o:", ""), v.Content, v.Enabled)
            }
        }
        LV_ModifyCol()
        Gui, Show
    }
}

class ToggleUI extends UI {
    Assemble() {
        uiName := this.name

        Gui, %uiName%:Add, ListView, w600 h600, Command|Content|Enabled
    }

    HandleInput() {
        if (this.isDefault) {
            uiName := this.name
            this.SetDefault()
            Gui, %uiName%:Hide
            ; Gui, %uiName%:Default

            firstRun := 1
            selectedRow := 0
            while(selectedRow || firstRun) {
                if (firstRun) {
                    firstRun := 0
                }
                selectedRow := LV_GetNext(selectedRow)
                LV_GetText(command, selectedRow, 1)
                LV_GetText(content, selectedRow, 2)
                LV_GetText(enabled, selectedRow, 3)

                modEntry := entries.Get(command)
                modEntry.Toggle()
            }
        }
    }

    SetAll() {
        this.SetDefault()

        LV_Delete()
        for k, v in entries.entries {
            LV_Add("", RegExReplace(v.Command, ":o:", ""), v.Content, v.Enabled)
        }
        LV_ModifyCol()
        Gui, Show
    }
}

class RemoveUI extends ToggleUI {
    HandleInput() {
        if (this.isDefault) {
            uiName := this.name
            this.SetDefault()
            Gui, %uiName%:Hide
            ; Gui, %uiName%:Default

            firstRun := 1
            selectedRow := 0
            while(selectedRow || firstRun) {
                if (firstRun) {
                    firstRun := 0
                }
                selectedRow := LV_GetNext(selectedRow)
                LV_GetText(command, selectedRow, 1)
                LV_GetText(content, selectedRow, 2)
                LV_GetText(enabled, selectedRow, 3)

                modEntry := entries.Remove(command)
            }
        }
    }
}

global entries := new AllEntries()
entries.ReadFile()

global MainUIO := new MainUI("Main")
global EditUIO := new EditUI("Edit")
global ToggleUIO := new ToggleUI("Toggle")
global RemoveUIO := new RemoveUI("Remove")

AddMacroTray() {
    MainUIO.Show()
}

OpenRemoveMenu() {
    RemoveUIO.SetAll()
    RemoveUIO.Show()
}

OpenModMenu() {
    EditUIO.SetAll()
    EditUIO.Show()
}

OpenToggleMenu() {
    ToggleUIO.SetAll()
    ToggleUIO.Show()
}

Reload() {
    reload
}

MakeTrayMenu() {
    Menu, Tray, Add, Add Macro, AddMacroTray
    Menu, Tray, Add, Remove Macro, OpenRemoveMenu
    Menu, Tray, Add, Modify Macro, OpenModMenu
    Menu, Tray, Add, Toggle Macro, OpenToggleMenu
    Menu, Tray, Add, Reload, Reload
}

MakeTrayMenu()

~Esc::
    if (WinActive("ahk_class AutoHotkeyGUI")) {
        UI.GetDefault().Hide()
    }
return

~Enter::
    if (WinActive("ahk_class AutoHotkeyGUI")) {
        UI.GetDefault().HandleInput()
    }
return

GuiClose:
    UI.GetDefault().HandleInput()
return

+!c::
    Send, ^c
    Sleep, 20
    Run, https://www.google.com/search?q=%clipboard%
return