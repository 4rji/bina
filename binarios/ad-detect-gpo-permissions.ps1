# POWERSHELL SCRIPT TO FIND DANGEROUS ACLS ON GPOS (ONLY FOR NON-ADMIN USERS)

Import-Module GroupPolicy
Import-Module ActiveDirectory

$GPOs = Get-GPO -All

# DEFINE ADMINISTRATIVE IDENTITIES TO IGNORE
$IgnoreList = @(
    "NT AUTHORITY\SYSTEM",
    "CREATOR OWNER",
    "4RJI-MEX1\DOMAIN ADMINS",            # <--- MAYÚSCULAS EN DOMINIO/GRUPO
    "4RJI-MEX1\ENTERPRISE ADMINS",         # <--- MAYÚSCULAS EN DOMINIO/GRUPO
    "AUTHENTICATED USERS", 
    "EVERYONE"
)

foreach ($gpo in $GPOs) {
    $GPOName = $gpo.DisplayName       # <--- CAMBIA $gpoName ➔ $GPOName
    $GPOID = $gpo.Id                  # <--- CAMBIA $gpoID ➔ $GPOID
    $GPODN = "CN={$GPOID},CN=Policies,CN=System,DC=4RJI,DC=LOCAL"  # <--- MAYÚSCULAS EN DC

    # GET ACL PROPERLY
    $GPOObject = Get-ADObject -Identity $GPODN -Properties ntSecurityDescriptor
    $ACL = $GPOObject.ntSecurityDescriptor   # <--- CAMBIA $acl ➔ $ACL

    foreach ($ACE in $ACL.Access) {          # <--- CAMBIA $ace ➔ $ACE
        $Identity = $ACE.IdentityReference.ToString()
        
        if (($ACE.ActiveDirectoryRights -match "WriteDacl|WriteOwner") -and ($IgnoreList -notcontains $Identity)) {
            Write-Host "`n[!] POTENTIAL DANGEROUS ACE FOUND:" -ForegroundColor Red
            Write-Host "GPO NAME: $GPOName"
            Write-Host "IDENTITY: $Identity"
            Write-Host "RIGHTS: $($ACE.ActiveDirectoryRights)"
            Write-Host "ACCESS TYPE: $($ACE.AccessControlType)"
        }
    }
}
