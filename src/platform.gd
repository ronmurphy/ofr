class_name Platform
extends RefCounted

## The single place that knows whether this build is running in a browser.
##
## There is no second codebase and no `#ifdef`. The web build is the same
## project, the same scene and the same simulation; three things behave
## differently and they are all here:
##
##   1. A browser tab cannot be quit. Offering "save and quit" there would put
##      a button in the menu that leaves a dead canvas sitting in the page.
##   2. Ctrl+W is one keystroke from destroying a run, and the browser will not
##      let the canvas capture it. So we ask the browser to ask first.
##   3. Closing a tab is an accident in a way that closing an application is
##      not, so the suspend slot is written when the page goes away.
##
## Point 3 is the one that changes a design decision, so it is worth being
## clear about what it does NOT change: it is still one slot, it is still
## destroyed the moment it is loaded, and there is still no way to roll back a
## bad fight. All it does is stop the browser being able to take a run away
## from you in a way the desktop build never could.

static var _guarded := false

static func is_web() -> bool:
	return OS.has_feature("web")

## Whether this build can meaningfully exit. Everywhere but a browser, yes.
static func can_quit() -> bool:
	return not is_web()

## Asks the browser to confirm before the page goes away.
##
## Browsers deliberately ignore this until the player has interacted with the
## page, which costs us nothing: you cannot have a run in progress without
## having pressed a key.
static func guard_against_leaving(on: bool) -> void:
	if not is_web() or on == _guarded:
		return
	_guarded = on
	if on:
		JavaScriptBridge.eval("""
			window.__ofr_guard = function (e) {
				e.preventDefault();
				e.returnValue = '';
				return '';
			};
			window.addEventListener('beforeunload', window.__ofr_guard);
		""", true)
	else:
		JavaScriptBridge.eval("""
			if (window.__ofr_guard) {
				window.removeEventListener('beforeunload', window.__ofr_guard);
				window.__ofr_guard = null;
			}
		""", true)

## Calls `handler` whenever the page is hidden -- switching tabs, minimising,
## or closing.
##
## `visibilitychange` rather than `beforeunload` on purpose. Writes to `user://`
## land in IndexedDB, which flushes asynchronously; beforeunload gives it no
## time to finish, while hiding a tab happens long before the page is torn
## down. Hooking the earlier event is the difference between a save that is
## written and a save that was started.
##
## Returns the callback, which the caller MUST hold a reference to -- a
## JavaScriptObject that goes out of scope is collected, and the listener then
## fires into nothing. That failure is silent and only shows up as a lost run.
static func on_page_hidden(handler: Callable) -> Variant:
	if not is_web():
		return null
	var cb := JavaScriptBridge.create_callback(func(_args): 
		var doc := JavaScriptBridge.get_interface("document")
		if doc != null and bool(doc.hidden):
			handler.call()
	)
	var win := JavaScriptBridge.get_interface("window")
	if win == null:
		return null
	win.addEventListener("visibilitychange", cb)
	return cb
