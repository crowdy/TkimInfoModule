Function Test-P025 {
    $MaxThreads = 10
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    $RunspacePool.Open()
    $PowerShell.AddScript({ 
    
        $cmd = Get-Command "set-writelog" -ErrorAction SilentlyContinue
        if (! $cmd) {
            . "C:\Users\Administrator\Documents\PowerShell\Modules\TkiminfoModule\1.0.0\Functions\Test-P025-WriteLog.ps1"
        }
        $Fname = "test.log"
        $Command = "command"
        $Action = "action"
        1..100000 | foreach-object { set-writelog $Fname $Command $Action }
        Write-Host "Done"
    })
    $PowerShell.AddArgument("Hello world!")
    $Job = $PowerShell.BeginInvoke()

    # after done
    $PowerShell.EndInvoke($Job)
    $RunspacePool.Close()
    
}

Function Test-P025-2 {
    $MaxThreads = 10
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    $RunspacePool.Open()
    $PowerShell.AddScript({ 
    
        $cmd = Get-Command "Add-LoggingTarget" -ErrorAction SilentlyContinue
        if (! $cmd) {
            Import-Module Logging

            $Fname = "test.log"
            Add-LoggingTarget -Name File -Configuration @{
                Path = "C:\Log\logging_$Fname"
                Append = $True
                Encoding = "utf8"
            }
        }

        $Command = "command"
        $Action = "action"
        foreach ($i in 1..100000) {
            Write-Log -Level 'WARNING' -Message 'Hello, {0} {0}!' -Arguments $Command,$Action
        }

    })
    $PowerShell.AddArgument("Hello world!")
    $Job = $PowerShell.BeginInvoke()

    # after done
    $PowerShell.EndInvoke($Job)
    $RunspacePool.Close()
}

Function Test-P025-3 {
    if ($PSVersionTable.PSVersion -ge [version]::Parse("7.0")) {
        Measure-Command  {
            $Fname = "test.log"
            $Command = "command"
            $Action = "action"
            1..100000| foreach-object -Parallel {
                $f = gcm set-writelog
                if (!$f) {
                    . c:\log\set-writelog.ps1
                }
                set-writelog $Fname $Command $Action
            }
        }
    }
}

