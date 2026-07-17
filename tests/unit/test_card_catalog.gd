extends TestCase
## Catalog integrity and regression checks for the July 2026 card expansion.

const EXPANSION_IDS := [
	"volcano_oracle", "volcanic_insight",
	"mycelium_warden", "bark_renewal",
	"veil_executioner", "grave_bargain",
	"solar_vigil", "dawn_psalm",
	"ember_sentinel", "lava_skirmisher", "cinder_alchemist", "pyre_colossus", "smoke_duelist",
	"molten_surge", "forge_rite", "wildfire_burst", "ember_reckoning",
	"mosswarden", "thorn_whisperer", "canopy_hunter", "root_titan", "bloom_vanguard",
	"seed_surge", "verdant_blessing", "canopy_shield", "moonbloom", "living_grove",
	"void_hound", "umbra_knight", "grave_sibyl", "dusk_reaver",
	"sepulchral_mark", "night_veil", "black_tribute", "abyssal_hex", "grave_fog",
	"sunward_lancer", "halo_medic", "prism_archon", "dawn_paladin", "temple_sentinel", "auric_phoenix",
	"blessing_ray", "sanctified_aegis", "sunrise_liturgy", "radiant_pulse",
]

const EXPECTED_TOTAL_CARDS := 184
const EXPECTED_GUILD_COUNTS := {
	"flame": 46,
	"sylvan": 46,
	"shadow": 46,
	"light": 46,
}


func _cards() -> Array:
	var file := FileAccess.open("res://resources/data/cards.json", FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed.get("cards", []) if parsed is Dictionary else []


func _signature(card: Dictionary) -> String:
	# Cosmetic identity and guild are deliberately excluded: two cards in
	# different guilds must not share the exact same gameplay profile either.
	var gameplay := {
		"kind": card.get("kind"),
		"cost": card.get("cost"),
		"attack_type": card.get("attack_type"),
		"levels": card.get("levels", []),
		"keywords": card.get("keywords", {}),
		"effect": card.get("effect", []),
		"on_summon": card.get("on_summon", []),
		"on_attack": card.get("on_attack", []),
		"on_death": card.get("on_death", []),
		"evolves_to": card.get("evolves_to"),
		"evolve_cost": card.get("evolve_cost"),
		"token": card.get("token", false),
	}
	return JSON.stringify(gameplay, "", true)


func test_catalog_has_no_duplicate_ids_or_names() -> void:
	var ids := {}
	var names := {}
	for card in _cards():
		var id := String(card.get("id", ""))
		var card_name := String(card.get("name", ""))
		ok(not ids.has(id), "identifiant de carte dupliqué : %s" % id)
		ok(not names.has(card_name), "nom de carte dupliqué : %s" % card_name)
		ids[id] = true
		names[card_name] = true


func test_catalog_reaches_one_hundred_and_stays_balanced() -> void:
	var cards := _cards()
	eq(cards.size(), EXPECTED_TOTAL_CARDS, "le catalogue doit atteindre 184 cartes")
	var guild_counts := {
		"flame": 0,
		"sylvan": 0,
		"shadow": 0,
		"light": 0,
	}
	var kind_counts := {
		"monster": 0,
		"spell": 0,
	}
	for card in cards:
		var guild := String(card.get("guild", ""))
		var kind := String(card.get("kind", ""))
		if guild_counts.has(guild):
			guild_counts[guild] += 1
		if kind_counts.has(kind):
			kind_counts[kind] += 1
	for guild in EXPECTED_GUILD_COUNTS:
		eq(guild_counts[guild], EXPECTED_GUILD_COUNTS[guild], "répartition de guilde %s" % guild)
	eq(kind_counts["monster"], 128, "répartition des monstres")
	eq(kind_counts["spell"], 56, "répartition des sorts")


func test_expansion_has_no_gameplay_duplicates() -> void:
	var cards := _cards()
	for card in cards:
		if String(card.get("id", "")) not in EXPANSION_IDS:
			continue
		var signature := _signature(card)
		for other in cards:
			if other == card:
				continue
			ne(_signature(other), signature,
					"%s duplique le profil de %s" % [card.id, other.id])


func test_expansion_assets_are_complete() -> void:
	var cards_by_id := {}
	for card in _cards():
		cards_by_id[String(card.id)] = card
	for id in EXPANSION_IDS:
		ok(cards_by_id.has(id), "définition manquante : %s" % id)
		ok(FileAccess.file_exists("res://assets/sprites/cards/%s.png" % id),
				"illustration manquante : %s" % id)
		ok(FileAccess.file_exists("res://assets/sprites/cards_full/%s.png" % id),
				"carte composée manquante : %s" % id)
		if cards_by_id.has(id) and cards_by_id[id].get("kind") == "monster":
			ok(FileAccess.file_exists("res://assets/sprites/units/%s.png" % id),
					"sprite d'unité manquant : %s" % id)


func test_expansion_balance_regression() -> void:
	var cards_by_id := {}
	for card in _cards():
		cards_by_id[String(card.id)] = card
	var expected := {
		"volcano_oracle": [4.0, 2.0, 5.0],
		"mycelium_warden": [3.0, 1.0, 6.0],
		"veil_executioner": [3.0, 4.0, 2.0],
		"solar_vigil": [4.0, 3.0, 4.0],
	}
	for id in expected:
		var card: Dictionary = cards_by_id.get(id, {})
		ok(not card.is_empty(), "carte d'équilibrage manquante : %s" % id)
		if card.is_empty():
			continue
		var level: Dictionary = card.levels[0]
		eq(card.cost, expected[id][0], "%s coût" % id)
		eq(level.atk, expected[id][1], "%s ATQ" % id)
		eq(level.hp, expected[id][2], "%s PV" % id)
