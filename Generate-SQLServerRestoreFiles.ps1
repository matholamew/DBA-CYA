function Export-SqlRestoreFile {
    <#
    .SYNOPSIS
        Exports files for SQL Server restore.
    .DESCRIPTION
        Exports the files for a SQL Server restore including Databases, Backup Devices
            , Triggers, SQL Agent, Jobs, Linked Servers, Logins, Roles, Alerts, Operators
            , and DB Mail settings.

        Requires dbatools.
    .EXAMPLE
        Export-SqlRestoreFile -Server Server1\Inst1 -OutputDirectory "D:\DbBackups\"
        Export-SqlRestoreFile -Server Server1\Inst1,Server2\Inst1 -OutputDirectory "D:\DbBackups\"
    #>
    
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
            [string[]]$Server,
        [Parameter(Mandatory = $true, Position = 1)]
            [string]$OutputDirectory
    )

    Begin {
        #Import dbatools module.
        Import-Module dbatools;
        #Load SMO.
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
    }

    Process {
        Try {
            ForEach ($ServerInstance in $Server) {
                #Remove \inst from server name.
                If ($ServerInstance.Contains(“\”)) {$ServerShort = $ServerInstance.Split("\")[0]};
            
                #Connect to server.
                $srvConn = New-Object "Microsoft.SqlServer.Management.Smo.Server" $ServerInstance;
                Write-Output $srvConn.Name
            
                #Create backup directory if it does not exist.
                $FullPath = ($OutputDirectory + "\" + $ServerShort + "\")
                $FileName = ($FullPath + $ServerShort)
                If (!(Test-Path -Path $FullPath)) {New-Item $FullPath -ItemType Directory -Force}
        
                #Databases
                    $srvConn.Databases | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-Databases.txt");
                #BackupDevices
                    $srvConn.BackupDevices | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-BackupDevices.txt");
                #Triggers
                    $srvConn.Triggers | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-Triggers.txt");
                #SqlAgents
                    $srvConn.JobServer | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-SqlAgentScript.txt");
                #Jobs
                    $srvConn.JobServer.Jobs | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-Jobs.txt");
                #LinkedServers
                    $srvConn.LinkedServers | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-LinkedServers.txt");
                #Logins
                    Export-DbaLogin -SqlServer $srvConn -FileName ($FileName + "-Logins.txt") | Out-Null;
                #Roles --Note: If major SQL version is not 10 (SQL2008 and SQL2008R2) then do the first.
                    If ($srvConn.Version.Major -ne 10) {$srvConn.Roles | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-Roles.txt")}
                    #If it is SQL2008 or SQL2008R2, do the else.
                    Else {$srvRoles = @($srvConn.Roles | Select-Object -ExpandProperty name)
                        ForEach ($role in $srvRoles){ $Output += "CREATE SERVER ROLE [$role]`r`nGO`r`n" }
                    $Output | Out-File $($FileName + "-Roles.txt")};
                #Alerts
                    $srvConn.JobServer.Alerts | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-Alerts.txt");
                #Operators
                    $srvConn.JobServer.Operators | ForEach-Object {$_.Script()+ "GO"} | Out-File $($FileName + "-Operators.txt");
                #SysConfigurations
                    Invoke-SqlCmd -query "SELECT * FROM sys.configurations" -ServerInstance $ServerInstance | Export-CSV -Path "$FileName-SysConfigurations.csv" -NoTypeInformation;
                #DBMail
                    $MailOutput = $srvConn.Mail.Script();
                    $MailOutput += ForEach ($account in $srvConn.Mail.Accounts){
                        $AccountName = $account.Name
                        $MailServerName = $account.MailServers[0].Name;
                        $MailServerPort = $account.MailServers[0].Port;
                        "EXEC msdb.dbo.sysmail_update_account_sp @account_name = N'$AccountName',";
                            "	@mailserver_name = N'$MailServerName',";
                            "	@port = N'$MailServerPort'";
                    }
                    #Output for DB Mail.
                    $MailOutput | Out-File $($FileName + "-DBMail.txt");
            
                #Disconnect
                $srvConn.ConnectionContext.Disconnect();
            }
        }
        Catch {
            $_
        }
    }

    End {
        #Nothing to do here.
    }
}