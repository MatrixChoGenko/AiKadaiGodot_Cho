extends GutTest
## 図鑑（CompendiumScreen）：載せる範囲・絞り込み・並べ替え・強化版の切り替え・拡大表示。

const SCENE: PackedScene = preload("res://scenes/screens/compendium.tscn")
const T = preload("res://src/presentation/screens/compendium_screen.gd")

var _screen: CompendiumScreen


func before_each() -> void:
	_screen = SCENE.instantiate() as CompendiumScreen
	add_child_autofree(_screen)
	_screen.enter({})


func after_each() -> void:
	await wait_process_frames(2)


func _ids(items: Array) -> Array:
	return items.map(func(r: Resource) -> StringName: return r.get(&"id"))


## カードは強化版を除く全部（初期・状態異常・呪いを含む）。レリック・ポーションは全部。
func test_lists_every_base_card_relic_and_potion() -> void:
	var lib := Content.library
	assert_eq(_screen.total_count(T.Tab.CARDS), lib.base_cards().size())
	assert_eq(_screen.total_count(T.Tab.RELICS), lib.relics.size())
	assert_eq(_screen.total_count(T.Tab.POTIONS), lib.potions.size())
	var shown := _screen.shown_items()
	assert_eq(shown.size(), lib.base_cards().size(), "no filter -> everything")
	for c: CardData in lib.cards:
		if c.upgraded != null:
			assert_false(shown.has(c.upgraded), "upgrade %s is not listed" % c.upgraded.id)
	var types := {}
	for c: CardData in shown:
		types[c.type] = true
	assert_true(types.has(CardData.Type.STATUS) and types.has(CardData.Type.CURSE))


## 同じ列の中は「または」、列どうしは「かつ」。解除で全部に戻る。
func test_filters_combine() -> void:
	_screen.toggle_type_filter(0)   # アタック
	_screen.toggle_type_filter(1)   # スキル
	_screen.toggle_rarity_filter(CardData.Rarity.RARE)
	var shown := _screen.shown_items()
	assert_gt(shown.size(), 0)
	for c: CardData in shown:
		assert_true(c.type in [CardData.Type.ATTACK, CardData.Type.SKILL], c.name)
		assert_eq(c.rarity, CardData.Rarity.RARE, c.name)
	_screen.clear_filters()
	assert_eq(_screen.shown_items().size(), _screen.total_count())


func test_status_and_curse_share_one_type_filter() -> void:
	_screen.toggle_type_filter(3)
	for c: CardData in _screen.shown_items():
		assert_true(c.type in [CardData.Type.STATUS, CardData.Type.CURSE], c.name)


func test_sort_orders() -> void:
	var shown := _screen.shown_items()
	for i in shown.size() - 1:
		assert_true(shown[i].rarity <= shown[i + 1].rarity, "rarity order at %d" % i)
	_screen.set_sort(T.Sort.COST)
	shown = _screen.shown_items()
	for i in shown.size() - 1:
		assert_true(T.cost_key(shown[i]) <= T.cost_key(shown[i + 1]), "cost order at %d" % i)
	_screen.set_sort(T.Sort.NAME)
	shown = _screen.shown_items()
	for i in shown.size() - 1:
		assert_true(shown[i].name <= shown[i + 1].name, "name order at %d" % i)


## 表示している枠の並び = shown_items の順（絞り込みは枠の表示 / 非表示）。
func test_grid_follows_filter_and_sort() -> void:
	_screen.toggle_rarity_filter(CardData.Rarity.STARTER)
	_screen.set_sort(T.Sort.NAME)
	var visible_cards: Array = []
	for view: CardView in _screen._card_views:
		if (view.get_parent() as Control).visible:
			visible_cards.append(view)
	visible_cards.sort_custom(func(a: CardView, b: CardView) -> bool: return a.get_parent().get_index() < b.get_parent().get_index())
	assert_eq(_ids(visible_cards.map(func(v: CardView) -> CardData: return v.data)), _ids(_screen.shown_items()))


## 強化版の表示：強化できるカードだけ面が替わり、一覧の件数は変わらない。
func test_show_upgraded_swaps_only_upgradable_cards() -> void:
	var before := _screen.shown_items().size()
	_screen.set_show_upgraded(true)
	assert_eq(_screen.shown_items().size(), before)
	for view: CardView in _screen._card_views:
		var base: CardData = _screen._data[T.Tab.CARDS][_screen._card_views.find(view)]
		assert_eq(view.data, base.upgraded if base.upgraded != null else base, base.name)
	_screen.set_show_upgraded(false)
	for i in _screen._card_views.size():
		assert_eq(_screen._card_views[i].data, _screen._data[T.Tab.CARDS][i])


## 拡大：強化できるカードは強化前 → 強化後の 2 枚、できないカードは 1 枚。閉じられる。
func test_card_detail_shows_upgrade_pair() -> void:
	var shown := _screen.shown_items()
	var with_up := shown.find_custom(func(c: CardData) -> bool: return c.upgraded != null)
	var without := shown.find_custom(func(c: CardData) -> bool: return c.upgraded == null)
	_screen.open_detail(with_up)
	assert_true(_screen.detail_open())
	var views := _screen.detail_cards()
	assert_eq(views.size(), 2)
	assert_eq(views[1].data, (shown[with_up] as CardData).upgraded)
	_screen.open_detail(without)
	assert_eq(_screen.detail_cards().size(), 1)
	_screen.close_detail()
	assert_false(_screen.detail_open())


func test_relic_and_potion_tabs() -> void:
	_screen.select_tab(T.Tab.RELICS)
	assert_eq(_screen.shown_items().size(), Content.library.relics.size())
	_screen.toggle_rarity_filter(RelicData.Rarity.BOSS)
	for r: RelicData in _screen.shown_items():
		assert_eq(r.rarity, RelicData.Rarity.BOSS)
	_screen.open_detail(0)
	assert_true(_screen.detail_open())
	_screen.select_tab(T.Tab.POTIONS)
	assert_false(_screen.detail_open(), "switching tabs closes the detail")
	assert_eq(_screen.shown_items().size(), Content.library.potions.size())
	_screen.select_tab(T.Tab.RELICS)
	assert_eq(_screen.shown_items().size(), Content.library.relics.filter(
		func(r: RelicData) -> bool: return r.rarity == RelicData.Rarity.BOSS).size(), "filters are kept per tab")
