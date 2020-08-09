<#
#>
Function Test-P030 {
    $script = @'
    Write-Host $Args
'@
    $script > Test-P030-Test.ps1
    . .\Test-P030-Test.ps1 1 2 3
}

