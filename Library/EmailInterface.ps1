Function EmailInterfaceInit {
    $global:emailQueuePath = "C:\PowershellAutomation\Queue\SendAutomatedEmail"
    if(!(Test-Path -Path $emailQueuePath )){
        New-Item -ItemType directory -Path $emailQueuePath
    }
    $global:smtpServer = 'yoursmtpserver.dns.name'
}


Function RemoveEmailQueueXMLFile {
  Param(
      [Parameter(Mandatory=$true)]$emailQueueObject
  )
    $id = $emailQueueObject.ID
    Remove-Item "$emailQueuePath\$id.xml"
}

Function WriteEmailObjectToQueueXMLFile {
    ###########################################################################
    # WriteEmailObjectToQueueXMLFile
    #
    # Creates an XML file in a queue folder from a custom email PSObject
    #
    # Usage:
    #   WriteEmailObjectToQueueXMLFile -queueArrayObject <custom email PSObject>
    #
    # Returns: void
    ###########################################################################
    Param(
        [Parameter(Mandatory=$true)]$queueArrayObject
    )

    $id = $queueArrayObject.ID
    $source = $queueArrayObject.Source
    $doNotDeliverBefore = $queueArrayObject.DoNotDeliverBefore
    $from = $queueArrayObject.From
    $to = $queueArrayObject.To
    $cc = $queueArrayObject.CC
    $bcc = $queueArrayObject.BCC
    $priority = $queueArrayObject.Priority
    $subject = [System.Security.SecurityElement]::Escape($queueArrayObject.Subject)
    $body = [System.Security.SecurityElement]::Escape($queueArrayObject.Body)
    $status = $queueArrayObject.Status

    $xmlTemplate = "<Email version='0.1'>
    <ID>$id</ID>
    <Source>$source</Source>
  	<DoNotDeliverBefore>$doNotDeliverBefore</DoNotDeliverBefore>
  	<From>$from</From>
  	<To>$to</To>
    <CC>$cc</CC>
    <BCC>$bcc</BCC>
    <Priority>$priority</Priority>
  	<Subject>$subject</Subject>
  	<Body>$body</Body>
    <Status>$status</Status>
    </Email>"

    #Write-Host "The XML is : $xmlTemplate"
    $filename = "$id"
    #Write-Host "The file path is: $emailQueuePath\$filename.xml"
    $xmlTemplate | Out-File "$emailQueuePath\$filename.xml" -Force
    #TODO: should we return something here?
}

