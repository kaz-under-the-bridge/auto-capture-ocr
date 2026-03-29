#!/usr/bin/env python3
"""OCRテキストのクリーンアップスクリプト"""
import re
import sys

def is_garbage_page(text):
    """ゴミページ（図表・画像など）を検出"""
    stripped = text.strip()
    if len(stripped) < 20:
        return True
    # 英数字・記号の割合が高いページはゴミ
    total = len(text.replace(' ', '').replace('\n', ''))
    if total == 0:
        return True
    jp_chars = len(re.findall(r'[\u3000-\u9fff\uff00-\uffef]', text))
    ratio = jp_chars / total
    if ratio < 0.3 and total > 30:
        return True
    # 1文字ずつ改行されているページは縦書きの表紙/著作権ページのゴミ
    lines = [l.strip() for l in stripped.split('\n') if l.strip()]
    if len(lines) > 5:
        single_char_lines = sum(1 for l in lines if len(l) <= 2)
        if single_char_lines / len(lines) > 0.6:
            return True
    return False

def clean_text(text):
    """OCRテキストのクリーンアップ"""
    # 日本語文字間の不要スペースを除去
    # ひらがな・カタカナ・漢字間のスペース
    jp = r'[\u3000-\u9fff\uff00-\uffef]'
    # 日本語文字同士の間のスペースを除去
    text = re.sub(f'({jp}) ({jp})', r'\1\2', text)
    # 2回実行（奇数位置のスペースも除去）
    text = re.sub(f'({jp}) ({jp})', r'\1\2', text)
    # 3回目
    text = re.sub(f'({jp}) ({jp})', r'\1\2', text)

    # 句読点前後のスペース修正
    text = re.sub(r' ([。、！？」）])', r'\1', text)
    text = re.sub(r'([「（]) ', r'\1', text)

    # 「…」系の修正
    text = text.replace('::…:', '……')
    text = text.replace('::……:', '……')
    text = text.replace('…:', '…')

    # OCRの誤認識修正
    text = text.replace('サーハー', 'サーバー')
    text = text.replace('サイハー', 'サイバー')
    text = re.sub(r'へ況', '状況', text)
    text = text.replace('ee る', 'える')
    text = text.replace('oe ちろん', 'もちろん')
    text = text.replace('DN LAW', '')
    text = text.replace('SWARM?', 'のだ。')
    text = text.replace('SWAMP', 'のだ。')
    text = text.replace('SPS |', '福島伸也')
    text = text.replace('TERNS OV Sr?', '')
    text = text.replace('HH x', '')
    text = text.replace('ROYHHROORAK4—-D-', '被害企業のリアルストーリー')
    text = text.replace('教詞', '教訓')
    text = text.replace('9ッべて', 'すべて')
    text = text.replace('9 ッべて', 'すべて')
    text = text.replace('>: S', '')
    text = text.replace('-: 8S', '')
    text = text.replace('2:8', '')
    text = text.replace('2: S', '')
    text = text.replace('-: S', '')
    text = text.replace('ご : ら', '')
    text = text.replace('Pr |', '九月一五日')
    text = text.replace('Pri ao', '九月一五日')
    text = text.replace('Eo', '')
    text = text.replace('ヘー|', 'へ——')
    text = text.replace('にまたこき', '')
    # 「こに o」系の行末ゴミ
    text = re.sub(r'こに\s*o\.?', 'た。', text)
    text = text.replace('こに o', 'た。')
    # その他の頻出誤認識
    text = re.sub(r'(?:^|\n)(?:NO\s*ー:|i>\s*\d|-\s*@|計る\s*$|i\s*=|複\s*A|で\s*D|Se\s*$|無\s*J|、O|を\s*O|8\s*る)', '', text)
    text = text.replace('aZ社', 'Z社')
    text = text.replace('人害額', '被害額')

    # 行頭のゴミ文字除去
    lines = text.split('\n')
    cleaned_lines = []
    for line in lines:
        line = line.strip()
        # 完全にゴミな行をスキップ
        if re.match(r'^[a-zA-Z0-9\s\-\.\|\+\*\#\!\?\@\&\=\<\>\{\}\[\]\_\~\^\$\%]+$', line) and len(line) > 3:
            if not re.search(r'[A-Z]{2,}', line):  # 略語は残す
                continue
        cleaned_lines.append(line)

    text = '\n'.join(cleaned_lines)

    # 連続する空行を1つに
    text = re.sub(r'\n{3,}', '\n\n', text)

    return text.strip()

def remove_duplicate_pages(pages):
    """重複ページを除去（キャプチャタイミングで同じページが2回取れることがある）"""
    result = []
    prev_text = ""
    for page_num, text in pages:
        # 前のページと80%以上一致する場合は重複とみなす
        if prev_text and len(text) > 50 and len(prev_text) > 50:
            # 簡易的な類似度チェック
            shorter = min(len(text), len(prev_text))
            longer = max(len(text), len(prev_text))
            # 先頭部分の一致をチェック
            match_len = 0
            for i in range(min(shorter, 100)):
                if i < len(text) and i < len(prev_text) and text[i] == prev_text[i]:
                    match_len += 1
            if match_len > 60:
                # 長い方を採用
                if len(text) > len(prev_text):
                    result[-1] = (page_num, text)
                continue
        result.append((page_num, text))
        prev_text = text
    return result

def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else "Output/result.txt"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "Output/book.txt"

    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # ページごとに分割
    page_pattern = r'--- Page (\d+) ---\n'
    parts = re.split(page_pattern, content)

    pages = []
    for i in range(1, len(parts), 2):
        page_num = int(parts[i])
        text = parts[i + 1] if i + 1 < len(parts) else ""
        pages.append((page_num, text.strip()))

    print(f"総ページ数: {len(pages)}")

    # ゴミページを除外
    valid_pages = []
    garbage_count = 0
    for page_num, text in pages:
        if is_garbage_page(text):
            garbage_count += 1
            print(f"  スキップ: Page {page_num} (ゴミページ)")
        else:
            valid_pages.append((page_num, text))
    print(f"ゴミページ除外: {garbage_count}ページ")

    # テキストクリーンアップ
    cleaned_pages = [(num, clean_text(text)) for num, text in valid_pages]

    # 重複除去
    deduped_pages = remove_duplicate_pages(cleaned_pages)
    print(f"重複除去後: {len(deduped_pages)}ページ")

    # 書籍テキストとして結合
    book_title = "サイバー攻撃　その瞬間　社長の決定"
    book_author = "関通サイバー攻撃対策室"

    output = f"{book_title}\n{book_author}\n\n{'='*50}\n\n"

    for _, text in deduped_pages:
        if text.strip():
            output += text + "\n\n"

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(output)

    total_chars = len(output.replace(' ', '').replace('\n', ''))
    print(f"\n出力: {output_file}")
    print(f"総文字数: {total_chars:,}")

if __name__ == '__main__':
    main()
