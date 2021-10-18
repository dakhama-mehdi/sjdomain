
# SJDomain
* Secure Join Domain is a Free tool based on onlline domain join method (ODJ) that allow to join a machine to an Active Directory without network connectivity and password
* This is a easy and secure way to allowing non-administrator users limited access based on (JEA) prciniple
* No need to delegated add object computer for your IT
* Can be used from any computer in the domain from CMD or PS1 without administrator terminal

![sjdomain-pub (1)](https://user-images.githubusercontent.com/49924401/137764614-86234f7e-6b47-4193-898d-e1447d6338a3.gif)

# More information : 
* This is based C# scirpt that i have simplified and improved, the orginal script is used by "Ryan Ephgrave"
* I'm also used the "François-Xavier Cat" post and script :
link to post : https://lazywinadmin.com/2020/06/powershell-offline_domain_join_csharp.html

link to script : https://github.com/lazywinadmin/PowerShell/blob/master/AD-COMPUTER-New-ADDomainJoin/New-ADDomainJoin.ps1

link to Ryan script : https://gist.github.com/Ryan2065/79838b78643d2311d60cb6147e3b87bf


# What's News :
* Create computer from list .txt
* The domain will be automatically choose, and use current user domain
* New option (OU/path/Reuse)
* Automaticaly add computer from destination like localcomputername with deploying tools like MDT/SCCM/WDS

# How tu use :

This work on two phases :

# First phase : create a computer account in Active Directory from list or name and chose option 
Exemple : 

* this sample comand will provision a computer account named PC-1 on AD in default OU "Computer" and save file in local folder named "Approv"

sjdomain.exe "PC-1"  

another possible option : 

-path  : Specific destination to save provisioning data file
-OU    : Specifies the name of the organizational unit (OU) in which you want the computer account to be created
-Reuse : Specifies the reuse of any existing computer account. The password for the computer account will be reset

you can custom option by using "-" or respect order example :

* this two command create a account computer on specific OU and save the file in directory c:\folder
sjdomain.exe "pc-1" c:\folder\ "ou=test,DC=info,DC=prive"  

sjdomain.exe "pc-1" -Ou "ou=test,DC=info,DC=prive"  -Path c:\folder\  

* you can create more computer separated by ","
sjdomain.exe "PC-1,PC-2,PC-3"

* create computer from list : 
sjdomain.exe c:\myfile-namecomputer.txt

# Last phase : Add computer 
To request an offline domain join for a local computer run the following command at an elevated command prompt:

* enter simply the patch to file, the computer will be restart and rename
sjdomain "c:\path-to-file\file-1"

* this command will chose from folder the file like current computer name, and add it to domain, for example if local machine named "PC-1", the tool will search the file named 
"PC-1" from folder

sjdomain.exe add "C:\folder-contains-offline-file"

this is link to how to integre SJDomain with MDT or SCCM

* Help :

# you can get help, by enter command "?" or "help"

example :

sdjoin.exe /?

sdjoin.exe /help

# Thanks :
Matthieu Souin
