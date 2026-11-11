"""Regression cases for Xcode's distinct Simulator entitlement representation."""
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
from simulator_entitlements import effective_entitlements, read_entitlements

GROUP = {'com.apple.security.application-groups': ['group.com.jhardorp.loopaiphototest']}


def executable(entitlements, binary=False):
    payload = plistlib.dumps(entitlements, fmt=plistlib.FMT_BINARY if binary else plistlib.FMT_XML)
    # Public Mach-O 64-bit header, one LC_SEGMENT_64 and one section_64.
    offset = 32 + 72 + 80
    header = struct.pack('<8I', 0xfeedfacf, 0x01000007, 3, 2, 1, 152, 0, 0)
    segment = struct.pack('<II16sQQQQIIII', 0x19, 152, b'__TEXT', 0, 4096, 0, offset + len(payload), 7, 5, 1, 0)
    section = struct.pack('<16s16sQQ8I', b'__entitlements', b'__TEXT', 0, len(payload), offset, 0, 0, 0, 0, 0, 0, 0)
    return header + segment + section + payload


def universal(first, second):
    start = 8 + 2 * 20
    return (struct.pack('>II', 0xcafebabe, 2) +
            struct.pack('>5I', 0x01000007, 3, start, len(first), 0) +
            struct.pack('>5I', 0x0100000c, 0, start + len(first), len(second), 0) + first + second)


class SimulatorEntitlementTests(unittest.TestCase):
    def test_xml_and_binary_sections_decode_exactly(self):
        for binary in (False, True):
            with self.subTest(binary=binary):
                self.assertEqual(read_entitlements(executable(GROUP, binary)), GROUP)

    def test_universal_architectures_must_agree(self):
        self.assertEqual(read_entitlements(universal(executable(GROUP), executable(GROUP))), GROUP)
        with self.assertRaisesRegex(ValueError, 'different entitlements'):
            read_entitlements(universal(executable(GROUP), executable({'com.apple.security.application-groups': ['group.production']})))

    def test_truncated_and_out_of_bounds_data_is_rejected(self):
        for payload in (b'', executable(GROUP)[:35], executable(GROUP)[:-4]):
            with self.subTest(length=len(payload)), self.assertRaises((ValueError, plistlib.InvalidFileException)):
                read_entitlements(payload)

    def test_missing_entitlement_section_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'one embedded'):
            read_entitlements(executable(GROUP).replace(b'__entitlements', b'__othersection'))

    def test_simulator_uses_embedded_group_with_empty_signature(self):
        with tempfile.TemporaryDirectory() as temp:
            app = Path(temp)
            (app / 'Loop').write_bytes(executable(GROUP))
            info = {'CFBundleExecutable': 'Loop', 'CFBundleSupportedPlatforms': ['iPhoneSimulator']}
            self.assertEqual(effective_entitlements(app, info, {}, simulator=True), GROUP)
            with self.assertRaisesRegex(ValueError, 'conflicts'):
                effective_entitlements(app, info, {'com.apple.security.application-groups': ['group.production']}, simulator=True)

    def test_device_mode_never_uses_simulator_entitlements(self):
        with tempfile.TemporaryDirectory() as temp:
            app = Path(temp)
            (app / 'Loop').write_bytes(executable(GROUP))
            info = {'CFBundleExecutable': 'Loop', 'CFBundleSupportedPlatforms': ['iPhoneOS']}
            self.assertEqual(effective_entitlements(app, info, {}), {})
            with self.assertRaisesRegex(ValueError, 'actual Simulator'):
                effective_entitlements(app, info, {}, simulator=True)


if __name__ == '__main__':
    unittest.main()
