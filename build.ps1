param(
	[Parameter(Position = 0)]
	[string] $Version = "3.8.1"
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

function Nupkg
{
	InstallToolPackages

	. $nuget pack $(Join-Path $NugetDir 'Magic.NetFramework.nuspec') -NoPackageAnalysis -Version $Version -OutputDirectory $NugetDir -Properties "SlowCheetahPath=$SlowCheetahPath"
	. $nuget pack $(Join-Path $NugetDir 'Magic.NetStandard.nuspec') -NoPackageAnalysis -Version $Version -OutputDirectory $NugetDir
	. $nuget pack $(Join-Path $NugetDir 'Mime.nuspec') -NoPackageAnalysis -Version $Version -OutputDirectory $NugetDir
}

function Build
{
	. dotnet build -c Release $Solution -p Version=$Version
}

Build
Nupkg