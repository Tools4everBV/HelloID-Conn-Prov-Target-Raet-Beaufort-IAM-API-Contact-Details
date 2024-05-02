#################################################
# HelloID-Conn-Prov-Target-RAET-Beaufort-IAM-API-Contact-Details-Update
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Used to connect to RAET IAM API endpoints
$Script:AuthenticationUri = "https://connect.visma.com/connect/token"
$Script:BaseUri = "https://api.youforce.com"

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

        throw "Error creating Access Token at uri ''$($splatAccessTokenParams.Uri)'. Please check credentials. Error Message: $($errorMessage.AuditErrorMessage)" 
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
    if (($actionContext.AccountCorrelated -eq $true) -or ($actionContext.Configuration.onlyUpdateOnCorrelate -eq $false)) {
              
        #region account
        # Define account object
        $account = [PSCustomObject]$actionContext.Data
        # Remove personCode field because only used for export data
        $account = $account | Select-Object -ExcludeProperty personCode

        # Define properties to compare for update
        $accountPropertiesToCompare = $account.PsObject.Properties.Name
        #endRegion account

        $actionContext.References.Account = '60880'
        # Verify if [aRef] has a value
        if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
            throw 'The account reference could not be found'
        }

        $accessTokenValid = Confirm-AccessTokenIsValid
        if ($true -ne $accessTokenValid) {
            $splatRaetSession = @{
                ClientId     = $actionContext.Configuration.clientId
                ClientSecret = $actionContext.Configuration.clientSecret
                TenantId     = $actionContext.Configuration.tenantId
            }
            New-RaetSession @splatRaetSession
        }

        Write-Verbose "Verifying if a Raet Beaufort employee account for [$($personContext.Person.DisplayName)] exists"

        $splatWebRequest = @{
            Uri             = "$($Script:BaseUri)/iam/v1.0/persons/$($actionContext.References.Account)"
            Headers         = $Script:AuthenticationHeaders
            Method          = 'GET'
            ContentType     = "application/json"
            UseBasicParsing = $true
        }
        try {
            $correlatedAccount = Invoke-RestMethod @splatWebRequest -Verbose:$false
        }
        catch {
            $ex = $PSItem
            $errorMessage = Get-ErrorMessage -ErrorObject $ex
            Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))"

            if ($errorMessage.AuditErrorMessage -Like "*Not Found*" -or $errorMessage.AuditErrorMessage -Like "No employee found in Raet Beaufort with $($correlationProperty) '$($correlationValue)'") {
                write-verbose "No employee found in Raet Beaufort with personCode [$($actionContext.References.Account)]. Possibly already deleted."
                $correlatedAccount = $null
            }
            else {
                throw $_
            }
        }
        $outputContext.PreviousData.personCode = $correlatedAccount.personCode
        
        # Always compare the account against the current account in target system
        if ($null -ne $correlatedAccount.id) {

            $propertiesChanged = $null

            # Get value of current Business Email Address
            if ($null -ne $correlatedAccount.emailAddresses) {
                $businessEmailAddress = $correlatedAccount.emailAddresses | Where-Object { $_.type -eq "Business" }
                $businessEmailAddressValue = $businessEmailAddress.address
            }

            # Get value of current Business Phonenumber
            if ($null -ne $correlatedAccount.phoneNumbers) {
                $businessPhoneNumber = $correlatedAccount.phoneNumbers | Where-Object { $_.type -eq "Business" }
                $businessPhoneNumberValue = $businessPhoneNumber.number
            }

            # Retrieve current account data for properties to be updated
            $previousAccount = [PSCustomObject]@{
                'emailAddress' = $businessEmailAddressValue
                'phoneNumber'  = $businessPhoneNumberValue
            }

            if (-not($actionContext.Data.PSObject.Properties.Name -Contains 'emailAddress')) {
                $previousAccount.PSObject.Properties.Remove('emailAddress')
            }
            else {
                $outputContext.PreviousData.emailAddress = $previousAccount.emailAddress
            }

            if (-not($actionContext.Data.PSObject.Properties.Name -Contains 'phoneNumber')) {
                $previousAccount.PSObject.Properties.Remove('phoneNumber')
            }
            else {
                $outputContext.PreviousData.phoneNumber = $previousAccount.phoneNumber
            }

            $splatCompareProperties = @{
                ReferenceObject  = $previousAccount.PSObject.Properties | Where-Object { $_.Name -in $accountPropertiesToCompare }
                DifferenceObject = $account.PSObject.Properties | Where-Object { $_.Name -in $accountPropertiesToCompare }
            }

            if ($null -ne $splatCompareProperties.ReferenceObject -and $null -ne $splatCompareProperties.DifferenceObject) {
                $accountPropertiesChanged = Compare-Object @splatCompareProperties -PassThru
                $accountOldProperties = $accountPropertiesChanged | Where-Object { $_.SideIndicator -eq "<=" }
                $accountNewProperties = $accountPropertiesChanged | Where-Object { $_.SideIndicator -eq "=>" }
            }

            if ($accountNewProperties) {
                $action = 'Update'
                Write-Information "Account property(s) required to update: $($accountNewProperties.Name -join ', ')"
            }
            else {
                $action = 'NoChanges'
            }
        }
        else {
            $action = 'NotFound'
        }

        # Process
        switch ($action) {
            'Update' {
                Write-Verbose "Updating Raet Beaufort employee account with accountReference: [$($actionContext.References.Account)]"

                # Create custom object with old and new values (for logging)
                $accountChangedPropertiesObject = [PSCustomObject]@{
                    OldValues = @{}
                    NewValues = @{}
                }

                foreach ($accountOldProperty in ($accountOldProperties | Where-Object { $_.Name -in $accountNewProperties.Name })) {
                    $accountChangedPropertiesObject.OldValues.$($accountOldProperty.Name) = $accountOldProperty.Value
                }

                foreach ($accountNewProperty in $accountNewProperties) {
                    $accountChangedPropertiesObject.NewValues.$($accountNewProperty.Name) = $accountNewProperty.Value
                }

                $body = ($account | ConvertTo-Json -Depth 10)

                $splatWebRequest = @{
                    Uri             = "$($Script:BaseUri)/iam/v1.0/ContactDetails/$($actionContext.References.Account)"
                    Headers         = $Script:AuthenticationHeaders
                    Method          = 'POST'
                    Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))
                    ContentType     = "application/json;charset=utf-8"
                    UseBasicParsing = $true
                }

                if ($actionContext.DryRun -eq $true) {
                    Write-Warning "DryRun: Would update account with AccountReference: $($actionContext.References.Account | ConvertTo-Json). Old values: $($accountChangedPropertiesObject.oldValues | ConvertTo-Json). New values: $($accountChangedPropertiesObject.newValues | ConvertTo-Json)"
                }
                else {
                    $updatedAccount = Invoke-RestMethod @splatWebRequest -Verbose:$false
                    $outputContext.Data.personCode = $updatedAccount.contactDetails.personCode

                    if ($actionContext.Data.PSObject.Properties.Name -Contains 'emailAddress') {
                        $outputContext.Data.emailAddress = $updatedAccount.contactDetails.emailAddress
                    }
                    if ($actionContext.Data.PSObject.Properties.Name -Contains 'phoneNumber') {
                        $outputContext.Data.phoneNumber = $updatedAccount.contactDetails.phoneNumber
                    }

                    $outputContext.Success = $true
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Update account was successful, Account property(s) updated: Old values: $($accountChangedPropertiesObject.oldValues | ConvertTo-Json). New values: $($accountChangedPropertiesObject.newValues | ConvertTo-Json)"
                            IsError = $false
                        })   
                }
                break
            }

            'NoChanges' {
                Write-Verbose "No changes to Raet Beaufort employee account with accountReference: [$($actionContext.References.Account)]"

                $outputContext.Data.personCode = $correlatedAccount.personCode
                $outputContext.Success = $true

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = 'No changes will be made to the account during enforcement'
                        IsError = $false
                    })
                break
            }

            'NotFound' {
                $outputContext.Success = $false
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Raet Beaufort employee account [$($actionContext.References.Account)] for: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
                        IsError = $true
                    })
                break
            }
        }
    }
    else {
        $outputContext.Success = $true
        Write-Verbose "The configuration parameter only update on correlate is [$($actionContext.Configuration.onlyUpdateOnCorrelate)]"
    }
}
catch {
    $outputContext.Success = $false
    $ex = $PSItem
    $errorMessage = Get-ErrorMessage -ErrorObject $ex

    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))"
    $auditMessage = "Could not update Raet Beaufort employee account. Error Message: $($errorMessage.AuditErrorMessage)"
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}