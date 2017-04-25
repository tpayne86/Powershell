param (
    $VNCPw,
    $VNCAdmin,
    $file,
    $IP,
    $Username,
    $Password
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

#Create Creds for Automatic Login
if($Password -and $Username) {
    $pass = ConvertTo-SecureString -AsPlainText $password -Force
    $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$pass
} elseif(!$Password) {
    $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username
} else {
    Write-Error "No Username was Specified"
    exit
}


$Script = {
    param(
        $VNCRemote,
        $VNCAdmin
    )
    $computername = [System.Net.DNS]::GetHostName()
	$IP = (Test-Connection -Computername $computername -count 1).IPv4Address.IPAddressToString
    try {
        if($VNCRemote){
            New-ItemProperty -Path "HKLM:\SOFTWARE\TightVNC\Server" -Name Password -Value $VNCRemote -PropertyType Binary -Force -ErrorAction Stop | Out-Null
        }
        if($VNCAdmin) {
            New-ItemProperty -Path "HKLM:\SOFTWARE\TightVNC\Server" -Name ControlPassword -Value $VNCAdmin -PropertyType Binary -Force -ErrorAction Stop | Out-Null
        }
        stop-service tvnserver
        start-service tvnserver
        "Password Change was successful`t$IP`t$computername"
    } catch {
        "There was an error changing VNC passwords`t$IP`t$computername"
    }
}

$err = @()
$errResults = @()
$MaximumErrorCount = 500

if($file) {
    $Computers = Get-Content $file
} elseif($IP) {
    $Computers = $IP
} else {
    Write-Error "No Systems Specified"
    exit 
}

if($Computers){
    $Results = Invoke-Command -ComputerName $Computers -Credential $Cred -ScriptBlock $Script -ArgumentList $EncryptedRemote,$EncryptedAdmin -ErrorVariable +err -ErrorAction SilentlyContinue
}

#Error Handling	
$Exception = $err.Exception
if($err.count -gt 0){
	for($i=0; $i -lt $err.count; $i++){
	if($err.TargetObject.count -gt 1){
	$computer = $err.TargetObject[$i]
	} else {
	$computer = $err.TargetObject
	}
	$ExceptionType = $Exception[$i].GetType().FullName
	$ExMessage = $Exception[$i].Message
		if($ExMessage -ilike "*WinRM cannot complete the operation*"){
			$errResults = $errResults +"`t$computer`tConnection Issue"
		} elseif($ExMessage -ilike "*Access is denied*"){
			$errResults = $errResults +"`t$computer`tAccess Denied"
		} else {
			$errResults = $errResults +"`t$computer`tUnknown PSRemoting Error"
		}
		"Computer IP: $computer`r`n$ExMessage`r`n$ExceptionType`r`n" | out-file .\error.txt -append
	}
}
#Save to Logs
$results | out-file .\results.txt -append
if($errResults) {
$errResults.Trim().toLower() |out-file .\results.txt -append
}
Write-Host "Finished Crawling System(s)"

