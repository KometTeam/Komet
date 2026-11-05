from pathlib import Path
import base64
import hashlib
import struct
import sys
import xml.etree.ElementTree as ET
import zipfile


def pe_info(data):
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    assert data[pe:pe + 4] == b'PE\0\0'
    machine, sections = struct.unpack_from('<HH', data, pe + 4)
    opt = pe + 24
    assert struct.unpack_from('<H', data, opt)[0] == 0x10b
    subsystem, flags = struct.unpack_from('<HH', data, opt + 68)
    section_table = opt + struct.unpack_from('<H', data, pe + 20)[0]

    def offset(rva):
        for i in range(sections):
            size, address, raw_size, raw = struct.unpack_from('<IIII', data, section_table + i * 40 + 8)
            if address <= rva < address + max(size, raw_size):
                return raw + rva - address
        raise ValueError('Unmapped RVA')

    imports = []
    rva = struct.unpack_from('<I', data, opt + 104)[0]
    if rva:
        descriptor = offset(rva)
        while any(data[descriptor:descriptor + 20]):
            name = offset(struct.unpack_from('<I', data, descriptor + 12)[0])
            imports.append(data[name:data.index(0, name)].decode('ascii'))
            descriptor += 20
    return machine, subsystem, flags, imports


def main():
    path = Path(sys.argv[1])
    ns = {'m': 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'}
    with zipfile.ZipFile(path) as archive:
        manifest = ET.fromstring(archive.read('AppxManifest.xml'))
        identity = manifest.find('m:Identity', ns)
        assert identity.get('Name') == 'Komet.W10M'
        assert identity.get('ProcessorArchitecture') == 'arm'
        family = manifest.find('m:Dependencies/m:TargetDeviceFamily', ns)
        assert tuple(map(int, family.get('MinVersion').split('.'))) <= (10, 0, 15254, 0)
        assert [c.get('Name') for c in manifest.find('m:Capabilities', ns)] == ['internetClient']
        assert manifest.find('m:Dependencies/m:PackageDependency', ns) is None
        machine, subsystem, flags, imports = pe_info(archive.read('Komet.exe'))
        assert machine == 0x1c4 and subsystem == 2 and flags & 0x1000
        forbidden = {'kernel32.dll', 'advapi32.dll', 'msvcp140.dll', 'vcruntime140.dll', 'ucrtbase.dll'}
        assert not forbidden.intersection(s.lower() for s in imports)
        blockmap = ET.fromstring(archive.read('AppxBlockMap.xml'))
        bm = {'b': 'http://schemas.microsoft.com/appx/2010/blockmap'}
        for file in blockmap.findall('b:File', bm):
            payload = archive.read(file.get('Name').replace('\\', '/'))
            assert len(payload) == int(file.get('Size'))
            blocks = file.findall('b:Block', bm)
            assert len(blocks) == (len(payload) + 65535) // 65536
            for i, block in enumerate(blocks):
                assert hashlib.sha256(payload[i * 65536:(i + 1) * 65536]).digest() == base64.b64decode(block.get('Hash'))
        assert 'AppxSignature.p7x' in archive.namelist()
    print('PASS: ARM Thumb-2, AppContainer, Mobile manifest, static runtime, block hashes, signature present')
    print('Imports: ' + ', '.join(imports))
    print('SHA256: ' + hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
