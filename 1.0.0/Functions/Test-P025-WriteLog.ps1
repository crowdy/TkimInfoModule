Function set-writelog{
    [CmdletBinding()]
    Param(
        [string] $Fname,
        [string] $Command,
        [string] $Action
    )
    try {

        $Log = @()
        $objPs = New-Object PSCustomObject
        $objPs | Add-Member -NotePropertyMembers @{DateTime = Get-Date}
        $objPs | Add-Member -NotePropertyMembers @{Function = $Fname}
        $objPs | Add-Member -NotePropertyMembers @{Command = $Command}
        $objPs | Add-Member -NotePropertyMembers @{Action = $Action}
        $Log += $objPs

        $LogFile = "C:\Log\kase_" + (Get-Date).ToString("yyyyMMdd") + ".txt"

        $mutex = New-Object System.Threading.Mutex($false, "logwrite")
        $mutex.WaitOne()
        $LogText = $Log | Out-String -Stream -Width 9999 | ? {$_ -ne ""}
        $LogText += "------------------------------"
        $LogText | Out-File -FilePath $LogFile -Encoding Default -Append -Width 99999
        $mutex.ReleaseMutex()
        Return $Log
    } catch {
        Write-Error $_.Exception
    }
}