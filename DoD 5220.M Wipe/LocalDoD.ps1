#requires -version 4
<#
.SYNOPSIS
  Delete specified files and/or folders and perform a DoD 5220.22M wipe on the unallocated space of the partition
.DESCRIPTION
  LocalDoD.ps1 makes uses of Cipher.exe's ability to perform a DoD 5220.22M wipe on the unallocated space of a said partition to securely destroy data on the hard drive.
.PARAMETER PathFile
  Path to Text file containing a list of directories and files needing to be removed
.PARAMETER folderPath
	Single Directory that needs to be removed as apposed to using -PathFile
.PARAMETER KillSearchCache
	Remove Windows Search Cache. Default: False
.PARAMETER FindImages
	Remove all image types from the system, excluded windows directory. Default: False
.PARAMETER KillFontCache
	Remove Windows Font Cache. Default: False
.PARAMETER LogFile
	Path and File name where you want a log file to be created. Defaulted to C:\{USERPROFILE}\Desktop\DoD 5220.22M.log}. 
.PARAMETER EmailLog
	Boolean - Email the Log file to an email address. System must have Powershell 4.0 to be able to send email
.PARAMETER EmailFrom
	Email address that you want to email to be shown from
.PARAMETER EmailTo
  Email address the email will be sent to

.EXAMPLE

	--(PathFile txt file example) Directories.txt--
	 C:\users\MyUser\Documents
	 C:\Users\MyUser\Downloads
	 C:\Users\MyUser\Appdata\Local\Temp

	--Powershell Command--

	.\localdod.ps1 -pathfile directories.txt -killsearchcache:$true -findimages:$true -killfontcache:$true -logfile .\results.txt -emaillog:$true -emailfrom IT@it-company.com -emailto client@it-company.com

.NOTES
  Version:        1.0
  Author:         Theodore Payne
  Creation Date:  3/27/2017
  Purpose/Change: Targed DoD 5220.22M wipes for Data Destruction while leaving OS operational.

#>

Param(
    [alias('paths','directories','pf','d')]
    [string]$Pathfile,                          #File containing directories can be specified using this flag
    [alias('path')] 
    [string]$folderPath,                        #Single Directory that needs to be removed can be specified using this flag
    [alias('killsearch','ks','search')]
    [bool]$KillSearchCache=$false,            #Remove Windows Search Cache
    [alias('fi')]
    [bool]$FindImages=$false,                 #Locates all images on the C:\ partition for removal
    [alias('kf')]
    [bool]$KillFontCache=$false,               #Remove Windows Font Cache
		[string]$LogFile = "Env:\USERPROFILE\Desktop\DoD 5220.22M.log",
		[bool]$EmailLog=$false,
		[string]$EmailFrom,
		[string]$EmailTo
)
<#------------------------------------------------Functions--------------------------------------------------------------------------#>
function Execute-cmd {
    param(
        $cmd,
        $cmdArgs
    )
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $cmd
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.Arguments = $cmdArgs
    $P = New-Object System.Diagnostics.Process
    $P.StartInfo = $ProcessInfo
    $P.Start() | Out-Null
    $P.WaitForExit()
    [PSCustomObject]@{
        Output = $P.StandardOutput.ReadToEnd()
        Error = $P.StandardError.ReadToEnd()
        ExitCode = $P.ExitCode
    }

}

function batchErrorHandle {
    param (
        $exitCode
    )
    switch($exitCode) {
        1 {
            return "Unknown Function"
        }
        2 {
            return "The system cannot find the file specified"
        }
        3 {
            return "The system cannot find the path specified"
        }
        5 {
            return "Access Denied"
        }
        9009 {
            return "Program is not recognized as an internal or external command, operable program or batch file"
        }
        -1073741819 {
            return "Access violation: program has terminated abnormally or crashed."
        }
        -1073741801 {
            return "Not enough virtual memory is available."
        }
        -1073741510 {
            return "The application terminated as a result of a CTRL+C, CTRL+Break or closing command prompt window"
        }
        -1073741502 {
            return "The application failed to initialize properly."
        }
        -1073740791 {
            return "Stack buffer overflow"
        }
        -1073741571 {
            return "Stack overflow"
        }
        -532459699 {
            return "Unhandled exception in .NET application"
        }
        default {
            return "Unknown Error"
        }
    }
}
#Disable Windows Search, and remove the cache files
function killSearch {
    $Path = "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\*" #Location of the Windows Search service's Cache files
    try {
        write-output "$(get-date -Format g) - Disabling Windows Search" | out-file $LogFile -append
        set-service "Wsearch" -StartupType Disabled | Out-Null  #Set the startup type as being Disabled
        stop-service "Wsearch" | Out-Null       #Stop the service
        Write-Output "$(get-date -Format g) - Deleting Directory Files: $Path" | out-file $LogFile -append
        remove-item ($Path) -Recurse -ea Stop | Out-Null    #Remove all files located with in the folder, including subfolders
        Write-Output "$(get-date -Format g) - Removal of Directory items was successfull for $Path"| out-file $LogFile -append
    } catch [Exception] {                       #If an exceptions happen log the error
        $errormsg = $_.Exception.Message
        write-output "$(get-date -Format g) - ERROR: Wipe on $Path has failed. Error Message: $errormsg" | out-file $LogFile -append
    }
}

