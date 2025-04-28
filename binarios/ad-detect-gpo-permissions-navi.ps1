# PowerShell script to find dangerous ACLs on GPOs (only for non-admin users)

Import-Module GroupPolicy
Import-Module ActiveDirectory

$GPOs = Get-GPO -All

# Define administrative identities to ignore
$IgnoreList = @(
    "NT AUTHORITY\SYSTEM",
    "CREATOR OWNER",
    "4RJI-Mex1\Domain Admins",
    "4RJI-Mex1\Enterprise Admins",
    "Authenticated Users", 
    "Everyone"
)

foreach ($gpo in $GPOs) {
    $gpoName = $gpo.DisplayName
    $gpoID = $gpo.Id
    $gpoDN = "CN={$gpoID},CN=Policies,CN=System,DC=4rji,DC=local"

    # Get ACL properly
    $gpoObject = Get-ADObject -Identity $gpoDN -Properties ntSecurityDescriptor
    $acl = $gpoObject.ntSecurityDescriptor

    foreach ($ace in $acl.Access) {
        $identity = $ace.IdentityReference.ToString()
        
        if (($ace.ActiveDirectoryRights -match "WriteDacl|WriteOwner") -and ($IgnoreList -notcontains $identity)) {
            Write-Host "`n[!] Potential Dangerous ACE Found:" -ForegroundColor Red
            Write-Host "GPO Name: $gpoName"
            Write-Host "Identity: $identity"
            Write-Host "Rights: $($ace.ActiveDirectoryRights)"
            Write-Host "Access Type: $($ace.AccessControlType)"
        }
    }
}