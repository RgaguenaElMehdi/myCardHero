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
	var prev := rating()
	var updated := Ranking.update(prev, [{
		"rating": opponent_rating.get("rating", 1500.0),
		"rd": opponent_rating.get("rd", 350.0),
		"score": score,
	}])
	# Bilan victoires/défaites + série en cours (affichés dans le hub Arène).
	updated["wins"] = int(prev.get("wins", 0)) + (1 if score >= 1.0 else 0)
	updated["losses"] = int(prev.get("losses", 0)) + (1 if score <= 0.0 else 0)
	updated["streak"] = int(prev.get("streak", 0)) + 1 if score >= 1.0 else 0
	var f := FileAccess.open(RATING_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(updated, "\t"))
		f.close()
	return updated


## Paliers de rang [nom, cote min, cote max] — divisions I-III par tranche de 50.
const TIERS := [
	["BRONZE", 0.0, 1300.0],
	["ARGENT", 1300.0, 1450.0],
	["OR", 1450.0, 1600.0],
	["PLATINE", 1600.0, 1750.0],
	["DIAMANT", 1750.0, 1900.0],
	["MAÎTRE", 1900.0, 99999.0],
]


## Teinte d'affichage du blason par palier (le blason généré est argent clair).
const TIER_COLORS := {
	"BRONZE": Color(0.85, 0.55, 0.32),
	"ARGENT": Color(0.92, 0.96, 1.05),
	"OR": Color(1.15, 0.92, 0.45),
	"PLATINE": Color(0.5, 1.05, 0.9),
	"DIAMANT": Color(0.5, 0.72, 1.15),
	"MAÎTRE": Color(0.95, 0.5, 1.1),
}


static func tier_of(rating: float) -> Array:
	for t in TIERS:
		if rating < float(t[2]):
			return t
	return TIERS[-1]


## Nom du palier affiché pour une cote Glicko-2 (hub Arène).
## Divisions I-III sur les 150 derniers points du palier (comportement historique).
static func rank_name(r: float) -> String:
	for t in TIERS:
		if String(t[0]) == "MAÎTRE":
			break
		if r < float(t[2]):
			var base := maxf(float(t[1]), float(t[2]) - 150.0)
			var span := (float(t[2]) - base) / 3.0
			var div := 3 - int(clampf((r - base) / span, 0.0, 2.999))
			return "%s %s" % [t[0], ["", "I", "II", "III"][div]]
	return "MAÎTRE"


func leaderboard(_top := 20) -> Array:
	var r := rating()
	return [{ "name": "Vous", "rating": int(round(float(r.rating))) }]
