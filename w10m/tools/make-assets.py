from pathlib import Path
import sys
from PIL import Image

root = Path(__file__).resolve().parents[2]
target = Path(sys.argv[1])
target.mkdir(parents=True, exist_ok=True)
icon = Image.open(root / 'assets' / 'komet_icon.png').convert('RGBA')
sizes = {'StoreLogo': (50, 50), 'SmallLogo': (44, 44), 'Logo': (150, 150),
         'WideLogo': (310, 150), 'LargeLogo': (310, 310), 'Splash': (620, 300)}
for name, size in sizes.items():
    image = Image.new('RGBA', size, '#15151F')
    edge = int(min(size) * (0.55 if name == 'Splash' else 0.8))
    mark = icon.copy()
    mark.thumbnail((edge, edge), Image.Resampling.LANCZOS)
    image.alpha_composite(mark, ((size[0] - mark.width) // 2, (size[1] - mark.height) // 2))
    image.save(target / f'{name}.png')
