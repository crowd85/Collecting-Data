Import-Module  "C:\Program Files\WindowsPowerShell\Modules\Influx\1.0.102\Influx.psd1"

$username = "Monitoring" #Username berechtigt in InfluxDB
$password = "Monitoring" #Password berechtigt in InfluxDB
$Datenbank = "Wasserstand" #InfluxDB Datenbank in InfluxDB Instanz
$InfluxDBServer = "http://ServernameOderIP:8086"

$PWSecure = ConvertTo-SecureString -String $password -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential($username,$PWSecure) 

$ResponseWasserpegel = Invoke-WebRequest "https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations.json?includeTimeseries=true&includeCurrentMeasurement=true"
((Get-Date).ToString() + " | Führe Luftquali aus") | Out-File b:\scripte\Wasser.log -Encoding utf8 -Append
((Get-Date).ToString() + " | Status-Return API: " + ($ResponseWasserpegel.statuscode) ) | Out-File b:\scripte\Wasser.log -Encoding utf8 -Append
if ($ResponseWasserpegel.statuscode -eq '200') 
{
    $Wasserpegel = ConvertFrom-Json $ResponseWasserpegel.Content #| Select-Object -expand "timeseries"

    foreach ($Pegel in $Wasserpegel)
    {
        #Write-Host ""
        #Write-Host "###############################################" -ForegroundColor Red
        $metrics = @{
        "UUID"=$Pegel.uuid
        ;"shortname"=$Pegel.shortname
        ;"WasserShortname"=$Pegel.water.shortname
        }
    
        foreach($x in $Pegel.timeseries)
        {
            #$x.longname
            #$x.currentMeasurement.value
            $metrics += @{$x.longname = $x.currentMeasurement.value}
        }
        #$Pegel.timeseries
        #Write-Host "ende timeseries" -ForegroundColor Red
        #Write-Host "###############################################" -ForegroundColor Red
    
    
        # Schreibe alles in die Datenbank
        Write-Influx -Measure $Pegel.shortname -Metrics $metrics -Database $Datenbank -Server $InfluxDBServer -Credential $Cred -Verbose
    }
}