function killFont {
    $Path = "C:\Windows\ServiceProfiles\*" #Location of the Windows Search service's Cache files
    try {
        write-output "$(get-date -Format g) - Disabling Windows Search" | out-file $LogFile -append
        set-service "FontCache" -StartupType Disabled | Out-Null  #Set the startup type as being Disabled
        stop-service "FontCache" | Out-Null       #Stop the service
        set-service "FontCache3.0.0.0" -StartupType Disabled | Out-Null  #Set the startup type as being Disabled
        stop-service "FontCache3.0.0.0" | Out-Null       #Stop the service
        Write-Output "$(get-date -Format g) - Deleting Directory Files: $Path" | out-file $LogFile -append
        remove-item ($Path) -Recurse -force -Confirm:$false -ea Stop | Out-Null    #Remove all files located with in the folder, including subfolders
        Write-Output "$(get-date -Format g) - Removal of Directory items was successfull for $Path"| out-file $LogFile -append
    } catch [Exception] {                       #If an exceptions happen log the error
        $errormsg = $_.Exception.Message
        write-output "$(get-date -Format g) - ERROR: Wipe on $Path has failed. Error Message: $errormsg" | out-file $LogFile -append
    }
}
#Write 0's,1's, and Random characters across the volume
function DoDCDrive {
    $DODError = @()
    $DODLog = @()
    Write-Output "$(get-date -Format g) - DoD 5220.22M Wipe on C:\ has Started"| out-file $LogFile -append
    $DOD = Execute-cmd -cmd "cipher.exe" -cmdArgs "/w:C:\" #Start DoD 5220.22M wipe
    if($DOD.ExitCode -eq 0) {
        write-output "$(get-date -Format g) - DoD 5220.22M Wipe on C:\ was successful"| out-file $LogFile -append
    } else {
        $ExitCode = batchErrorHandle -exitCode ($DOD.ExitCode)
        write-output "$(get-date -Format g) - DoD 5220.22M Wipe on C:\ has failed: $ExitCode"| out-file $LogFile -append
    }
    Write-Output "$(get-date -Format g) - DoD 5220.22M Log - $($DOD.Output)" | Out-File $LogFile -append
    Write-Output "$(get-date -Format g) - DoD 5220.22M Errors - $($DOD.Error)" | Out-File $LogFile -append
}

function emailResults {                         #Email the results of the script to Velocity
  $PC = [System.Net.DNS]::GetHostName()  
	$IP = (Test-Connection -Computername $PC -count 1).IPv4Address.IPAddressToString

    $From = $EmailFrom
    $To = $EmailTo
    $Subject = "$PC - DoD 5220.22M Wipe "
    $Body = "Attached are the results for the Targeted Wiping of $PC - IP: $IP

Sent By the Automated Powershell Script"
    $SMTPServer = "in-v3.mailjet.com"
    $SMTPPort = "587"

    #Email Credentials
    $username = "4fd3b3fd9b87f65c3b3da62c295c2732"
    $password = "2b0fe603348b6d8a0ad61cbf15720a8b"

    #Create Creds for Automatic Login
    $pass = ConvertTo-SecureString -AsPlainText $password -Force
    $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$pass

    #Command to Send Email
    Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -Attachments $LogFile -SmtpServer $SMTPServer -port $SMTPPort -Credential $Cred
}
<#-------------------------------------------------------------Run Script----------------------------------------------------------------------------#>
#Assign Paths to the directories needing to be removed
if($Pathfile) {
    $Paths = Get-Content $Pathfile
} elseif ($folderPath) {
    $Paths = $folderPath
}

