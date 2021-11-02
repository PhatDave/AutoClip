#NoEnv
#Warn
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance force
#Persistent
#Hotstring r

; Hotstring(":o:eml", "kosmodiskclassic0@gmail.com")

global hotstrings := {}

AddHotstring(command, content) {
    if (!hotstrings.HasKey(command)) {
        hotstrings[command] := content
        HotString(command, content)
    }
}

ReadFile() {
    IfNotExist, Macros.txt
        FileAppend,, Macros.txt
    FileRead, macros, Macros.txt
    for index, macro in StrSplit(macros, "`n") {
        tempData := StrSplit(macro, "|")
        if (tempData.Length() == 2) {
            command := tempData[1]
            content := tempData[2]
            AddHotstring(command, content)
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

ReadFile()

UpdateFile()

F5::reload