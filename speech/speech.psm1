# ================================================================================
# =                                    SPEECH                                    =
# ================================================================================

function Invoke-Speech {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [string[]]$Text
    )

    begin {
        Add-Type -AssemblyName System.Speech
        $SpeechSynthesizer = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
    }

    process {
        foreach ($Phrase in $Text) {
            $SpeechSynthesizer.Speak($Phrase)
        }
    }

    end {
    }
}

New-Alias -Name talk Invoke-Speech

# ==================================== EXPORT ====================================

$ModuleMemberParameters = @{
    Function = @(
        'Invoke-Speech'
    )

    Alias = @(
        'talk'
    )

}

Export-ModuleMember @ModuleMemberParameters
