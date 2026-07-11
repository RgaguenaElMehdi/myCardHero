extends TestCase
## Tests de sérialisation du profil joueur.
## Vérifie : round-trip JSON, mismatch de version, ownership de deck,
## structure requise. Pas de dépendance à Game/Db (headless-safe).

const SAVE_VERSION := 1


func _default_profile() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"campaign_progress": 0,
		"collection": {},
		"masters": ["kiran"],
		"decks": [{ "name": "Mon deck", "master": "kiran", "cards": [] }],
		"active_deck": 0,
		"settings": { "music_volume": 0.8, "sfx_volume": 0.9, "fullscreen": false },
	}


func test_profile_has_required_keys() -> void:
	var p := _default_profile()
	for key in ["save_version", "campaign_progress", "collection",
			"masters", "decks", "active_deck", "settings"]:
		ok(p.has(key), "profil par défaut contient '%s'" % key)
	var d: Dictionary = p.get("decks", [])[0]
	for key in ["name", "master", "cards"]:
		ok(d.has(key), "un deck contient '%s'" % key)
	var s: Dictionary = p.get("settings", {})
	for key in ["music_volume", "sfx_volume", "fullscreen"]:
		ok(s.has(key), "settings contient '%s'" % key)


func test_json_roundtrip_scalars() -> void:
	var p := _default_profile()
	p["campaign_progress"] = 7
	p["active_deck"] = 2
	var restored = JSON.parse_string(JSON.stringify(p))
	ok(restored is Dictionary, "parsé comme Dictionary")
	eq(int(restored.get("campaign_progress")), 7, "progress survit au round-trip")
	eq(int(restored.get("active_deck")), 2, "active_deck survit au round-trip")
	eq(int(restored.get("save_version")), SAVE_VERSION, "version conservée")


func test_json_roundtrip_nested() -> void:
	var p := _default_profile()
	p["collection"] = { "grunt": 2, "bolt": 1 }
	p["decks"] = [{ "name": "Aggro", "master": "brand", "cards": ["grunt", "grunt", "bolt"] }]
	p["masters"] = ["kiran", "brand"]
	p["settings"] = { "music_volume": 0.5, "sfx_volume": 0.7, "fullscreen": true }
	var restored = JSON.parse_string(JSON.stringify(p))
	eq(int(restored.get("collection", {}).get("grunt")), 2, "collection imbriquée survit")
	var deck0: Dictionary = restored.get("decks", [])[0]
	eq(str(deck0.get("master")), "brand", "maître du deck survit au round-trip")
	eq(deck0.get("cards", []).size(), 3, "cartes du deck survivent au round-trip")
	ok(bool(restored.get("settings", {}).get("fullscreen")), "fullscreen survit")


## Mirror of game.gd _migrate_legacy_deck: a legacy { deck, active_master } save
## must fold into one deck object carrying its master.
func test_legacy_save_migrates_to_deck() -> void:
	var legacy := {
		"save_version": SAVE_VERSION,
		"deck": ["grunt", "bolt", "bolt"],
		"active_master": "vane",
	}
	var migrated := legacy.duplicate(true)
	if not migrated.has("decks") and (migrated.has("deck") or migrated.has("active_master")):
		migrated["decks"] = [{
			"name": "Mon deck",
			"master": migrated.get("active_master", "kiran"),
			"cards": migrated.get("deck", []),
		}]
		migrated["active_deck"] = 0
	var d: Dictionary = migrated["decks"][0]
	eq(str(d.get("master")), "vane", "l'ancien active_master devient le maître du deck")
	eq(d.get("cards", []).size(), 3, "l'ancien deck devient les cartes du deck")
	eq(int(migrated["active_deck"]), 0, "deck actif = 0 après migration")


func test_version_mismatch_does_not_overwrite() -> void:
	var default_p := _default_profile()
	var stale := _default_profile()
	stale["save_version"] = 0
	stale["campaign_progress"] = 99
	var loaded := default_p.duplicate(true)
	var data = JSON.parse_string(JSON.stringify(stale))
	if data is Dictionary and int(data.get("save_version", 0)) == SAVE_VERSION:
		for key in loaded:
			if data.has(key):
				loaded[key] = data[key]
	eq(int(loaded.get("campaign_progress")), 0,
			"mismatch de version : progress non écrasé")


func test_valid_version_merges_data() -> void:
	var default_p := _default_profile()
	var saved := _default_profile()
	saved["campaign_progress"] = 5
	saved["collection"] = { "bolt": 2 }
	saved["masters"] = ["kiran", "grim"]
	var loaded := default_p.duplicate(true)
	var data = JSON.parse_string(JSON.stringify(saved))
	if data is Dictionary and int(data.get("save_version", 0)) == SAVE_VERSION:
		for key in loaded:
			if data.has(key):
				loaded[key] = data[key]
	eq(int(loaded.get("campaign_progress")), 5,
			"version valide : progress fusionné")
	eq(int(loaded.get("collection", {}).get("bolt")), 2,
			"version valide : collection fusionnée")
	eq(loaded.get("masters", []).size(), 2,
			"version valide : masters fusionnés")


func test_deck_owned_all_present() -> void:
	var collection := { "grunt": 2, "archer": 1 }
	ok(_deck_owned(collection, ["grunt", "grunt", "archer"]),
			"deck entièrement possédé")


func test_deck_owned_missing_card() -> void:
	var collection := { "grunt": 2 }
	ok(not _deck_owned(collection, ["grunt", "bolt"]),
			"carte absente de la collection détectée")


func test_deck_owned_exceeds_count() -> void:
	var collection := { "grunt": 1 }
	ok(not _deck_owned(collection, ["grunt", "grunt"]),
			"copies en excès détectées")


func test_deck_owned_empty() -> void:
	ok(_deck_owned({}, []), "deck vide toujours possédé")


## Réplique exacte de la logique _deck_owned de game.gd (source de vérité).
func _deck_owned(collection: Dictionary, deck: Array) -> bool:
	var counts := {}
	for id in deck:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		if counts[id] > int(collection.get(id, 0)):
			return false
	return true
