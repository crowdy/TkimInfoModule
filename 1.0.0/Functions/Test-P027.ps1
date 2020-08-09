Function Test-P027 {


    Get-WmiObject -Class Win32_Product

    # SCCM/SMS client 가 설치되어 있는 경우.
    gwmi Win32Reg_AddRemovePrograms

}

<#
store app인 경우
Get-AppxPackage


HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
    For 32-bit applications
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\
    For 64-bit applications

Get-WmiObject -Class Win32_Product -Filter 'Name like "%Microsoft Office%"' | 
Select Caption,InstallLocation



Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | % { Get-ItemProperty $_.PsPath } | Select DisplayName,InstallLocation | Sort-Object Displayname -Descending
Get-ChildItem HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | % { Get-ItemProperty $_.PsPath } | Select DisplayName,InstallLocation | Sort-Object Displayname -Descending

Get-Software https://mcpmag.com/articles/2017/07/27/gathering-installed-software-using-powershell.aspx
#>

Function Get-Software {
    [OutputType('System.Software.Inventory')]
    [Cmdletbinding()] 
    Param( 
        [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)] 
        [String[]]$Computername=$env:COMPUTERNAME
    )

    ForEach ($Computer in $Computername) { 
        If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
            $Paths = @(
                "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
                "SOFTWARE\\Wow6432node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
            )
            ForEach($Path in $Paths) { 
                Write-Verbose "Checking Path: $Path"

                # Create an instance of the Registry Object and open the HKLM base key 
                Try { 
                    $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$Computer,'Registry64') 
                } Catch {
                    Write-Error $_ 
                    Continue 
                } 

                # Drill down into the Uninstall key using the OpenSubKey Method 
                Try {
                    $regkey=$reg.OpenSubKey($Path)

                    # Retrieve an array of string that contain all the subkey names 
                    $subkeys=$regkey.GetSubKeyNames()

                    # Open each Subkey and use GetValue Method to return the required values for each 
                    ForEach ($key in $subkeys) {
                        Write-Verbose "Key: $Key"
                        $thisKey=$Path+"\\"+$key 
                        Try {
                            $thisSubKey=$reg.OpenSubKey($thisKey)

                            # Prevent Objects with empty DisplayName 
                            $DisplayName = $thisSubKey.getValue("DisplayName")
                            If ($DisplayName -AND $DisplayName -notmatch '^Update for|rollup|^Security Update|^Service Pack|^HotFix') {
                                $Date = $thisSubKey.GetValue('InstallDate')
                                If ($Date) { 
                                    Try {
                                        $Date = [datetime]::ParseExact($Date, 'yyyyMMdd', $Null)
                                    } Catch {
                                        Write-Warning "$($Computer): $_ <$($Date)>"
                                        $Date = $Null
                                    }
                                }

                                # Create New Object with empty Properties 
                                $Publisher = Try {
                                    $thisSubKey.GetValue('Publisher').Trim()
                                } Catch {
                                    $thisSubKey.GetValue('Publisher')
                                }

                                $Version = Try {
                                    #Some weirdness with trailing [char]0 on some strings
                                    $thisSubKey.GetValue('DisplayVersion').TrimEnd(([char[]](32,0)))
                                } Catch {
                                    $thisSubKey.GetValue('DisplayVersion')
                                }

                                $UninstallString = Try {
                                    $thisSubKey.GetValue('UninstallString').Trim()
                                } Catch {
                                    $thisSubKey.GetValue('UninstallString')
                                }

                                $InstallLocation = Try {
                                    $thisSubKey.GetValue('InstallLocation').Trim()
                                } Catch {
                                    $thisSubKey.GetValue('InstallLocation')
                                }

                                $InstallSource = Try { 
                                    $thisSubKey.GetValue('InstallSource').Trim()
                                } Catch {
                                    $thisSubKey.GetValue('InstallSource')
                                }
                            
                                $HelpLink = Try {
                                    $thisSubKey.GetValue('HelpLink').Trim()
                                } Catch {
                                    $thisSubKey.GetValue('HelpLink')
                                }
                            
                                $Object = [pscustomobject]@{
                                    Computername = $Computer
                                    DisplayName = $DisplayName
                                    Version = $Version
                                    InstallDate = $Date
                                    Publisher = $Publisher
                                    UninstallString = $UninstallString
                                    InstallLocation = $InstallLocation
                                    InstallSource = $InstallSource
                                    HelpLink = $thisSubKey.GetValue('HelpLink')
                                    EstimatedSizeMB = [decimal]([math]::Round(($thisSubKey.GetValue('EstimatedSize')*1024)/1MB,2))
                                }
                                $Object.pstypenames.insert(0,'System.Software.Inventory')
                                Write-Output $Object
                            }
                        } Catch {
                            Write-Warning "$Key : $_"
                        }
                    }
                } Catch {}
                $reg.Close() 
            }
        } Else {
            Write-Error "$($Computer): unable to reach remote system!"
        }
    } 
} 


