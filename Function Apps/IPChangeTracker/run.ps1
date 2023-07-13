# Input bindings are passed in via param block.
param($Timer)

# Define script var to its name
$env:script = ($MyInvocation.MyCommand.Name).replace("_","")
Write-Log "Start of function app"

# Define API URL of Pushover
$pushoverURL = "https://api.pushover.net/1/messages.json"

# Previous IP File
$previousIPpath = ".\IPChangeTracker\previousIP.xml"

# Verify if variable is filled
if($env:DNSentry) {
    # Retrieve IP from DNS entry
    $DNSresult = [system.net.dns]::GetHostByName($env:DNSentry).AddressList.IPAddressToString
    Write-Log "DNS entry: $($env:DNSentry)"
}

# Test
#$env:previousIP = "1.1.1.1"

# Retrieve current IP
$ExternalIP = Invoke-RestMethod ipinfo.io/json
Write-Log "Current IP: $($ExternalIP.ip)"
Write-Log "Previous IP: $($env:previousIP)"

function Send-PushoverNotification {
    param(
        $Message,
        [string]$Title
    )

    # Verify if required variables are known
    if($null -ne $env:PushoverAPIKey -and $null -ne $env:PusoverUserKey -and $null -ne $pushoverURL) {
        # Create notification message
        $params = @{
            token = $env:PushoverAPIKey
            user = $env:PusoverUserKey
            title = $Title
            message = $Message
        }

        # Send notification message
        Invoke-RestMethod -Method Post -Uri $pushoverURL -Body $params
    }
    else {
        Write-Log "Not all required values are given! Please enter: PushoverAPIKey and PusoverUserKey"
    }
}

if($null -eq $env:previousIP) {
    Write-Log "Previous IP not known, try to restore previous IP"
    # Verify if previous IP has been stored
    if(Test-Path -Path $previousIPpath) {
        Write-Log "Restoring previous IP from disk"

        # Read previous IP from disk (PS Object)
        $env:previousIP = Import-Clixml $previousIPpath
        Write-Log "Previous IP restored: $($env:previousIP)"
    }
    else {
        Write-Log "Previous IP unkown, previous IP will be updated to current IP"
        # update previous IP to current IP
        $env:previousIP = $ExternalIP.ip

        # Store previous IP to disk
        $env:previousIP | Export-Clixml -Path $previousIPpath
    }
}
if($env:previousIP -ne $ExternalIP.ip) {
    Write-Log "IP changed: $($env:previousIP) vs current: $($ExternalIP.ip)"
    
    # Create message
    $message = "IP address changed (vs previous IP)!`n" `
    +"Old IP:     $($env:previousIP)`n" `
    +"New IP:     $($ExternalIP.ip)`n"`
    +"DNS Entry:  $($env:DNSentry)`n"`
    +"$($ExternalIP | Out-String)"
    
    # Send notification
    Send-PushoverNotification -Title $env:previousIP -Message $message
    
    # Update previousIP
    $env:previousIP = $ExternalIP.ip
    $env:previousIP | Export-Clixml -Path $previousIPpath
}
else {
    Write-Log "IP not changed: $($env:previousIP) vs current: $($ExternalIP.ip)"
}

# Verify if variables are filled
if($DNSresult -and $ExternalIP.ip) {
    # Verify if IP has change
    if($DNSresult -ne $ExternalIP.ip) {
        Write-Log "IP has changed!"

        # Create message
        $message = "IP address changed (vs DNS)!`n" `
        +"DNS IP:     $($DNSresult)`n" `
        +"New IP:     $($ExternalIP.ip)`n"`
        +"DNS Entry:  $($env:DNSentry)`n"`
        +"$($ExternalIP | Out-String)"

        # Send notification
        Send-PushoverNotification -Title $env:DNSentry -Message $message
    }
}

Write-Log "End of function app"