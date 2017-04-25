<#
    This Script is currently configured for Tight-VNC Server, to change supply -VNCService {Service Name}
#>
param (
    $VNCPw,
    $VNCAdmin,
    $VNCService = 'tvnserver'
    )

function Convert-HexStringToByteArray
{
    Param ([String] $String)
    
    #Clean out whitespaces and any other non-hex crud.
    $String = $String.ToLower() -replace '[^a-f0-9\\,x\-\:]',"
    
    #Try to put into canonical colon-delimited format.
    $String = $String -replace '0x|\x|\-|,',':'
    
    #Remove beginning and ending colons, and other detritus.
    $String = $String -replace '^:+|:+$|x|\',"
    
    #Maybe there's nothing left over to convert...
    if ($String.Length -eq 0) { ,@() ; return }
    
    #Split string with or without colon delimiters.
    if ($String.Length -eq 1)
    { ,@([System.Convert]::ToByte($String,16)) }
    elseif (($String.Length % 2 -eq 0) -and ($String.IndexOf(":") -eq -1))
    { ,@($String -split '([a-f0-9]{2})' | foreach-object { if ($_) {[System.Convert]::ToByte($_,16)}}) }
    elseif ($String.IndexOf(":") -ne -1)
    { ,@($String -split ':+' | foreach-object {[System.Convert]::ToByte($_,16)}) }
    else
    { ,@() }
    #The strange ",@(...)" syntax is needed to force the output into an
    #array even if there is only one element in the output (or none).
}

#Import C# Code to be run
$Source = get-content encrypt.cs | Out-String
#Make the C# Functions Available
Add-Type -ReferencedAssemblies $Assem -TypeDefinition $Source -Language CSharp
#Encrypt the Password for VNC
if($VNCPw){
    $EncryptedRemote = [VNC.Encrypt]::EncryptVNC($VNCPw)
    $EncryptedRemote = Convert-HexStringToByteArray($EncryptedRemote)
} else {
    Write-Warning "There was no Remote Access Password Specified, Will not set Remote Access Password"
}
if($VNCAdmin){
    $EncryptedAdmin = [VNC.Encrypt]::EncryptVNC($VNCAdmin)
    $EncryptedAdmin = Convert-HexStringToByteArray($EncryptedAdmin)
} else {
    Write-Warning "There was no Remote Access Password Specified, Will not set Remote Access Password"
}

try {
    if($VNCRemote){
        New-ItemProperty -Path "HKLM:\SOFTWARE\TightVNC\Server" -Name Password -Value $VNCRemote -PropertyType Binary -Force -ErrorAction Stop | Out-Null
    }
    if($VNCAdmin) {
        New-ItemProperty -Path "HKLM:\SOFTWARE\TightVNC\Server" -Name ControlPassword -Value $VNCAdmin -PropertyType Binary -Force -ErrorAction Stop | Out-Null
    }
    stop-service $VNCService
    start-service $VNCService
    "Password Change was successful`t$IP`t$computername"
} catch {
    "There was an error changing VNC passwords`t$IP`t$computername"
}

Write-Host "Finished Updating VNC Password"

