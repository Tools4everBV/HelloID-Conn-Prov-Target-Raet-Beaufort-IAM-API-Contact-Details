## HelloID-Conn-Prov-Target-Raet-Beaufort-IAM-API-Contact-Details

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

| :warning: Warning |
|:---------------------------|
| This connector requires **new api credentials**. To get these, please follow the [Visma documentation on how to register the App and grant access to client data](https://community.visma.com/t5/Kennisbank-Youforce-API/Visma-Developer-portal-een-account-aanmaken-applicatie/ta-p/527059).       |

<p align="center">
  <img src="https://user-images.githubusercontent.com/69046642/170068731-d6609cc7-2b27-416c-bbf4-df65e5063a36.png">
</p>

## Versioning
| Version | Description | Date |
| - | - | - |
| 1.0.0   | Initial release | 2023/02/27  |

## Table of contents
- [HelloID-Conn-Prov-Target-Raet-Beaufort-IAM-API-Contact-Details](#helloid-conn-prov-target-raet-beaufort-iam-api-contact-details)
- [Versioning](#versioning)
- [Table of contents](#table-of-contents)
- [Introduction](#introduction)
- [Endpoints implemented](#endpoints-implemented)
- [Raet IAM API status monitoring](#raet-iam-api-status-monitoring)
- [Getting started](#getting-started)
  - [App within Visma](#app-within-visma)
  - [Scope Configuration within Visma](#scope-configuration-within-visma)
  - [Connection settings](#connection-settings)
  - [Prerequisites](#prerequisites)
  - [Remarks](#remarks)
- [Getting help](#getting-help)
- [HelloID docs](#helloid-docs)
  
---

## Introduction
This connector allows you to write back contact details to a person in Raet Beaufort using the IAM API.
> Note: Currently, only the following fields are supported.
>   - Business Email Address
>   - Business Phone Number

## Endpoints implemented
[IAM Domain model](https://community.visma.com/t5/Kennisbank-Youforce-API/IAM-Domain-model-amp-field-mapping/ta-p/428102)
- [/iam/v1.0/persons/{id}](https://vr-api-integration.github.io/SwaggerUI/IAM.html#/Persons/Get)
- /iam/v1.0/ContactDetails/{id} (No Raet documentation article for yet)

## Raet IAM API status monitoring
https://developers.youforce.com/api-status

---

## Getting started
### App within Visma
First an App will have to be created in the [Visma Developer portal](https://oauth.developers.visma.com). This App can then be linked to specific scopes and to a client, which will only be available after the invitation has been accepted. 
Please follow the [Visma documentation on how to register the App and grant access to client data](https://community.visma.com/t5/Kennisbank-Youforce-API/Visma-Developer-portal-een-account-aanmaken-applicatie/ta-p/527059).

### Scope Configuration within Visma 
Before the connector can be used to retrieve and update employee information, the following scopes need to be enabled and assigned to the connector. If you need help setting the scopes up, please consult your Visma contact.

- Youforce-IAM:Get_Basic
- Youforce-IAM:Write_Basic

> Note: When using any of the other Raet IAM API connectors, additional scopes are required.
>   - For [HelloID-Conn-Prov-Source-Raet-Beaufort-IAM-API](https://github.com/Tools4everBV/HelloID-Conn-Prov-Source-Raet-Beaufort-IAM-API), used to import the HR data from Beaufort into HelloID Provisioning, the following scopes are required:
>     - Youforce-IAM:Get_Basic
>     - Youforce-Extensions:files:Get_Basic
>   - For [HelloID-Conn-Prov-Target-Raet-Beaufort-IAM-API-Identity](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Raet-Beaufort-IAM-API-Identity), used to write back the identity field, which is used for SSO, in Youforce, the following scopes are required:
>     - Youforce-IAM:Update_Identity
>   - For [HelloID-Conn-Prov-Target-Raet-DPIA100-FileAPI](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Raet-DPIA100-FileAPI), used to write back the data to Beaufort, e.g. the business email address, the following scopes are required:
>     - youforce-fileapi:files:list
>     - youforce-fileapi:files:upload

### Connection settings
The following settings are required to run the source import.

| Setting                                       | Description                                                               | Mandatory   |
| --------------------------------------------- | ------------------------------------------------------------------------- | ----------- |
| Client ID         | The Client ID to connect with the IAM API (created when registering the App in in the Visma Developer portal). | Yes   |
| Client Secret     | The Client Secret to connect with the IAM API (created when registering the App in in the Visma Developer portal). | Yes   |
| Tenant ID         | The Tenant ID to specify to which Raet tenant to connect with the IAM API (available in the Visma Developer portal after the invitation code has been accepted).  | Yes  |
| Update account when correlating   | When toggled, the account will de updated in the create action (not just correlated), if the mapped data differs from data target system. | No    |
| Toggle debug logging  | When toggled, extra logging is shown. Note that this is only meant for debugging, please switch this off when in production.  | No    |

### Prerequisites
- Authorized Visma Developers account in order to request and receive the API credentials in the [Visma Developer portal](https://oauth.developers.visma.com). Please follow the [Visma documentation on how to register the App and grant access to client data](https://community.visma.com/t5/Kennisbank-Youforce-API/Visma-Developer-portal-een-account-aanmaken-applicatie/ta-p/527059).
- ClientID, ClientSecret and tenantID to authenticate with the IAM API of Raet Beaufort. Please follow the [Visma documentation on how to register the App and grant access to client data](https://community.visma.com/t5/Kennisbank-Youforce-API/Visma-Developer-portal-een-account-aanmaken-applicatie/ta-p/527059).

### Remarks
 - Currently, only the 'Business Email Address' and 'Business Phone Number' fields can be updated, no other fields are (currently) supported.
    > When the value in Raet Beaufort equals the value in HelloID, the action will be skipped (no update will take place).

## Getting help
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/