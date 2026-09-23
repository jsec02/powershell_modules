# ================================================================================
# =                                    TOOLS                                     =
# ================================================================================

# ===================================== HELP =====================================

function Get-CommandParameters {
    [CmdletBinding()]
    param([string]$Command)

    Get-Help -Name $Command -Parameter *
}

function Get-CommandExamples {
    [CmdletBinding()]
    param([string]$Command)

    Get-Help -Name $Command -Example
}

Set-Alias -Name gcp -Value Get-CommandParameters
Set-Alias -Name gce -Value Get-CommandExamples

# ==================================== WINGET ====================================

function Update-Packages {
    [CmdletBinding()]
    param()

    Get-WinGetPackage | Where-Object -Property IsUpdateAvailable | Update-WinGetPackage -Mode Silent
}

Set-Alias -Name up -Value Update-Packages

# ===================================== GIT ======================================

function Get-GitStatus {
    git status 
}

function Update-GitMaster {
    git pull origin master
}

Set-Alias -Name gs -Value Get-GitStatus
Set-Alias -Name gpom -Value Update-GitMaster

# ================================== PROCESSES ===================================

function Get-GroupedProcesses {
    [CmdletBinding()]
    param()

    Get-Process | Group-Object -Property ProcessName | ForEach-Object {
        [PSCustomObject]@{
            'NPM(K)' = (($_.Group.NonpagedSystemMemorySize64 | Measure-Object -Sum).Sum / 1KB)
            'PM(M)' = (($_.Group.PagedMemorySize64 | Measure-Object -Sum).Sum / 1MB)
            'WS(M)' = (($_.Group.WorkingSet64 | Measure-Object -Sum).Sum / 1MB)
            'CPU' = ($_.Group.CPU | Measure-Object -Sum).Sum
            'CNT' = $_.Count
            'ProcessName' = $_.Name
        }
    }
}

function Get-SortedGroupedProcesses {
    [CmdletBinding()]
    param([string]$SortBy = 'WS(M)')

    Get-GroupedProcesses | Sort-Object -Property $SortBy -Descending
}

Set-Alias -Name ps -Value Get-SortedGroupedProcesses

# ===================================== CIM ======================================

function Get-CimChildNamespace {
    [CmdletBinding()]
    param([string]$Namespace = 'root')

    Get-CimInstance -Namespace $Namespace -Query 'SELECT * FROM __NAMESPACE' | Select-Object -Property Name
}

Set-Alias -Name gccn -Value Get-CimChildNamespace

# =================================== DRIVERS ====================================

function Get-Driver {
    [CmdletBinding()]
    param()

    Get-CimInstance -Namespace Root\CIMv2 -Query 'SELECT * FROM Win32_SystemDriver' | ForEach-Object {
        [PSCustomObject]@{
            'ModuleName' = $_.Name
            'DisplayName' = $_.DisplayName
            'DriverType' = $_.ServiceType
        }
    }
}

# ==================================== DRIVES ====================================

function Get-LocalDrive {
    [CmdletBinding()]
    param()

    # DriveType of 3 signifies a local disk type
    Get-CimInstance -Namespace Root\CIMv2 -Query 'SELECT * FROM Win32_LogicalDisk WHERE DriveType = 3' | ForEach-Object {
        [PSCustomObject]@{
            'DeviceID' = $_.DeviceID
            'VolumeName' = $_.VolumeName
            'Size(G)' = $_.Size / 1GB
            'Free(G)' = $_.FreeSpace / 1GB
            'PercentFree' = ($_.FreeSpace / $_.Size) * 100
        }
    }
} 

# ===================================== CPU ======================================

function Get-CPU {
    [CmdletBinding()]
    param()

    Get-CimInstance -Namespace Root\CIMv2 -Query 'SELECT * FROM Win32_SystemProcessor' |  ForEach-Object {
        [PSCustomObject]@{
            'DeviceID' = $_.DeviceID
            'Name' = $_.Name
            'Cores' = $_.NumberOfCores
            'LogicalProcessors' = $_.NumberOfLogicalProcessors
            'Threads' = $_.ThreadCount
            'CurrentClockSpeed' = $_.CurrentClockSpeed
        }
    }
}

# ===================================== GPU ======================================

function Get-GPU {
    [CmdletBinding()]
    param()

    Get-CimInstance -Namespace Root\CIMv2 -Query 'SELECT * FROM Win32_VideoController' |  ForEach-Object {
        [PSCustomObject]@{
            'DeviceID' = $_.DeviceID
            'Name' = $_.Name
            'DriverDate' = $_.DriverDate
            'DriverVersion' = $_.DriverVersion
        }
    }
}

# =================================== FIREWALL ===================================

function Enable-Firewall {
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
}

function Disable-Firewall {
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False
}

function New-FirewallInboundPort {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$Port)
    New-NetFirewallRule -DisplayName "Allow inbound Port $Port" -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow
}

function Remove-FirewallInboundPort {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$Port)
    Remove-NetFirewallRule -DisplayName "Allow inbound Port $Port" -ErrorAction SilentlyContinue
}

$ModuleMemberParameters = @{
    Function = @(
        # Help
        'Get-CommandParameters'
        'Get-CommandExamples'

        # winget
        'Update-Packages'

        # git
        'Get-GitStatus'
        'Update-GitMaster'

        # Processes
        'Get-GroupedProcesses'
        'Get-SortedGroupedProcesses'

        # CIM
        'Get-CimChildNamespace'

        # Drivers
        'Get-Driver'

        # Drives
        'Get-LocalDrive'

        # CPU
        'Get-CPU'

        #GPU
        'Get-GPU'

        # Firewall
        'Enable-Firewall'
        'Disable-Firewall'
        'New-FirewallInboundPort'
        'Remove-FirewallInboundPort'
    )

    Alias = @(
        # Help
        'gcp'
        'gce'

        # winget
        'up'

        # git
        'gs'
        'gpom'

        # Processes
        'ps'

        # CIM
        'gccn'
    )

}

Export-ModuleMember @ModuleMemberParameters
