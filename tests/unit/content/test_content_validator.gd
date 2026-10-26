extends GutTest
## ContentValidator が各種の違反を検出できること（わざと壊したコンテンツで失敗すること）。

var _lib: ContentLibrary


func before_each() -> void:
	_lib = ContentFixture.valid_library()


func _errors() -> PackedStringArray:
	return ContentValidator.new().validate(_lib).errors


func _assert_error_contains(fragment: String) -> void:
	var errors := _errors()
	var hit := false
	for e in errors:
		if fragment in e:
			hit = true
	assert_true(hit, "expected an error containing '%s', got:\n%s" % [fragment, "\n".join(errors)])


func test_fixture_is_valid() -> void:
	var errors := _errors()
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_duplicate_id() -> void:
	_lib.cards.append(ContentFixture.attack_card(&"strike", 9))
	_assert_error_contains("duplicate card id 'strike'")


func test_bad_id_format() -> void:
	_lib.cards[0].id = &"Strike"
	_assert_error_contains("lower_snake_case")


func test_placeholder_without_label() -> void:
	_lib.cards[0].text = "{damage} ダメージ、{block} ブロック"
	_assert_error_contains("{block} has no matching effect label")


func test_label_not_used_in_text() -> void:
	_lib.cards[0].text = "ダメージを与える。"
	_assert_error_contains("label 'damage' is not used")


func test_aim_mismatch() -> void:
	_lib.cards[0].aim = CardData.Aim.NONE
	_assert_error_contains("ChosenTarget but aim is not ENEMY")


func test_chosen_target_in_trigger() -> void:
	_lib.cards[0].on_discard.append(ContentFixture.damage(3, ChosenTarget.new(), &""))
	_assert_error_contains("trigger effects")


func test_required_field_null() -> void:
	(_lib.cards[0].on_play[0] as DamageEffect).amount = null
	_assert_error_contains("DamageEffect.amount must not be null")


func test_null_entry_in_array() -> void:
	_lib.cards[0].on_play.append(null)
	_assert_error_contains("null entry")


func test_reference_not_in_index() -> void:
	var stray := ContentFixture.attack_card(&"stray", 1)
	_lib.cards[0].upgraded = stray
	_assert_error_contains("not in the content index")


func test_upgrade_cycle() -> void:
	var plus := ContentFixture.attack_card(&"strike_plus", 9)
	_lib.cards.append(plus)
	_lib.cards[0].upgraded = plus
	plus.upgraded = _lib.cards[0]
	_assert_error_contains("upgrade chain has a cycle")
	plus.upgraded = null  # RefCounted の循環参照を切ってリークを防ぐ


func test_missing_keyword_data() -> void:
	_lib.keywords = _lib.keywords.filter(func(k: KeywordData) -> bool: return k.kind != KeywordData.Kind.EXHAUST)
	_lib.cards[0].keywords = CardData.Keyword.EXHAUST
	_assert_error_contains("no KeywordData")


func test_stateful_block() -> void:
	_lib.cards[0].on_play.append(StatefulTestEffect.new())
	_assert_error_contains("non-exported member 'counter'")


func test_enemy_opening_unknown_move() -> void:
	(_lib.enemies[0].ai as ScriptedAI).opening.append(&"nope")
	_assert_error_contains("unknown move 'nope'")


func test_duplicate_move_id() -> void:
	_lib.enemies[0].moves.append(_lib.enemies[0].moves[0].duplicate())
	_assert_error_contains("duplicate move id 'bite'")


func test_status_text_placeholder() -> void:
	_lib.statuses[0].text = "{amount} 減る"
	_assert_error_contains("{amount}")


func test_act_without_boss() -> void:
	_lib.acts[0].bosses.clear()
	_assert_error_contains("has no bosses")


func test_missing_config() -> void:
	_lib.config = null
	_assert_error_contains("RunConfig is missing")
