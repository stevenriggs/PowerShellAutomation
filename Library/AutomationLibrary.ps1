

Function AutomationLibraryInit {
    ###########################################################################
    # LibraryInit
    #
    # Initialize the components needed for the shared functions.
    #
    # Usage:
    #   LibraryInit
    #
    # Returns: void
    ###########################################################################

    $global:healthy = 0
    $global:warning = 1
    $global:unhealthy = 2
}

Function CallFunctionAndReturnResult {
    ###########################################################################
    # CallFunctionAndReturnResult
    #
    # Creates nicely formatted shell output while the script runs
    #
    # Usage:
    #   CallFunctionAndReturnResult -FunctionName <name of function> -Parameters <string of powershell parameters>
    #
    #   Parameters example: "-UserName 'user' -Password 'password'"
    #
    # Returns: The resulting health state value from the function
    ###########################################################################
    param(
      [Parameter(Mandatory=$True)][string]$FunctionName,
      [Parameter(Mandatory=$False)][string]$Parameters
    )

    If ($DebugLevel -gt 0) {
        Write-Host
        Write-Host
        Write-Host "###########"
        Write-Host "#### START Function $functionName"
        Write-Host "###########"
        Write-Host
    }
    $startDate = (Get-Date)
    $codeRunResult = $healthy
    $codeName = "Function $functionName"
    $codeDescription = $null

    $expression = "$functionName"
    If (![string]::IsNullOrEmpty($Parameters)) { $expression += " $Parameters" }

    Try {
        $runResult = invoke-expression $expression
    } catch {
        $codeRunResult = $unhealthy
        $codeName = "Function $functionName - Caught an Exception Type: $($_.Exception.GetType().FullName)"
        $codeDescription = "Exception Message: $($_.Exception.Message)"
    } finally {

        $endDate = (Get-Date)
        $TimeDiff = New-TimeSpan $startDate $endDate
        $runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
        WriteCodeLogMessage -RunResult $codeRunResult -Name $codeName -Description $codeDescription -RunTimeInMilliseconds $runtimeInMilliseconds

        If ($DebugLevel -gt 0) {
            Write-Host
            Write-Host "Function ran for: $runtimeInMilliseconds milliseconds."
            Write-Host
            Write-Host "###########"
            Write-Host "####  END Function $functionName"
            Write-Host "###########"
            Write-Host
            Write-Host
        }
    }
    #Return the resulting health state value from the function
    Return $runResult
}

Function RunExternalProgram {
  Param (
    [string]$ProgramPath,
    [string]$Arguments,
    [int]$TimeoutInSeconds
  )
  $TimeoutInMilliseconds = $TimeoutInSeconds * 1000

  # Setup the Process startup info
  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = $ProgramPath
  If ($Arguments) {$pinfo.Arguments = $Arguments}
  $pinfo.UseShellExecute = $false
  $pinfo.CreateNoWindow = $true
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError = $true
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $pinfo
  $process.Start() | Out-Null
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $exitCode = $process.ExitCode
  If ($TimeoutInSeconds -gt 0) {
    $process.WaitForExit($TimeoutInMilliseconds)
  } else {
    $process.WaitForExit()
  }

  # If the process is still active kill it
  if (!$process.HasExited) {
      $process.Kill()

      If ($DebugLevel -gt 0) {
          $description = "The process is still active, killing it."
          WriteDebugLogMessage -RunResult $warning -Name 'RunExternalProgram' -Description $description -RunTimeInMilliseconds 0
      }
  }

  If ($DebugLevel -gt 0) {
      Write-Host "STDOUT: $stdout"
      Write-Host "STDERR: $stderr"
      Write-Host "ExitCode: $exitCode"
      $description = "STDOUT: $stdout --- STDERR: $stderr --- ExitCode: $exitCode"
      WriteDebugLogMessage -RunResult $warning -Name 'RunExternalProgram' -Description $description -RunTimeInMilliseconds 0
  }

  $object = New-Object -TypeName PSObject
  $object | Add-Member -Name stdout -MemberType Noteproperty -Value $stdout
  $object | Add-Member -Name stderr -MemberType Noteproperty -Value $stderr
  $object | Add-Member -Name exitCode -MemberType Noteproperty -Value $exitCode

  If ($DebugLevel -gt 0) {
    Write-Host $object
  }
  return $object
}

