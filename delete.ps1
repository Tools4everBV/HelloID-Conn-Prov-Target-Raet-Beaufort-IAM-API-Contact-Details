##################################################
# HelloID-Conn-Prov-Target-RAET-Beaufort-IAM-API-Contact-Details-Delete
# PowerShell V2
##################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

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
    
    $outputContext.PreviousData = $correlatedAccount

    if ($null -ne $correlatedAccount) {
        $splatCompareProperties = @{
            ReferenceObject  = $correlatedAccount.PSObject.Properties
            DifferenceObject = $actionContext.Data.PSObject.Properties
        }
        $propertiesChanged = Compare-Object @splatCompareProperties -PassThru | Where-Object { $_.SideIndicator -eq '=>' }


        if ($propertiesChanged) {
            $updateAction = 'Update'
            $dryRunMessage = "Account property(s) required to update: $($propertiesChanged.Name -join ', ')"
        }
        else {
            $updateAction = 'NoChanges'
            $dryRunMessage = 'No changes will be made to the account during enforcement'
        }
        $action = 'DeleteAccount'
    }
    else {
        $action = 'NotFound'
        $dryRunMessage = "Raet Beaufort employee account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Verbose "[DryRun] $dryRunMessage" -Verbose
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'Update' {
                Write-Verbose "Updating Raet Beaufort employee account with accountReference: [$($actionContext.References.Account)]"

                $body = ($actionContext.Data | ConvertTo-Json -Depth 10)
                # Not sure if we need to use account (actionContext.Data) or something with properties changed:
                # $body = ($propertiesChanged | ConvertTo-Json -Depth 10)

                $splatWebRequest = @{
                    Uri             = "$($Script:BaseUri)/iam/v1.0/ContactDetails/$($actionContext.References.Account)"
                    Headers         = $Script:AuthenticationHeaders
                    Method          = 'POST'
                    Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))
                    ContentType     = "application/json;charset=utf-8"
                    UseBasicParsing = $true
                }

                $updatedAccount = Invoke-RestMethod @splatWebRequest -Verbose:$false

                # Not sure if $updatedAccount gives back the result you updated. Else return $actionContext.Data
                # $outputContext.Data = $actionContext.Data
                $outputContext.Data = $updatedAccount

                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = $action
                        Message = "Delete account was successful, Account property(s) updated: [$($propertiesChanged.name -join ',')]"
                        IsError = $false
                    })
                break
            }

            'NoChanges' {
                Write-Verbose "No changes to Raet Beaufort employee account with accountReference: [$($actionContext.References.Account)]"

                $outputContext.Success = $true

                # Remove this AuditLog?
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = 'No changes will be made to the account during enforcement'
                        IsError = $false
                    })
                break
            }

            'NotFound' {
                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Raet Beaufort employee account [$($actionContext.References.Account)] for: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
                        IsError = $false
                    })
                break
            }
        }
    }
}
catch {
    $outputContext.Success = $false
    $ex = $PSItem
    $errorMessage = Get-ErrorMessage -ErrorObject $ex

    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))"
    $auditMessage = "Could not update Raet Beaufort employee updateOnUpdate account. Error Message: $($errorMessage.AuditErrorMessage)"
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}