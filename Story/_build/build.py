"""assets 폴더의 그림으로 탐정호랑이_단군.html 을 다시 만든다 (파이썬 기본 기능만 사용).
- 캐릭터: characters/<이름>.svg 를 넣는다. characters/교체/<이름>.png 가 있으면 그 그림을 대신 넣는다
  (아이패드에서 고친 png 를 여기에 두면 된다. png 를 쓰면 눈 깜빡임은 빠진다).
- 호랑이: tiger/1_몸통_팔제거.png, tiger/2_팔_돋보기.png  (캔버스 크기를 바꾸지 말 것)
"""
import base64, json, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, '..', 'assets')
def b64(p): return base64.b64encode(open(p, 'rb').read()).decode()
names = json.load(open(os.path.join(HERE, 'names.json'), encoding='utf-8'))
h = open(os.path.join(HERE, 'template.html'), encoding='utf-8').read()
for key, name in names.items():
    svg = os.path.join(ASSETS, 'characters', name + '.svg'); png = os.path.join(ASSETS, 'characters', '교체', name + '.png')
    if os.path.exists(png):
        art = '<img src="data:image/png;base64,%s" alt="" style="display:block;width:100%%;height:auto">' % b64(png)
        print('PNG 사용:', name)
    else:
        art = open(svg, encoding='utf-8').read()
    h = h.replace('__%s__' % key, art)
h = h.replace('__TIGERARM__', 'data:image/png;base64,' + b64(os.path.join(ASSETS, 'tiger', '2_팔_돋보기.png')))
h = h.replace('__TIGER__', 'data:image/png;base64,' + b64(os.path.join(ASSETS, 'tiger', '1_몸통_팔제거.png')))
h = h.replace('__MESH__', open(os.path.join(HERE, 'mesh.json')).read())
h = h.replace('.prop.on{opacity:1;transform:none}', '.prop.on{opacity:1;transform:none}\n.prop>div>svg,.prop>svg:not(.spark){display:block;width:100%;height:auto}', 1)
left = re.findall(r'__[A-Z]+__', h)
if left: raise SystemExit('채우지 못한 자리: %s' % left)
out = os.path.join(HERE, '..', '탐정호랑이_단군.html')
open(out, 'w', encoding='utf-8').write(h)
print('완료:', os.path.normpath(out))
