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
		
    #Print out up to 10 of those VMs
    if (!$VMs) {
        Write-Output "No VMs were found in your subscription."
    } else {
		Foreach -parallel ($VM in $VMs) {
	        Write-Output "Stopping " + $VM.Name
		    $VM | Stop-AzureRmVM -Force -ErrorAction SilentlyContinue
	        Write-Output "Stopped " + $VM.Name
		}
    }
    Write-Output "DONE."

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
}