# Note, due to how `Expand-Archive` is leveraged in this script,
# powershell core is a requirement for successful execution.
param (
  $AzCopy,
  $DocLocation,
  $SASKey,
  $Language,
  $BlobName,
  $ExitOnError=1,
  $UploadLatest=1,
  $PublicArtifactLocation = "",
  $RepoReplaceRegex = "(https://github.com/.*/(?:blob|tree)/)master"
)
. (Join-Path $PSScriptRoot artifact-metadata-parsing.ps1)

$Language = $Language.ToLower()

# Regex inspired but simplified from https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
$SEMVER_REGEX = "^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-?(?<prelabel>[a-zA-Z-]*)(?:\.?(?<prenumber>0|[1-9]\d*))?)?$"

function ToSemVer($version){
    if ($version -match $SEMVER_REGEX)
    {
        if(-not $matches['prelabel']) {
            # artifically provide these values for non-prereleases to enable easy sorting of them later than prereleases.
            $prelabel = "zzz"
            $prenumber = 999;
            $isPre = $false;
        }
        else {
            $prelabel = $matches["prelabel"]
            $prenumber = 0

            # some older packages don't have a prenumber, should handle this
            if($matches["prenumber"]){
                $prenumber = [int]$matches["prenumber"]
            }

            $isPre = $true;
        }

        New-Object PSObject -Property @{
            Major = [int]$matches['major']
            Minor = [int]$matches['minor']
            Patch = [int]$matches['patch']
            PrereleaseLabel = $prelabel
            PrereleaseNumber = $prenumber
            IsPrerelease = $isPre
            RawVersion = $version
        }
    }
    else
    {
        if ($ExitOnError)
        {
            throw "Unable to convert $version to valid semver and hard exit on error is enabled. Exiting."
        }
        else
        {
            return $null
        }
    }
}

function SortSemVersions($versions)
{
    return $versions | Sort -Property Major, Minor, Patch, PrereleaseLabel, PrereleaseNumber -Descending
}

function Sort-Versions
{
    Param (
        [Parameter(Mandatory=$true)] [string[]]$VersionArray
    )

    # standard init and sorting existing
    $versionsObject = New-Object PSObject -Property @{
        OriginalVersionArray = $VersionArray
        SortedVersionArray = @()
        LatestGAPackage = ""
        RawVersionsList = ""
        LatestPreviewPackage = ""
    }

    if ($VersionArray.Count -eq 0)
    {
        return $versionsObject
    }

    $versionsObject.SortedVersionArray = @(SortSemVersions -versions ($VersionArray | % { ToSemVer $_}))
    $versionsObject.RawVersionsList = $versionsObject.SortedVersionArray | % { $_.RawVersion }

    # handle latest and preview
    # we only want to hold onto the latest preview if its NEWER than the latest GA.
    # this means that the latest preview package either A) has to be the latest value in the VersionArray
    # or B) set to nothing. We'll handle the set to nothing case a bit later.
    $versionsObject.LatestPreviewPackage = $versionsObject.SortedVersionArray[0].RawVersion
    $gaVersions = $versionsObject.SortedVersionArray | ? { !$_.IsPrerelease }

    # we have a GA package
    if ($gaVersions.Count -ne 0)
    {
        # GA is the newest non-preview package
        $versionsObject.LatestGAPackage = $gaVersions[0].RawVersion

        # in the case where latest preview == latestGA (because of our default selection earlier)
        if ($versionsObject.LatestGAPackage -eq $versionsObject.LatestPreviewPackage)
        {
            # latest is newest, unset latest preview
            $versionsObject.LatestPreviewPackage = ""
        }
    }

    return $versionsObject
}

function Get-Existing-Versions
{
    Param (
        [Parameter(Mandatory=$true)] [String]$PkgName
    )
    $versionUri = "$($BlobName)/`$web/$($Language)/$($PkgName)/versioning/versions"
    Write-Host "Heading to $versionUri to retrieve known versions"

    try {
        return ((Invoke-RestMethod -Uri $versionUri -MaximumRetryCount 3 -RetryIntervalSec 5) -Split "\n" | % {$_.Trim()} | ? { return $_ })
    }
    catch {
        # Handle 404. If it's 404, this is the first time we've published this package.
        if ($_.Exception.Response.StatusCode.value__ -eq 404){
            Write-Host "Version file does not exist. This is the first time we have published this package."
        }
        else {
            # If it's not a 404. exit. We don't know what's gone wrong.
            Write-Host "Exception getting version file. Aborting"
            Write-Host $_
            exit(1)
        }
    }
}

