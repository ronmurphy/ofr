class_name BuildInfo
extends RefCounted

## Which build this is, so a screenshot can be traced back to a commit.
##
## STAMPED AT EXPORT TIME by tools/stamp_build.sh and put back immediately
## after, so this file reads "dev" in a working tree and carries a real version
## only inside a shipped binary. That is deliberate rather than awkward:
## committing the stamp would mean a commit containing its own hash, which
## cannot be done.
##
## DERIVED FROM GIT RATHER THAN COUNTED IN A FILE, and that is the whole design.
## A counter incremented by each build script would give three different
## versions to the three exports of identical code, depending on what order
## they were run in -- and it would tick over on every local test build, so the
## number would name nothing you could look up. `git rev-list --count HEAD` is
## a real monotonic build number that all three scripts compute identically
## from the same commit. Nothing needs synchronising because nothing is bumped.
##
## A trailing "+" means the tree had uncommitted changes when it was built, so
## the hash beside it does NOT describe what is running.
##
## "dev" is information, not a failure: it says this binary was run straight
## from a working tree rather than built, which is exactly what you want to
## know when somebody reports a bug against it.
const BUILD := "dev"
