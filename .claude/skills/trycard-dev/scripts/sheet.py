import sys, glob, os
from PIL import Image
src, pattern, out, cols = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
files = sorted(glob.glob(os.path.join(src, pattern)))
crop = (0, 120, 1600, 520)  # field area
tw, th = 800, 200
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGB', (tw * cols, th * rows))
for i, f in enumerate(files):
    im = Image.open(f).convert('RGB').crop(crop).resize((tw, th))
    sheet.paste(im, ((i % cols) * tw, (i // cols) * th))
sheet.save(out)
print(len(files), out)
