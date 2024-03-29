# Package

version       = "0.2.0"
author        = "Maurizio Tomasi"
description   = "CLI editor for audio tags, similar to vorbistagedit"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["audiotagedit"]

# Dependencies

requires "nim >= 1.4.8", "docopt >= 0.6.8"
