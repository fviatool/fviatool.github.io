Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell -ExecutionPolicy Bypass -File \"dist\all_urls.ps1\"", 0, False