function Update-Existing-Versions
{
    Param (
        [Parameter(Mandatory=$true)] [String]$PkgName,
        [Parameter(Mandatory=$true)] [String]$PkgVersion,
        [Parameter(Mandatory=$true)] [String]$DocDest
    )
    $existingVersions = @(Get-Existing-Versions -PkgName $PkgName)

    Write-Host "Before I update anything, I am seeing $existingVersions"

    if (!$existingVersions)
    {
        $existingVersions = @()
        $existingVersions += $PkgVersion
        Write-Host "No existing versions. Adding $PkgVersion."
    }
    else
    {
        $existingVersions += $pkgVersion
        Write-Host "Already Existing Versions. Adding $PkgVersion."
    }

    $existingVersions = $existingVersions | Select-Object -Unique

    # newest first
    $sortedVersionObj = (Sort-Versions -VersionArray $existingVersions)

    Write-Host $sortedVersionObj
    Write-Host $sortedVersionObj.LatestGAPackage
    Write-Host $sortedVersionObj.LatestPreviewPackage

    # write to file. to get the correct performance with "actually empty" files, we gotta do the newline
    # join ourselves. This way we have absolute control over the trailing whitespace.
    $sortedVersionObj.RawVersionsList -join "`n" | Out-File -File "$($DocLocation)/versions" -Force -NoNewLine
    $sortedVersionObj.LatestGAPackage | Out-File -File "$($DocLocation)/latest-ga" -Force -NoNewLine
    $sortedVersionObj.LatestPreviewPackage | Out-File -File "$($DocLocation)/latest-preview" -Force -NoNewLine

    & $($AzCopy) cp "$($DocLocation)/versions" "$($DocDest)/$($PkgName)/versioning/versions$($SASKey)" --cache-control "max-age=300, must-revalidate"
    & $($AzCopy) cp "$($DocLocation)/latest-preview" "$($DocDest)/$($PkgName)/versioning/latest-preview$($SASKey)" --cache-control "max-age=300, must-revalidate"
    & $($AzCopy) cp "$($DocLocation)/latest-ga" "$($DocDest)/$($PkgName)/versioning/latest-ga$($SASKey)" --cache-control "max-age=300, must-revalidate"
    return $sortedVersionObj
}

function Upload-Blobs
{
    Param (
        [Parameter(Mandatory=$true)] [String]$DocDir,
        [Parameter(Mandatory=$true)] [String]$PkgName,
        [Parameter(Mandatory=$true)] [String]$DocVersion,
        [Parameter(Mandatory=$false)] [String]$ReleaseTag
    )
    #eg : $BlobName = "https://azuresdkdocs.blob.core.windows.net"
    $DocDest = "$($BlobName)/`$web/$($Language)"

    Write-Host "DocDest $($DocDest)"
    Write-Host "PkgName $($PkgName)"
    Write-Host "DocVersion $($DocVersion)"
    Write-Host "DocDir $($DocDir)"
    Write-Host "Final Dest $($DocDest)/$($PkgName)/$($DocVersion)"
    Write-Host "Release Tag $($ReleaseTag)"

    # Use the step to replace master link to release tag link 
    if ($ReleaseTag) {
        foreach ($htmlFile in (Get-ChildItem $DocDir -include *.html -r)) 
        {
            $fileContent = Get-Content -Path $htmlFile -Raw
            $updatedFileContent = $fileContent -replace $RepoReplaceRegex, "`${1}$ReleaseTag"
            if ($updatedFileContent -ne $fileContent) {
                Set-Content -Path $htmlFile -Value $updatedFileContent
            }
        }
    } 
    else {
        Write-Warning "Not able to do the master link replacement, since no release tag found for the release. Please manually check."
    } 
   
    Write-Host "Uploading $($PkgName)/$($DocVersion) to $($DocDest)..."
    & $($AzCopy) cp "$($DocDir)/**" "$($DocDest)/$($PkgName)/$($DocVersion)$($SASKey)" --recursive=true --cache-control "max-age=300, must-revalidate"

    Write-Host "Handling versioning files under $($DocDest)/$($PkgName)/versioning/"
    $versionsObj = (Update-Existing-Versions -PkgName $PkgName -PkgVersion $DocVersion -DocDest $DocDest)

    # we can safely assume we have AT LEAST one version here. Reason being we just completed Update-Existing-Versions
    $latestVersion = ($versionsObj.SortedVersionArray | Select-Object -First 1).RawVersion

    if ($UploadLatest -and ($latestVersion -eq $DocVersion))
    {
        Write-Host "Uploading $($PkgName) to latest folder in $($DocDest)..."
        & $($AzCopy) cp "$($DocDir)/**" "$($DocDest)/$($PkgName)/latest$($SASKey)" --recursive=true --cache-control "max-age=300, must-revalidate"
    }
}

