class_name TestCase
extends RefCounted
## Minimal test base: assertion helpers accumulating failures.
## Test scripts live in tests/unit/, extend TestCase and define test_* methods.

var failures: Array[String] = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(got, want, label: String = "") -> void:
	if got != want:
		failures.append("%s — attendu %s, obtenu %s" % [label, want, got])


func ne(got, not_want, label: String = "") -> void:
	if got == not_want:
		failures.append("%s — ne devait pas valoir %s" % [label, not_want])


## Asserts that a Rules.apply result succeeded.
func applied(res: Dictionary, label: String = "") -> void:
	if not res.ok:
		failures.append("%s — action refusée : %s" % [label, res.error])


## Asserts that a Rules.apply result was rejected.
func rejected(res: Dictionary, label: String = "") -> void:
	if res.ok:
		failures.append("%s — l'action aurait dû être refusée" % label)


## True if events contain an event with matching "e" field.
func has_event(events: Array, e_name: String) -> bool:
	for ev in events:
		if ev.get("e") == e_name:
			return true
	return false
