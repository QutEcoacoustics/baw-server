#!/bin/env pwsh

$ErrorActionPreference = "Stop"

try {
  Push-Location
  Set-Location ..
  docker build . -t qutecoacoustics/baw-server:latest



}
finally {
  Pop-Location
}