if ($Language -eq "javascript")
{
    $PublishedDocs = Get-ChildItem "$($DocLocation)/documentation" | Where-Object -FilterScript {$_.Name.EndsWith(".zip")}

    foreach ($Item in $PublishedDocs) {
        $PkgName = "azure-$($Item.BaseName)"
        Write-Host $PkgName
        Expand-Archive -Force -Path "$($DocLocation)/documentation/$($Item.Name)" -DestinationPath "$($DocLocation)/documentation/$($Item.BaseName)"
        $dirList = Get-ChildItem "$($DocLocation)/documentation/$($Item.BaseName)/$($Item.BaseName)" -Attributes Directory

        if($dirList.Length -eq 1){
            $DocVersion = $dirList[0].Name
            Write-Host "Uploading Doc for $($PkgName) Version:- $($DocVersion)..."
            $releaseTag = RetrieveReleaseTag "NPM" $PublicArtifactLocation
            Upload-Blobs -DocDir "$($DocLocation)/documentation/$($Item.BaseName)/$($Item.BaseName)/$($DocVersion)" -PkgName $PkgName -DocVersion $DocVersion -ReleaseTag $releaseTag
        }
        else{
            Write-Host "found more than 1 folder under the documentation for package - $($Item.Name)"
        }
    }
}

if ($Language -eq "dotnet")
{
    $PublishedPkgs = Get-ChildItem "$($DocLocation)" | Where-Object -FilterScript {$_.Name.EndsWith(".nupkg") -and -not $_.Name.EndsWith(".symbols.nupkg")}
    $PublishedDocs = Get-ChildItem "$($DocLocation)" | Where-Object -FilterScript {$_.Name.EndsWith("docs.zip")}

    if (($PublishedPkgs.Count -gt 1) -or ($PublishedDoc.Count -gt 1))
    {
        Write-Host "$($DocLocation) should contain only one (1) published package and docs"
        Write-Host "No of Packages $($PublishedPkgs.Count)"
        Write-Host "No of Docs $($PublishedDoc.Count)"
        exit 1
    }

    $DocsStagingDir = "$WorkingDirectory/docstaging"
    $TempDir = "$WorkingDirectory/temp"

    New-Item -ItemType directory -Path $DocsStagingDir
    New-Item -ItemType directory -Path $TempDir

    Expand-Archive -LiteralPath $PublishedDocs[0].FullName -DestinationPath $DocsStagingDir
    $pkgProperties = ParseNugetPackage -pkg $PublishedPkgs[0].FullName -workingDirectory $TempDir

    Write-Host "Start Upload for $($pkgProperties.ReleaseTag)"
    Write-Host "DocDir $($DocsStagingDir)"
    Write-Host "PkgName $($pkgProperties.PackageId)"
    Write-Host "DocVersion $($pkgProperties.PackageVersion)"
    Upload-Blobs -DocDir "$($DocsStagingDir)" -PkgName $pkgProperties.PackageId -DocVersion $pkgProperties.PackageVersion -ReleaseTag $pkgProperties.ReleaseTag
}

if ($Language -eq "python")
{
    $PublishedDocs = Get-ChildItem "$DocLocation" | Where-Object -FilterScript {$_.Name.EndsWith(".zip")}

    foreach ($Item in $PublishedDocs) {
        $PkgName = $Item.BaseName
        $ZippedDocumentationPath = Join-Path -Path $DocLocation -ChildPath $Item.Name
        $UnzippedDocumentationPath = Join-Path -Path $DocLocation -ChildPath $PkgName
        $VersionFileLocation = Join-Path -Path $UnzippedDocumentationPath -ChildPath "version.txt"

        Expand-Archive -Force -Path $ZippedDocumentationPath -DestinationPath $UnzippedDocumentationPath

        $Version = $(Get-Content $VersionFileLocation).Trim()

        Write-Host "Discovered Package Name: $PkgName"
        Write-Host "Discovered Package Version: $Version"
        Write-Host "Directory for Upload: $UnzippedDocumentationPath"
        $releaseTag = RetrieveReleaseTag "PyPI" $PublicArtifactLocation 
        Upload-Blobs -DocDir $UnzippedDocumentationPath -PkgName $PkgName -DocVersion $Version -ReleaseTag $releaseTag
    }
}

