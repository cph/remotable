# Changelog

### 0.7.0
* **Bugfix** Ensured ActiveRecord models were using Nosync's `ClassMethods` instead of the non-threadsafe `InstanceMethods`

### 0.6.4
* **Feature** Added `Remotable.unsafe_nosync!` method to set `nosync` globally using a class variable. As the method name indicates, this is not threadsafe and should only be used for testing or other situations where thread safety is not an issue.
* **Bugfix** Stopped deferring to `Thread.main` if `nosync` was unset on the current thread; while convenient for tests (see above), it ended up allowing requests to leak state if they were handled on the main thread.


### 0.6.3
* **Fix** Replaced deprecated calls to URI.escape

### 0.6.2
* ~~**Bugfix** Replaced deprecated calls to URI.escape~~ _Pulled_

### 0.6.1
* **Bugfix** Tweaked the behavior of `Remotable.nosync?` to defer to a value set on the main thread if no value has been set for the current thread.

### 0.6.0
* **Bugfix** Completely removed dependence on `activeresource`'s `ThreadsafeAttributes`. This makes multithreaded behavior more deterministic and involves fewer edgecases, since things meant to be global state are reverted back to being so, while things meant to have a per-thread scope are constrained as they should be.

### 0.5.1
* **Bugfix** Addressed an issue where `Remotable.with_remote_model` could leave a model with the wrong `remote_model` when used in a multithreaded environment.

***

_TODO: Backfill for previous releases_
