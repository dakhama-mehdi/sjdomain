
# SJDomain

* Secure Join Domain is a Free tool based on onlline domain join method (ODJ) that allow to join a machine to an Active Directory without network connectivity and password
* This is a easy and secure way to allowing non-administrator users limited access based on (JEA) prciniple
* No need to delegated add object computer for your IT
* Can be used from any computer in the domain from CMD or PS1 without administrator terminal

# More information : 
* This is based 


# What's News :
* Create computer from list .txt
* The domain will be automatically choose, and use current user domain
* New option (OU/path/Reuse)
* Automaticaly add computer from destination like localcomputername with deploying tools like MDT/SCCM/WDS

# How tu use :

This work on twi phases :

* First phase : create a computer account in Active Directory from list or name and chose option 
Exemple : 

#this sample comand will provision a computer account named PC-1 on AD in default OU "Computer" and save file in local folder named "Approv"

sjdomain.exe "PC-1"  

another possible option : 

-path  : Specific destination to save provisioning data file
-OU    : Specifies the name of the organizational unit (OU) in which you want the computer account to be created
-Reuse : Specifies the reuse of any existing computer account. The password for the computer account will be reset

you can custom option by using "-" or respect order example :

#this two command create a account computer on specific OU and save the file in directory c:\folder
sjdomain.exe "pc-1" c:\folder\ "ou=test,DC=info,DC=prive"  

sjdomain.exe "pc-1" -Ou "ou=test,DC=info,DC=prive"  -Path c:\folder\  

#you can create more computer separated by ","
sjdomain.exe "PC-1,PC-2,PC-3"

#create computer from list : 
sjdomain.exe c:\myfile-namecomputer.txt

* Last phase :




