class_name LocalBackend
extends MetaBackend
## Offline implementation of the meta seam: the account is the local player, decks
## live in the local profile, ranked rating is a small user:// file. Lets the whole
## game run (incl. ranked maths) with no server, and doubles as the reference the
## NakamaBackend must match. Matchmaking here is manual direct-connect (Net.host /
## Net.join). See docs/multiplayer-plan.md.

const RATING_PATH := "user://rating.json"


func login(username: String) -> Dictionary:
	return { "ok": true, "user_id": "local:%s" % username }


func load_profile() -> Dictionary:
	return Game.profile


func save_decks(decks: Array) -> void:
	Game.profile.decks = decks.duplicate(true)
	Game.save_profile()


func rating() -> Dictionary:
	if FileAccess.file_exists(RATING_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(RATING_PATH))
		if data is Dictionary and data.has("rating"):
			return data
	return Ranking.new_rating()


func report_result(score: float, opponent_rating: Dictionary) -> Dictionary:
	var updated := Ranking.update(rating(), [{
		"rating": opponent_rating.get("rating", 1500.0),
		"rd": opponent_rating.get("rd", 350.0),
		"score": score,
	}])
	var f := FileAccess.open(RATING_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(updated, "\t"))
		f.close()
	return updated


func leaderboard(_top := 20) -> Array:
	var r := rating()
	return [{ "name": "Vous", "rating": int(round(float(r.rating))) }]
