# ターンのバナー（TurnBanner）と報酬画面のリボン・ボタン用の明朝体を、使う文字だけに絞って assets/fonts/ に置く。
# 使い方: python -I tools/banner_font.py <ShipporiMinchoB1-ExtraBold.ttf>  （要 fonttools）
# 元のフォント：Shippori Mincho B1 ExtraBold（SIL OFL 1.1、Reserved Font Name なし。google/fonts の ofl/shipporiminchob1）。
# 全体は 15MB あるので、ASCII・かな・記号と、バナーで使う漢字（KANJI）だけに絞る。バナーの文言に漢字を足したら KANJI にも足す。
# 報酬画面（RewardScreen / CardShowcase）：戦利品・宝箱・カードを選ぶ・進む・スキップ。
# タイトル画面のメニュー（ButtonTitle）：続きから・新しいラン・ランを放棄・図鑑・終了と、その確認の文言。
# 図鑑の画面：見出し（図鑑）・タブ・戻る。
# 協力プレイ：タイトルの「協力プレイ」、進む矢印の「待機中」（UiText.WAITING_FOR_PARTY）。
# イベント画面の見出し：content/events/*.tres の title の文字を自動で含める（イベントを足したら回し直す）。
import os
import re
import sys

from fontTools import subset

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "fonts", "banner_mincho.ttf")
KANJI = "敵味方戦闘開始勝利敗北終了第回番" + "品宝箱選進" + "続新放棄一度押上書削除読込" + "図鑑戻" + "協力待機中"


def event_titles():
    """イベント画面の見出し（content/events/*.tres の title）。イベントを足したらこのスクリプトを回し直す。"""
    titles = ""
    folder = os.path.join(ROOT, "content", "events")
    for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
        if name.endswith(".tres"):
            for line in open(os.path.join(folder, name), encoding="utf-8"):
                m = re.match(r'^title = "(.*)"', line)
                if m:
                    titles += m.group(1)
    return titles


def chars():
    s = "".join(chr(c) for c in range(0x20, 0x7F))
    s += "".join(chr(c) for c in range(0x3040, 0x3100))   # ひらがな・カタカナ
    s += "ー・「」（）！？、。…０１２３４５６７８９"
    return s + KANJI + event_titles()


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: banner_font.py <ShipporiMinchoB1-ExtraBold.ttf>")
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    font = subset.load_font(sys.argv[1], opts)
    sub = subset.Subsetter(opts)
    sub.populate(text=chars())
    sub.subset(font)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    subset.save_font(font, OUT, opts)
    print("wrote", OUT, os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()
