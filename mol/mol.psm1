# ================================================================================
# =                                     MOL                                      =
# ================================================================================

# =============================== GET-MACHINEINFO ================================

function Get-MachineInfo {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [string]$LogFailuresToPath,
        [string]$Protocol = 'WSMAN',
        [switch]$ProtocolFallback
    )
    
    BEGIN {
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {
            # Establish session protocol
            if ($Protocol -eq 'DCOM') {
                $Option = New-CimSessionOption -Protocol DCOM
            } else {
                $Option = New-CimSessionOption -Protocol WSMAN
            }

            # Connect session
            $Session = New-CimSession -ComputerName $Computer -SessionOption $Option

            # Query data
            $Os = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $Session

            # Close session
            $Session | Remove-CimSession

            $Os | Select-Object -Property @{Name = 'ComputerName'; Expression = {$Computer}}, Version, ServicePackMajorVersion
        }
    }

    END {
    }
}

# ============================ SET-MASTERSERVICELOGON ============================

function Set-MasterServiceLogon {
    param(
        [string]$ServiceName,
        [string[]]$ComputerName,
        [string]$NewPassword,
        [string]$NewUser,
        [string]$ErrorLogFilePath
    )

    if ($PSBoundParameters.ContainsKey('NewUser')) {
        $Arguments = @{
            StartName = $NewUser
            StartPassword = $NewPassword
        }
    } else {
        $Arguments = @{
            StartPassword = $NewPassword
        }
    }

    foreach ($Computer in $ComputerName) {
        $SessionOption = New-CimSessionOption -Protocol Wsman
        $Session = New-CimSession -SessionOption $SessionOption -ComputerName $Computer

        $Method = @{
            Query = "SELECT * FROM Win32_Service WHERE name = '$ServiceName'"
            MethodName = 'Change'
            Arguments = $Arguments
            ComputerName = $Computer
        }

        Invoke-CimMethod @Method | ForEach-Object {
            [PSCustomObject]@{
                ComputerName = $Computer
                Result = $_.ReturnValue
            }
        }

        $Session | Remove-CimSession
    } 
}
