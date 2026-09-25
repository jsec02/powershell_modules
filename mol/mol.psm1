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
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('CN', 'MachineName', 'Name')]
        [string[]]$ComputerName,

        [string]$LogFailuresToPath,

        [ValidateSet('WSMAN', 'DCOM')]
        [string]$Protocol = 'WSMAN',

        [switch]$ProtocolFallback
    )

    begin {
    }

    process {
        foreach ($Computer in $ComputerName) {
            # Establish session protocol
            $SessionOption = New-CimSessionOption -Protocol $Protocol

            try {
                # Connect session
                Write-Verbose "Connecting to $Computer over $Protocol"
                $CimSessionParameters = @{
                    ComputerName = $Computer
                    SessionOption = $SessionOption
                    ErrorAction = 'Stop'
                }
                $Session = New-CimSession @CimSessionParameters

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
            } catch {
                Write-Warning "FAILED $Computer on $Protocol"
                # Did we specify protocol fallback? If so, try again. If we specified
                # logging, we won't log a problem here - we'll let the logging occur
                # if this fallback also fails
                if ($ProtocolFallback) {
                    if ($Protocol -eq 'Dcom') {
                        $NewProtocol = 'Wsman'
                    } else {
                        $NewProtocol = 'Dcom'
                    }

                    Write-Verbose "Trying again with $NewProtocol"
                    $MachineInfoParameters = @{
                        ComputerName = $Computer
                        Protocol = $NewProtocol
                        ProtocolFallback = $false
                    }
                    if ($PSBoundParameters.ContainsKey('LogFailuresToPath')) {
                        $MachineInfoParameters += @{
                            LogFailuresToPath = $LogFailuresToPath
                        }
                    }
                    Get-MachineInfo $MachineInfoParameters
                }
                # If we didn't specify fallback, but we did specify logging, then log the error,
                # because we won't be trying again
                if (-not $ProtocolFallback -and $PSBoundParameters.ContainsKey('LogFailuresToPath')) {
                    Write-Verbose "Logging to $LogFailuresToPath"
                    $Computer | Out-File $LogFailuresToPath -Append
                }
            }
        }
    }

    end {
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
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]$ServiceName,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]$ComputerName,

        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]$NewPassword,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$NewUser,

        [string]$LogFailuresToPath
    )

    begin {
    }

    process {
        if ($PSBoundParameters.ContainsKey('NewUser')) {
            $Arguments = @{
                StartName = $NewUser
                StartPassword = $NewPassword
            }
        } else {
            $Arguments = @{
                StartPassword = $NewPassword
            }
            Write-Warning "Not setting a new username"
        }

        $Protocols = 'WSMAN', 'DCOM'

        foreach ($Computer in $ComputerName) {

            $Session = $null

            foreach ($Protocol in $Protocols) {
                try {
                    $SessionOption = New-CimSessionOption -Protocol $Protocol
                    Write-Verbose "Connecting to $Computer on $Protocol"
                    $CimSessionParameters = @{
                        SessionOption = $SessionOption
                        ComputerName = $Computer
                        ErrorAction = 'Stop'
                    }
                    $Session = New-CimSession @CimSessionParameters
                    break
                } catch {
                    Write-Warning "FAILED $Computer on $Protocol"

                    if ($Protocol -eq $Protocols[-1] -and $PSBoundParameters.ContainsKey('LogFailuresToPath')) {
                        Write-Verbose "Logging to $LogFailuresToPath"
                        $Computer | Out-File $LogFailuresToPath -Append
                    }
                }
            }

            if (-not $Session) {
                continue
            }

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

    end {
    }
}

Export-ModuleMember -Function Get-MachineInfo, Set-MasterServiceLogon
