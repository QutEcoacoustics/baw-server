#!/usr/bin/env pwsh

param(
  $next_version
)

function script:exec {
    [CmdletBinding()]

    param(
        [Parameter(Position = 0, Mandatory = 1)][scriptblock]$cmd,
        [Parameter(Position = 1, Mandatory = 0)][string]$errorMessage,

        [switch]$WhatIf = $false
    )
    if ($WhatIf) {
        $InformationPreference = 'Continue'
        Write-Information "Would execute `"$cmd`""
        return;
    }

    Write-Information "Executing `"$cmd`""

    & $cmd
    if ($LASTEXITCODE -ne 0) {
        throw ("Error ($LASTEXITCODE) executing command: {0}" -f $cmd) + ($errorMessage ?? "")
    }
}

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$env:NEXT_VERSION = $next_version

if ($null -eq $env:CHANGELOG_GITHUB_TOKEN) {
  Write-Error "Cannot generate change log unless CHANGELOG_GITHUB_TOKEN environment variable is set"
}

if ($null -eq $next_version -or '' -eq $next_version ) {
  Write-Error "Next version variable is required"
  exit 1
}

Write-Output "Generate changelog"
exec { docker-compose run --rm web rake changelog }

Write-Output "Generate API docs"
exec { docker-compose run --rm web generate_docs.sh }

Write-Output "Set VERSION $next_version"
exec { Write-Output $next_version > VERSION }

exec {
  git add -A && git commit -m "Generated changelog and API docs for version $next_version" -m "[skip ci]"
}

Write-Output "Creating tag $next_version"

exec { git tag -a -m "Version $next_version" $next_version }

exec { git push --follow-tags }

$short = exec { git describe }
$long =  exec { git describe --long }

Write-Output "Building docker file"
exec {
  docker build --build-arg version=$short --build-arg trimmed=true `
   --label version=$long `
   --tag qutecoacoustics/workbench-server:latest --tag qutecoacoustics/workbench-server:$long `
   .
}

Write-Output "Pushing dockerfile"
exec {
  docker push -a qutecoacoustics/workbench-server
}
