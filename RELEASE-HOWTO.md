# How to release a new version

-   Update the version number in `audiotagedit.nimble`
-   Update the version number in `manpage.md`
-   Commit your modifications
-   Run the following commands:

    ```
    git tag vX.Y.Z
    git push origin vX.Y.Z
    ```

-   Open the GitHub release page and write down a description of the release, possibly including stuff from `CHANGELOG.md`
