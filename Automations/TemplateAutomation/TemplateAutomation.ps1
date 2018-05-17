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


Function TemplateAutomation {
    #Example of passing parameters into your script
    Param (
          [Parameter(Mandatory=$true)][string]$UserName,
          [Parameter(Mandatory=$true)][string]$Password
    )
    #Get the start time for logging runtimeInMilliseconds
    $startDate = (Get-Date)

    ######################################################################
    # YOUR CODE STARTS HERE ##############################################

    #Example code
    $mathResult = 1 + 1

    #Example debug logging
    If ($DebugLevel -gt 0) {
        $description = '$mathResult = '+$mathResult
        WriteDebugLogMessage -RunResult 0 -Name 'Function AutomationTemplate' -Description $description
    }

    # YOUR CODE ENDS HERE ################################################
    ######################################################################

    # LOGGING ############################################################
    If ([int]$mathResult -eq 2) {
        $errorMessageTitle = "$scriptName successful"
        $errorMessageDescription = ""
        $theResult = $healthy
    } else {
        $errorMessageTitle = "$scriptName error"
        $errorMessageDescription = '$mathResult did not equal 2. Result was '+$mathResult
        $theResult = $unhealthy
    }
    $endDate = (Get-Date)
    $TimeDiff = New-TimeSpan $startDate $endDate
    $runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
    WriteResultLogMessage -RunResult $theResult -Name $errorMessageTitle -Description $errorMessageDescription -RunTimeInMilliseconds $runtimeInMilliseconds
    #Hand the resulting health state back to CallFunctionAndReturnResult
    Return $theResult
}

##############################################################
###################  CALL FUNCTIONS HERE  ####################

$finalHealthResult = CallFunctionAndReturnResult -FunctionName TemplateAutomation -Parameters $Parameters

#Hand the final resulting health state back to the wrapper
Return $finalHealthResult
