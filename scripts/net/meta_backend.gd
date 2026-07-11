class_name MetaBackend
extends RefCounted
## Abstract meta-service seam: accounts, server-side collection/decks, matchmaking,
## and the ranked leaderboard. The game talks only to this interface.
##
## LocalBackend implements it offline (single machine); a NakamaBackend (Phases
## 2-4) will implement it against a hosted Nakama server without the game code
## changing. See docs/multiplayer-plan.md.


## Authenticate. Returns { ok, error?, user_id? }.
func login(_username: String) -> Dictionary:
	return { "ok": false, "error": "backend non implémenté" }


## The account's profile (collection, decks, progression). Empty if none.
func load_profile() -> Dictionary:
	return {}


## Persist the account's decks (server-authoritative in competitive).
func save_decks(_decks: Array) -> void:
	pass


## This account's ranked rating { rating, rd, vol }.
func rating() -> Dictionary:
	return Ranking.new_rating()


## Report a finished RANKED match against `opponent_rating` and return the new
## rating (already persisted). `score` is 1 win / 0.5 draw / 0 loss.
func report_result(score: float, opponent_rating: Dictionary) -> Dictionary:
	return Ranking.update(rating(), [{
		"rating": opponent_rating.get("rating", 1500.0),
		"rd": opponent_rating.get("rd", 350.0),
		"score": score,
	}])


## Top ranked entries: Array of { name, rating }.
func leaderboard(_top := 20) -> Array:
	return []
