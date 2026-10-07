import Foundation

enum SrunEncoder {

    private static let alpha = Array(
        "LVoJPiCN2R8G90yg+hmFHuacZ1OWMnrsSTXkYpUq/3dlbfKwv6xztjI7DeBE45QA"
    )

    private static let delta: UInt32 = 0x9E3779B9

    static func build(
        username: String,
        password: String,
        ip: String,
        acid: String,
        encVer: String,
        token: String
    ) -> String {

        // 完全对应 Java String.format()
        let info =
            "{\"username\":\"\(username)\"," +
            "\"password\":\"\(password)\"," +
            "\"ip\":\"\(ip)\"," +
            "\"acid\":\"\(acid)\"," +
            "\"enc_ver\":\"\(encVer)\"}"

        print("========== SRUN ENCODE ==========")
        print("INFO JSON:")
        print(info.replacingOccurrences(
            of: password,
            with: password
        ))

        let encrypted = encode(
            info,
            key: token
        )

        print("Encrypted bytes:")
        print(
            encrypted
                .map {
                    String(
                        format: "%02X",
                        $0
                    )
                }
                .joined(
                    separator: " "
                )
        )

        let encoded = customBase64Encode(
            encrypted
        )

        print("Custom Base64:")
        print(encoded)

        print("=================================")

        return "{SRBX1}" + encoded
    }

    // ============================================================
    // Java:
    //
    // private static String encode(String str, String key)
    //
    // ============================================================

    private static func encode(
        _ str: String,
        key: String
    ) -> [UInt8] {

        var v = stringToUInt32(
            str,
            includeLength: true
        )

        var k = stringToUInt32(
            key,
            includeLength: false
        )

        if k.count < 4 {
            k += Array(
                repeating: 0,
                count: 4 - k.count
            )
        }

        let n = v.count - 1

        var z = v[n]
        var y = v[0]

        let q = Int(
            floor(
                6.0 +
                52.0 / Double(n + 1)
            )
        )

        var sum: UInt32 = 0

        for _ in 0..<q {

            sum = sum &+ delta

            let e = Int(
                (sum >> 2) & 3
            )

            for p in 0..<n {

                y = v[p + 1]

                var m =
                    ((z >> 5) ^ (y << 2))

                m =
                    m &+
                    (
                        ((y >> 3) ^ (z << 4))
                        ^ (sum ^ y)
                    )

                m =
                    m &+
                    (
                        k[(p & 3) ^ e] ^ z
                    )

                z = v[p] &+ m

                v[p] = z
            }

            y = v[0]

            var m =
                ((z >> 5) ^ (y << 2))

            m =
                m &+
                (
                    ((y >> 3) ^ (z << 4))
                    ^ (sum ^ y)
                )

            m =
                m &+
                (
                    k[(n & 3) ^ e] ^ z
                )

            z = v[n] &+ m

            v[n] = z
        }

        // 对应 Java:
        //
        // return l(v, false);
        //
        // 但这里直接返回 byte[]，
        // 因为 Java 后面马上又：
        //
        // encrypted.charAt(i) & 0xff
        //
        // 所以直接取每个 char 的低 8 位。

        return uint32ToBytes(
            v
        )
    }

    // ============================================================
    // Java:
    //
    // private static int[] s(String a, boolean b)
    //
    // ============================================================

    private static func stringToUInt32(
        _ string: String,
        includeLength: Bool
    ) -> [UInt32] {

        // Java String.charAt()
        // 使用 UTF-16 code unit。
        let chars = Array(
            string.utf16
        )

        let len = chars.count

        let size =
            (len + 3) / 4
            + (includeLength ? 1 : 0)

        var v = [UInt32](
            repeating: 0,
            count: size
        )

        var i = 0

        while i < len {

            var value =
                UInt32(chars[i])

            if i + 1 < len {
                value |=
                    UInt32(chars[i + 1])
                    << 8
            }

            if i + 2 < len {
                value |=
                    UInt32(chars[i + 2])
                    << 16
            }

            if i + 3 < len {
                value |=
                    UInt32(chars[i + 3])
                    << 24
            }

            v[i >> 2] = value

            i += 4
        }

        if includeLength {
            v[v.count - 1] =
                UInt32(len)
        }

        return v
    }

    // ============================================================
    // Java:
    //
    // l(v, false)
    //
    // ============================================================

    private static func uint32ToBytes(
        _ values: [UInt32]
    ) -> [UInt8] {

        var result = [UInt8]()

        result.reserveCapacity(
            values.count * 4
        )

        for value in values {

            result.append(
                UInt8(
                    truncatingIfNeeded: value
                )
            )

            result.append(
                UInt8(
                    truncatingIfNeeded: value >> 8
                )
            )

            result.append(
                UInt8(
                    truncatingIfNeeded: value >> 16
                )
            )

            result.append(
                UInt8(
                    truncatingIfNeeded: value >> 24
                )
            )
        }

        return result
    }

    // ============================================================
    // Java customBase64Encode()
    // ============================================================

    private static func customBase64Encode(
        _ bytes: [UInt8]
    ) -> String {

        guard !bytes.isEmpty else {
            return ""
        }

        var result = ""

        var i = 0

        while i < bytes.count {

            let b1 =
                Int(bytes[i])

            i += 1

            // 1 byte
            if i == bytes.count {

                result.append(
                    alpha[b1 >> 2]
                )

                result.append(
                    alpha[
                        (b1 & 0x03) << 4
                    ]
                )

                result += "=="

                break
            }

            let b2 =
                Int(bytes[i])

            i += 1

            // 2 bytes
            if i == bytes.count {

                result.append(
                    alpha[b1 >> 2]
                )

                result.append(
                    alpha[
                        ((b1 & 0x03) << 4)
                        | ((b2 & 0xF0) >> 4)
                    ]
                )

                result.append(
                    alpha[
                        (b2 & 0x0F) << 2
                    ]
                )

                result += "="

                break
            }

            let b3 =
                Int(bytes[i])

            i += 1

            // 3 bytes
            result.append(
                alpha[
                    b1 >> 2
                ]
            )

            result.append(
                alpha[
                    ((b1 & 0x03) << 4)
                    | ((b2 & 0xF0) >> 4)
                ]
            )

            result.append(
                alpha[
                    ((b2 & 0x0F) << 2)
                    | ((b3 & 0xC0) >> 6)
                ]
            )

            result.append(
                alpha[
                    b3 & 0x3F
                ]
            )
        }

        return result
    }
}
