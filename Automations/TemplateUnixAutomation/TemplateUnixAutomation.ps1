######### do not remove #########
# AutomationTemplate version: 5
#################################

Param (
      [Parameter(Mandatory=$false)][int]$DebugLevel,
      [Parameter(Mandatory=$false)][string]$LogFolderPath,
      [Parameter(Mandatory=$false)][string]$RunID,
      [Parameter(Mandatory=$false)][string]$Parameters
)

#dot source the Library.ps1
. "$PSScriptRoot\..\..\Library\AutomationLibrary.ps1"
AutomationLibraryInit

#Get the name of the script for logging
$scriptPath = $MyInvocation.MyCommand.Name
$scriptName = [io.path]::GetFileNameWithoutExtension($scriptPath)
#Write-Host $scriptName
$global:logName = $scriptName

#Write logs in the script folder for testing
If ([string]::IsNullOrEmpty($LogFolderPath)) {
    $LogFolderPath = $PSScriptRoot
}


#################### FUNCTIONS START HERE ####################
##############################################################


Function TemplateUnixAutomation {
    #Example of passing parameters into your script
    Param (
          [Parameter(Mandatory=$true)][string]$UserName,
          [Parameter(Mandatory=$true)][string]$Password
    )
    #Get the start time for logging runtimeInMilliseconds
    $startDate = (Get-Date)

    ######################################################################
    # YOUR CODE STARTS HERE ##############################################

    #http://blog.coretech.dk/rja/capture-output-from-command-line-tools-with-powershell/


    #Add the server SSH key to the registry so plink doesn't prompt about the ssh key
    $command = "REGEDIT /S $PSScriptRoot\..\..\Library\PuTTY\Registry\yourserver_SshKey.reg"
    Invoke-Expression -Command:$command
    #Add putty configuration for a 5 minute keepalive. Firewall terminates the connection at 1 hour
    $command = "REGEDIT /S $PSScriptRoot\..\..\Library\PuTTY\Registry\keepalive.reg"
    Invoke-Expression -Command:$command


    $programPath = "$PSScriptRoot\..\..\Library\PuTTY\plink.exe"
    $serverName = "yourserver.dns.name"

    #Create the lock file so we know it's running from other scripts
    $arguments = $UserName+'@'+$serverName+' -pw '+$Password+' "touch /tmp/TemplateUnixAutomation.lock"'
    $createLockResultObject = RunExternalProgram -ProgramPath $programPath -Arguments $arguments -TimeoutInSeconds 10

    #Execute the program
    $arguments = '-load keepalive '+$UserName+'@'+$serverName+' -pw '+$Password+' "cd /data/PROD/scripts && ksh yourscript.ksh yourscriptparameter.ksh >/dev/null ; echo $?"'
    $resultObject = RunExternalProgram -ProgramPath $programPath -Arguments $arguments
    $programStdOut = $resultObject.stdout
    $programStdErr = $resultObject.stderr

    If ($DebugLevel -gt 0) {
        Write-Host "STDOUT: $stdout"
        $description = "STDOUT: " + $programStdOut
        WriteDebugLogMessage -RunResult 0 -Name 'TemplateUnixAutomation' -Description $description -RunTimeInMilliseconds 0

        Write-Host "STDERR: $programStdErr"
        $description = "STDERR: " + $resultObject.stderr
        WriteDebugLogMessage -RunResult 0 -Name 'TemplateUnixAutomation' -Description $description -RunTimeInMilliseconds 0
    }


    #Remove the lock file so we know it's not running from other scripts
    $arguments = $UserName+'@'+$serverName+' -pw '+$Password+' "rm -f /tmp/TemplateUnixAutomation.lock"'
    $deleteLockResultObject = RunExternalProgram -ProgramPath $programPath -Arguments $arguments -TimeoutInSeconds 10

    # YOUR CODE ENDS HERE ################################################
    ######################################################################

    # LOGGING ############################################################
    If ([string]$programStdOut.StartsWith("0") -eq $true) {
        $errorMessageTitle = "$scriptName run successful"
        $errorMessageDescription = ""
        $theResult = $healthy
    } else {
        $errorMessageTitle = "$scriptName run error"
        $errorMessageDescription = "programStdOut:$programStdOut   programStdErr:$programStdErr"
        $theResult = $unhealthy
    }
    $endDate = (Get-Date)
    $TimeDiff = New-TimeSpan $startDate $endDate
    $runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
    WriteResultLogMessage -RunResult $theResult -Name $errorMessageTitle -Description $errorMessageDescription -RunTimeInMilliseconds $runtimeInMilliseconds

    # SEND AN EMAIL NOTIFICATION OF THE RUN RESULTS #########
    $emailRecipient = "email1@domain.name,email2@domain.name"
    $runTimeInSeconds = [math]::Round([int]$runtimeInMilliseconds / 1000)
    CreateEmail -Source "TemplateUnixAutomation" -From "TemplateUnixAutomation@domain.name" -To $emailRecipient -Priority "Normal" -Subject "$errorMessageTitle" -Body "RunResult: $theResult, Name: $errorMessageTitle, Description: $errorMessageDescription, RunTimeInSeconds: $runTimeInSeconds"

    #Hand the resulting health state back to CallFunctionAndReturnResult
    Return $theResult
}

##############################################################
###################  CALL FUNCTIONS HERE  ####################

#We send email from this script
#dot source the EmailInterface.ps1
. "$PSScriptRoot\..\..\Library\EmailInterface.ps1"
EmailInterfaceInit

$finalHealthResult = CallFunctionAndReturnResult -FunctionName TemplateUnixAutomation -Parameters $Parameters

#Hand the final resulting health state back to the wrapper
Return $finalHealthResult
