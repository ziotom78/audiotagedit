import options
import oids
import os
import tables
import std/sha1

import ../src/audiotagedit

const fileNames = [
    joinpath("tests", "silence-id3v1.mp3"),
    joinpath("tests", "silence-id3v2.mp3"),
    joinpath("tests", "silence.ogg"),
]

proc testRetrieveMetadata() =
    let metadata = retrieveMetadata(fileNames)

    # Check that all the files have been hashed
    doAssert metadata.len == 3
    doAssert fileNames[0] in metadata
    doAssert fileNames[1] in metadata
    doAssert fileNames[2] in metadata

    let entry1 = metadata[fileNames[0]]
    let entry2 = metadata[fileNames[1]]
    let entry3 = metadata[fileNames[2]]

    # Check that the metadata were read correctly
    doAssert entry1.title.get() == "This is the so-called \"song\" t"
    doAssert entry2.title.get() == "This is the so-called \"song\" title"
    doAssert entry3.title.get() == "This is the song title"

    doAssert entry1.artist.get() == "This is the artist"
    doAssert entry2.artist.get() == "This is the artist"
    doAssert entry3.artist.get() == "This is the artist"

    doAssert entry1.album.get() == "This is the album"
    doAssert not entry2.album.isSome
    doAssert entry3.album.get() == "This is the album"

    doAssert entry1.year.get() == 2019
    doAssert entry2.year.get() == 2020
    doAssert entry3.year.get() == 2021

    doAssert entry1.track_number.get() == 132
    doAssert entry2.track_number.get() == 321
    doAssert entry3.track_number.get() == 123

    doAssert entry1.comment.get() == "This is the comment"
    doAssert entry2.comment.get() == "This is the comment"
    doAssert not entry3.comment.isSome


proc createWritableTestDirectory(): seq[string] =
    let dirName = joinpath(getTempDir(), "audiotagedit_test_" & $genOid())

    result = newSeq[string](len(fileNames))

    createDir(dirName)

    for idx, curFileName in fileNames:
        let destFile = joinpath(
            dirName, 
            extractFileName(curFileName),
        )
        copyFile(
            source=curFileName, 
            dest=destFile,
        )
        result[idx] = destFile


proc testApplyChanges() =
    var destFilenames = createWritableTestDirectory()

    # Step 1: read the metadata from the copies
    var metadata = retrieveMetadata(destFilenames)

    # Step 2: make some changes

    # Change the year
    metadata[destFilenames[0]].year = some(uint(567))

    # Force a file name change
    let newFilename = joinpath(
        parentDir(metadata[destFilenames[1]].oldFileName), 
        "test.mp3",
    )
    metadata[destFilenames[1]].newFileName = newFilename
    destFilenames[1] = newFilename

    metadata.applyChanges(preserveMetadata = false)

    # Step 3: re-read the metadata and check that the
    #         changes have been made
    let newMetadata = retrieveMetadata(destFilenames)
    let entry1 = newMetadata[destFilenames[0]]
    let entry2 = newMetadata[newFilename]
    let entry3 = newMetadata[destFilenames[2]]

    doAssert entry1.title.get() == "This is the so-called \"song\" t"
    doAssert entry2.title.get() == "This is the so-called \"song\" title"
    doAssert entry3.title.get() == "This is the song title"

    doAssert entry1.artist.get() == "This is the artist"
    doAssert entry2.artist.get() == "This is the artist"
    doAssert entry3.artist.get() == "This is the artist"

    doAssert entry1.album.get() == "This is the album"
    doAssert not entry2.album.isSome
    doAssert entry3.album.get() == "This is the album"

    doAssert entry1.year.get() == 567
    doAssert entry2.year.get() == 2020
    doAssert entry3.year.get() == 2021

    doAssert entry1.track_number.get() == 132
    doAssert entry2.track_number.get() == 321
    doAssert entry3.track_number.get() == 123

    doAssert entry1.comment.get() == "This is the comment"
    doAssert entry2.comment.get() == "This is the comment"
    doAssert not entry3.comment.isSome


when isMainModule:
    testRetrieveMetadata()
    testApplyChanges()
