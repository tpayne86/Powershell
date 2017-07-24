@echo off

:titlebox
echo  +---------------------------------------------+
echo  ^|              Enable PSRemoting            ^|
echo  +---------------------------------------------+
echo.

set enablewinrmstatus=fail
set startwinrmstatus=fail
set enablepsremotingstatus=fail


:testadmin
echo Testing for Admin rights.
net session> nul 2>&1
if not %errorlevel%==0 (
	echo No Admin rights.  Aborting installation.
	ping -n 5 localhost> nul
	goto installsummary
)
echo Admin rights confirmed.  Continuing with installation.
goto enablewinrm

:enablewinrm
echo.
echo Setting WinRM to start automatically.
sc config winrm start= auto> nul
if %errorlevel% GTR 0 (
	echo There was an error setting WinRM to start automatically.
	goto startwinrm
)
echo WinRM has been set to start automatically
set enablewinrmstatus=success
goto startwinrm

:startwinrm
echo.
echo Checking WinRM current state.
FOR /f "tokens=3" %%G IN ('sc query winrm^|find "STATE"') DO (set currentwinrmstatus=%%G)
if %currentwinrmstatus%==4 (
	echo WinRM is already started.
	set startwinrmstatus=success
	goto enablepsremoting
)
echo WinRM is not started. Starting WinRM.
net start winrm> nul
if %errorlevel% GTR 0 (
	echo There was an error starting WinRM.
	goto enablepsremoting
)
echo WinRM has been started.
set startwinrmstatus=success
goto enablepsremoting

:enablepsremoting
echo.
echo Enabling PSRemoting.
powershell -command enable-psremoting -force> nul
if %errorlevel% GTR 0 (
	echo There was an error enabling PSRemoting.
	goto disableautoplay
)
echo PSRemoting has been enabled.
set enablepsremotingstatus=success
goto installsummary

:installsummary
cls
echo ***%computername% Install Summary***
echo WinRM set to start automatically: %enablewinrmstatus%
echo WinRM started: %startwinrmstatus%
echo PSRemoting enabled: %enablepsremotingstatus%
echo.
pause