if ($Language -eq "java")
{
    $PublishedDocs = Get-ChildItem "$DocLocation" | Where-Object -FilterScript {$_.Name.EndsWith("-javadoc.jar")}
    foreach ($Item in $PublishedDocs) {
        $UnjarredDocumentationPath = ""
        try {
            $PkgName = $Item.BaseName
            # The jar's unpacking command doesn't allow specifying a target directory
            # and will unjar all of the files in whatever the current directory is.
            # Create a subdirectory to unjar into, set the location, unjar and then
            # set the location back to its original location.
            $UnjarredDocumentationPath = Join-Path -Path $DocLocation -ChildPath $PkgName
            New-Item -ItemType directory -Path "$UnjarredDocumentationPath"
            $CurrentLocation = Get-Location
            Set-Location $UnjarredDocumentationPath
            jar -xf "$($Item.FullName)"
            Set-Location $CurrentLocation

            # If javadocs are produced for a library with source, there will always be an
            # index.html. If this file doesn't exist in the UnjarredDocumentationPath then
            # this is a sourceless library which means there are no javadocs and nothing
            # should be uploaded to blob storage.
            $IndexHtml = Join-Path -Path $UnjarredDocumentationPath -ChildPath "index.html"
            if (!(Test-Path -path $IndexHtml))
            {
                Write-Host "$($PkgName) does not have an index.html file, skippping."
                continue
            }

            # Get the POM file for the artifact we're processing
            $PomFile = $Item.FullName.Substring(0,$Item.FullName.LastIndexOf(("-javadoc.jar"))) + ".pom"
            Write-Host "PomFile $($PomFile)"

            # Pull the version from the POM
            [xml]$PomXml = Get-Content $PomFile
            $Version = $PomXml.project.version
            $ArtifactId = $PomXml.project.artifactId

            Write-Host "Start Upload for $($PkgName)/$($Version)"
            Write-Host "DocDir $($UnjarredDocumentationPath)"
            Write-Host "PkgName $($ArtifactId)"
            Write-Host "DocVersion $($Version)"
            $releaseTag = RetrieveReleaseTag "Maven" $PublicArtifactLocation 
            Upload-Blobs -DocDir $UnjarredDocumentationPath -PkgName $ArtifactId -DocVersion $Version -ReleaseTag $releaseTag

        } Finally {
            if (![string]::IsNullOrEmpty($UnjarredDocumentationPath)) {
                if (Test-Path -Path $UnjarredDocumentationPath) {
                    Write-Host "Cleaning up $UnjarredDocumentationPath"
                    Remove-Item -Recurse -Force $UnjarredDocumentationPath
                }
            }
        }
    }
}

if ($Language -eq "c")
{
    # The documentation publishing process for C differs from the other
    # langauges in this file because this script is invoked for the whole SDK
    # publishing. It is not, for example, invoked once per service publishing.
    # There is a similar situation for other langauge publishing steps above...
    # Those loops are left over from previous versions of this script which were
    # used to publish multiple docs packages in a single invocation.
    $pkgInfo = Get-Content $DocLocation/package-info.json | ConvertFrom-Json
    $releaseTag = RetrieveReleaseTag "C" $PublicArtifactLocation 
    Upload-Blobs -DocDir $DocLocation -PkgName 'docs' -DocVersion $pkgInfo.version -ReleaseTag $releaseTag
}

if ($Language -eq "cpp")
{
    $packageInfo = (Get-Content (Join-Path $DocLocation 'package-info.json') | ConvertFrom-Json)
    $releaseTag = RetrieveReleaseTag "CPP" $PublicArtifactLocation
    Upload-Blobs -DocDir $DocLocation -PkgName $packageInfo.name -DocVersion $packageInfo.version -ReleaseTag $releaseTag
}
