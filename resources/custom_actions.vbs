Option Explicit

Dim oEnv, oFSO, oShell, oWMI

Sub Run_All
    Set oFSO = CreateObject("Scripting.FileSystemObject")
    Set oShell = CreateObject("WScript.Shell")
    Set oEnv = oShell.Environment("PROCESS")
    Set oWMI = GetObject("WinMgmts:root/cimv2")

    Find_Java
    Find_PSModule
    Find_Terminals
End Sub

Sub Find_PSModule
    Dim sDir

    For Each sDir in Split(oEnv("PSModulePath"), ";") 
        If oFSO.FileExists(oFSO.BuildPath(Trim(sDir), "ClojureTools\ClojureTools.psd1")) Then 
            Session.Property("PSMODULEINSTALLED") = sDir
            Exit Sub
        End If
    Next
End Sub

Sub Find_Terminals
    Dim colProcess
    Set colProcess = oWMI.ExecQuery ("SELECT * FROM Win32_Process WHERE Name = 'cmd.exe' OR Name = 'powershell.exe' OR Name = 'pwsh.exe'")
    If colProcess.Count > 0 Then
        Session.Property("ACTIVETERMINALS") = "Yes"
        Exit Sub
    End If
End Sub

Sub Find_Java
    Dim sDir
    
    If oFSO.FileExists(oFSO.BuildPath(Trim(oEnv("JAVA_HOME")), "bin\java.exe")) Then 
        Session.Property("JAVAINSTALLED") = "Yes"
        Exit Sub
    Else 
        For Each sDir in Split(oEnv("PATH"), ";") 
            If oFSO.FileExists(oFSO.BuildPath(Trim(sDir), "java.exe")) Then 
                Session.Property("JAVAINSTALLED") = "Yes"
                Exit Sub
            End If
        Next
    End If
End Sub