Function GetEmailQueueArray {
    #LOAD ALL XML FILES IN THE OPEN QUEUE INTO AN ARRAY
    $emailQueueArray = @()
    Get-ChildItem "$emailQueuePath" -Filter *.xml | `
    Foreach-Object{
        [xml]$XmlDocument = Get-Content $_.FullName

        $object = CreateCustomEmailObject -id $XmlDocument.Email.ID -Source $XmlDocument.Email.Source -DoNotDeliverBefore $XmlDocument.Email.DoNotDeliverBefore -From $XmlDocument.Email.from -To $XmlDocument.Email.To -Cc $XmlDocument.Email.Cc -Bcc $XmlDocument.Email.Bcc -Priority $XmlDocument.Email.Priority -Subject $XmlDocument.Email.Subject -Body $XmlDocument.Email.Body -Status $XmlDocument.Email.Status

        $emailQueueArray += $object
    }
    return $emailQueueArray
}

Function SendEmailUsingCustomEmailObject {
    Param (
      [Parameter(Mandatory=$true)]$emailQueueObject
    )
    #TODO: Handle comma or semicolon separated email list here

    SendEmail -from $emailQueueObject.From -to $emailQueueObject.To -cc $emailQueueObject.Cc -bcc $emailQueueObject.Bcc -priority $emailQueueObject.Priority -subject $emailQueueObject.Subject -body $emailQueueObject.Body
    SetStatusForEmailQueueObject -id $emailQueueObject.Id -status "Sent"
}

Function SendEmail {
  Param(
    [Parameter(Mandatory=$true)][string]$from,
    [Parameter(Mandatory=$true)][string]$to,
    [Parameter(Mandatory=$false)][string]$cc,
    [Parameter(Mandatory=$false)][string]$bcc,
    [Parameter(Mandatory=$false)][string]$priority,
    [Parameter(Mandatory=$true)][string]$subject,
    [Parameter(Mandatory=$false)][string]$body
  )
  #TODO: Can we use this member of Send-MailMessage??? DeliveryNotificationOption

  #we can't have semicolons in our email address list, replace with commas
  $newTo = $to -Replace ";",","
  $newCc = $cc -Replace ";",","
  $newBcc = $bcc -Replace ";",","

  $message = New-Object System.Net.Mail.MailMessage
  $message.From = $from
  $message.To.Add($newTo)
  $message.Subject = $subject
  If (![string]::IsNullOrEmpty($newCc)) { $message.CC.Add($cc) }
  If (![string]::IsNullOrEmpty($newBcc)) { $message.BCC.Add($bcc) }
  If (![string]::IsNullOrEmpty($priority)) { $message.Priority = $priority }
  If (![string]::IsNullOrEmpty($body)) { $message.Body = $body }

  $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
  $messageReturn = $smtp.Send($message)

  if ($messageReturn -eq $null) {
      return $true
  } else {
      return $messageReturn
  }
}

Function CreateCustomEmailObject {
  Param (
    [Parameter(Mandatory=$true)][string]$id,
    [Parameter(Mandatory=$false)][string]$source,
    [Parameter(Mandatory=$false)][string]$doNotDeliverBefore,
    [Parameter(Mandatory=$true)][string]$from,
    [Parameter(Mandatory=$true)][string]$to,
    [Parameter(Mandatory=$false)][string]$cc,
    [Parameter(Mandatory=$false)][string]$bcc,
    [Parameter(Mandatory=$false)][string]$priority,
    [Parameter(Mandatory=$true)][string]$subject,
    [Parameter(Mandatory=$false)][string]$body,
    [Parameter(Mandatory=$false)][string]$status
  )

  # TODO: Validate data time format from doNotDeliverBefore and expiresAfter

  $object = New-Object -TypeName PSObject
  $object | Add-Member -Name ID -MemberType Noteproperty -Value $id
  $object | Add-Member -Name Source -MemberType Noteproperty -Value $Source
  $object | Add-Member -Name DoNotDeliverBefore -MemberType Noteproperty -Value $doNotDeliverBefore
  $object | Add-Member -Name From -MemberType Noteproperty -Value $from
  $object | Add-Member -Name To -MemberType Noteproperty -Value $to
  $object | Add-Member -Name Cc -MemberType Noteproperty -Value $cc
  $object | Add-Member -Name Bcc -MemberType Noteproperty -Value $bcc
  $object | Add-Member -Name Priority -MemberType Noteproperty -Value $Priority
  $object | Add-Member -Name Subject -MemberType Noteproperty -Value $subject
  $object | Add-Member -Name Body -MemberType Noteproperty -Value $body
  $object | Add-Member -Name Status -MemberType Noteproperty -Value $status

  return $object
}

Function CreateEmail {
  ###########################################################################
  # CreateEmail
  #
  # Creates the XML file for the email queue. The queue processor will send
  # it.
  #
  # Usage:
  #   CreateEmail -Source <String name of runbook calling this function> -doNotDeliverBefore <date/time> -From <email address> -To <email address(s) (use commas)> -cc <email address(s) (use commas)> -bcc <email address(s) (use commas)> -Priority <string> -Subject <string> -Body <string>
  #
  #  * Multiple recipients with a comma list(e.g. $recipients = "email1@domain.com,email2@domain.com")
  #
  # Returns: Void
  ###########################################################################
  Param (
    [Parameter(Mandatory=$false)][string]$source,
    [Parameter(Mandatory=$false)][string]$doNotDeliverBefore,
    [Parameter(Mandatory=$true)][string]$from,
    [Parameter(Mandatory=$true)][string]$to,
    [Parameter(Mandatory=$false)][string]$cc,
    [Parameter(Mandatory=$false)][string]$bcc,
    [Parameter(Mandatory=$false)][string]$priority,
    [Parameter(Mandatory=$true)][string]$subject,
    [Parameter(Mandatory=$false)][string]$body
  )

  #we can't have semicolons in our email address list, replace with commas
  $newTo = $to -Replace ";",","
  $newCc = $cc -Replace ";",","
  $newBcc = $bcc -Replace ";",","

  $emailObject = CreateCustomEmailObject -id (GenerateGUID) -Source $source -DoNotDeliverBefore $doNotDeliverBefore -From $from -To $newTo -Cc $newCc -Bcc $newBcc -Priority $priority -Subject $subject -Body $body -Status "New"

  WriteEmailObjectToQueueXMLFile -queueArrayObject $emailObject
}

Function GetEmailQueueObject {
  Param (
    [Parameter(Mandatory=$true)][string]$id
  )
  [xml]$XmlDocument = Get-Content "$emailQueuePath\$id.xml"

  $object = CreateCustomEmailObject -id $XmlDocument.Email.ID -Source $XmlDocument.Email.Source -DoNotDeliverBefore $XmlDocument.Email.DoNotDeliverBefore -From $XmlDocument.Email.from -To $XmlDocument.Email.To -Cc $XmlDocument.Email.Cc -Bcc $XmlDocument.Email.Bcc -Priority $XmlDocument.Email.Priority -Subject $XmlDocument.Email.Subject -Body $XmlDocument.Email.Body -Status $XmlDocument.Email.Status

  return $object
}

Function SetStatusForEmailQueueObject {
  Param (
    [Parameter(Mandatory=$true)][string]$id,
    [Parameter(Mandatory=$true)][string]$status
  )

  $emailQueueObject = GetEmailQueueObject -id $id
  $emailQueueObject.Status = $status

  WriteEmailObjectToQueueXMLFile -queueArrayObject $emailQueueObject
}

Function GenerateGUID {
  return [System.Guid]::NewGuid().toString()
}
