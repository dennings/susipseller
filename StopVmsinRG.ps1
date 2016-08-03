workflow StopVmsinRG
{
	Param(
	  	[string]$ResourceGroupName = 'DEMO2',
		#The name of the Automation Credential Asset this runbook will use to authenticate to Azure.
		[string]$AzureRunAsConnection = 'AzureRunAsConnection'
 	)

	$Conn = Get-AutomationConnection -Name $AzureRunAsConnection 
    if(!$Conn) {
        Throw "Could not find an Automation Connection Asset named '${AzureRunAsConnection}'. Make sure you have created one in this Automation Account."
    }
 	Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
	
    #TODO (optional): pick the right subscription to use. Without this line, the default subscription for your Azure Account will be used.
    #Select-AzureSubscription -SubscriptionName "TODO: your Azure subscription name here"
	
    $VMs = Get-AzureRmResourceGroup | ? { $_.ResourceGroupName -like $ResourceGroupName } | Get-AzureRmVM 
		
	$Sendnotification = 0
    #Print out up to 10 of those VMs
    if (!$VMs) {
        Write-Output "No VMs were found in your subscription."
    } else {
		Foreach -parallel ($VM in $VMs) {
			$status = Get-AzureRmVM -Status -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
			if ( ($status.Statuses | ? { $_.Code -eq 'PowerState/running' }).Count -gt 0) {
    			# VM is running, so turn it off
		        Write-Output "Stopping " + $VM.Name
			    $VM | Stop-AzureRmVM -Force -ErrorAction SilentlyContinue
		        Write-Output "Stopped " + $VM.Name
				$WORKFLOW:Sendnotification = 1
			} else {
				# 				
				Write-Output "was already Stopped! -> " + $VM.Name
			}
		}
    }
    Write-Output "DONE."

	if ($sendnotification -eq 1) {
		# TODO put the AuthKey in KeyVault
		$pushKey = Get-AutomationVariable -Name 'PushALotAuthKey'
		$Body = '{
	    	"AuthorizationToken": "'+$pushKey+'",
	    	"Title": "StopVMs '+$ResourceGroupName+'",
	    	"IsImportant": "True",
	    	"Body": "Stop VMs in ResourceGroupName matching '+$ResourceGroupName+'",
			"Source": "AzureAutom StopVmsinRG",
			"TimeToLive": "200"
		}'
		# do not send Important Messages on Weekends ;)
		if ( ((get-date).DayOfWeek.value__ -eq 6) -or ((get-date).DayOfWeek.value__ -eq 7) ) {  $Body = $Body.Replace('"IsImportant": "True"', '"IsImportant": "False"') }
		Invoke-RestMethod -Method Post -Uri https://pushalot.com/api/sendmessage -ContentType 'application/json' -Body $Body
		Write-Output "Notification DONE."
	} else {
		Write-Output "nothing to notify."
	}
}

# eof