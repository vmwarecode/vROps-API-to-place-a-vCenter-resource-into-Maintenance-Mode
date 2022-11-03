Function Set-AdapterMaintOn {

    <#
        .SYNOPSIS
    The Set-AdapterMaintOn function places the vCenter resource into Maintenance Mode in vROps
        .DESCRIPTION
    Set the vCenter resource into Maintenance Mode in vROps to suspend alerting while performing maintenance.
        .EXAMPLE
    Set-AdapterMaintOn -vcenter vcsa-lab001.domain.local
    #>

    #
    param (
        [Parameter(Mandatory = $true)][string]$vrops_user,
        [Parameter(Mandatory = $true)][secureString]$vrops_pass,
        [parameter(Mandatory = $true)][string]$vcenter #FQDN of vCenter server for Maintenance Schedule
    )

    if (!$vrops_user) { $vrops_user = Read-Host  "Please enter your username" }
    if (!$vrops_pass) { $vrops_pass = Read-Host  | ConvertFrom-SecureString -AsPlainText -Force "Please your password" }
    if (!$vcenter) { $vcenter = Read-Host  "Please Enter vCenter to add to maintenance schedule in vROps" }
    $pass =  ($vrops_pass | ConvertFrom-SecureString -AsPlainText)

    $vROPsServer = "vrops.domain.local"
    $BaseUrl = "https://" + $vROPsServer + "/suite-api/api"
    $BaseAuthUrl = $BaseUrl + "/auth/token/acquire"
    $LogoutUrl = $BaseUrl + "/auth/token/release"
    $ResourcesUrl = $BaseUrl+"/adapters?_no_links=true"

    ## API Request Body
    $body = 
    "{
        ""username"" : ""$vrops_user"",
        ""authSource"" : ""ad.domain.local"",
        ""password"" : ""$pass""
    }"

    ## Acquire Auth Token
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "application/json")
    $headers.Add("Content-Type", "application/json")
    $vropsAccess = Invoke-RestMethod -Method 'POST' -Uri $BaseAuthURL -Body $body -Headers $headers
    $token = $vropsAccess.token


    ## Get vCenter Resource Identifier
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", "vRealizeOpsToken $token")
    $response = Invoke-RestMethod  -Method 'GET' -Uri $ResourcesUrl -Headers $headers
    $vcAdpapterId = ($response.adapterInstancesInfoDto | Select-Object $_.id | Where-Object {($_.resourcekey.resourceIdentifiers.value -eq $vcenter)}).id

    $MaintUrl = $BaseUrl + "/resources/" + $vcAdpapterId + "/maintained"

    ## Place resource into maintenance
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", "vRealizeOpsToken $token")
    $maintResponse = Invoke-WebRequest -Method 'PUT' -Uri $MaintUrl -Headers $headers

    if ($maintResponse.StatusCode -ne "200") {
        Write-Host Status Code is $response.StatusCode
        Write-Host $maintResponse.StatusDescription
        Write-Host -ForegroundColor DarkRed "The $vcenter adapter has not been placed into a Maintenance Schedule."
        Write-Host -ForegroundColor DarkRed "Review the Status Code and Status Description from above to troubleshoot."
    }
    else {
        ## Logout of vROps and release auth token
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Accept", "application/json")
        $headers.Add("Authorization", "vRealizeOpsToken $token")
        Invoke-WebRequest -Method 'POST' -Uri $LogoutUrl -Headers $headers | Out-Null
        Write-Host -ForegroundColor Green "vCenter $vcenter is now set to a manual maintenance schedule."
        Write-Host -ForegroundColor Green "You are now being logged out of vROps. Your access token has been released and is no longer valid."
    }

}