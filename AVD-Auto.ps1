param($Timer)

#Define Session Pool, RG, domain suffix and number of always on hosts
$hpn = "VD-Pool"
$rg = "VD"
$dom = ".VDI.lab"
$AlOnWeekday = "1"
$AlOnWeekend = "0"

#Define Work Hours
$StartHour = "8"
$StopHour = "16"

#Convert Azure Time to Local time
$tempDate =(Get-Date).ToUniversalTime()
$tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("GMT Standard Time")
$CurrentTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($tempDate, $tz)
$Now = (Get-Date -Date $CurrentTime).Hour

$timeout = "The current hour is: " + $Now
write-output $timeout

##Prep workday variables 
$Today = (get-date).dayofweek
$dayout = "The current day is: " + $Today
write-output $dayout

#Define workdays
switch ((get-date).dayofweek.toString())
{
    Monday {$working = '1';break}
    Tuesday {$working = '1';break}
    Wednesday {$working = '1';break}
    Thursday {$working = '1';break}
    Friday {$working = '1';break}
    Saturday {$working = '0';break}
    Sunday {$working = '0';break}
}
if($working -eq '1')
{
    $AlOn = $AlOnWeekday
}
if($working -eq '0')
{
    $AlOn = $AlOnWeekday
}

$wdayout = "Working today, (1=Yes O=No): " + $working
write-output $wdayout

##Get Session Hosts
$SessionHosts = Get-AzWVDSessionHost -HostPoolName $hpn -ResourceGroupName $rg
write-output "hosts are:"
foreach ($SessionHost in $SessionHosts)
{
    write-output $SessionHost.Name
}

##Shutdown session hosts if it is before opening, after closing, the weekend and the host has no users connected, excluded a number of always on hosts 
if(($Now -lt $StartHour -or $Now -ge $StopHour) -or $working -ne '1')
{
    $Status = "It is currently outside working hours"
    write-output $Status

    $Skip = "Skipping first " + $AlOn + " hosts"
    write-output $Skip

    foreach ($SessionHost in ($SessionHosts | select -skip $AlOn))
    {  
    ##Convert VDHost name to VM name 
        $SessionHostName1 = $SessionHost.Name -Replace($hpn,"")
        $SessionHostName = $SessionHostName1 -Replace("/","")
        $SHVMN = $SessionHostName -Replace($dom,"")
     
    ##Get Sessions on host & VM Status
        $shsessions = (Get-AzWvdUserSession -ResourceGroupName $rg -HostPoolName $hpn -SessionHostname $SessionHostName).count
        $SHVMStatus = (Get-AzVM -ResourceGroupName $rg -Name $SHVMN -Status).Statuses[1].DisplayStatus

    ##Output host status
        $Out = "Host " + $SessionHostName + " currently has " + $shsessions + " sessions and it's status is " + $SHVMStatus
        write-output $Out

    ##Shutdown running VMs with no sessions and turn off drain mode
        if($shsessions -eq 0 -And $SHVMStatus -eq "VM running")
	    {
        	write-output "Shutting down host"
    	    Stop-AzVM -Id $SessionHost.ResourceId -Force
        ##Uncomment if using the drain mode setting below
        # write-output "Turning off drain mode"
				# Update-AzWvdSessionHost -ResourceGroupName $rg -HostPoolName $hpn -Name $SessionHostName -AllowNewSession:$True
            
	    }
    ##Uncomment to set drainmode on machines that are running VMs with connected sessions
        if($shsessions -ne 0 -And $SHVMStatus -eq "VM running")
        {   
             
            if($working -ne 1)
            {
            #    write-output "Turning on drain mode"
            #    Update-AzWvdSessionHost -ResourceGroupName $rg -HostPoolName $hpn -name $SessionHostName -AllowNewSession:$False
            }
        }
    }
}

##First check if the company is open
if($working -eq '1')
{
    ##Start machines that are not running if it is during work hours 
    if($Now -ge $StartHour -And $Now -lt $StopHour)
    {
       foreach ($SessionHost in $SessionHosts)
        {  
        ##Convert VDHost name to VM name 
            $SessionHostName1 = $SessionHost.Name -Replace($hpn,"")
            $SessionHostName = $SessionHostName1 -Replace("/","")
            $SHVMN = $SessionHostName -Replace($dom,"")
     
        ##Get Sessions on host & VM Status
            $shsessions = (Get-AzWvdUserSession -ResourceGroupName $rg -HostPoolName $hpn -SessionHostname $SessionHostName).count
            $SHVMStatus = (Get-AzVM -ResourceGroupName $rg -Name $SHVMN -Status).Statuses[1].DisplayStatus

            $Out = "Host " + $SessionHostName + " currently has " + $shsessions + " sessions and it's status is " + $SHVMStatus
            write-output $Out

        ##Starting VMs and turn off drain mode
            if($SHVMStatus -ne "VM running")
	        {
                write-output "Starting session host"
    	        Start-AzVM -Id $SessionHost.ResourceId
	        }
        }
    }
}
