#This is lazywinadmin original script and base added on sjdomain.exe
# links to script : https://github.com/lazywinadmin/PowerShell/blob/master/AD-COMPUTER-New-ADDomainJoin/djoin_2012.cs

function New-ADDomainJoin {
    <#
.Synopsis
    Perform offline domain join in c#/PowerShell without djoin.exe
.Description
    Perform offline domain join in c#/PowerShell without djoin.exe
    This will create an object in active directory and output the blob needed to join the machine offline

    If needed, you can use the function New-DjoinFile to recreate the file consumed by djoin.exe
    https://github.com/lazywinadmin/PowerShell/tree/master/TOOL-New-DjoinFile
.Parameter machinename
    Specify the machinename
.Parameter domain
    Specify the domain name
.Parameter credential
    Specify credential
.Parameter machineaccountou
    Specify the organizational unit in Active Directory where the machine account should be placed.
.Parameter dcname
    Specify the Domain Controller
.Example
    $MyAccount = 'MyDomain\MyAccount'
    $Passw = ConvertTo-SecureString -String '<SecretPassword>' -AsplainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($MyAccount,$Passw)

    $Splatting = @{
        domain = 'mydomain.com'
        machinename = 'testmachine'
        machineaccountou = 'OU=test,DC=mydomain,DC=com'
        dcname = 'dc01.mydomain.com'
    }

    New-ADDomainJoin -Credential $credential @splatting

.Notes
    Version History
        1.0 | 2019/01/08 | Francois-Xavier Cat
            Initial version based on 'WinPENanoDomainJoin' https://gist.github.com/Ryan2065/79838b78643d2311d60cb6147e3b87bf
    Documentations
        Window  7/ Windows 2008 function https://docs.microsoft.com/en-us/windows/desktop/api/lmjoin/nf-lmjoin-netprovisioncomputeraccount
        Windows 8. / 2012 function https://docs.microsoft.com/en-us/windows/desktop/api/lmjoin/nf-lmjoin-netcreateprovisioningpackage
        Offline Domain Join documentation 2008 https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd392267(v=ws.10)

    Todo
        Add support for non dc specified
        Add support for non credential specified
.link
    https://github.com/lazywinadmin/PowerShell
#>
    [CmdletBinding()]
    PARAM(
        [Parameter(Mandatory = $true)]
        $machinename,

        [Parameter(Mandatory = $true)]
        $domain,

        [Alias("RunAs")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        $machineaccountou = $null,

        $dcname
    )
    Try {
        $FunctionName = (Get-Variable -Name MyInvocation -Scope 0 -ValueOnly).MyCommand

        # Detect OS
        $OSVersion = [Environment]::OSVersion
        $OSVersionMajorMinor = "$($OSVersion.version.major).$($OSVersion.version.minor)"
        Write-Verbose -Message "[$FunctionName] OS detected - $OSVersionMajorMinor"
        if ($OSVersionMajorMinor -lt 6.2) { $CodeToUse = 'W2008' }
        else { $CodeToUse = 'W2012' }

        # W2008
        Write-Verbose -Message "[$FunctionName] Declare code for Windows Server 2008/Windows 7"
        $source2008 = @'
    using System;
    using System.Security.Principal;
    using System.Runtime.InteropServices;

    namespace Djoin
    {
        public class Kernel32
        {
            [DllImport("Kernel32.dll", SetLastError = true)]
            public static extern int GetLastError();
            [DllImport("Kernel32.dll", SetLastError = true)]
            public static extern void CloseHandle(IntPtr existingTokenHandle);
        }

        public class Netapi32
        {
            [DllImport("netapi32.dll", EntryPoint = "NetProvisionComputerAccount", SetLastError = true, ExactSpelling = true, CharSet = CharSet.Unicode)]
                public static extern int NetProvisionComputerAccount(
                    string lpDomain,
                    string lpMachineName,
                    string lpMachineAccountOU,
                    string lpDcName,
                    int dwOptions,
                    IntPtr pProvisionBinData,
                    IntPtr pdwProvisionBinDataSize,
                    [MarshalAs(UnmanagedType.LPWStr)]
                    out string pProvisionTextData);
        }

        public class AdvApi32
        {
            [DllImport("advapi32.DLL", SetLastError = true)]
            public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, out IntPtr phToken);
            [DllImport("advapi32.dll", SetLastError = true)]
            public extern static bool DuplicateToken(IntPtr ExistingTokenHandle, int SECURITY_IMPERSONATION_LEVEL, out IntPtr DuplicateTokenHandle);
            public enum LogonTypes
            {
                /// <summary>
                /// This logon type is intended for users who will be interactively using the computer, such as a user being logged on
                /// by a terminal server, remote shell, or similar process.
                /// This logon type has the additional expense of caching logon information for disconnected operations;
                /// therefore, it is inappropriate for some client/server applications,
                /// such as a mail server.
                /// </summary>
                LOGON32_LOGON_INTERACTIVE = 2,

                /// <summary>
                /// This logon type is intended for high performance servers to authenticate plaintext passwords.

                /// The LogonUser function does not cache credentials for this logon type.
                /// </summary>
                LOGON32_LOGON_NETWORK = 3,

                /// <summary>
                /// This logon type is intended for batch servers, where processes may be executing on behalf of a user without
                /// their direct intervention. This type is also for higher performance servers that process many plaintext
                /// authentication attempts at a time, such as mail or Web servers.
                /// The LogonUser function does not cache credentials for this logon type.
                /// </summary>
                LOGON32_LOGON_BATCH = 4,

                /// <summary>
                /// Indicates a service-type logon. The account provided must have the service privilege enabled.
                /// </summary>
                LOGON32_LOGON_SERVICE = 5,

                /// <summary>
                /// This logon type is for GINA DLLs that log on users who will be interactively using the computer.
                /// This logon type can generate a unique audit record that shows when the workstation was unlocked.
                /// </summary>
                LOGON32_LOGON_UNLOCK = 7,

                /// <summary>
                /// This logon type preserves the name and password in the authentication package, which allows the server to make
                /// connections to other network servers while impersonating the client. A server can accept plaintext credentials
                /// from a client, call LogonUser, verify that the user can access the system across the network, and still
                /// communicate with other servers.
                /// NOTE: Windows NT:  This value is not supported.
                /// </summary>
                LOGON32_LOGON_NETWORK_CLEARTEXT = 8,

                /// <summary>
                /// This logon type allows the caller to clone its current token and specify new credentials for outbound connections.
                /// The new logon session has the same local identifier but uses different credentials for other network connections.
                /// NOTE: This logon type is supported only by the LOGON32_PROVIDER_WINNT50 logon provider.
                /// NOTE: Windows NT:  This value is not supported.
                /// </summary>
                LOGON32_LOGON_NEW_CREDENTIALS = 9,
            }

            public enum LogonProvider
            {
                /// <summary>
                /// Use the standard logon provider for the system.
                /// The default security provider is negotiate, unless you pass NULL for the domain name and the user name
                /// is not in UPN format. In this case, the default provider is NTLM.
                /// NOTE: Windows 2000/NT:   The default security provider is NTLM.
                /// </summary>
                LOGON32_PROVIDER_DEFAULT = 0,
                LOGON32_PROVIDER_WINNT35 = 1,
                LOGON32_PROVIDER_WINNT40 = 2,
                LOGON32_PROVIDER_WINNT50 = 3
            }

            public enum SecurityImpersonationLevel : int
            {
                /// <summary>
                /// The server process cannot obtain identification information about the client,
                /// and it cannot impersonate the client. It is defined with no value given, and thus,
                /// by ANSI C rules, defaults to a value of zero.
                /// </summary>
                SecurityAnonymous = 0,

                /// <summary>
                /// The server process can obtain information about the client, such as security identifiers and privileges,
                /// but it cannot impersonate the client. This is useful for servers that export their own objects,
                /// for example, database products that export tables and views.
                /// Using the retrieved client-security information, the server can make access-validation decisions without
                /// being able to use other services that are using the client's security context.
                /// </summary>
                SecurityIdentification = 1,

                /// <summary>
                /// The server process can impersonate the client's security context on its local system.
                /// The server cannot impersonate the client on remote systems.
                /// </summary>
                SecurityImpersonation = 2,

                /// <summary>
                /// The server process can impersonate the client's security context on remote systems.
                /// NOTE: Windows NT:  This impersonation level is not supported.
                /// </summary>
                SecurityDelegation = 3,
            }

            [DllImport("advapi32.DLL")]
            public static extern bool ImpersonateLoggedOnUser(IntPtr hToken); //handle to token for logged-on user

            [DllImport("advapi32.DLL")]
            public static extern bool RevertToSelf();

            [DllImport("kernel32.dll")]
            public extern static bool CloseHandle(IntPtr hToken);

        }

        public class DomainJoin
        {
            public static int GetDomainJoin(string username,string password,string Domain,string Machine,string OU,string DC,out string DomainJoinBlob)
            {

                int Result = -1;

                //define the handles
                IntPtr existingTokenHandle = IntPtr.Zero;
                IntPtr duplicateTokenHandle = IntPtr.Zero;

                //split domain and name
                String[] splitUserName = username.Split('\\');
                string userdomain = splitUserName[0];
                username = splitUserName[1];

                try
                {
                    //get a security token
                    Console.WriteLine("Before Calling AdvApi32.LogonUser");

                    bool isOkay = AdvApi32.LogonUser(username, userdomain, password,
                        (int)AdvApi32.LogonTypes.LOGON32_LOGON_NEW_CREDENTIALS,
                        (int)AdvApi32.LogonProvider.LOGON32_PROVIDER_WINNT50,
                        out existingTokenHandle);

                    Console.WriteLine("After Calling AdvApi32.LogonUser");

                    if (!isOkay)
                    {
                        int lastWin32Error = Marshal.GetLastWin32Error();
                        int lastError = Kernel32.GetLastError();
                        throw new Exception("LogonUser Failed: " + lastWin32Error + " - " + lastError);
                    }

                    // copy the token
                    Console.WriteLine("Before Calling AdvApi32.DuplicateToken");

                    isOkay = AdvApi32.DuplicateToken(existingTokenHandle,
                        (int)AdvApi32.SecurityImpersonationLevel.SecurityImpersonation,
                        out duplicateTokenHandle);

                    //Console.WriteLine("After Calling AdvApi32.DuplicateToken");
                    if (!isOkay)
                    {
                        int lastWin32Error = Marshal.GetLastWin32Error();
                        int lastError = Kernel32.GetLastError();
                        Kernel32.CloseHandle(existingTokenHandle);
                        throw new Exception("DuplicateToken Failed: " + lastWin32Error + " - " + lastError);
                    }

                    // create an identity from the token
                    Console.WriteLine("Before Calling AdvApi32.ImpersonateLoggedOnUser(duplicateTokenHandle)");
                    AdvApi32.ImpersonateLoggedOnUser(duplicateTokenHandle);
                    Console.WriteLine("After Calling AdvApi32.ImpersonateLoggedOnUser(duplicateTokenHandle)");

                    String blob = String.Empty;

                    Console.WriteLine("Calling NetProvisionComputerAccount");

                    Result = Netapi32.NetProvisionComputerAccount(Domain,Machine,OU,DC,2,IntPtr.Zero,IntPtr.Zero,out blob);

                    DomainJoinBlob = blob;

                    Console.WriteLine("Domain Blob: {0}", blob);
                    Console.WriteLine("Before Calling RevertToSelf");

                    if(AdvApi32.RevertToSelf())
                    {
                        Console.WriteLine("RevertToSelf Succeeded");
                    }
                    else
                    {
                        Console.WriteLine("RevertToSelf Failed");
                    }
                }
                finally
                {
                    //free all handles
                    if (existingTokenHandle != IntPtr.Zero)
                    {
                        Kernel32.CloseHandle(existingTokenHandle);
                    }
                    if (duplicateTokenHandle != IntPtr.Zero)
                    {
                        Kernel32.CloseHandle(duplicateTokenHandle);
                    }
                }

                return Result;
            }

            static void Main(string[] args)
            {
                Console.WriteLine("MAIN CALLED");
                Console.ReadLine();
            }
        }
    }
'@

        # W2012
        Write-Verbose -Message "[$FunctionName] Declare code for Windows Server 2012/Windows 8"
        $source2012 = @'
using System;
using System.Security.Principal;
using System.Runtime.InteropServices;

namespace Djoin
{
    public class Kernel32
    {
        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern int GetLastError();
        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern void CloseHandle(IntPtr existingTokenHandle);

    }

    public class Netapi32
    {

        [System.Runtime.InteropServices.StructLayoutAttribute(System.Runtime.InteropServices.LayoutKind.Sequential)]
        public class NetsetupProvisoningParams

        {

            // Version 1 fields

            public uint dwVersion;

            [MarshalAs(UnmanagedType.LPWStr)]

            public string lpDomain;

            [MarshalAs(UnmanagedType.LPWStr)]

            public string lpHostName;

            [MarshalAs(UnmanagedType.LPWStr)]

            public string lpMachineAccountOU;

            [MarshalAs(UnmanagedType.LPWStr)]

            public string lpDcName;



            public uint dwProvisionOptions;



            //[MarshalAs(UnmanagedType.LPArray, ArraySubType=UnmanagedType.LPWStr, SizeParamIndex=7)]

            //public string[] aCertTemplateNames;

            public IntPtr aCertTemplateNames;  // hack until correct MarshalAs setting is figured out

            public uint cCertTemplateNames;



            //[MarshalAs(UnmanagedType.LPWStr)]

            //public string[] aMachinePolicyNames;

            public IntPtr aMachinePolicyNames;  // hack until correct MarshalAs setting is figured out

            public uint cMachinePolicyNames;



            //[MarshalAs(UnmanagedType.LPWStr)]

            //public string[] aMachinePolicyPaths;

            public IntPtr aMachinePolicyPaths;  // hack until correct MarshalAs setting is figured out

            public uint cMachinePolicyPaths;



            // Version 2 fields

            [MarshalAs(UnmanagedType.LPWStr)]

            public string lpNetbiosName;

            [MarshalAs(UnmanagedType.LPWStr)]

            public string lpSiteName;

            [MarshalAs(UnmanagedType.LPWStr)]

            public string lpPrimaryDNSDomain;

        }

        [DllImport("Netapi32.dll", EntryPoint = "NetCreateProvisioningPackage", SetLastError = true, ExactSpelling = true, CharSet = CharSet.Unicode)]

        public static extern int NetCreateProvisioningPackage  (

             NetsetupProvisoningParams pProvisioningParams,

             //[MarshalAs(UnmanagedType.LPArray, ArraySubType=UnmanagedType.U1, SizeParamIndex=2)]

             IntPtr ppPackageBinData,

             IntPtr pdwPackageBinDataSize,

             //[MarshalAs(UnmanagedType.LPWStr)]

             //working - IntPtr ppPackageText // should be out - not needed for now
             [MarshalAs(UnmanagedType.LPWStr)]
             out string ppPackageText // should be out - not needed for now
         );

            }

    public class AdvApi32
    {
        [DllImport("advapi32.DLL", SetLastError = true)]
        public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, out IntPtr phToken);

        [DllImport("advapi32.dll", SetLastError = true)]
        public extern static bool DuplicateToken(IntPtr ExistingTokenHandle, int SECURITY_IMPERSONATION_LEVEL, out IntPtr DuplicateTokenHandle);
        public enum LogonTypes
        {
            /// <summary>
            /// This logon type is intended for users who will be interactively using the computer, such as a user being logged on
            /// by a terminal server, remote shell, or similar process.
            /// This logon type has the additional expense of caching logon information for disconnected operations;
            /// therefore, it is inappropriate for some client/server applications,
            /// such as a mail server.
            /// </summary>
            LOGON32_LOGON_INTERACTIVE = 2,

            /// <summary>
            /// This logon type is intended for high performance servers to authenticate plaintext passwords.

            /// The LogonUser function does not cache credentials for this logon type.
            /// </summary>
            LOGON32_LOGON_NETWORK = 3,

            /// <summary>
            /// This logon type is intended for batch servers, where processes may be executing on behalf of a user without
            /// their direct intervention. This type is also for higher performance servers that process many plaintext
            /// authentication attempts at a time, such as mail or Web servers.
            /// The LogonUser function does not cache credentials for this logon type.
            /// </summary>
            LOGON32_LOGON_BATCH = 4,

            /// <summary>
            /// Indicates a service-type logon. The account provided must have the service privilege enabled.
            /// </summary>
            LOGON32_LOGON_SERVICE = 5,

            /// <summary>
            /// This logon type is for GINA DLLs that log on users who will be interactively using the computer.
            /// This logon type can generate a unique audit record that shows when the workstation was unlocked.
            /// </summary>
            LOGON32_LOGON_UNLOCK = 7,

            /// <summary>
            /// This logon type preserves the name and password in the authentication package, which allows the server to make
            /// connections to other network servers while impersonating the client. A server can accept plaintext credentials
            /// from a client, call LogonUser, verify that the user can access the system across the network, and still
            /// communicate with other servers.
            /// NOTE: Windows NT:  This value is not supported.
            /// </summary>
            LOGON32_LOGON_NETWORK_CLEARTEXT = 8,

            /// <summary>
            /// This logon type allows the caller to clone its current token and specify new credentials for outbound connections.
            /// The new logon session has the same local identifier but uses different credentials for other network connections.
            /// NOTE: This logon type is supported only by the LOGON32_PROVIDER_WINNT50 logon provider.
            /// NOTE: Windows NT:  This value is not supported.
            /// </summary>
            LOGON32_LOGON_NEW_CREDENTIALS = 9,
        }

        public enum LogonProvider
        {
            /// <summary>
            /// Use the standard logon provider for the system.
            /// The default security provider is negotiate, unless you pass NULL for the domain name and the user name
            /// is not in UPN format. In this case, the default provider is NTLM.
            /// NOTE: Windows 2000/NT:   The default security provider is NTLM.
            /// </summary>
            LOGON32_PROVIDER_DEFAULT = 0,
            LOGON32_PROVIDER_WINNT35 = 1,
            LOGON32_PROVIDER_WINNT40 = 2,
            LOGON32_PROVIDER_WINNT50 = 3
        }

        public enum SecurityImpersonationLevel : int
        {
            /// <summary>
            /// The server process cannot obtain identification information about the client,
            /// and it cannot impersonate the client. It is defined with no value given, and thus,
            /// by ANSI C rules, defaults to a value of zero.
            /// </summary>
            SecurityAnonymous = 0,

            /// <summary>
            /// The server process can obtain information about the client, such as security identifiers and privileges,
            /// but it cannot impersonate the client. This is useful for servers that export their own objects,
            /// for example, database products that export tables and views.
            /// Using the retrieved client-security information, the server can make access-validation decisions without
            /// being able to use other services that are using the client's security context.
            /// </summary>
            SecurityIdentification = 1,

            /// <summary>
            /// The server process can impersonate the client's security context on its local system.
            /// The server cannot impersonate the client on remote systems.
            /// </summary>
            SecurityImpersonation = 2,

            /// <summary>
            /// The server process can impersonate the client's security context on remote systems.
            /// NOTE: Windows NT:  This impersonation level is not supported.
            /// </summary>
            SecurityDelegation = 3,
        }

        [DllImport("advapi32.DLL")]
        public static extern bool ImpersonateLoggedOnUser(IntPtr hToken); //handle to token for logged-on user

        [DllImport("advapi32.DLL")]
        public static extern bool RevertToSelf();

        [DllImport("kernel32.dll")]
        public extern static bool CloseHandle(IntPtr hToken);

    }

    public class DomainJoin
    {
        public static string GetDomainJoin(String username,String password,String Domain,String Machine, String OU, String DC, out string DomainJoinBlob)
        {
            WindowsIdentity winId = WindowsIdentity.GetCurrent();
            //Console.WriteLine("Current User Identity : {0}", winId.Name);
            //if (winId != null)
            //{
            //    if (string.Compare(winId.Name, username, true) == 0)
            //    {
            //        return null;
            //    }
            //}

            //define the handles
            IntPtr existingTokenHandle = IntPtr.Zero;
            IntPtr duplicateTokenHandle = IntPtr.Zero;

            //split domain and name
            String[] splitUserName = username.Split('\\');
            userdomain = splitUserName[0];
            username = splitUserName[1];

            try
            {
                //get a security token
                Console.WriteLine("Before Calling AdvApi32.LogonUser");

                bool isOkay = AdvApi32.LogonUser(username, userdomain, password,
                    (int)AdvApi32.LogonTypes.LOGON32_LOGON_NEW_CREDENTIALS,
                    (int)AdvApi32.LogonProvider.LOGON32_PROVIDER_WINNT50,
                    out existingTokenHandle);

                Console.WriteLine("After Calling AdvApi32.LogonUser");

                if (!isOkay)
                {
                    int lastWin32Error = Marshal.GetLastWin32Error();
                    int lastError = Kernel32.GetLastError();

                    throw new Exception("LogonUser Failed: " + lastWin32Error + " - " + lastError);
                }

                // copy the token
                Console.WriteLine("Before Calling AdvApi32.DuplicateToken");

                isOkay = AdvApi32.DuplicateToken(existingTokenHandle,
                    (int)AdvApi32.SecurityImpersonationLevel.SecurityImpersonation,
                    out duplicateTokenHandle);

                Console.WriteLine("After Calling AdvApi32.DuplicateToken");
                if (!isOkay)
                {
                    int lastWin32Error = Marshal.GetLastWin32Error();
                    int lastError = Kernel32.GetLastError();
                    Kernel32.CloseHandle(existingTokenHandle);
                    throw new Exception("DuplicateToken Failed: " + lastWin32Error + " - " + lastError);
                }
                // create an identity from the token


                Console.WriteLine("Before Calling AdvApi32.ImpersonateLoggedOnUser(duplicateTokenHandle)");
                AdvApi32.ImpersonateLoggedOnUser(duplicateTokenHandle);
                Console.WriteLine("After Calling AdvApi32.ImpersonateLoggedOnUser(duplicateTokenHandle)");
                Console.WriteLine("After AdvApi32.ImpersonateLoggedOnUser User Identity : {0}", winId.Name);

                Netapi32.NetsetupProvisoningParams provisioningParams = new Netapi32.NetsetupProvisoningParams();
                provisioningParams.dwVersion = 1;
                provisioningParams.lpDomain = domain;
                provisioningParams.lpHostName = machine;
                provisioningParams.dwProvisionOptions = 2; // Reuse https://docs.microsoft.com/en-us/windows/desktop/api/lmjoin/nf-lmjoin-netprovisioncomputeraccount
                provisioningParams.lpMachineAccountOU = OU;
                provisioningParams.lpDcName = DC;

                //IntPtr blob = new IntPtr();
                //StringBuilder blob = new StringBuilder();
                String blob = String.Empty;

                //working - int result = Netapi32.NetCreateProvisioningPackage(provisioningParams, out a, out b, blob);

                int result = Netapi32.NetCreateProvisioningPackage(provisioningParams, IntPtr.Zero, IntPtr.Zero, out blob);
                DomainJoinBlob = blob;

                //string str = Marshal.PtrToStringAuto(blobptr);


                Console.WriteLine("Domain Blob: {0}", blob);
                //Console.WriteLine("Before Calling WindowsIdentity(duplicateTokenHandle)");
                WindowsIdentity newId = new WindowsIdentity(duplicateTokenHandle);

                //Console.WriteLine("After Calling WindowsIdentity(duplicateTokenHandle)");

                //Console.WriteLine("Before Calling newId.Impersonate()");

                WindowsImpersonationContext impersonatedUser = newId.Impersonate();


                //Console.WriteLine("After Calling newId.Impersonate()");
                //Console.WriteLine("After Impersonation User Identity : {0}", winId.Name);

                //return impersonatedUser;

                return blob;
            }
            finally
            {

                //Console.WriteLine("Inside Finally");
                //free all handles
                if (existingTokenHandle != IntPtr.Zero)
                {
                    Kernel32.CloseHandle(existingTokenHandle);
                }
                if (duplicateTokenHandle != IntPtr.Zero)
                {
                    Kernel32.CloseHandle(duplicateTokenHandle);
                }
            }
        }

        static void Main(string[] args)
        {
            Console.WriteLine("{0}",WinPE_DJoin(username: args[0],password: args[1], machinename:"NetSetup02"));

            Console.ReadLine();
        }
    }
}
'@

        switch ($CodeToUse) {
            'W2008' {
                Write-Verbose -Message "[$FunctionName] Importing code for Windows Server 2008/Windows 7"
                Add-Type -TypeDefinition $Source2008 -Language CSharp
            }
            default {
                Write-Verbose -Message "[$FunctionName] Importing code for Windows Server 2012/Windows 8"
                Add-Type -TypeDefinition $Source2012 -Language CSharp
            }
        }

        Write-Verbose -Message "[$FunctionName] Performing offline domain join...."

        $DomainJoinBlob = ""
        [void]([Djoin.DomainJoin]::GetDomainJoin($($Credential.username), $($Credential.GetNetworkCredential().password), $domain, $machinename, $machineaccountou, $dcname, [ref]$DomainJoinBlob))

        # return the blob
        return $DomainJoinBlob
    }
    catch {
        throw $_
    }
}
