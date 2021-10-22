# -*- encoding: utf-8 -*-
#
# audiotagedit
# Edit audio file tags from the command line using your favourite editor
# Copyright (C) 2021 Maurizio Tomasi
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import times
import tables
import strutils
import hashes
import os
import osproc
import oids
import taglib
import options
import docopt
import std/sha1
import strformat
import parsetoml
import logging

var logger* = newConsoleLogger()

const version = "0.1.0"

type
  AudioFileItem* = object
    oldFileName*: string
    newFileName*: string
    checksum*: Option[SecureHash]
    title*: Option[string]
    album*: Option[string]
    artist*: Option[string]
    year*: Option[uint]
    trackNumber*: Option[uint]
    comment*: Option[string]
    length*: int


proc hash*(checksum: sha1.SecureHash): Hash =
  result = ($checksum).hash


proc readStringOrNone(s: string): Option[string] =
  if s != "":
    result = some(s)


proc readUintOrNone(i: uint): Option[uint] =
  if i != 0:
    result = some(i)


proc retrieveMetadata*(fileName: string, item: var AudioFileItem) =
  block:
    var curFile = taglib.open(fileName)
    defer: curFile.close()

    item.oldFileName = normalizedPath(fileName)
    item.newFileName = item.oldFileName

    item.title = readStringOrNone(curFile.title)
    item.album = readStringOrNone(curFile.album)
    item.artist = readStringOrNone(curFile.artist)
    item.year = readUintOrNone(curFile.year)
    item.track_number = readUintOrNone(curFile.track)
    item.comment = readStringOrNone(curFile.comment)
    item.length = curFile.length

  item.checksum = some(sha1.secureHashFile(fileName))


proc retrieveMetadata*(fileNames: openArray[string]): OrderedTableRef[string, AudioFileItem] =
  result = newOrderedTable[string, AudioFileItem]()
  for idx, curFileName in fileNames:
    var curEntry: AudioFileItem
    retrieveMetadata(curFileName, curEntry)

    result[curEntry.oldFileName] = curEntry


proc sanitizeToml*(input: string): string =
  result = ""
  
  for curChar in input:
    case curChar
      of '\b': result.add(r"\b")
      of '\t': result.add(r"\t")
      of '\n': result.add(r"\n")
      of '\f': result.add(r"\f")
      of '\r': result.add(r"\r")
      of '\\': result.add("\\\\")
      of '"': result.add("\\\"")
      else:
        result.add(curChar)


