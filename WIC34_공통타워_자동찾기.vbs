Option Explicit

Dim fso, sh, root, engine, observer, html, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")

root = fso.GetParentFolderName(WScript.ScriptFullName)
If LCase(fso.GetFileName(root)) <> "wic34_c_rebuild" Then
    MsgBox "HOLD: Run this file from the WIC34_C_REBUILD root.", 48, "WIC34"
    WScript.Quit
End If

engine = fso.BuildPath(root, "CONTROL_TOWER\tool002_engine.ps1")
observer = fso.BuildPath(root, "CONTROL_TOWER\observer_engine.ps1")
html = fso.BuildPath(root, "CONTROL_TOWER\WIC34_CONTROL_TOWER_V2.html")
If Not fso.FileExists(engine) Or Not fso.FileExists(observer) Or Not fso.FileExists(html) Then
    MsgBox "HOLD: A required CONTROL_TOWER file is missing.", 48, "WIC34"
    WScript.Quit
End If

cmd = "powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -File " & Chr(34) & engine & Chr(34) & " -Root " & Chr(34) & root & Chr(34)
sh.Run cmd, 0, True

cmd = "powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -File " & Chr(34) & observer & Chr(34) & " -Root " & Chr(34) & root & Chr(34)
sh.Run cmd, 0, False
WScript.Sleep 1500
sh.Run Chr(34) & html & Chr(34), 1, False
