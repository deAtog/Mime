param(
	[Parameter(Position = 0)]
	[string] $Version = "3.8.1-alpha-2",
	[Parameter(Position = 1)]
	[string] $AssemblyVersion = "3.8.1"
)

$WorkingDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$Solution = Join-Path $WorkingDir 'Mime.sln'
$NugetDir = Join-Path $WorkingDir 'nuget'
$ToolDir = Join-Path $NugetDir 'tools'
$SlowCheetahPackage = 'SlowCheetah'
$SlowCheetahVersion = '2.5.48'
$SlowCheetahPath = Join-Path $ToolDir "$SlowCheetahPackage.$SlowCheetahVersion"

$nuget = Join-Path $NugetDir 'nuget.exe'

function DownloadNuget
{
	if (Test-Path $nuget) { return }

	Debug "Downloading nuget..."
	$client = New-Object System.Net.WebClient;
	$client.DownloadFile('https://dist.nuget.org/win-x86-commandline/latest/nuget.exe', $nuget);
}

function InstallToolPackages
{
	DownloadNuget

	Debug "Installing tools..."
	$OutDir = New-Item -ItemType Directory -Path $ToolDir -Force

	if (-not (Test-Path "$SlowCheetahPath"))
	{
		# Install SlowCheetah version 2.5.48 which only requires .Net 4.0 to run
		. $nuget install $SlowCheetahPackage -Verbosity quiet -Version $SlowCheetahVersion -OutputDirectory $OutDir 
	}
}

function Debug
{
	param(
		[Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
		[string] $Message
	)

	Write-Host
	Write-Host $Message -ForegroundColor Green
	Write-Host
}

function WriteVersionToTransforms
{
	$transforms = Get-ChildItem -Path $NugetDir -File -Filter "*.transform" -Name

	foreach ($transform in $transforms)
	{
		$Filename = Join-Path $NugetDir $transform
		$Regex = 'codeBase version="(.*?)"'

		$TransformData = Get-Content -Encoding UTF8 $Filename
		$NewString = $TransformData -replace $Regex, "codeBase version=""$AssemblyVersion.0"""

		$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
		[System.IO.File]::WriteAllLines($Filename, $NewString, $Utf8NoBomEncoding)
	}
}

function Nupkg
{
	InstallToolPackages
	WriteVersionToTransforms

	$repo_type = 'git'

	if (-not $env:CI)
	{
		$branch = git branch --show-current
		$remote = git config --get branch.$branch.remote
		$remote = if ($remote) { $remote } else { "origin" }

		$repo_url = git config --get remote.$remote.url
		$repo_branch = git symbolic-ref HEAD
		$repo_commit = git rev-parse HEAD
	}
	else
	{
		$repo_url = "${$env:GITHUB_SERVER_URL}/${$env:GITHUB_REPOSITORY_ID}.git"
		$repo_branch = $env:GITHUB_REF
		$repo_commit = $env:GITHUB_SHA
	}

	. $nuget pack $(Join-Path $NugetDir 'Magic.NetFramework.nuspec') -NoPackageAnalysis -Version $Version -OutputDirectory $NugetDir -Properties "SlowCheetahPath=$SlowCheetahPath;repo_type=$repo_type;repo_url=$repo_url;repo_branch=$repo_branch;repo_commit=$repo_commit"
	. $nuget pack $(Join-Path $NugetDir 'Magic.NetStandard.nuspec') -NoPackageAnalysis -Version $Version -OutputDirectory $NugetDir -Properties "repo_type=$repo_type;repo_url=$repo_url;repo_branch=$repo_branch;repo_commit=$repo_commit"

	. $nuget pack $(Join-Path $NugetDir 'Mime.nuspec') -NoPackageAnalysis -Version $Version -OutputDirectory $NugetDir -Properties "repo_type=$repo_type;repo_url=$repo_url;repo_branch=$repo_branch;repo_commit=$repo_commit"
}

function Build
{
	. dotnet clean -c Release $Solution -p Version=$AssemblyVersion
	. dotnet build -c Release $Solution -p Version=$AssemblyVersion
}

Build
Nupkg