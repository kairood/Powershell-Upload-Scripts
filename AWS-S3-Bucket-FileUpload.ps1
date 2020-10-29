# Check CSV File Exists Local for S3 Object Upload & Date Written is current day for process and Verify the Object has been written to S3 bucket


# Import AWS Module
Import-Module AWSPowerShell

# Get the file and ensure inital path exists - - These fields needs updating depending on the path/name of the data and what you would like the data to be renamed to in S3 (I.E ABC Report with Current Date)

$Path = "\\SHARENAME\Folder\DataSource"
$FileName = "MyReportData.csv"
$Date = Get-Date -UFormat %d_%m_%Y
$S3WriteFileName = "CompanyABCReport" + "_" + "$Date" + ".csv"


#S3 Bucket Info! - These fields needs updating depending on the S3 bucket location / Key Name and Bucket Name!

$S3BucketName = "BucketABC"
$S3KeyName = "KeyNameABC"
$S3Region = "eu-west-1"


$FullPath = Join-Path -Path $Path -ChildPath $FileName


$NewRenamedFullPath = Join-Path -Path $Path -ChildPath $S3WriteFileName


Write-Verbose "S3 Bucket Region Selected: $S3Region" -Verbose


#Use the code below to store the AWS Credentials 

#Generate Credentials
#Set-AWSCredential -AccessKey XXXXXXXXXXX -SecretKey XXXXXXXX -StoreAs AWSCreds

#Use the code below to delete the stored AWS Credentials if there out of date or no longer required

#Remove Credentials
#Remove-AWSCredentialProfile -ProfileName AWSCreds

# Check File exists locally and if $TRUE check Date the file was modified before Invoking Function to write S3 Object (Upload CSV File to AWS)

Try {
$CheckPath = Test-Path -Path $FullPath -ErrorVariable $Errorfindingpath

if ($CheckPath -eq $false) {
Write-Warning "The path $FullPath WAS NOT found. Quitting Script"
exit
}

Elseif ($CheckPath -eq $true) {
Write-Verbose "The path $FullPath WAS found." -Verbose

Try {

Write-Verbose "Checking LastWriteTime on $FullPath" -Verbose

$GetItemWriteDateTime = Get-Item -Path $FullPath

$ConvertWriteDateTime_TODATE = $GetItemWriteDateTime.LastWriteTime.Date

If ($ConvertWriteDateTime_TODATE -ge (Get-Date).Date) {
Write-Verbose "Adjusting $FileName in $Path to be renamed with Date_Time" -Verbose


Try {
Rename-Item -Path $FullPath -NewName $S3WriteFileName
}

Catch {
Write-Warning "Failed to rename $FileName in $Path to $S3WriteFileName"
Exit
}


Write-Verbose "Renamed $FileName to $S3WriteFileName in $Path Succesfully. Invoking Write-S3Object Function" -Verbose


#Function to write S3 Object
Function Write-S3Object {
# Attempt to write the S3 Object
Try {
$TimeBeforeS3Upload = Get-Date

# Get Secured Creds & Write Object
Get-AWSCredential -ProfileName AWSCreds -ErrorVariable ErrorRetrievingCredsProfileWrite -ErrorAction SilentlyContinue | Write-S3Object -BucketName $S3BucketName -Key "$S3KeyName/$S3WriteFileName" -File $NewRenamedFullPath -Region $S3Region -ErrorVariable ErrorWritingObjectToS3 -ErrorAction SilentlyContinue -Verbose

}
# Catch any errors for writing S3 object and output this to Console
Catch {
Write-Warning "An error has occured writing the file into the S3 System due to the following $ErrorWritingObjectToS3 $ErrorRetrievingCredsProfileWrite"

}
}

Write-S3Object

Write-Verbose "Invoking ReadS3-Object Function" -Verbose

#Function to read S3 Object
Function ReadS3-Object {
# Attempt to write the S3 Object
Try {
$GetS3Object = Get-AWSCredential -ProfileName AWSCreds -ErrorVariable ErrorRetrievingCredsProfileRead -ErrorAction SilentlyContinue | Read-S3Object -BucketName $S3BucketName -Key "$S3KeyName/$S3WriteFileName" -File $NewRenamedFullPath -Region $S3Region -ErrorVariable ErrorReadingObjectToS3 -Verbose | Where LastWriteTime -GT $TimeBeforeS3Upload

If ($GetS3Object.Exists -eq $True){
$GetS3ObjectName = $GetS3Object.Name
Write-Verbose "The file $GetS3ObjectName has successfully been uploaded to S3" -Verbose
}
Elseif ($GetS3Object.Exists -eq $False){
$GetS3ObjectName = $GetS3Object.Name
Write-Warning "The file $GetS3ObjectName has FAILED to upload to S3"
exit
}

}
# Catch any errors for reading S3 object and output this to Console
Catch {
Write-Warning "An error has occured reading the file into the S3 System due to the following $ErrorReadingObjectToS3 $ErrorRetrievingCredsProfileRead"
exit
}
}


ReadS3-Object

Log-Write -LogPath $sLogFile -LineValue "Adjusting $FileName in $Path to be renamed back without Date"


Try {
Rename-Item -Path $NewRenamedFullPath -NewName $FileName
}

Catch {
Write-Warning "Failed to rename $S3WriteFileName in $Path to $FileName"
}


}

Else {
Write-Verbose "The LastWriteTime on $FullPath is Incorrect. Quitting Script" -Verbose
}


}

Catch {
Write-Warning -Message "An error has occured attempting to check the LastWriteTime on $FullPath"

}

}
}
# Catch any other errors
Catch {
Write-Warning -Message "An error has occured due to the following $Errorfindingpath"

}


