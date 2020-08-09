

Function Test-P026 {
 

    # example 1
    Get-Process | Where-Object {$_.ProcessName -eq 'svchost'} |     Select-Object CPU | Where-Object {$_.CPU -ne $null}

    # example 2
    Get-Process -Name 'svchost' | Where-Object {$_.CPU -ne $null} | 	Select-Object CPU

    # 10 Milli seconds
    Measure-Command {Get-Process | Where-Object {$_.ProcessName -eq 'svchost'} |     Select-Object CPU | Where-Object {$_.CPU -ne $null}}

    # 5 Milli seconds
    Measure-Command {Get-Process -Name 'svchost' | Where-Object {$_.CPU -ne $null} | 	Select-Object CPU}
    
    # this stacks psjob
    Start-Job -Scriptblock {Start-Sleep 5}

    # status : Completed, Running, Blocked, Failed.
    Get-Job

    # job commands?
    Get-Command *-Job

    # delete Job
    Remove-Job 1
    Get-Job

    # 103 Milliseconds
    Measure-Command { Start-Job -ScriptBlock {Start-Sleep -s 5} }

    # retreive output
    $Job = Start-Job -ScriptBlock {Write-Output 'Hello World'}
    Receive-Job $Job

    # multiple jobs
    $Test = 'test'
    $Something = 1..10
    1..5 | ForEach-Object { 
        start-job -Name $_ -ScriptBlock {
            [pscustomobject]@{
                Result=($_*2)
                Test=$Using:Test
                Something=$Using:Something
            }
        }
    }            
    Get-job | Receive-Job

    # remove-job which are done.
    Get-job | Where-Object {$_.State -eq 'Completed'} | remove-Job


    # ScheduledJob
    $Trigger = New-JobTrigger -AtLogon
    $Script = {"User $env:USERNAME logged in at $(Get-Date -Format 'y-M-d H:mm:ss')" | Out-File -FilePath C:\Temp\Login.log -Append}
    Register-ScheduledJob -Name Log_Login -ScriptBlock $Script -Trigger $Trigger

    # find command run as job
    Get-Command -ParameterName AsJob

    # this takes 5 sec
    Invoke-Command -ScriptBlock {Start-Sleep 5} -ComputerName localhost

    # really?
    Measure-Command {Invoke-Command -ScriptBlock {Start-Sleep 5}}

    # what about this? 8 MilliSeconds
    Measure-Command {Invoke-Command -ScriptBlock {Start-Sleep 5} -AsJob -ComputerName localhost}


    # runspaces is like PSJobs
    Measure-Command {
        $Runspace = [runspacefactory]::CreateRunspace()
        $PowerShell = [powershell]::Create()
        $PowerShell.Runspace = $Runspace
        $Runspace.Open()
        $PowerShell.AddScript({Start-Sleep 5})
        $Job = $PowerShell.BeginInvoke()
    }

    # should run these when job is completed.
    $PowerShell.EndInvoke($Job)
    $Runspace.Close()
    
    # 10 Runspaces?, 50 seconds
    # 다음 BeginInvoke하기 전에 현재의 Job이 끝나기를 기다린다.
    Measure-Command { $Runspace = [runspacefactory]::CreateRunspace()
        $PowerShell = [powershell]::Create()
        $PowerShell.Runspace = $Runspace
        $Runspace.Open()
        $PowerShell.AddScript({Start-Sleep 5})
        
        1..10 | Foreach-Object {
            $Job = $PowerShell.BeginInvoke()
            while ($Job.IsCompleted -eq $false) {Start-Sleep -Milliseconds 100}
        }
    }


    # using RunspacePool with Throttle Limit 5 and 10 Runspaces
    # RunspacePool은 Thread를 가질 수 있다.
    # 동시에 전부 실행하고 모두가 다 끝나기를 기다린다.
    $Scriptblock = {
        param($Name)
        New-Item -Name $Name -ItemType File
    }
    
    $MaxThreads = 5
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $RunspacePool.Open()
    $Jobs = @()
    
    1..10 | Foreach-Object {
        $PowerShell = [powershell]::Create()
        $PowerShell.RunspacePool = $RunspacePool
        $PowerShell.AddScript($ScriptBlock).AddArgument($_)
        $Jobs += $PowerShell.BeginInvoke()
    }
    
    while ($Jobs.IsCompleted -contains $false) {
        Start-Sleep 1
    }

    # Install-Module PoshRSJob
    Install-Module PoshRSJob

    # 90 Milliseconds
    Measure-Command {Start-Job -ScriptBlock {Start-Sleep 5}}

    # 30 Milliseconds
    Measure-Command {Start-RSJob -ScriptBlock {Start-Sleep 5}}

    # pwsh 7

    Measure-Command {1..10 | Foreach-Object {Start-Sleep 5}} # 50 seconds
    Measure-Command {1..10 | Foreach-Object -Parallel {Start-Sleep 5}} # 10 Milliseconds

    # psjob
    Start-Job -Scriptblock {param ($Text) Write-Output $Text} -ArgumentList "Hello world!"

    # rsjob
    Start-RSJob -Scriptblock {param ($Text) Write-Output $Text} -ArgumentList "Hello world!"

    # AddArgument() method for Runspace
    $Runspace = [runspacefactory]::CreateRunspace()
    $PowerShell = [powershell]::Create()
    $PowerShell.Runspace = $Runspace
    $Runspace.Open()
    $PowerShell.AddScript({param ($Text) Write-Output $Text})
    $PowerShell.AddArgument("Hello world!")
    $PowerShell.BeginInvoke()

    # AddArgument() method for RunspacePool
    $MaxThreads = 5
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    $RunspacePool.Open()
    $PowerShell.AddScript({param ($Text) Write-Output $Text})
    $PowerShell.AddArgument("Hello world!")
    $PowerShell.BeginInvoke()

    # logging?
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, 5)
    $RunspacePool.Open()
    1..100 | Foreach-Object {
        $PowerShell = [powershell]::Create().AddScript({'Hello' | Out-File -Append -FilePath .\Test.txt})
        $PowerShell.RunspacePool = $RunspacePool
        $PowerShell.BeginInvoke()
    }
    $RunspacePool.Close()

    # check count, 100? no.
    (gc .\Test.txt).Count   
}

