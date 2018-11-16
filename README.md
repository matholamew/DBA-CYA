# DBA-CYA

As a DBA you are responsible for much more than simply backup and recovery of databases. This script will backup some SQL Server objects like Alerts, DBMail, LinkedServers, SQL Agent properties, and others with PowerShell to a chosen directory. WIll overwrite the previous files.

## Getting Started

Clone or download the repo

### Prerequisites

* [dbatools](https://dbatools.io/)

### Installing

Schedule the .ps1 to run. Change the 'SQLInstance', 'Database', and 'Environment' variables. You also need to change the 'directoryname' variable toward the bottom of the script.