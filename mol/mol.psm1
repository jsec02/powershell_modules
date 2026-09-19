# ================================================================================
# =                                     MOL                                      =
# ================================================================================

# =============================== GET-MACHINEINFO ================================

function Get-MachineInfo {
    <#
    .SYNOPSIS
    Retrieves specific information about one or more computers using WMI or CIM.

    .DESCRIPTION
    This command uses either WMI or CIM to retrieve specific information about
    one or more computers. You must run this command as a user with
    permission to query CIM or WMI on the machines involved remotely. You can
    specify a starting protocol (CIM by default), and specify that, in the
    event of a failure, the other protocol be used on a per-machine basis.

    .PARAMETER ComputerName
    One or more computer names. When using WMI, this can also be IP addresses.
    IP addresses may not work for CIM.

    .PARAMETER LogFailuresToPath
    A path and filename to write failed computer names to. If omitted, no log
    will be written.

    .PARAMETER Protocol
    Valid values: Wsman (uses CIM) or Dcom (uses WMI). It will be used for all
    machines. "Wsman" is the default.

    .PARAMETER ProtocolFallback
    Specify this to try the other protocol if a machine fails automatically.

    .EXAMPLE
    Get-MachineInfo -ComputerName ONE,TWO,THREE
    This example will query three machines.

    .EXAMPLE
    Get-ADUser -filter * | Select -Expand Name | Get-MachineInfo
    This example will attempt to query all machines in AD.
    #>

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
            Write-Verbose "Connecting to $Computer over $Protocol"
            $Session = New-CimSession -ComputerName $Computer -SessionOption $Option

            # Query data
            Write-Verbose "Querying from $Computer"
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
            Write-Verbose "Closing session to $Computer"
            $Session | Remove-CimSession

            # Output data
            Write-Verbose "Outputting for $Computer"
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
    <#
    .SYNOPSIS
    Sets service login name and password.

    .DESCRIPTION
    This command uses either CIM (default) or WMI to set the service
    password, and optionally the logon user name, for a service,
    which can be running on one or more remote machines. You must
    run this command as a user who has permission to perform this task,
    remotely, on the computers involved.

    .PARAMETER ServiceName
    The name of the service. Query the Win32_Service class to verify
    that you know the correct name.

    .PARAMETER ComputerName
    One or more computer names. Using IP addresses will fail with CIM;
    they will work with WMI. CIM is always attempted first.

    .PARAMETER NewPassword
    A plain-text string of the new password.

    .PARAMETER NewUser
    Optional; the new logon user name, in DOMAIN\USER format.

    .PARAMETER ErrorLogFilePath
    If provided, this is a path and filename of a text file where failed
    computer names will be logged.
    #>

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
            Write-Warning "Not setting a new user name"
        }

        foreach ($Computer in $ComputerName) {
            $SessionOption = New-CimSessionOption -Protocol Wsman
            Write-Verbose "Connecting to $Computer on WS-MAN"
            $Session = New-CimSession -SessionOption $SessionOption -ComputerName $Computer

            $MethodProperties = @{
                CimSession = $Session
                Query = "SELECT * FROM Win32_Service WHERE name = '$ServiceName'"
                MethodName = 'Change'
                Arguments = $Arguments
            }

            Write-Verbose "Setting $ServiceName on $Computer"
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

            Write-Verbose "Closing connection to $Computer"
            $Session | Remove-CimSession
        }
    }

    END {
    }
}
