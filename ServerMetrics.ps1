$MyHost = $env:COMPUTERNAME

Import-Module  "C:\Program Files\WindowsPowerShell\Modules\Influx\1.0.102\Influx.psd1"

$username = "Monitoring" #Username berechtigt in InfluxDB
$password = "Monitoring" #Password berechtigt in InfluxDB
$Datenbank = "Leistung" #InfluxDB Datenbank in InfluxDB Instanz
$InfluxDBServer = "http://ServernameOderIP:8086"
    
$PWSecure = ConvertTo-SecureString -String $password -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential($username,$PWSecure) 


Function Get-CPU()
{
    # Für jeden Prozessor die Auslastung
    $Prozessor = Get-CimInstance -Class CIM_Processor -ErrorAction Stop | select *
    $metric=@{"CPULoadPercentage"=$Prozessor.LoadPercentage
    "CPUCurrentClockSpeed"=$Prozessor.CurrentClockSpeed;
    "CPUMaxClockSpeed"=$Prozessor.MaxClockSpeed;
    "CPUNumberOfLogicalProcessors"=$Prozessor.NumberOfLogicalProcessors;
    "CPUCurrentVoltage"=$Prozessor.CurrentVoltage}
    influx-DB-Schreiben -metrics $metric
    
}

Function Get-RAM()
{
    # Verfügbarer Arbeitsspeicher
    $freeBytes = Get-CIMInstance Win32_OperatingSystem | Select FreePhysicalMemory
    foreach ($x in $freeBytes.CounterSamples)
    {
        $metric=@{"freebyte"=$freebyte = $x.CookedValue}
    }
    
    #Gesamter Arbeitsspeicher
    $totalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum
    $metric+=@{"totalRAM"=$totalRAM}
    influx-DB-Schreiben -metrics $metric
    
}

Function Get-Uptime()
{
    $bootTime = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $machine.computer | Select-Object -ExpandProperty LastBootupTime
    $upTime = New-TimeSpan -Start $bootTime
    $upMinutes = [int]$upTime.TotalMinutes
    $metric = @{"UptimeInMinutes"=$upMinutes}
    influx-DB-Schreiben -metrics $metric
}

Function Get-DISK()
{
    #Unbekannt (0)
    #Kein Stammverzeichnis (1)
    #Wechseldatenträger (2)
    #Lokaler Datenträger (3)
    #Netzlaufwerk (4)
    #Cd ( 5)
    #RAM-Datenträger (6)

    $Disks = Get-WmiObject Win32_logicaldisk | select *
    foreach($Disk in $Disks)
    {
        if($Disk.DriveType -eq 3)
        {
            $Laufwerk = $Disk.DeviceID
            $FreeSpace = $Disk.FreeSpace
            $DiskSize = $Disk.Size
            $UsedDiskSize = $DiskSize - $FreeSpace
            $DiskLabel = $Disk.VolumeName

            write-host "####################" -ForegroundColor Green
            $metric = @{"Disklabel"=$DiskLabel;
            "Laufwerk"=$Laufwerk;
            "FreeSpaceBytes"=$FreeSpace;
            "DiskSizeBytes"=$DiskSize;
            "UsedDiskSizeBytes"=$UsedDiskSize}
            influx-DB-Schreiben -metrics $metric
        }
    }
}

Function Get-ServiceNotRunning()
{
    $ServicesNotRunning = Get-Service | select * | where {$_.StartType -eq "Automatic"} | where Status -NE Running
    $metric = @{"ServiceCountNotRunning" = $ServicesNotRunning.count}
    influx-DB-Schreiben -metrics $metric
}

function influx-DB-Schreiben($metrics)
{
    Write-Influx -Measure $MyHost -Metrics $metrics -Database $Datenbank -Server $InfluxDBServer -Credential $Cred -Verbose
}

Get-DISK
Get-ServiceNotRunning
Get-Uptime
Get-RAM
Get-CPU