Function ExecuteSqlQuery {
    param(
      [Parameter(Mandatory=$True)][string]$server,
      [Parameter(Mandatory=$True)][string]$database,
      [Parameter(Mandatory=$True)][string]$sqlQuery
    )
    $Datatable = New-Object System.Data.DataTable
    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server='$server';database='$database';trusted_connection=true;"
    $Connection.Open()
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $Connection
    $Command.CommandText = $sqlQuery
    $Command.CommandTimeout = 0
    $Reader = $Command.ExecuteReader()
    $Datatable.Load($Reader)
    $Connection.Close()

    return $Datatable
}

Function CreateAutomationLogEntryObject {
    param(
      [Parameter(Mandatory=$True)][string]$RunResult,
      [Parameter(Mandatory=$False)][string]$Name,
      [Parameter(Mandatory=$False)][string]$Description,
      [Parameter(Mandatory=$False)][int]$RuntimeInMilliseconds
    )

    $timeStamp = (Get-Date).ToUniversalTime().tostring("yyyy-MM-ddTHH:mm:ss+00:00")

    #we can't have full quotes in our log description, replace with half quotes
    #we can't have new lines in our log description, replace with a comma.
    $modifiedDescription = $Description.replace('"',"'").replace("`n",",").replace("`r",",")

    $object = New-Object -TypeName PSObject
    $object | Add-Member -Name TimeStamp -MemberType Noteproperty -Value $timeStamp
    $object | Add-Member -Name RunResult -MemberType Noteproperty -Value $RunResult
    $object | Add-Member -Name Name -MemberType Noteproperty -Value $Name
    $object | Add-Member -Name Description -MemberType Noteproperty -Value $modifiedDescription
    $object | Add-Member -Name RunTimeInMilliseconds -MemberType Noteproperty -Value $RunTimeInMilliseconds

    return $object
}

Function CreateAutomationWrapperLogEntryObject {
    param(
      [Parameter(Mandatory=$True)][int]$RunResult,
      [Parameter(Mandatory=$False)][string]$Name,
      [Parameter(Mandatory=$False)][string]$Description,
      [Parameter(Mandatory=$True)][int]$RuntimeInMilliseconds,
      [Parameter(Mandatory=$True)][int]$TimeoutInMilliseconds
    )

    switch ($RunResult) {
        0 {$runResultString = "WRAPPERHEALTHY"; break}
        1 {$runResultString = "WRAPPERWARNING"; break}
        2 {$runResultString = "WRAPPERUNHEALTHY"; break}
        default {$runResultString = $null} #Maybe throw something crazy to show we got the number wrong??
    }

    $timeStamp = (Get-Date).ToUniversalTime().tostring("yyyy-MM-ddTHH:mm:ss+00:00")

    #we can't have full quotes in our log description, replace with half quotes
    #we can't have new lines in our log description, replace with a comma.
    $modifiedDescription = $Description.replace('"',"'").replace("`n",",").replace("`r",",")

    $object = New-Object -TypeName PSObject
    $object | Add-Member -Name TimeStamp -MemberType Noteproperty -Value $timeStamp
    $object | Add-Member -Name RunResult -MemberType Noteproperty -Value $runResultString
    $object | Add-Member -Name Name -MemberType Noteproperty -Value $Name
    $object | Add-Member -Name Description -MemberType Noteproperty -Value $modifiedDescription
    $object | Add-Member -Name RunTimeInMilliseconds -MemberType Noteproperty -Value $RunTimeInMilliseconds
    $object | Add-Member -Name TimeoutInMilliseconds -MemberType Noteproperty -Value $TimeoutInMilliseconds

    return $object
}

Function CreateAutomationCodeLogEntryObject {
    param(
      [Parameter(Mandatory=$True)][int]$RunResult,
      [Parameter(Mandatory=$False)][string]$Name,
      [Parameter(Mandatory=$False)][string]$Description,
      [Parameter(Mandatory=$True)][int]$RuntimeInMilliseconds
    )

    switch ($RunResult) {
        0 {$runResultString = "CODEHEALTHY"; break}
        1 {$runResultString = "CODEWARNING"; break}
        2 {$runResultString = "CODEUNHEALTHY"; break}
        default {$runResultString = $null} #Maybe throw something crazy to show we got the number wrong??
    }
    $object = CreateAutomationLogEntryObject -RunResult $runResultString -Name $name -Description $description -RunTimeInMilliseconds $runtimeInMilliseconds

    return $object
}

