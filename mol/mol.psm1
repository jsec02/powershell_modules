function Get-MachineInfo {
    param(
        [string[]]$ComputerName,
        [string]$LogFailuresToPath,
        [string]$Protocol = 'WSMAN',
        [switch]$ProtocolFallback
    )

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

Get-MachineInfo -ComputerName WINDOWS
