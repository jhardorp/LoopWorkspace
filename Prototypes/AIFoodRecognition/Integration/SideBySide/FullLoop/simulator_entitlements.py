"""Read Xcode's Simulator-only __TEXT,__entitlements from the actual Mach-O."""
import plistlib
import struct


def read_entitlements(data):
    magic = data[:4]
    fat = {b'\xca\xfe\xba\xbe': ('>', False), b'\xbe\xba\xfe\xca': ('<', False),
           b'\xca\xfe\xba\xbf': ('>', True), b'\xbf\xba\xfe\xca': ('<', True)}
    if magic in fat:
        endian, wide = fat[magic]
        if len(data) < 8:
            raise ValueError('Truncated universal Mach-O header')
        count = struct.unpack_from(endian + 'I', data, 4)[0]
        stride = 32 if wide else 20
        if not 1 <= count <= 128 or 8 + count * stride > len(data):
            raise ValueError('Invalid universal Mach-O architecture table')
        results = []
        for index in range(count):
            offset, size = struct.unpack_from(endian + ('QQ' if wide else 'II'), data, 8 + index * stride + 8)
            if offset < 8 + count * stride or not size or offset + size > len(data):
                raise ValueError('Invalid universal Mach-O slice bounds')
            results.append(read_entitlements(data[offset:offset + size]))
        if any(result != results[0] for result in results[1:]):
            raise ValueError('Simulator architectures have different entitlements')
        return results[0]
    endian = {b'\xcf\xfa\xed\xfe': '<', b'\xfe\xed\xfa\xcf': '>'}.get(magic)
    if endian is None or len(data) < 32:
        raise ValueError('Expected a 64-bit Mach-O executable')
    count, size = struct.unpack_from(endian + 'II', data, 16)
    end = 32 + size
    if end > len(data) or count > size // 8:
        raise ValueError('Invalid Mach-O load commands')
    position = 32
    found = []
    for _ in range(count):
        if position + 8 > end:
            raise ValueError('Truncated Mach-O load command')
        command, command_size = struct.unpack_from(endian + 'II', data, position)
        if command_size < 8 or position + command_size > end:
            raise ValueError('Invalid Mach-O load command size')
        if command == 0x19:  # LC_SEGMENT_64
            if command_size < 72:
                raise ValueError('Truncated Mach-O segment')
            sections = struct.unpack_from(endian + 'I', data, position + 64)[0]
            if 72 + sections * 80 > command_size:
                raise ValueError('Invalid Mach-O section table')
            for index in range(sections):
                section = position + 72 + index * 80
                name = data[section:section + 16].rstrip(b'\0')
                segment = data[section + 16:section + 32].rstrip(b'\0')
                if name == b'__entitlements' and segment == b'__TEXT':
                    length = struct.unpack_from(endian + 'Q', data, section + 40)[0]
                    offset = struct.unpack_from(endian + 'I', data, section + 48)[0]
                    if offset < end or not length or offset + length > len(data):
                        raise ValueError('Invalid Simulator entitlement section bounds')
                    payload = plistlib.loads(data[offset:offset + length].rstrip(b'\0'))
                    if not isinstance(payload, dict):
                        raise ValueError('Simulator entitlements must be a dictionary')
                    found.append(payload)
        position += command_size
    if len(found) != 1:
        raise ValueError('Expected one embedded Simulator entitlement section')
    return found[0]


def effective_entitlements(app, info, signed, simulator=False):
    if not simulator:
        # A real iOS IPA must pass using its Apple-signed entitlements alone.
        return signed
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneSimulator']:
        raise ValueError('Simulator entitlement extraction requires an actual Simulator product')
    executable = app / info['CFBundleExecutable']
    injected = read_entitlements(executable.read_bytes())
    if any(key in injected and injected[key] != value for key, value in signed.items()):
        raise ValueError('Code signature conflicts with embedded Simulator entitlements')
    return {**signed, **injected}