if(($Paths.count) -gt 0) {
    foreach($path in $Paths) {
        try {
            if($path -notlike "C:\Users\*"){    #Due to Windows 7 having Junction folders, and powershell does not handle the removal of them well, if the directory contain C:\Users use the batch remove directory
                remove-item $path -recurse -force -ea stop | out-null
                Write-Output "$(get-date -Format g) - Removal of Directory was successfull for $path"| out-file $LogFile -append
            } else {
                $Remove = Execute-cmd -cmd "cmd" -cmdArgs "/c rmdir $path /s /q" 
                if($Remove.ExitCode -eq 0){
                    Write-Output "$(get-date -Format g) - Removal of Directory was successfull for $path"| out-file $LogFile -append
                }
                else {
                    $ExitCode = batchErrorHandle -exitCode ($Remove.ExitCode)
                    Write-output "$(get-date -Format g) - Removal of Path failed : $path  - Error: $ExitCode"| out-file $LogFile -append
                }
                if($Remove.Error){
                write-output "$(get-date -Format g) - $($Remove.Error)" | out-file C:\Velocity\TargetedWipeErrors.log -Append
                }
            }
            
        } catch [Exception]{                    #Catch System Exception and log error
            $errmsg = $_.Exception.Message
            Write-output "$(get-date -Format g) - Removal of Path failed : $path  - Error: $errmsg"| out-file $LogFile -append
        } catch {                               #Catch powershell error and attempt Batch command Rmdir to remove directory
            try{
                $Remove = Execute-cmd -cmd "cmd" -cmdArgs "/c rmdir $path /s /q"
                if($Remove.ExitCode -eq 0){
                    Write-Output "$(get-date -Format g) - Removal of Directory was successfull for $path"| out-file $LogFile -append
                }
                else {
                    $ExitCode = batchErrorHandle -exitCode ($Remove.ExitCode)
                    Write-output "$(get-date -Format g) - Removal of Path failed : $path - Error: $ExitCode"| out-file $LogFile -append
                }
                if($Remove.Error){
                write-output "$(get-date -Format g) - $($Remove.Error)" | out-file $LogFile -Append
                }
            } catch [Exception]{
                $errmsg = $_.Exception.Message
                Write-output "$(get-date -Format g) - Removal of Path failed : $path - Error: $errmsg"| out-file $LogFile -append
            }
        }
    }
}

if($FindImages) {
    $Files = Get-ChildItem C:\ -Recurse -include *png,*jpg,*bmp,*gif,*jpeg,*tif |?{$_ -notlike "C:\Windows*"} #Locate all Image Files not located in Windows folder
    foreach($file in $Files) {
        try {
            remove-item $file -recurse -force -ea stop | out-null
            Write-Output "$(get-date -Format g) - Removal of Directory items was successfull for $file"| out-file $LogFile -append
        } catch {                               #Catch Powershell Error and try Batch command Del to attempt to delete file
            try{
                $Remove = Execute-cmd -cmd "cmd" -cmdArgs "/c del $file /F /Q" 
                if($Remove.ExitCode -eq 0){
                    Write-Output "$(get-date -Format g) - Removal of Directory was successfull for $file"| out-file $LogFile -append
                }
                else {
                    $ExitCode = batchErrorHandle($Remove.ExitCode)
                    Write-output "$(get-date -Format g) - Removal of file failed : $file - Error: $ExitCode"| out-file $LogFile -append
                }
                if($Remove.Error){
                write-output "$(get-date -Format g) - $($Remove.Error)" | out-file $LogFile -Append
                }
            } catch [Exception] {               #If Del failed output Error
                $errmsg = $_.Exception.Message
                Write-output "$(get-date -Format g) - Removal of file failed : $file - Error: $errmsg"| out-file $LogFile -append
            }
        }

    }
}
if($KillSearchCache) {
    killSearch 
}
if($killFontCache) {
    killFont
}
DoDCDrive
if($KillSearchCache){                           #Reset and restart Windows Search Service
    set-service "Wsearch" -StartupType Automatic | Out-Null #Set the startup type back to Automatic
    start-service "Wsearch" | Out-Null          #Rebuild dependant files
    start-service "Wsearch" | Out-Null          #Restart Windows Search
}
Write-Output "$(get-date -Format g) - Finished Wiping the director(y/ies)" | out-file $LogFile -append
emailResults
