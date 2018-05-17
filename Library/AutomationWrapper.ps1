Param (
      [Parameter(Mandatory=$false)][string]$AutomationScriptName,
      [Parameter(Mandatory=$false)][string]$TimeoutInSeconds,
      [Parameter(Mandatory=$false)][string]$LogFolderPath,
      [Parameter(Mandatory=$false)][string]$Parameters,
      [Parameter(Mandatory=$false)][int]$DebugLevel
)

$shouldContinue = $TRUE
If ([string]::IsNullOrEmpty($AutomationScriptName)) {
    $shouldContinue = $FALSE
    Write-Host "Please provide a string value for the AutomationScriptName parameter (without the .ps1 extension)"
}
If ([string]::IsNullOrEmpty($TimeoutInSeconds)) {
    $shouldContinue = $FALSE
    Write-Host "Please provide an int value for the TimeoutInSeconds parameter"
}
If ($shouldContinue -eq $FALSE) {
    Exit
}
If ([string]::IsNullOrEmpty($LogFolderPath)) {
    #Log locally for testing
    $LogFolderPath = $PSScriptRoot
}
If ([string]::IsNullOrEmpty($DebugLevel)) {
    $DebugLevel = 0
}


$path = $PSScriptRoot

#dot source the AutomationLibrary.ps1
. "$path\AutomationLibrary.ps1"
AutomationLibraryInit

#create the runId to tie log entries together later in splunk
$global:RunID = [System.Guid]::NewGuid().toString()

$global:logName = $AutomationScriptName

$global:runThis = "$path\..\Automations\$AutomationScriptName\$AutomationScriptName.ps1 -DebugLevel $DebugLevel -LogFolderPath $LogFolderPath -RunID $RunID"
If (![string]::IsNullOrEmpty($Parameters)) { $global:runThis += " -Parameters ""$Parameters"" " }


$scriptBlock = [scriptblock]::Create(". $runThis")
$job = Start-Job -ScriptBlock $scriptBlock

If ($DebugLevel -gt 0) {
    $description = "Job id = " + $job.id
    WriteDebugLogMessage -RunResult 0 -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0
}

#While loop workes better than Wait-Job $job -Timeout $TimeoutInSeconds | out-null
$jobStartTime = Get-Date
$isOutOfTime = $FALSE
while (($job.State -eq "Running") -and ($isOutOfTime -eq $FALSE)) {
    $jobNowTime = Get-Date
    $jobTimeDiff = New-TimeSpan -Start $jobStartTime -End $jobNowTime
    $jobRuntimeInSeconds = [math]::Round($jobTimeDiff.TotalSeconds)
    if ($jobRuntimeInSeconds -ge $TimeoutInSeconds){
        #job hit the timeout threshold
        $isOutOfTime = $TRUE
    } else {
        #job isn't done yet, sleep for one second and check again
        Start-Sleep -s 1
    }
}

$results = Receive-Job $job -Keep
$startTime = $job.PSBeginTime

#Make sure this CAN BE TYPED AS AN INT or the healthy/unhealthy return will fail!!!!
If ([string]::IsNullOrEmpty($results)) {
    #$results is empty, something went wrong
    $results = 2  #TODO: Maybe there is a better return here
}
$resultsVariableType = $results.GetType().FullName
If ($resultsVariableType.StartsWith("System.Int")) {
  $output = [int]$results
  If ($DebugLevel -gt 0) {
        $description = "True output from run = " + $output + " : " + $resultsVariableType.StartsWith("System.Int")
        WriteDebugLogMessage -RunResult $healthy -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0
    }
} else {
  $output = 2  #TODO: Maybe there is a better return here
  If ($DebugLevel -gt 0) {
        $description = "Generic output from run = " + $output + " : " + $resultsVariableType.StartsWith("System.Int")
        WriteDebugLogMessage -RunResult $warning -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0
    }
}

$endTime = Get-Date
$TimeDiff = New-TimeSpan -Start $startTime -End $endTime
$runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
$runResult = $null
$name = $null
$description = $null
$exitDescription = $null
$exitCode = 0

If ($DebugLevel -gt 0) {
    $description = 'Job object command = '+$job.ChildJobs[0].Command
    WriteDebugLogMessage -RunResult $healthy -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0

    $job.ChildJobs[0] | Format-List -Property *

    "output = $output"
}

if ($job.State -eq "Completed") {
    if($job.ChildJobs[0].Error) {
        $runResult = $unhealthy
        $name = "Automation $AutomationScriptName - Error in wrapper execution"
        $description = $job.ChildJobs[0].Error
        If ($DebugLevel -gt 0) {
            $description = "Job object encountered error $description ... command = "+$job.ChildJobs[0].Command
            WriteDebugLogMessage -RunResult $unhealthy -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0
        }
        #Exit so Orchestrator will see the error
        $exitDescription = "$name :: $description"
        $exitCode = 1
    } else {
        $runResult = $healthy
        If ($DebugLevel -gt 0) {
            $description = "Command executed successfully ... command = "+$job.ChildJobs[0].Command
            WriteDebugLogMessage -RunResult $healthy -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0

            $description = "Output variable contains = "+$output
            WriteDebugLogMessage -RunResult $healthy -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0
        }

        If ($output -gt 0) {
            If ($DebugLevel -gt 0) {
                $description = "Legit run result error = $output"
                WriteDebugLogMessage -RunResult $healthy -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0
            }
            #Exit so Orchestrator will see the error
            $exitDescription = "Legit run result error = $output"
            $exitCode = 1
        }
    }
}
elseif ($job.State -eq "Running") {
    $runResult = $unhealthy
    $name = "Automation $AutomationScriptName - Timeout in wrapper execution"
    $endTime = Get-Date
    $TimeDiff = New-TimeSpan -Start $startTime -End $endTime
    $runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
    $description = "Timeout set to $TimeoutInSeconds seconds. Wrapper ran for $runtimeInMilliseconds milliseconds."
    If ($DebugLevel -gt 0) {
        $description = "Timeout: $description ... command = "+$job.ChildJobs[0].Command
        WriteDebugLogMessage -RunResult $unhealthy -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0
    }

    # If the job is still running, kill the job before exiting
    stop-job $job.childjobs
    stop-job $job
    $job=""

    #Exit so Orchestrator will see the error
    $exitDescription = "$description"
    $exitCode = 1
}
else {
    "???"
    If ($DebugLevel -gt 0) {
        $description = "Job object encountered an unexpected error... command = "+$job.ChildJobs[0].Command
        WriteDebugLogMessage -RunResult $warning -Name 'AutomationWrapper' -Description $description -RunTimeInMilliseconds 0
    }

    #Exit so Orchestrator will see the error
    $exitDescription = "$description"
    $exitCode = 1
}

$endTime = Get-Date
$TimeDiff = New-TimeSpan -Start $startTime -End $endTime
$runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
$timeoutInMilliseconds = [int]$TimeoutInSeconds * 1000
WriteWrapperLogMessage -RunResult $runResult -Name $name -Description $description -RunTimeInMilliseconds $runtimeInMilliseconds -TimeoutInMilliseconds $timeoutInMilliseconds

Remove-Job -force $job #cleanup

#Exit so Orchestrator will see the error
Write-Host "$exitDescription"
Exit $exitCode
