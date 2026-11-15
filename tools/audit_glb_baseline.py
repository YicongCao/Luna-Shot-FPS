"""Read-only GLB topology/UV baseline. No decoding of compressed geometry."""
import argparse
import hashlib
import json
import struct
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', raw)
    assert magic == 0x46546C67 and version == 2 and length == len(raw)
    offset, doc, binary = 12, None, None
    while offset < length:
        size, kind = struct.unpack_from('<II', raw, offset)
        chunk = raw[offset + 8:offset + 8 + size]
        if kind == 0x4E4F534A:
            doc = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + size
    assert doc is not None and binary is not None

    def accessor(index):
        a = doc['accessors'][index]
        assert 'sparse' not in a, 'Sparse accessor needs explicit decoding'
        v = doc['bufferViews'][a['bufferView']]
        assert v.get('buffer', 0) == 0
        assert not v.get('extensions'), 'Compressed view unsupported'
        width = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[a['componentType']]
        size = width * {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        start = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = v.get('byteStride', size)
        payload = b''.join(binary[start+i*stride:start+i*stride+size] for i in range(a['count']))
        assert len(payload) == a['count'] * size
        return {'count': a['count'], 'type': a['type'], 'component_type': a['componentType'], 'sha256': digest(payload)}

    meshes = []
    for i, m in enumerate(doc.get('meshes', [])):
        primitives = []
        for p in m['primitives']:
            assert not p.get('extensions'), 'Compressed primitive unsupported'
            attrs = {k: accessor(v) for k, v in p['attributes'].items() if k in ('POSITION', 'NORMAL', 'TANGENT') or k.startswith('TEXCOORD_')}
            primitives.append({'mode': p.get('mode', 4), 'indices': accessor(p['indices']) if 'indices' in p else None, 'attributes': attrs})
        meshes.append({'index': i, 'name': m.get('name'), 'primitives': primitives})
    return {'path': str(path.resolve()), 'sha256': digest(raw), 'meshes': meshes}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('files', nargs='+', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    result = [inspect(p) for p in args.files]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'Recorded {len(result)} GLB baselines: {args.output}')
