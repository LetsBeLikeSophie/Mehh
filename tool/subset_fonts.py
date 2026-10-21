"""IBM Plex Sans KR을 앱에 필요한 글자만 남겨 줄인다 (README '폰트').

남기는 글자: 영문·숫자·문장부호, 자주 쓰는 한글 2,350자(KS X 1001, 장소 이름까지 대부분),
한글 자모, 앱 문구(lib/l10n/*.arb)에 나오는 모든 글자.
없는 글자는 폰의 기본 글꼴로 대신 보인다.

OFL의 예약 이름("Plex") 때문에 줄인 글꼴은 "Mehh Sans KR"로 이름을 바꾼다.

원본은 fonts/source/ 에 두지 않는다 — 다시 줄이려면 원본 TTF를 받아 경로를 넘긴다:
  python tool/subset_fonts.py <원본 폴더>
"""
import glob
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), '..', 'fonts')
NEW_FAMILY = 'Mehh Sans KR'

chars = set()
chars.update(range(0x20, 0x7F))  # 영문·숫자
chars.update(range(0xA0, 0x100))  # 라틴 보충
chars.update(range(0x2010, 0x2070))  # 일반 문장부호 (· … – — ‘’ “”)
chars.update(range(0x20A0, 0x20C0))  # 통화 (₩ €)
chars.update(range(0x2190, 0x2200))  # 화살표
chars.update(range(0x3131, 0x3190))  # 한글 자모
chars.update(range(0x3000, 0x3040))  # CJK 문장부호
for c in range(0xAC00, 0xD7A4):  # KS X 1001 한글 2,350자
    try:
        # 파이썬 euc-kr은 나머지 글자를 8바이트 조합으로 내보내므로 2바이트만 센다
        if len(chr(c).encode('euc-kr')) == 2:
            chars.add(c)
    except UnicodeEncodeError:
        pass
for arb in glob.glob(os.path.join(os.path.dirname(__file__), '..', 'lib', 'l10n', '*.arb')):
    chars.update(ord(ch) for ch in open(arb, encoding='utf-8').read())

WEIGHTS = {'Regular': 'Regular', 'Medium': 'Medium', 'SemiBold': 'SemiBold', 'Bold': 'Bold'}
for w in WEIGHTS:
    src = os.path.join(SRC, f'IBMPlexSansKR-{w}.ttf')
    font = TTFont(src)
    opts = subset.Options()
    opts.layout_features = ['*']
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    s = subset.Subsetter(opts)
    s.populate(unicodes=chars)
    s.subset(font)
    # 예약 이름 "Plex"를 쓰지 않는다 (OFL 1.1 조건 3)
    for rec in font['name'].names:
        if rec.nameID in (1, 3, 4, 6, 16, 17, 21):
            text = rec.toUnicode()
            text = text.replace('IBM Plex Sans KR', NEW_FAMILY).replace('IBMPlexSansKR', 'MehhSansKR')
            text = text.replace('Plex', 'Mehh')
            rec.string = text
    out = os.path.join(OUT, f'MehhSansKR-{w}.ttf')
    font.save(out)
    print(w, os.path.getsize(src) // 1024, 'KB ->', os.path.getsize(out) // 1024, 'KB')
