##BEIR
#Barely Enough Inventory Report
#Author: Sam Anderson
#Date 10 April 2022
#Tested on PSVersion 5.1

#Summary:
#
#Outpouts an html report of the subnet(s) the host is connected to. 
#This program only does Reverse lookups of IPAddress.
#BEIR Has 3 Outputs.
#1) WHen this script is run, if a baseline file does not exist, it will be written to the current working directory
#2) When this script is run, an HTML report (report.html) will be written to the current working directory
#3) If enabled in the control vars, an Email will be sent to the recipent defined in the control vars.


###Control Vars
#[string]ifFilter, the string to filter by. Change to your needs
#[bool]quick: change to toggle quick or long lookup 
#[string]delim: set csv delimiter. default is ','
#[bool]verbose: outputs the script status during execution

###Email
#[bool] mailOn If true, will send an email to the defined recipient
#[string] dest  To: in the email field
#[string] source From : email fielf
#[string] SMTPServer : SMPTServer to use

$ifFilter = "vmware*"
$quick = 0
$delim = ","
$verbose = 1

$mailOn = 0
$dest = "samthebadmin@nobody.local"
$source = "beir@nobody.local"
$SMTPServer = "mail.nobody.local:25"

#####Script Body#####
#var init
$baseline = @{}
$Hosts = @{}

#find and filter connected interfaces
$IPAddr = @(Get-NetIPAddress -Type Unicast -AddressFamily IPv4 -PrefixOrigin Dhcp, Manual | Where-Object {$_.InterfaceAlias -inotlike $ifFilter} | Select -Property IPAddress, PrefixLength)

#remove last octect of ip address in interfaces
ForEach ($Addr in $IPAddr) {$Addr.IPAddress = $Addr.IPAddress.split(".")[0..2] -join "." | %{$_ + "."}}

# Do Reverse-DNS lookup of network range. This can be very slow. quicktimeout may not use mDNS
ForEach ($Addr in $IPAddr) 
{
    ForEach ($o in 1..254)
    {
        $ip = $Addr.IPAddress +$o
        if ($verbose)
        {
            Write-Host "Doing Reverse-lookup of $ip"
        }
        
        $h = Resolve-DnsName $ip -QuickTimeout $quick -ErrorAction SilentlyContinue | select -Property NameHost
        
        if ($h -eq $null)
            {$Hosts.Add($ip, "N/A")}
        else
            {$Hosts.Add($ip,  $h.NameHost)}
        
    }
}

#Write the baseline.csv if it does not exist. Otherwise, attempt to load the CSV and transpose
#the  resulting PSobject itno into a hashtable.
if (Test-Path -Path .\baseline.csv -PathType Leaf)
{
    $header = 'IPAddress','HostName'
    $csv = Import-Csv -Delimiter $delim -Path .\baseline.csv -Header $header
    $csv | %{$baseline[$_.IPAddress] = $_.HostName}
}
else
{
    $Hosts.GetEnumerator() | Select -Property Key,Value | Export-Csv -NoTypeInformation -Path "./baseline.csv" -Delimiter $delim 
}

######REPORT########
#generate report rows, and identify differences with baseline

$rows = ""
ForEach ($item in $Hosts.Keys)
{
    $res = $Hosts[$item] 
    $rows+=@"
    `n<tr>`n<td> $item </td>`n<td style="text-align: center;"> $res </td>
"@
    if ($res -iin $baseline.Values)
    {
        $rows+="`n<td></td>"
    }
    else
    {
        $rows+="`n<td Style=`"color:red;`">ANOMALY!</td>"
    }

    $rows+="`n</tr>"
}

#HTML Header Template
 $RHead= @"
 <!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Document</title>
</head>
<body>
    <h3>Inventory Report</h3>
    <table>
        <tr>
            <th>IPaddress</th>
            <th>HostName</th>
            <th>Note</th>
        </tr>
"@

#HTML Footer Template
$RFoot=@"
    </table>
    
</body>
</html>
"@

#concaonte Header Rows and Footer
$Report = $RHead + $rows + $RFoot

#Write Report
Out-File -FilePath ./report.html -InputObject $Report

#Send Email of report if enabled
if ($mailOn) 
{
    Send-MailMessage -From $source -To $dest -SmtpServer $SMTPServer  `
    -Subject "BEIR Inventory Report" -Body "Please see attached report" `
    -Attachments "report.html"
}