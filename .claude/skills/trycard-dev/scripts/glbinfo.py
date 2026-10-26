import json, struct, sys

for p in sys.argv[1:]:
    b = open(p, 'rb').read()
    l = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + l])
    anims = [a.get('name') for a in j.get('animations', [])]
    print('##', p.replace('\\', '/').split('/')[-1], 'nodes', len(j.get('nodes', [])),
          'meshes', [m.get('name') for m in j.get('meshes', [])], 'skins', len(j.get('skins', [])))
    print('  anims(%d):' % len(anims), anims)
