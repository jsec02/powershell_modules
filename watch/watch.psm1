# ================================================================================
# =                                    WATCH                                     =
# ================================================================================

function Build-InfoBar {
    param(
        [Parameter(Mandatory=$True)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$True)]
        [double]$Interval
    )

    $TerminalWidth = $Host.UI.RawUI.WindowSize.Width

    $LeftInfo = "Every ${Interval}s: $ScriptBlock"
    $LeftInfoLength = $LeftInfo.Length

    $RightInfo = "${Env:COMPUTERNAME}: $(Get-Date -Format 'dddd MMMM dd hh:mm:ss yyyy')"
    $RightInfoLength = $RightInfo.Length

    
    if (($LeftInfoLength + $RightInfoLength) -gt $TerminalWidth) {
        return
    }

    $SeparatorLength = $TerminalWidth - ($LeftInfoLength + $RightInfoLength)

    return ($LeftInfo + (' ' * $SeparatorLength) + $RightInfo)
}

function Watch-Command {
    param(
        [Parameter(Mandatory=$True)]
        [scriptblock]$ScriptBlock,

        [double]$Interval = 1
    )

    while ($true) {
        Clear-Host

        $InfoBar = Build-InfoBar -ScriptBlock $ScriptBlock -Interval $Interval

        if ($InfoBar) {
            Write-Host $InfoBar
        }

        # Out-Host in required here because without it, when the output is table-based,
        # subsequent iterations in the while loop chop off the header columns for some reason
        & $ScriptBlock | Out-Host

        Start-Sleep -Seconds $Interval
    }

}

Export-ModuleMember -Function Watch-Command
