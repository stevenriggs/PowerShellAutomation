###### do not remove ########
# RunbookTemplate version: 2
#############################

Param (
      [Parameter(Mandatory=$false)][int]$DebugLevel,
      [Parameter(Mandatory=$false)][string]$LogFolderPath,
      [Parameter(Mandatory=$false)][string]$RunID,
      [Parameter(Mandatory=$false)][string]$Parameters
)

#dot source the Library.ps1
. "$PSScriptRoot\..\..\Library\RunbookLibrary.ps1"
RunbookLibraryInit

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



Function SendAutomatedEmail {
    #Get the start time for logging runtimeInMilliseconds
    $startDate = (Get-Date)
    # YOUR CODE STARTS HERE ##############################################

    #Get the entire email queue
    $emailQueueArray = GetEmailQueueArray
    If ($DebugLevel -gt 0) {
        $description = '$emailQueueArray count = '+($emailQueueArray.Count)
        WriteDebugLogMessage -RunResult 0 -Name 'Function SendAutomatedEmail' -Description $description
    }

    #Get new email items
    $emailQueueNewItemArray = @()
    ForEach ($item in $emailQueueArray) {
        $status = $item.Status
        If ($status -eq "New") { # TODO: Add somewhere the time check for date to send and expiration
            $emailQueueNewItemArray += $item
        }
    }
    $totalNewEmailsInQueue = $emailQueueNewItemArray.Count

    #Get email items that aren't delayed for delivery
    $emailQueueNewItemWithNoDelayArray = @()
    $doNotDeliverBeforeCount = 0
    ForEach ($item in $emailQueueNewItemArray) {
        $doNotDeliverBefore = $item.DoNotDeliverBefore
        If (![string]::IsNullOrEmpty($doNotDeliverBefore)) {
            #There is a DoNotDeliverBefore time set
            $doNotDeliverBeforeDateObject = Get-Date $doNotDeliverBefore
            $nowDateObject = (Get-Date)
            #Tally all deferred emails
            If ($doNotDeliverBeforeDateObject -gt $nowDateObject) {
                $doNotDeliverBeforeCount++
            } else {
                #This has passed the defer time, let's send it
                $emailQueueNewItemWithNoDelayArray += $item
            }
        } else {
            #There is no DoNotDeliverBefore time set
            $emailQueueNewItemWithNoDelayArray += $item
        }
    }
    If ($DebugLevel -gt 0) {
        $description = '$emailQueueNewItemWithNoDelayArray count = '+($emailQueueNewItemWithNoDelayArray.Count)
        WriteDebugLogMessage -RunResult 0 -Name 'Function SendAutomatedEmail' -Description $description
    }

    #TODO: Check for duplicate emails and delete the duplicate??

    #TODO: Send emails from the emailQueueNewItemWithNoDelayArray
    $emailSentCount = 0
    ForEach ($email in $emailQueueNewItemWithNoDelayArray) {
      SendEmailUsingCustomEmailObject -emailQueueObject $email
      $errorMessageTitle = "$scriptName sent email"
      $errorMessageDescription = "$email"
      $theResult = $healthy
      $endDate = (Get-Date)
      $TimeDiff = New-TimeSpan $startDate $endDate
      $runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
      WriteResultLogMessage -RunResult $theResult -Name $errorMessageTitle -Description $errorMessageDescription -RunTimeInMilliseconds $runtimeInMilliseconds

      $emailSentCount++

      #TODO: What do we do with the email xml file now that we're done???
      #$email.Status = "Sent"
      #WriteEmailObjectToQueueXMLFile -queueArrayObject $email
      RemoveEmailQueueXMLFile -emailQueueObject $email
    }



    # LOGGING ############################################################
    #TODO: figure out real health of this script!
    If ($true -eq $true) {
        $errorMessageTitle = "$scriptName completed successful"
        $errorMessageDescription = "Sent $emailSentCount of $totalNewEmailsInQueue total new emails in the queue. $doNotDeliverBeforeCount emails were deferred."
        $theResult = $healthy
    } else {
        $errorMessageTitle = "$scriptName error"
        $errorMessageDescription = ""
        $theResult = $unhealthy
    }
    $endDate = (Get-Date)
    $TimeDiff = New-TimeSpan $startDate $endDate
    $runtimeInMilliseconds = [math]::Round($TimeDiff.TotalMilliseconds)
    WriteResultLogMessage -RunResult $theResult -Name $errorMessageTitle -Description $errorMessageDescription -RunTimeInMilliseconds $runtimeInMilliseconds
}






##############################################################
###################  CALL FUNCTIONS HERE  ####################

#dot source the EmailInterface.ps1
. "$PSScriptRoot\..\..\Library\EmailInterface.ps1"
EmailInterfaceInit

CallFunctionAndReturnResult -FunctionName SendAutomatedEmail
