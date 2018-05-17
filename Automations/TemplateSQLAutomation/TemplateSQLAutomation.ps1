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


Function TemplateSQLAutomation {
    #Get the start time for logging runtimeInMilliseconds
    $startDate = (Get-Date)

    ######################################################################
    # YOUR CODE STARTS HERE ##############################################

    #Example code
    $errorCount = 0

    $databaseServer = "yourserver.dns.name"
    $database = "thedatabasename"
    $environmentName = "Production"

    [string]$sqlQuery = "EXEC dbo.yourstoredprocedure"

    #Run the SQL query
    $resultsDataTable = New-Object System.Data.DataTable
    try {
      $resultsDataTable = ExecuteSqlQuery $databaseServer $database $sqlQuery
    } catch {
      $errorCount++
      $errorMessageTitle = "TemplateSQLAutomation ($environmentName) Failed"
      If ($DebugLevel -gt 0) {
          Write-Host $errorMessageTitle
      }
      $errorMessageDescription = @"
Execution of SQL query failed: $sqlQuery

Error: $error.[0]

Automation Information: Organization > Team > TemplateSQLAutomation-$environmentName
"@
      If ($DebugLevel -gt 0) {
          Write-Host $errorMessageDescription
      }

      #Log the error
      $endDate = (Get-Date)
      $TimeDiff = New-TimeSpan $startDate $endDate
      $runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
      WriteResultLogMessage -RunResult $unhealthy -Name $errorMessageTitle -Description $errorMessageDescription -RunTimeInMilliseconds $runtimeInMilliseconds

    # YOUR CODE ENDS HERE ################################################
    ######################################################################

    # LOGGING ############################################################
    If ($errorCount -eq 0) {
        $errorMessageTitle = "$scriptName successful"
        $errorMessageDescription = ""
        $theResult = $healthy
    } else {
        $errorMessageTitle = "$scriptName error"
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

$finalHealthResult = CallFunctionAndReturnResult -FunctionName TemplateSQLAutomation

#Hand the final resulting health state back to the wrapper
Return $finalHealthResult