proc writeMetadataToFile*(
  fileName: string, 
  entries: OrderedTableRef[string, AudioFileItem],
  writeChecksums: bool = true,
) =
  let outFile = open(fileName, fmWrite)
  defer: outFile.close()

  outFile.write("""
# Created by audiotagedit on {now()}
#
# Edit the entries in this file according to your needs. When you close
# this file, the modifications will be applied to all the files.
#
# If you remove a whole section (the `[[file_entry]]` line and everything
# that goes below it) from this file, the corresponding audio file will
# *not* be touched on exit.
#
# The keys you can specify are the following:
# - `title`: the title of the piece
# - `album`: the album (string)
# - `artist`: the name of the artist (string)
# - `year`: the year of the piece (integer)
# - `track_number`: the track number, starting from 1 (integer)
# - `comment`: a generic comment (string)
#
# If there is a mismatch between the original file name and the field
# `new_file_path`, the file will be renamed.
#
# Please be careful about not messing with the syntax; you should stick
# to the TOML 1.0.0 specification (https://toml.io/en/v1.0.0).
#
# If you realized that you do not want to continue, just remove
# *all* the lines in this file.

""".fmt)

  for curEntry in entries.values:
    let checksumLine = if writeChecksums and curEntry.checksum.isSome:
      """checksum_DONOTCHANGE = "{curEntry.checksum.get()}"
""".fmt
    else:
      ""

    outFile.writeLine("""
[[file_entry]]
{checksumLine}original_file_path_DONOTCHANGE = "{sanitizeToml(curEntry.oldFileName)}"
# Length of this track: {curEntry.length} seconds
new_file_path = "{sanitizeToml(curEntry.newFileName)}"""".fmt)

    if curEntry.title.isSome and curEntry.title.get() != "":
      outFile.writeLine("""title = "{sanitizeToml(curEntry.title.get())}"""".fmt)

    if curEntry.album.isSome and curEntry.album.get() != "":
      outFile.writeLine("""album = "{sanitizeToml(curEntry.album.get())}"""".fmt)

    if curEntry.artist.isSome and curEntry.artist.get() != "":
      outFile.writeLine("""artist = "{sanitizeToml(curEntry.artist.get())}"""".fmt)

    if curEntry.year.isSome and curEntry.year.get() > 0:
      outFile.writeLine("""year = {curEntry.year.get()}""".fmt)

    if curEntry.trackNumber.isSome and curEntry.trackNumber.get() > 0:
      outFile.writeLine("""track_number = {curEntry.trackNumber.get()}""".fmt)

    if curEntry.comment.isSome and curEntry.comment.get() != "":
      outFile.writeLine("""comment = "{sanitizeToml(curEntry.comment.get())}"""".fmt)

    outFile.writeLine("")


proc buildAudioFileItemFromToml*(table: TomlTableRef): AudioFileItem =
  if table.hasKey("checksum_DONOTCHANGE"):
    result.checksum = some(
      sha1.parseSecureHash(table.getString("checksum_DONOTCHANGE"))
    )
  else:
    result.checksum = none[sha1.SecureHash]()

  result.oldFileName = table.getString("original_file_path_DONOTCHANGE")
  result.newFileName = table.getString("new_file_path")

  if table.hasKey("title"):
    result.title = some(table.getString("title"))

  if table.hasKey("album"):
    result.album = some(table.getString("album"))

  if table.hasKey("artist"):
    result.artist = some(table.getString("artist"))

  if table.hasKey("year"):
    result.year = some(uint(table.getInt("year")))

  if table.hasKey("track_number"):
    result.trackNumber = some(uint(table.getInt("track_number")))

  if table.hasKey("comment"):
    result.comment = some(table.getString("comment"))


proc readMetadataFromFile*(f: File): OrderedTableRef[string, AudioFileItem] =
  let contents = parsetoml.parseFile(f)

  result = newOrderedTable[string, AudioFileItem]()

  var idx = 0
  while true:
    let curEntry = getValueFromFullAddr(contents, "file_entry[{idx}]".fmt)
    if curEntry.kind == TomlValueKind.None:
      break

    doAssert(curEntry.kind == TomlValueKind.Table)

    let newItem = buildAudioFileItemFromToml(curEntry.tableVal)
    result[newItem.oldFileName] = newItem

    inc(idx)


proc readMetadataFromFileName*(fileName: string): OrderedTableRef[string, AudioFileItem] =
  let f = open(fileName, fmRead)
  defer: f.close()

  result = readMetadataFromFile(f)


template changeItem(fileElem: untyped, itemElem: untyped, voidValue: untyped, preserveMetadata: bool) =
  if itemElem.isSome:
    fileElem = itemElem.get()
  elif not preserveMetadata:
    fileElem = voidValue


proc applyChanges*(metadata: OrderedTableRef[string, AudioFileItem], preserveMetadata: bool) =
  for key, item in metadata:
    # Check that the file has not been changed since the
    # metadata were retrieved
    if item.checksum.isSome:
      doAssert item.checksum.get() == secureHashFile(item.oldFileName)

    let mustCopyFile = item.newFileName != item.oldFileName
    if mustCopyFile:
      stderr.writeLine("moving \"{item.oldFileName}\" to \"{item.newFileName}\"".fmt)

      # Make sure that the parent directory exists, otherwise create it
      createDir(parentDir(item.newFileName))
      copyFile(source = item.oldFileName, dest = item.newFileName)

    block:
      var curFile = try:
        taglib.open_unknown(item.newFileName)
      except IOError:
        stderr.write("unable to read file \"{item.newFileName}\"".fmt)
        raise

      defer: curFile.close()

      changeItem(
        fileElem = curFile.title,
        itemElem = item.title,
        voidValue = "",
        preserveMetadata = preserveMetadata,
      )
      changeItem(
        fileElem = curFile.album,
        itemElem = item.album,
        voidValue = "",
        preserveMetadata = preserveMetadata,
      )
      changeItem(
        fileElem = curFile.artist,
        itemElem = item.artist,
        voidValue = "",
        preserveMetadata = preserveMetadata,
      )
      changeItem(
        fileElem = curFile.year,
        itemElem = item.year,
        voidValue = 0,
        preserveMetadata = preserveMetadata,
      )
      changeItem(
        fileElem = curFile.track,
        itemElem = item.trackNumber,
        voidValue = 0,
        preserveMetadata = preserveMetadata,
      )
      changeItem(
        fileElem = curFile.comment,
        itemElem = item.comment,
        voidValue = "",
        preserveMetadata = preserveMetadata,
      )

      curFile.save()

    if mustCopyFile:
      if not tryRemoveFile(item.oldFileName):
        warn("unable to delete file \"{item.oldFileName}\"".fmt)


proc readMetadataAndApplyChanges(
  tomlFile : string, 
  preserveMetadata : bool,
) =
  try:
    let metadata = readMetadataFromFileName(tomlFile)
    metadata.applyChanges(preserveMetadata = preserveMetadata)
  except TomlError:
    let errorMessage = getCurrentExceptionMsg()
    let location = (ref TomlError)(getCurrentException()).location
    stderr.writeLine("""error in TOML file {tomlFile}, fix it and then run

    audiotagedit --set-only --toml-file={tomlFile}

{tomlFile}:{location.line}:{location.column}: {errorMessage}
""".fmt)
    quit(1)

proc randomTomlFileName(): string =
  result = joinpath(getTempDir(), `$`(genOid()) & ".toml")


proc fullPath(path: string): string =
  if fileExists(path):
    return path

  result = findExe(path)
  if path != "":
    return path

  stderr.writeLine("unable to find \"{path\"".fmt(path))
  quit(1)


proc findEditor(): string =
  for key in ["AUDIOTAG_EDITOR", "VISUAL", "EDITOR"]:
    if existsEnv(key):
      return fullPath(getEnv(key))

  # If we reached this point, it means that there are no environment variables
  # that can help us, so we must guess

  for editor in ["sensible-editor", "micro", "mcedit", "nano", "pico", "vim", "vi", "edit"]:
    let editorPath = findExe(editor)
    if editorPath != "":
      return editorPath

  stderr.write("error, no suitable editor was found")
  quit(1)


when isMainModule:
  const cliHelp = """
Modify the tags of many audio files at once using your favourite editor

Usage:
  audiotagedit [--no-checksums --preserve-tags --toml-file=<path> --editor=<path>] [--] <file>...
  audiotagedit --get-only [--no-checksums --toml-file=<path>] <file>...
  audiotagedit --set-only --toml-file=<path> [--preserve-tags]
  audiotagedit (-h | --help)
  audiotagedit --version

Options:
  -h --help           Print this help
  --version           Print version information
  --no-checksums      Do not compute nor verify checksums
  --toml-file=<path>  Set the path of the TOML file to create/read
  --get-only          Only read the metadata and save the TOML file
  --set-only          Take an existing TOML instead of generating one
  --preserve-tags     Do not delete those tags that have been removed from the TOML
  --editor=<path>     Path to the executable used to edit the TOML file.
                      If not specified, the value of the environment variables
                      AUDIOTAG_EDITOR, VISUAL, EDITOR will be checked in turn.
                      If no variable is set, a sensible default will be used.
"""

  let args = docopt(
    cliHelp,
    help=true, 
    version="audiotagedit {version}".fmt,
  )

  if args["--get-only"]:
    var originalEntries = retrieveMetadata(@(args["<file>"]))

    let filePath = if args["--toml-file"]:
      $(args["--toml-file"])
    else:
      randomTomlFileName()

    writeMetadataToFile(
      filePath, 
      originalEntries, 
      writeChecksums=not args["--no-checksums"],
    )
    stdout.writeLine(filePath)
  elif args["--set-only"]:
    let tomlFile = $(args["--toml-file"])

    readMetadataAndApplyChanges(tomlFile, preserveMetadata = args["--preserve-tags"])
  else:
    let editor = if args["--editor"]:
      $(args["--editor"])
    else:
      findEditor()

    var originalEntries = retrieveMetadata(@(args["<file>"]))

    let tomlFile = if args["--toml-file"]:
      $(args["--toml-file"])
    else:
      randomTomlFileName()

    writeMetadataToFile(
      tomlFile, 
      originalEntries, 
      writeChecksums=not args["--no-checksums"],
    )

    if execCmd("{editor} \"{tomlFile}\"".fmt) != 0:
      stderr.writeLine("the editor had an error, aborting")
      quit(1)

    readMetadataAndApplyChanges(tomlFile, preserveMetadata = args["--preserve-tags"])
