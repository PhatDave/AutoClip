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

    DisalbeAll() {
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

    Display() {
        this.SetDefault()
        Gui, Show
    }
}


class MainUI extends UI {
    Assemble() {
        static GUICommand := ""
        static GUIContent := ""

        Gui, Add, Text,, Enter the command to trigger clip
        Gui, Add, Edit, r1 w300 vGUICommand
        Gui, Add, Text,, Enter the clip to be pasted
        Gui, Add, Edit, r1 w300 vGUIContent
    }

    HandleInput() {
        if (StrLen(GUICommand) > 0 && StrLen(GUIContent) > 0) {
            new Entry(GUICommand, GUIContent).Enable()
            ControlSetText, Edit1,
            ControlSetText, Edit2,
        }
    }
}

class EditUI extends UI {
    Assemble() {
        this.SetDefault()
    }
}

global MainUI := new MainUI("Main")
global EditUI := new EditUI("Edit")
MsgBox, test
MainUI.Display()