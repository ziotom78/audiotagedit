---
title: "audiotagedit"
section: 1
header: "User manual"
footer: "audiotagedit"
date: "October 2021"
---

# NAME

*audiotagedit* – modify audio tags from the command line using your favourite editor


# SYNOPSIS

**audiotagedit** [**--no-checksums**] [**--preserve-tags**] [**--toml-file**=*path*] [**--editor**=*path*] [**--**] *file*...

**audiotagedit** **--get-only** [**--no-checksums** **--toml-file**=*path*] *file*...

**audiotagedit** **--set-only** **--toml-file**=*path* [**--preserve-tags**]

**audiotagedit** (**-h** | **--help**)

**audiotagedit** **--version**


# DESCRIPTION

*audiotagedit* is a command-line program that implements a command-line pipeline to add/modify/remove audio tags in audio files:

1. It reads tags from a set of audio files and saves them in a TOML file.
2. It starts a visual editor to allow the user to add/modify/remove the tags
3. Once the file is saved and the editor is closed, the new tags are written back into the audio files.

The program can also rename files, if a new name is supplied in the TOML. *audiotagedit* uses the [`TagLib`](https://taglib.org/) library and can read/write tags from MP3, OGG, FLAC files, as well as any other format supported by TagLib.

The TOML file format is documented at https://toml.io/en/.

The editor used by *audiotagedit* can be changed via the environment variables `AUDIOTAG_EDITOR`, `VISUAL`, or `EDITOR` (in this order), or through the command-line parameter **--editor**.

The workflow can be customized using the flags **--get-only** and **--write-only**: the flag **--get-only** instructs the program to run step 1 above and then stops, printing the name of the TOML file to *stdout*. The flag **--set-only** can be used to read a TOML file and apply the modifications to the files specified in the TOML itself. In both cases, no editor is executed. Thus, an invocation like this:

    audiotagedit --toml-file=tags.toml *.mp3

is equivalent to this sequence of commands:

    TOML_FILE=$(audiotagedit --get-only *.mp3)
    edit $(TOML_FILE)
    audiotagedit --set-only --toml-file=$(TOML_FILE)

The advantage of the latter approach is that you have more freedom in editing the TOML file: for instance, the program that modifies the TOML file might require a complex command line, or you need to call several scripts that process the TOML in various way before writing the tags back to the files. An interesting possibility is to use *audiotagedit* in conjunction with programs that create audio files from scratch, like [`LilyPond`](http://lilypond.org/) and [TiMidity](http://timidity.sourceforge.net/), to programmatically set up the tags for the newly-created files. 


# FILE FORMAT

The files produced by *audiotagedit* adhere to the TOML file format (https://toml.io/en/). They implement list of entries with name `file_entry`, each containing the following keys:

-   **original_file_path_DONOTCHANGE**: the original path of the file. Don't change this!
-   **checksum_DONOTCHANGE**: the SHA1 checksum of the file. This is skipped if you used the command-line switch **--no-checksum**
-   **new_file_path** (a string): the new path of the file
-   **title** (a string): the title of the song
-   **album** (a string): the name of the album containing the song
-   **artist** (a string): the name of the composer/performer/artist associated with the song
-   **year** (a integer): the year when the song was composed/recorded/released/ripped
-   **track_number** (a integer): the number of the track containing the song, starting from 1
-   **comment** (a string): free-form comment

When the editor closes and the TOML file is re-read, *audiotagedit* checks that the checksum of the file is still the same: if not, it means that the file was changed while the user was editing the TOML file, and thus the program aborts. If no checksum is present in the TOML file, this check is skipped; this is the usual case when you are using **--set-only** to tag newly-created audio files.

If you change the value of **new_file_path**, the file will be renamed; you can provide a different directory, and the path will be created if it does not already exist.

Here is an example of a valid TOML file:

    [[file_entry]]
    checksum_DONOTCHANGE = "BD6BEA01F359743CBA8B224E658FB2947097F3E8"
    original_file_path_DONOTCHANGE = "track01.mp3"
    new_file_path = "track01.mp3"
    title = "Quartet KV 464: Allegro"
    album = "String quartets KV 464 and KV465"
    artist = "Wolfgang Amadeus Mozart"
    comment = "LAME settings: VBR(q=2) qval"

    [[file_entry]]
    checksum_DONOTCHANGE = "0EE64F638642EA30A85BBB672FABAD8C59C716E6"
    original_file_path_DONOTCHANGE = "track02.mp3"
    new_file_path = "track02.mp3"
    title = "Quartet KV 464: Menuetto and trio"
    album = "String quartets KV 464 and KV465"
    artist = "Wolfgang Amadeus Mozart"
    comment = "LAME settings: VBR(q=2) qval"


# OPTIONS

**-h**, **--help**
: display a help message

**--version**
: prints version information to *stdout*

**--no-checksums**
: Do not output file checksums in the TOML nor check them

**--preserve-tags**
: If you remove a tag from the TOML, it will not be removed from the audio file.

**--toml-file**=*path*
: Specify the name of the TOML file to read/write. If you do not provide this, the program will pick a random name in a temporary directory.

**--editor**=*path*
: Specify the editor to be used to modify the TOML file. You can either specify a full path to the executable, or the name of the executable alone; in the latter case, it will be searched in the **PATH** environment variable. If no editor is provided, one of the environment variables listed under the **ENVIRONMENT** section will be searched for a list of commonly-used editors. If no editors are found, the programm will exit with an error.

**--get-only**
: After having created the TOML file, the program will print the name of the file on *stdout* and then quit. You can then pass this file to the program using the flag **--set-only** to resume the operation.

**--set-only**
: Instead of creating a TOML file from a set of files, read the TOML file from disk and apply the tags. This option can be used to resume operations after having used **--get-only** or to programmatically set tags for files starting from a handwritten/generated TOML file.

**--**:
: Used to mark the beginning of the list of audio files. It is required whenever the name of one of the files begins with **--** (this is very unusual!).


# ENVIRONMENT VARIABLES

**AUDIOTAG_EDITOR**, **VISUAL**, **EDITOR**
: Name of the editor to use. The environment variables are searched in the order specified above.


# RETURN VALUE

0
: Success

1
: Error


# LICENSE

The program is released under a MIT license.

# HISTORY

The first version of this program was released in October 2021. The author was inspired by *vorbistagedit*, by Martin F. Krafft.