Function CreateAutomationResultLogEntryObject {
    param(
      [Parameter(Mandatory=$True)][int]$RunResult,
      [Parameter(Mandatory=$False)][string]$Name,
      [Parameter(Mandatory=$False)][string]$Description,
      [Parameter(Mandatory=$True)][int]$RuntimeInMilliseconds
    )

    switch ($RunResult) {
        0 {$runResultString = "RESULTHEALTHY"; break}
        1 {$runResultString = "RESULTWARNING"; break}
        2 {$runResultString = "RESULTUNHEALTHY"; break}
        default {$runResultString = $null} #Maybe throw something crazy to show we got the number wrong??
    }
    $object = CreateAutomationLogEntryObject -RunResult $runResultString -Name $name -Description $description -RunTimeInMilliseconds $runtimeInMilliseconds

    return $object
}

Function CreateAutomationDebugLogEntryObject {
    param(
      [Parameter(Mandatory=$True)][int]$RunResult,
      [Parameter(Mandatory=$False)][string]$Name,
      [Parameter(Mandatory=$False)][string]$Description,
      [Parameter(Mandatory=$False)][int]$runtimeInMilliseconds
    )

    switch ($RunResult) {
        0 {$runResultString = "DEBUGINFO"; break}
        1 {$runResultString = "DEBUGWARNING"; break}
        2 {$runResultString = "DEBUGERROR"; break}
        default {$runResultString = $null} #Maybe throw something crazy to show we got the number wrong??
    }
    $object = CreateAutomationLogEntryObject -RunResult $runResultString -Name $name -Description $description -RunTimeInMilliseconds $runtimeInMilliseconds

    return $object
}

Function WriteLogMessageToDisk {
  ###########################################################################
  # WriteLogMessageToDisk
  #
  # Writes a line to a log file on disk
  #
  # Usage:
  #   WriteLogMessageToDisk -Message <string to write as a log entry> -LogFileName <string name of log file>
  #
  #   The purpose is to have a single function that writes to disk so we can focus on resiliency
  #
  # Returns: void
  ###########################################################################
  Param(
      [Parameter(Mandatory=$true)]$Message,
      [Parameter(Mandatory=$true)][string]$LogFileName
  )
  #TODO: Make this more resilient to deal with losing access to the target filesystem
  $logFile = $logFolderPath+'\'+$LogFileName
  $Message | Out-File -FilePath $logFile -Append -Force -Encoding UTF8
}

Function WriteLogMessage {
    Param(
        [Parameter(Mandatory=$true)]$LogEntryObject,
        [Parameter(Mandatory=$true)][string]$LogName
    )
    $dateForLogFileName = (Get-Date).ToUniversalTime().tostring("yyyyMMdd")
    #$logFile = $logFolderPath+'\Automation_'+$logName+"_"+$dateForLogFileName+".log"
    $logFileName = 'Automation_'+$logName+"_"+$dateForLogFileName+".log"
    $message = $LogEntryObject.TimeStamp+','+$logName+','+$LogEntryObject.RunResult+',"'+$LogEntryObject.Name+'","'+$LogEntryObject.Description+'"'
    If (![string]::IsNullOrEmpty($LogEntryObject.RunTimeInMilliseconds)) {
      $message += ',"'+$LogEntryObject.RunTimeInMilliseconds+'"'
    } else {
      $message += ',""'
    }
    #add an empty TimeoutInMilliseconds field in this log entry (this is only in the wrapper log entry)
    $message += ',""'
    #add the host name
    $computername = $env:computername
    $message += ',"'+$computername+'"'
    #add the runId to tie log entries together in splunk
    $message += ',"'+$RunID+'"'

    #$message | Out-File -FilePath $logFile -Append -Force -Encoding UTF8
    WriteLogMessageToDisk -Message $message -LogFileName $logFileName

    Write-Host "WriteLogMessage: $message"
}

Function WriteLogMessageForWrapper {
    Param(
        [Parameter(Mandatory=$true)]$LogEntryObject,
        [Parameter(Mandatory=$true)][string]$LogName
    )
    $dateForLogFileName = (Get-Date).ToUniversalTime().tostring("yyyyMMdd")
    #$logFile = $logFolderPath+'\Automation_'+$logName+"_"+$dateForLogFileName+".log"
    $logFileName = 'Automation_'+$logName+"_"+$dateForLogFileName+".log"
    $message = $LogEntryObject.TimeStamp+','+$logName+','+$LogEntryObject.RunResult+',"'+$LogEntryObject.Name+'","'+$LogEntryObject.Description+'","'+$LogEntryObject.RunTimeInMilliseconds+'","'+$LogEntryObject.TimeoutInMilliseconds+'"'
    #add the host name
    $computername = $env:computername
    $message += ',"'+$computername+'"'
    #add the runId to tie log entries together in splunk
    $message += ',"'+$RunID+'"'

    #$message | Out-File -FilePath $logFile -Append -Force -Encoding UTF8
    WriteLogMessageToDisk -Message $message -LogFileName $logFileName

    Write-Host "WriteWrapperLogMessage: $message"
}

