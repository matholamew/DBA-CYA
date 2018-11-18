# DBA-CYA

As a DBA you are responsible for much more than simply backup and recovery of databases. This script will backup some SQL Server objects. This function exports the files for a SQL Server restore including Databases, Backup Devices, Triggers, SQL Agent, Jobs, Linked Servers, Logins, Roles, Alerts, Operators, and DB Mail settings. with PowerShell to a chosen directory. Will overwrite the previous files.

## Getting Started

Clone or download the repo

### Prerequisites

* [dbatools](https://dbatools.io/)

### Examples

Export-SqlRestoreFile -Server Server1\Inst1 -OutputDirectory "D:\DbBackups\"
Export-SqlRestoreFile -Server Server1\Inst1,Server2/Inst1 -OutputDirectory "D:\DbBackups\"