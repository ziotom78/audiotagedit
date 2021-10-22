# Package

version       = "0.1.1"
author        = "Maurizio Tomasi"
description   = "CLI editor for audio tags, similar to vorbistagedit"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["audiotagedit"]

# Dependencies

requires "nim >= 1.4.8", "docopt >= 0.6.8"

# Tasks

import os

task genversion, "generate version file":
  # Update file src/versioninfo.nim with the current version
  let filename = joinpath("src", "versioninfo.nim")
  writeFile(filename, "const version = \"" & version & "\"\n")

before build:
  genversionTask()