Function WriteDebugLogMessage {
    Param(
        [Parameter(Mandatory=$true)][int]$RunResult,
        [Parameter(Mandatory=$false)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Description,
        [Parameter(Mandatory=$false)][int]$RunTimeInMilliseconds
    )
    $logEntryObject = CreateAutomationDebugLogEntryObject -RunResult $RunResult -Name $Name -Description $Description -RunTimeInMilliseconds $RunTimeInMilliseconds
    WriteLogMessage -LogEntryObject $logEntryObject -LogName $logName
}

Function WriteResultLogMessage {
    Param(
        [Parameter(Mandatory=$true)][int]$RunResult,
        [Parameter(Mandatory=$false)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Description,
        [Parameter(Mandatory=$true)][int]$RunTimeInMilliseconds
    )
    $logEntryObject = CreateAutomationResultLogEntryObject -RunResult $RunResult -Name $Name -Description $Description -RunTimeInMilliseconds $RunTimeInMilliseconds
    WriteLogMessage -LogEntryObject $logEntryObject -LogName $logName
}

Function WriteCodeLogMessage {
    Param(
        [Parameter(Mandatory=$true)][int]$RunResult,
        [Parameter(Mandatory=$false)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Description,
        [Parameter(Mandatory=$true)][int]$RunTimeInMilliseconds
    )
    $logEntryObject = CreateAutomationCodeLogEntryObject -RunResult $RunResult -Name $Name -Description $Description -RunTimeInMilliseconds $RunTimeInMilliseconds
    WriteLogMessage -LogEntryObject $logEntryObject -LogName $logName
}

Function WriteWrapperLogMessage {
    Param(
        [Parameter(Mandatory=$true)][int]$RunResult,
        [Parameter(Mandatory=$false)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Description,
        [Parameter(Mandatory=$true)][int]$RunTimeInMilliseconds,
        [Parameter(Mandatory=$True)][int]$TimeoutInMilliseconds
    )

    $logEntryObject = CreateAutomationWrapperLogEntryObject -RunResult $RunResult -Name $Name -Description $Description -RunTimeInMilliseconds $RunTimeInMilliseconds -TimeoutInMilliseconds $TimeoutInMilliseconds
    WriteLogMessageForWrapper -LogEntryObject $logEntryObject -LogName $logName
}

Function WriteCreateNewScomAlertMessage {
    Param(
        [Parameter(Mandatory=$False)][string]$Name,
        [Parameter(Mandatory=$False)][string]$Description,
        [Parameter(Mandatory=$False)][string]$Severity,
        [Parameter(Mandatory=$False)][string]$TimeStamp,
        [Parameter(Mandatory=$False)][string]$Team,
        [Parameter(Mandatory=$False)][string]$EventGuid
    )
    #Return an int for SCOM rule: Severity: Critical 2  Warning 1 Information 0
    $SeverityInt = "0"
    Switch ($Severity)
    {
      "Critical" { $SeverityInt = "2"}
      "Warning" { $SeverityInt = "1"}
      "Information" { $SeverityInt = "0"}
      Default { $SeverityInt = "0"}
    }
    $timeStamp = (Get-Date).ToUniversalTime().tostring("yyyy-MM-ddTHH:mm:ss+00:00")
    $dateForLogFileName = Get-Date -format "yyyyMMdd"
    #$logFile = $logFolderPath+'\'+$logName+"_"+$dateForLogFileName+".log"
    $logFileName = $logName+"_"+$dateForLogFileName+".log"
    $message = $timeStamp+',CREATENEWSCOMALERT,"'+$Name+'","'+$Description+'","'+$SeverityInt+'","'+$TimeStamp+'","'+$Team+'","'+'","'+$EventGuid+'"'
    #$message | Out-File -FilePath $logFile -Append -Force -Encoding UTF8
    WriteLogMessageToDisk -Message $message -LogFileName $logFileName

    Write-Host "WriteWrapperLogMessage: $message"
}
