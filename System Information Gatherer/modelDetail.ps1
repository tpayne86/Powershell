#Command Line Parameters
Param(
  [string]$file,
  [string]$ip,
  [string]$username,
  [string]$password
)

#Create Creds for Automatic Login
$pass = ConvertTo-SecureString -AsPlainText $password -Force
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$pass

#Script Used in Invoke-Command Below
$script = {
	$computername = [System.Net.DNS]::GetHostName()
	$IP = (Test-Connection -Computername $computername -count 1).IPv4Address.IPAddressToString
    $convertToGB = (1024*1024*1024)
	try {
		$Model = Get-WmiObject -Class Win32_ComputerSystem | Select Model -ea stop
		$Model = $Model.Model
        $Serial = Get-WmiObject Win32_Bios | Select SerialNumber -ea stop
        $Serial = $Serial.SerialNumber
        $totalmemory = Get-WMIObject Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | Foreach {"{0:N2}" -f ([math]::round(($_.Sum / 1GB),2))} -ea stop
        $maxMemory = Get-WmiObject Win32_PhysicalMemoryArray | Where {$_.Use -eq 3} | Foreach {($_.MaxCapacity*1KB)/1GB}
        $CPUSpeed = Get-WmiObject -Class Win32_Processor | select MaxClockSpeed -ea stop
        $CPUSpeed = ($CPUSpeed.MaxClockSpeed)/1000
        $hardDrive = Get-WmiObject Win32_logicaldisk  -filter "DeviceID='C:'"| select-Object Size, FreeSpace
        $totalSize = [math]::Round(($hardDrive.Size / $ConvertToGB),2)
        $freespace = [math]::Round(($hardDrive.FreeSpace / $ConvertToGB),2)
		echo "$Model`t$Serial`t$CPUSpeed`t$totalmemory`t$maxMemory`t$freespace`t$totalSize`t$IP`t$computername"
	}
	catch 
	{
  	$message = $_.Exception.Message
		"$message`t$IP`t$computername"
	}
}
	$err = @()
	$errResults = @()
	$MaximumErrorCount = 500
#Command to Run Installation File
IF($file) {
	$computers = Get-Content $file

	$results = Invoke-command -Computername $computers -credential $Cred -scriptblock $script -ErrorVariable +err -ea silentlycontinue
} else {
	$results = Invoke-command -Computername $ip -credential $Cred -scriptblock $script -ErrorVariable +err -ea silentlycontinue
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
			$errResults = $errResults +"Connection Issue`t$computer"
		} elseif($ExMessage -ilike "*Access is denied*"){
			$errResults = $errResults +"Access Denied`t$computer"
		} else {
			$errResults = $errResults +"Unknown PSRemoting Error`t$computer"
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