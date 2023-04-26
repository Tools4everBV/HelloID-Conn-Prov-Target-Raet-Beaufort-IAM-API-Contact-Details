#####################################################
# HelloID-Conn-Prov-Target-RAET-Beaufort-IAM-API-Contact-Details-Delete
#
# Version: 1.0.0
#####################################################
# Initialize default values
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($c.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Used to connect to RAET IAM API endpoints
$Script:AuthenticationUri = "https://connect.visma.com/connect/token"
$Script:BaseUri = "https://api.youforce.com"

$clientId = $c.clientid
$clientSecret = $c.clientsecret
$TenantId = $c.tenantid
$updateOnCorrelate = $c.updateOnCorrelate

# Correlation values
$correlationProperty = "personCode" # Has to match the name of the unique identifier
$correlationValue = $p.ExternalId # Has to match the value of the unique identifier

#Change mapping here
$account = [PSCustomObject]@{
    emailAddress = "" # Empty to clear the field
    phoneNumber  = "" # Empty to clear the field
}
# Additionally set account properties as required
$requiredFields = @()

#region functions
function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }

        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            # $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message # Does not show the correct error message for the Raet IAM API calls
            $httpErrorObj.ErrorMessage = $ErrorObject.Exception.Message

        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }

        Write-Output $httpErrorObj
    }
}

function Get-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $errorMessage = [PSCustomObject]@{
            VerboseErrorMessage = $null
            AuditErrorMessage   = $null
        }

        if ( $($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $httpErrorObject = Resolve-HTTPError -Error $ErrorObject

            $errorMessage.VerboseErrorMessage = $httpErrorObject.ErrorMessage

            $errorMessage.AuditErrorMessage = $httpErrorObject.ErrorMessage
        }

        # If error message empty, fall back on $ex.Exception.Message
        if ([String]::IsNullOrEmpty($errorMessage.VerboseErrorMessage)) {
            $errorMessage.VerboseErrorMessage = $ErrorObject.Exception.Message
        }
        if ([String]::IsNullOrEmpty($errorMessage.AuditErrorMessage)) {
            $errorMessage.AuditErrorMessage = $ErrorObject.Exception.Message
        }

        Write-Output $errorMessage
    }
}

function New-RaetSession {
    [CmdletBinding()]
    param (
        [Alias("Param1")] 
        [parameter(Mandatory = $true)]  
        [string]      
        $ClientId,

        [Alias("Param2")] 
        [parameter(Mandatory = $true)]  
        [string]
        $ClientSecret,

        [Alias("Param3")] 
        [parameter(Mandatory = $false)]  
        [string]
        $TenantId
    )

    #Check if the current token is still valid
    $accessTokenValid = Confirm-AccessTokenIsValid
    if ($true -eq $accessTokenValid) {
        return
    }

    try {
        # Set TLS to accept TLS, TLS 1.1 and TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

        $authorisationBody = @{
            'grant_type'    = "client_credentials"
            'client_id'     = $ClientId
            'client_secret' = $ClientSecret
            'tenant_id'     = $TenantId
        }        
        $splatAccessTokenParams = @{
            Uri             = $Script:AuthenticationUri
            Headers         = @{'Cache-Control' = "no-cache" }
            Method          = 'POST'
            ContentType     = "application/x-www-form-urlencoded"
            Body            = $authorisationBody
            UseBasicParsing = $true
        }

        Write-Verbose "Creating Access Token at uri '$($splatAccessTokenParams.Uri)'"

        $result = Invoke-RestMethod @splatAccessTokenParams -Verbose:$false
        if ($null -eq $result.access_token) {
            throw $result
        }

        $Script:expirationTimeAccessToken = (Get-Date).AddSeconds($result.expires_in)

        $Script:AuthenticationHeaders = @{
            'Authorization' = "Bearer $($result.access_token)"
            'Accept'        = "application/json"
        }

        Write-Verbose "Successfully created Access Token at uri '$($splatAccessTokenParams.Uri)'"
    }
    catch {
        $ex = $PSItem
        $errorMessage = Get-ErrorMessage -ErrorObject $ex

        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))"

        $auditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Error creating Access Token at uri ''$($splatAccessTokenParams.Uri)'. Please check credentials. Error Message: $($errorMessage.AuditErrorMessage)"
                IsError = $true
            })     
    }
}

