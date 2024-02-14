
# HelloID-Conn-Prov-Target-RAET-Beaufort-IAM-API-Contact-Details

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="./Logo.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-RAET-Beaufort-IAM-API-Contact-Details](#helloid-conn-prov-target-raet-beaufort-iam-api-contact-details)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [App within Visma](#app-within-visma)
    - [Scope Configuration within Visma](#scope-configuration-within-visma)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-RAET-Beaufort-IAM-API-Contact-Details_ is a _target_ connector. _RAET-Beaufort_ provides a set of REST API's that allow you to programmatically interact with its data. The HelloID connector uses the API endpoints listed in the table below.

| Endpoint                      | Description                                                                                          |
| ----------------------------- | ---------------------------------------------------------------------------------------------------- |
| /iam/v1.0/persons/{id}        | [Documentation](https://vr-api-integration.github.io/SwaggerUI/IAM.html#/Persons/Get)                |
| /iam/v1.0/ContactDetails/{id} | [Documentation](https://community.visma.com/t5/Releases-Youforce-API/API-Update-2023-03/ta-p/558402) |

The following lifecycle actions are available:

| Action             | Description                          |
| ------------------ | ------------------------------------ |
| create.ps1         | Correlation on person                |
| delete.ps1         | Empty configured field(s) on person  |
| update.ps1         | Update configured field(s) on person |
| configuration.json | Default _configuration.json_         |
| fieldMapping.json  | Default _fieldMapping.json_          |

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

### Provisioning PowerShell V2 connector

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _RAET-Beaufort-IAM-API-Contact-Details_ to a person in _HelloID_.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value                             |
    | ------------------------- | --------------------------------- |
    | Enable correlation        | `True`                            |
    | Person correlation field  | `PersonContext.Person.ExternalId` |
    | Account correlation field | ``                                |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

#### Field mapping

The field mapping can be imported by using the [_fieldMapping.json_](./fieldMapping.json) file.

> [!NOTE]
phoneNumber is not added to the _fieldMapping.json_ because it is realy used in combination with HelloID Provisioning.

### Connection settings

The following settings are required to connect to the API.

| Setting        | Description                                                                                                                                                      | Mandatory |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| Client ID      | The Client ID to connect with the IAM API (created when registering the App in in the Visma Developer portal).                                                   | Yes       |
| Client Secret  | The Client Secret to connect with the IAM API (created when registering the App in in the Visma Developer portal).                                               | Yes       |
| Tenant ID      | The Tenant ID to specify to which Raet tenant to connect with the IAM API (available in the Visma Developer portal after the invitation code has been accepted). | Yes       |
| UpdateOnUpdate | If you also want to update the user on a update account                                                                                                          |           |

### Prerequisites
- Authorized Visma Developers account in order to request and receive the API credentials in the [Visma Developer portal](https://oauth.developers.visma.com). Please follow the [Visma documentation on how to register the App and grant access to client data](https://community.visma.com/t5/Kennisbank-Youforce-API/Visma-Developer-portal-een-account-aanmaken-applicatie/ta-p/527059).
- ClientID, ClientSecret and tenantID to authenticate with the IAM API of Raet Beaufort. Please follow the [Visma documentation on how to register the App and grant access to client data](https://community.visma.com/t5/Kennisbank-Youforce-API/Visma-Developer-portal-een-account-aanmaken-applicatie/ta-p/527059).

### Remarks
- Currently, only the 'Business Email Address' and 'Business Phone Number' fields can be updated, no other fields are (currently) supported.
    > When the value in Raet Beaufort equals the value in HelloID, the action will be skipped (no update will take place).
- The endpoint operates asynchronously. The data is first stored and internally verified before being submitted to BO4. To track the processing in the API, a ticketId is returned. The ticket ID must be used to check the status of the API call. Within the API, various checks are performed. For example, it checks that the email address matches the format aaaa@bbbb.xxx. It also checks that the phone number does not contain alphanumeric values. However, it does support phone numbers like "035-1234567".

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