Function Get-InstalledApplication {
    [CmdletBinding()]
    Param(
      [Parameter(
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true
      )]
      [String[]]$ComputerName=$ENV:COMPUTERNAME,
  
      [Parameter(Position=1)]
      [String[]]$Properties,
  
      [Parameter(Position=2)]
      [String]$IdentifyingNumber,
  
      [Parameter(Position=3)]
      [String]$Name,
  
      [Parameter(Position=4)]
      [String]$Publisher
    )
    Begin{
      Function IsCpuX86 ([Microsoft.Win32.RegistryKey]$hklmHive){
        $regPath='SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
        $key=$hklmHive.OpenSubKey($regPath)
  
        $cpuArch=$key.GetValue('PROCESSOR_ARCHITECTURE')
  
        if($cpuArch -eq 'x86'){
          return $true
        }else{
          return $false
        }
      }
    }
    Process{
      foreach($computer in $computerName){
        $regPath = @(
          'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
          'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        )
  
        Try{
          $hive=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
            [Microsoft.Win32.RegistryHive]::LocalMachine, 
            $computer
          )
          if(!$hive){
            continue
          }
          
          # if CPU is x86 do not query for Wow6432Node
          if($IsCpuX86){
            $regPath=$regPath[0]
          }
  
          foreach($path in $regPath){
            $key=$hive.OpenSubKey($path)
            if(!$key){
              continue
            }
            foreach($subKey in $key.GetSubKeyNames()){
              $subKeyObj=$null
              if($PSBoundParameters.ContainsKey('IdentifyingNumber')){
                if($subKey -ne $IdentifyingNumber -and 
                  $subkey.TrimStart('{').TrimEnd('}') -ne $IdentifyingNumber){
                  continue
                }
              }
              $subKeyObj=$key.OpenSubKey($subKey)
              if(!$subKeyObj){
                continue
              }
              $outHash=New-Object -TypeName Collections.Hashtable
              $appName=[String]::Empty
              $appName=($subKeyObj.GetValue('DisplayName'))
              if($PSBoundParameters.ContainsKey('Name')){
                if($appName -notlike $name){
                  continue
                }
              }
              if($appName){
                if($PSBoundParameters.ContainsKey('Properties')){
                  if($Properties -eq '*'){
                    foreach($keyName in ($hive.OpenSubKey("$path\$subKey")).GetValueNames()){
                      Try{
                        $value=$subKeyObj.GetValue($keyName)
                        if($value){
                          $outHash.$keyName=$value
                        }
                      }Catch{
                        Write-Warning "Subkey: [$subkey]: $($_.Exception.Message)"
                        continue
                      }
                    }
                  }else{
                    foreach ($prop in $Properties){
                      $outHash.$prop=($hive.OpenSubKey("$path\$subKey")).GetValue($prop)
                    }
                  }
                }
                $outHash.Name=$appName
                $outHash.IdentifyingNumber=$subKey
                $outHash.Publisher=$subKeyObj.GetValue('Publisher')
                if($PSBoundParameters.ContainsKey('Publisher')){
                  if($outHash.Publisher -notlike $Publisher){
                    continue
                  }
                }
                $outHash.ComputerName=$computer
                $outHash.Path=$subKeyObj.ToString()
                New-Object -TypeName PSObject -Property $outHash
              }
            }
          }
        }Catch{
          Write-Error $_
        }
      }
    }
    End{}
  }

<#

Get-InstalledApplication https://codeandkeep.com/Get-List-of-Installed-Applications/

#>