# ================================================================================
# =                                     MOL                                      =
# ================================================================================

# =============================== GET-MACHINEINFO ================================

function Get-MachineInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('CN', 'MachineName', 'Name')]
        [string[]]$ComputerName,

        [string]$LogFailuresToPath,

        [ValidateSet('WSMAN', 'DCOM')]
        [string]$Protocol = 'WSMAN',

        [switch]$ProtocolFallback
    )

    BEGIN {
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {
            # Establish session protocol
            $Option = New-CimSessionOption -Protocol $Protocol

            # Connect session
            $Session = New-CimSession -ComputerName $Computer -SessionOption $Option

            # Query data
            $OsParameters = @{
                Query = 'SELECT * FROM Win32_OperatingSystem'
                CimSession = $Session
            }
            $Os = Get-CimInstance @OsParameters

            $CsParameters = @{
                Query = 'SELECT * FROM Win32_ComputerSystem'
                CimSession = $Session
            }
            $Cs = Get-CimInstance @CsParameters

            $SysDrive = $Os.SystemDrive # Usually returns C:
            $DriveParameters = @{
                Query = "SELECT * FROM Win32_LogicalDisk WHERE DeviceID = '$SysDrive'"
                CimSession = $Session
            }
            $Drive = Get-CimInstance @DriveParameters

            $CpuParameters = @{
                Query = 'SELECT * FROM Win32_Processor'
                CimSession = $Session
            }
            $Cpu = Get-CimInstance @CpuParameters | Select-Object -First 1 # Select first processor

            # Close session
            $Session | Remove-CimSession

            # Output data
            $OutputObject = [PSCustomObject]@{
                ComputerName = $Computer
                OSVersion = $Os.Version
                SPVersion = $Os.ServicePackMajorVersion
                OSBuild = $Os.BuildNumber
                Manufacturer = $Cs.Manufacturer
                Model = $Cs.Model
                CPUs = $Cs.NumberOfProcessors
                Cores = $Cs.NumberOfLogicalProcessors
                RAM = ($Cs.TotalPhysicalMemory / 1GB)
                Architecture = $Cpu.AddressWidth
                SysDriveFreeSpace = $Drive.Freespace
            }

            Write-Output $OutputObject

        }
    }

    END {
    }
}

# ============================ SET-MASTERSERVICELOGON ============================

function Set-MasterServiceLogon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$NewPassword,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$NewUser,

        [string]$ErrorLogFilePath
    )

    BEGIN {
    }

    PROCESS {
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

            $MethodProperties = @{
                CimSession = $Session
                Query = "SELECT * FROM Win32_Service WHERE name = '$ServiceName'"
                MethodName = 'Change'
                Arguments = $Arguments
            }

            $Method = Invoke-CimMethod @MethodProperties

            switch ($Method.ReturnValue) {
                0 {
                    $Status = 'Success'
                }
                22 {
                    $Status = 'Invalid Account'
                }
                default {
                    $Status = "Failed: $($Method.ReturnValue)"
                }
            }

            [PSCustomObject]@{
                ComputerName = $Computer
                Status = $Status
            }

            $Session | Remove-CimSession
        }
    }

    END {
    }
}
