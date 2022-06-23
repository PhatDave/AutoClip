#NoEnv
#Warn
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent

SetBatchLines, -1

IfExist, mergedinclude.ahk
	FileDelete, mergedinclude.ahk

merged := ""
Loop, Files, %A_ScriptDir%\scripts\*.*
{
	FileRead, merged, %A_LoopFileFullPath%
	FileAppend, %merged%`n, mergedinclude.ahk
}
#Include *i mergedinclude.ahk

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
global backupNo := 150

Save() {
	SetTimer, SaveAllToFile, 1000
}

Backup() {
	FileCreateDir, backups
	FormatTime, currentTime,, yyyy-MM-ddTHH-mm-ss
	target := Format("backups\{1}.txt", currentTime)
	FileCopy, Macros.txt, %target%

	backups := []
	Loop, Files, %A_ScriptDir%\backups\*.*
	{
		backups.Insert(A_Index, A_LoopFileName)
	}

	while (backups.Length() > backupNo) {
		DeleteFirstBackup(backups)
	}
}

DeleteFirstBackup(backups) {
	FormatTime, firstBackup,, yyyy-MM-ddTHH-mm-ss
	firstBackupIndex := -1

	for k, v in backups {
		if (v < firstBackup) {
			firstBackupIndex := k
			firstBackup := v
		}
	}
	FileDelete, backups\%firstBackup%
	backups.Remove(firstBackupIndex)
}

SaveAllToFile() {
	Backup()
	FileDelete, Macros.txt
	for k, v in entries.entries {
		eString := v.ToString()
		entryString := b64Encode(eString)
		StringReplace, entryString, entryString, `r`n,,A
		entryString .= "`r`n"
		FileAppend, %entryString%, Macros.txt
	}
	SetTimer, SaveAllToFile, Off
}

SafeReload() {
	SaveAllToFile()
	reload
}

; Source: https://www.autohotkey.com/board/topic/93570-sortarray/
sortArray(arr,options="") {
	new :=	[]
	list := ""
	For each, item in arr
		list .=	item.Command "`n"
	list :=	Trim(list, "`n")
	Sort, list, %options%
	Loop, parse, list, `n, `r
		new.Insert(entries.Get(A_LoopField))
	return new

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

		data := StrSplit(macros, "`n")

		lastGoodEntry := 1
		for k,v in data {
			if (SubStr(v, 1, 4) != "Om86") {
				data[lastGoodEntry] .= v
				data[k] := ""
			} else {
				lastGoodEntry := k
			}
		}

		for index, macro in data {
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

	Swap(key1, key2) {
		temp := this.entries[key1]
		this.entries[key1] := this.entries[key2]
		this.entries[key2] := temp
	}

	Sort() {
		this.entries := sortArray(this.entries)
	}
}

class EntriesSubsetFilter extends AllEntries {
	static entries := []

	Sort() {
		this.entries := sortArray(this.entries)
	}

	FilterBy(inputStr) {
		this.entries := []
		for k, v in AllEntries.entries {
			if (this.FitsCriteria(inputStr, v)) {
				this.entries.Insert(k, v)
			}
		}
	}

	FitsCriteria(inputStr, entry) {
		words := StrSplit(inputStr, " ")
		for k, v in words {
			if (!InStr(entry._content, v)) {
				return false
			}
		}
		return true
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

class ScriptEntry extends Entry {

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

; The plan
; Add checkbox when adding entry to mark it as a script
; When creating a "script" entry instead of using :o: use :oX:
; When a script entry is added create a new ahk file whose name will resemble the entry command and save the content as a function in the file
; Reload the script
; Script reload will load all the entries and compile the function
; Then replace the content with the function name
; Maybe make another entry that extends entry and has like extra stuff maybe even some overriding methods

; TODO:
; Add filtering by command (in addition to content)
class MainUI extends UI {
	Assemble() {
		uiName := this.name

		Gui, %uiName%:Add, Text,, Enter the command to trigger clip
		Gui, %uiName%:Add, Edit, r1 w300
		Gui, %uiName%:Add, Text,, Enter the clip to be pasted
		Gui, %uiName%:Add, Edit, r16 w300
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

		Gui, %uiName%:Add, Edit, r1 gApplySearch w600
		Gui, %uiName%:Add, ListView, -Multi w600 h600, Command|Content|Enabled
	}

	ApplySearch() {
		if (this.isDefault()) {
			uiName := this.name
			ControlGetText, inputText, Edit1
			EntriesSubsetFilter.filterBy(inputText)
			this.SetAll(EntriesSubsetFilter)
		}
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

	SetAll(entries) {
		this.SetDefault()
		entries.Sort()

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
		entries.Sort()

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
	EditUIO.SetAll(entries)
	EditUIO.ApplySearch()
	EditUIO.Show()
}

OpenToggleMenu() {
	ToggleUIO.SetAll()
	ToggleUIO.Show()
}

MakeTrayMenu() {
	Menu, Tray, Add, Add Macro, AddMacroTray
	Menu, Tray, Add, Remove Macro, OpenRemoveMenu
	Menu, Tray, Add, Modify Macro, OpenModMenu
	Menu, Tray, Add, Toggle Macro, OpenToggleMenu
	Menu, Tray, Add, Reload, SafeReload
}

MakeTrayMenu()

ApplySearch:
	EditUIO.ApplySearch()
return

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