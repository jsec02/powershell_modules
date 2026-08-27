# ================================================================================
# =                                    TOOLS                                     =
# ================================================================================

# ===================================== HELP =====================================

function Get-CommandParams {
    param([string]$Command)
    Get-Help -Name $Command -Parameter *
}

function Get-CommandExamples {
    param([string]$Command)
    Get-Help -Name $Command -Example
}

# ==================================== WINGET ====================================

function Update-Packages {
    Get-WinGetPackage | Where-Object IsUpdateAvailable | Update-WinGetPackage -Mode Silent
}

# ===================================== GIT ======================================

function Get-GitStatus {
    git status 
}

function Update-GitMaster {
    git pull origin master
}

# ================================== PROCESSES ===================================

function Get-GroupedProcesses {
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
    param([string]$SortBy = 'WS(M)')
    Get-GroupedProcesses | Sort-Object -Property $SortBy -Descending
}

# ===================================== CIM ======================================

function Get-CimChildNamespace {
    param([string]$Namespace = 'root')
    Get-CimInstance -Namespace $Namespace -ClassName __NAMESPACE | Select-Object -Property Name
}

# =================================== DRIVERS ====================================

function Get-Driver {
    Get-CimInstance -Namespace Root\CIMv2 -ClassName Win32_SystemDriver | ForEach-Object {
        [PSCustomObject]@{
            'ModuleName' = $_.Name
            'DisplayName' = $_.DisplayName
            'DriverType' = $_.ServiceType
        }
    }
}

# ==================================== DRIVES ====================================

function Get-LocalDrive {
    # DriveType of 3 signifies a local disk type
    Get-CimInstance -Namespace Root\CIMv2 -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | ForEach-Object {
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
    Get-CimInstance -Namespace Root\CIMv2 -ClassName Win32_Processor |  ForEach-Object {
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
    Get-CimInstance -Namespace Root\CIMv2 -ClassName Win32_VideoController |  ForEach-Object {
        [PSCustomObject]@{
            'DeviceID' = $_.DeviceID
            'Name' = $_.Name
            'DriverDate' = $_.DriverDate
            'DriverVersion' = $_.DriverVersion
        }
    }
}
