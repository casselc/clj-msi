Option Explicit

Const msiMessageTypeInfo = &H04000000

Dim oEnv, oFSO, oShell, oWMI, OMsg

Sub Log(sMsg)
    oMsg.StringData(1) = sMsg
    Session.Message msiMessageTypeInfo, oMsg
End Sub

Function Exists(ByVal sPath)
    sPath = Replace(sPath,"\", "\\")
    Exists = (oWMI.ExecQuery("SELECT * FROM CIM_DataFile WHERE Name = '" & sPath & "'").Count = 1)
End Function

Sub Run_All
    Set oFSO = CreateObject("Scripting.FileSystemObject")
    Set oShell = CreateObject("WScript.Shell")
    Set oEnv = oShell.Environment("PROCESS")
    Set oWMI = GetObject("WinMgmts:root/cimv2")
    Set oMsg = Installer.CreateRecord(1)
    oMsg.StringData(0) = "Log: [1]"

    Find_Java
    Find_PSModule
    Find_Terminals
End Sub

Sub Find_PSModule
    Dim sDir

    For Each sDir in Split(oEnv("PSModulePath"), ";") 
        If Exists(oFSO.BuildPath(Trim(sDir), "ClojureTools\ClojureTools.psd1")) Then 
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
    Dim sPath, bExists, oDir, oFile

    sPath = oFSO.BuildPath(Trim(oEnv("JAVA_HOME")), "bin\java.exe")
    If Exists(sPath) Then 
        Log "Found Java at " & sPath
        Session.Property("JAVAINSTALLED") = sPath
        Exit Sub
    Else 
        For Each sPath in Split(oEnv("PATH"), ";") 
            sPath = oFSO.BuildPath(Trim(sPath), "java.exe")
            If Exists(sPath) Then 
                Log "Found Java at " & sPath
                Session.Property("JAVAINSTALLED") = sPath
                Exit Sub
            End If
        Next
    End If
End Sub