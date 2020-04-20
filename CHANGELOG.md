# Changelog

### 0.6.2
* **Fix** Replace obsolete call to URI.escape with CGI.escape

### 0.6.1
* **Bugfix** Tweaked the behavior of `Remotable.nosync?` to defer to a value set on the main thread if no value has been set for the current thread.

### 0.6.0
* **Bugfix** Completely removed dependence on `activeresource`'s `ThreadsafeAttributes`. This makes multithreaded behavior more deterministic and involves fewer edgecases, since things meant to be global state are reverted back to being so, while things meant to have a per-thread scope are constrained as they should be.

### 0.5.1
* **Bugfix** Addressed an issue where `Remotable.with_remote_model` could leave a model with the wrong `remote_model` when used in a multithreaded environment.

***

_TODO: Backfill for previous releases_