function Confirm-AccessTokenIsValid {
    if ($null -ne $Script:expirationTimeAccessToken) {
        if ((Get-Date) -le $Script:expirationTimeAccessToken) {
            return $true
        }
    }
    return $false
}
#endregion functions

try {
    # Check if required fields are available for correlation
    $incompleteCorrelationValues = $false
    if ([String]::IsNullOrEmpty($correlationProperty)) {
        $incompleteCorrelationValues = $true
        Write-Warning "Required correlation field 'correlationProperty' has a null or empty value"
    }
    if ([String]::IsNullOrEmpty($correlationValue)) {
        $incompleteCorrelationValues = $true
        Write-Warning "Required correlation field 'correlationValue' has a null or empty value"
    }
    
    if ($incompleteCorrelationValues -eq $true) {
        throw "Correlation values incomplete, cannot continue. CorrelationProperty = '$correlationProperty', CorrelationValue = '$correlationValue'"
    }

    # Check if required fields are available in account object
    $incompleteAccount = $false
    foreach ($requiredField in $requiredFields) {
        if ($requiredField -notin $account.PsObject.Properties.Name) {
            $incompleteAccount = $true
            Write-Warning "Required account object field '$requiredField' is missing"
        }

        if ([String]::IsNullOrEmpty($account.$requiredField)) {
            $incompleteAccount = $true
            Write-Warning "Required account object field '$requiredField' has a null or empty value"
        }
    }

    if ($incompleteAccount -eq $true) {
        throw "Account object incomplete, cannot continue. Account object: $($account | ConvertTo-Json -Depth 10)"
    }

    # Get current account and verify if the action should be either [updated and correlated] or just [correlated]
    try {
        $accessTokenValid = Confirm-AccessTokenIsValid
        if ($true -ne $accessTokenValid) {
            New-RaetSession -ClientId $clientId -ClientSecret $clientSecret -TenantId $tenantId
        }

        Write-Verbose "Querying Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"

        $splatWebRequest = @{
            Uri             = "$($Script:BaseUri)/iam/v1.0/persons/$($correlationValue)"
            Headers         = $Script:AuthenticationHeaders
            Method          = 'GET'
            ContentType     = "application/json"
            UseBasicParsing = $true
        }
        $currentAccount = $null
        $currentAccount = Invoke-RestMethod @splatWebRequest -Verbose:$false

        if ($null -ne $currentAccount.id) {
            Write-Verbose "Successfully found Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"
        } 
        else {
            throw "No employee found in Raet Beaufort with $($correlationProperty) '$($correlationValue)'"
        }

        if ($updateOnCorrelate -eq $true) {
            $action = 'Update-Correlate'
        
            $propertiesChanged = $null
                
            # Get value of current Business Email Address
            if ($null -ne $currentAccount.emailAddresses) {
                $businessEmailAddress = $currentAccount.emailAddresses | Where-Object { $_.type -eq "Business" }
                $businessEmailAddressValue = $businessEmailAddress.address
            }

            # Get value of current Business Phonenumber
            if ($null -ne $currentAccount.phoneNumbers) {
                $businessPhoneNumber = $currentAccount.phoneNumbers | Where-Object { $_.type -eq "Business" }
                $businessPhoneNumberValue = $businessPhoneNumber.number
            }

            # Retrieve current account data for properties to be updated
            $previousAccount = [PSCustomObject]@{
                'emailAddress' = $businessEmailAddressValue
                'phoneNumber'  = $businessPhoneNumberValue
            }

            $splatCompareProperties = @{
                ReferenceObject  = @($previousAccount.PSObject.Properties)
                DifferenceObject = @($account.PSObject.Properties)
            }
            $propertiesChanged = (Compare-Object @splatCompareProperties -PassThru).Where( { $_.SideIndicator -eq '=>' })

            if ($propertiesChanged) {
                Write-Verbose "Account property(s) required to update: [$($propertiesChanged.name -join ",")]"

                foreach ($changedProperty in $propertiesChanged) {
                    Write-Verbose "Updating field $($changedProperty.name) '$($previousAccount.($changedProperty.name))' with new value '$($account.($changedProperty.name))'"
                }

                $updateAction = 'Update'
            }
            else {
                $updateAction = 'NoChanges'
            }
        }
        else {
            $action = 'Correlate'
        }
    }
    catch {
        $ex = $PSItem
        $errorMessage = Get-ErrorMessage -ErrorObject $ex
    
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))"

        $auditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Error querying Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'. Error Message: $($errorMessage.AuditErrorMessage)"
                IsError = $true
            })
    }

    if ($null -ne $currentAccount.id) {
        # Either [update and correlate] or just [correlate]
        switch ($action) {
            'Update-Correlate' {
                Write-Verbose "Updating and correlating Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"
    
                switch ($updateAction) {
                    'Update' {
                        try {
                            $body = ($account | ConvertTo-Json -Depth 10)
                            $splatWebRequest = @{
                                Uri             = "$($Script:BaseUri)/iam/v1.0/ContactDetails/$($correlationValue)"
                                Headers         = $Script:AuthenticationHeaders
                                Method          = 'POST'
                                Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))
                                ContentType     = "application/json;charset=utf-8"
                                UseBasicParsing = $true
                            }
      
                            Write-Verbose "Updating Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'. Account object: $($account | ConvertTo-Json -Depth 10)"
                            
                            if (-not($dryRun -eq $true)) {
                                $updatedAccount = Invoke-RestMethod @splatWebRequest -Verbose:$false

                                $auditLogs.Add([PSCustomObject]@{
                                        # Action  = "" # Optional
                                        Message = "Successfully updated Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"
                                        IsError = $false
                                    })
                            }
                            else {
                                Write-Warning "DryRun: Would update Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'. Account object: $($account | ConvertTo-Json -Depth 10)"
                            }

                            break
                        }
                        catch {
                            $ex = $PSItem
                            $errorMessage = Get-ErrorMessage -ErrorObject $ex
                    
                            Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))"
                
                            $auditLogs.Add([PSCustomObject]@{
                                    # Action  = "" # Optional
                                    Message = "Error updating Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'. Error Message: $($errorMessage.AuditErrorMessage) Account object: $($account | ConvertTo-Json -Depth 10)"
                                    IsError = $true
                                })
                        }
                    }
                    'NoChanges' {
                        Write-Verbose "No changes to Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"
    
                        if (-not($dryRun -eq $true)) {
                            $auditLogs.Add([PSCustomObject]@{
                                    # Action  = "" # Optional
                                    Message = "Successfully updated Raet Beaufort employee with $($correlationProperty) '$($correlationValue)' (No changes needed)"
                                    IsError = $false
                                })
                        }
                        else {
                            Write-Warning "DryRun: No changes to Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"
                        }                  

                        break
                    }
                }

                # Set aRef object for use in futher actions
                $aRef = $currentAccount.personCode

                # Define ExportData with account fields and correlation property 
                $exportData = $account.PsObject.Copy()
                $exportData | Add-Member -MemberType NoteProperty -Name $correlationProperty -Value $correlationValue -Force

                break
            }
            'Correlate' {
                Write-Verbose "Correlating to Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"

                if (-not($dryRun -eq $true)) {
                    $auditLogs.Add([PSCustomObject]@{
                            # Action  = "" # Optional
                            Message = "Successfully correlated to Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"
                            IsError = $false
                        })
                }
                else {
                    Write-Warning "DryRun: Would correlate to Raet Beaufort employee with $($correlationProperty) '$($correlationValue)'"
                }

                # Set aRef object for use in futher actions
                $aRef = $currentAccount.personCode

                # Define ExportData with account fields and correlation property 
                $exportData = $previousAccount.PsObject.Copy()
                $exportData | Add-Member -MemberType NoteProperty -Name $correlationProperty -Value $correlationValue -Force

                break
            }
        }
    }
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($auditLogs.IsError -contains $true)) {
        $success = $true
    }

    # Send results
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $aRef
        AuditLogs        = $auditLogs
        PreviousAccount  = $previousAccount
        Account          = $account

        # Optionally return data for use in other systems
        ExportData       = $exportData
    }

    Write-Output ($result | ConvertTo-Json -Depth 10)  
}