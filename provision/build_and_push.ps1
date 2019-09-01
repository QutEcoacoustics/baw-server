#!/bin/env pwsh

$ErrorActionPreference = "Stop"

try {
  Push-Location
  Set-Location "$PSScriptRoot/.."
  docker build . -t qutecoacoustics/workbench-server:latest

  docker push qutecoacoustics/workbench-server:latest


}
finally {
  Pop-Location
}

