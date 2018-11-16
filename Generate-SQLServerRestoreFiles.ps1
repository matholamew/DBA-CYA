#Import dbatools module.
Import-Module dbatools;

#Variables.
[string]$SQLInstance = "WINSYS1612DEV\INST1";
[string]$Database = "DBManagement";
[string]$Environment = "Demo";

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null

function Generate-Files {
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
        #Connect
        $srvConn = New-Object "Microsoft.SqlServer.Management.Smo.Server" $srv;
        Write-Output $srvConn.Name
        
        #Databases
            $srvConn.Databases | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-Databases.txt");
        #BackupDevices
            $srvConn.BackupDevices | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-BackupDevices.txt");
        #Triggers
            $srvConn.Triggers | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-Triggers.txt");
        #SqlAgents
            $srvConn.JobServer | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-SqlAgentScript.txt");
        #Jobs
            $srvConn.JobServer.Jobs | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-Jobs.txt");
        #LinkedServers
            $srvConn.LinkedServers | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-LinkedServers.txt");
        #Logins
            Export-DbaLogin -SqlServer $srvConn -FileName ($directoryname + $serverfilename + "-Logins.txt") | Out-Null;
        #Roles --Note: If major SQL version is not 10 (SQL2008 and SQL2008R2) then do the first.
            If ($srvConn.Version.Major -ne 10) {$srvConn.Roles | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-Roles.txt")}
            #If it is SQL2008 or SQL2008R2, do the else.
            Else {$srvRoles = @($srvConn.Roles | Select-Object -ExpandProperty name)
                ForEach ($role in $srvRoles){ $output += "CREATE SERVER ROLE [$role]`r`nGO`r`n" }
            $output | Out-File $($directoryname + $serverfilename + "-Roles.txt")};
        #Alerts
            $srvConn.JobServer.Alerts | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-Alerts.txt");
        #Operators
            $srvConn.JobServer.Operators | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-Operators.txt");
        #SysConfigurations
            Invoke-SqlCmd -query "SELECT * FROM sys.configurations" -ServerInstance $srv | Export-CSV -Path "$directoryname$serverfilename-SysConfigurations.csv" -NoTypeInformation;
        #DBMail
            $MailOutput = $srvConn.Mail.Script();
            $MailOutput += ForEach ($account in $srvConn.Mail.Accounts) {
	            $AccountName = $account.Name
	            $MailServerName = $account.MailServers[0].Name;
	            $MailServerPort = $account.MailServers[0].Port;
	            "EXEC msdb.dbo.sysmail_update_account_sp @account_name = N'$AccountName',";
		            "	@mailserver_name = N'$MailServerName',";
		            "	@port = N'$MailServerPort'";
                }
            #Output
            $MailOutput | Out-File $($directoryname + $serverfilename + "-DBMail.txt");
        #DrivesAndSizes
            #Get-WMIObject -query "select * from Win32_Volume where DriveType=3 and not name like '%?%'" -computername $srvConn `
                 #Select Name, Label, DriveLetter, @{Name="Capacity(GB)";Expression={[decimal]("{0:N0}" -f($_.Capacity/1GB))}} | Export-CSV -notype ($directoryname + $serverfilename + "-Drives.csv");
        #Endpoints
            #$srvConn.EndPoints | ForEach {$_.Script()+ "GO"} | Out-File $($directoryname + $serverfilename + "-EndPoints.txt");
        #ErrorLogs
            # $srvConn.ReadErrorLog() | export-csv -path $($directoryname + "-Box_ErrorLogs.csv") -noType;

        #Disconnect
        $srvConn.ConnectionContext.Disconnect();
}



$connection = new-object system.data.sqlclient.sqlconnection( `
    "Data Source=$SQLInstance;Initial Catalog=$Database;Trusted_Connection=true;");
$connection.Open()
$cmd = $connection.CreateCommand()
#$null = $cmd.ExecuteNonQuery()

##### Get the list of servers to inventory #####
$query = "SELECT DISTINCT ServerName, ServerNameShort
            FROM Inventory.Servers WHERE Environment IN ('$Environment')"
$cmd.CommandText = $query
$reader = $cmd.ExecuteReader()
 
##### For every server gather data #####
While($reader.Read()) {
 
    ##### See if the server is alive #####
    $srv = $reader['ServerName']
    $srvShort = $reader['ServerNameShort']
    $result = Get-WMIObject -query "select StatusCode from Win32_PingStatus where Address = '$srvShort'"
       $responds = $false
    If ($result.statuscode -eq 0)
    {
        $responds = $true
    }
 
    ##### If it is alive ... #####
    If ($responds) {
        
        If (!(Test-Path -path (".\Backup\" + $srvShort + "\RestoreFiles\"))) {New-Item (".\Backup\" + $srvShort + "\") -type directory}

        $directoryname = "C:\Users\Administrator\Google Drive\Demo\CYA\Backup\" + $srvShort + "\RestoreFiles\"
        $serverfilename = $srvShort
        
        #Run function
        Generate-Files
    }
    Else
    { 
              # Let the user know we couldn't connect to the server
              Write-Output "$srv does not respond"
    }
 
}