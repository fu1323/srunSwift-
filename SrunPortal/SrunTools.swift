import Foundation
import CommonCrypto

enum SrunTools {

    // MARK: - jQuery Callback

    static func jqueryBuilder() -> String {
        let a = Int.random(in: 100_000_000_000...999_999_999_999)
        let b = Int.random(in: 100_000_000...999_999_999)

        return "jQuery\(a)_\(b)"
    }

    // MARK: - HMAC-MD5

    static func hmacMD5(
        key: String,
        message: String
    ) -> String {

        let keyData = Data(key.utf8)
        let messageData = Data(message.utf8)

        var digest = [UInt8](
            repeating: 0,
            count: Int(CC_MD5_DIGEST_LENGTH)
        )

        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in

                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgMD5),
                    keyBytes.baseAddress,
                    keyData.count,
                    messageBytes.baseAddress,
                    messageData.count,
                    &digest
                )
            }
        }

        return digest
            .map {
                String(format: "%02x", $0)
            }
            .joined()
    }

    // MARK: - SHA1

    static func sha1Hex(_ value: String) -> String {

        let data = Data(value.utf8)

        var digest = [UInt8](
            repeating: 0,
            count: Int(CC_SHA1_DIGEST_LENGTH)
        )

        data.withUnsafeBytes { buffer in
            _ = CC_SHA1(
                buffer.baseAddress,
                CC_LONG(data.count),
                &digest
            )
        }

        return digest
            .map {
                String(format: "%02x", $0)
            }
            .joined()
    }

    // MARK: - SRun Password

    static func md5Password(
        token: String,
        password: String
    ) -> String {

        return hmacMD5(
            key: token,
            message: password
        )
    }

    // MARK: - SRun Checksum

    static func checksum(
        _ lb: LoginState
    ) -> String {

        let pre =
            lb.challengeToken
            + lb.username
            + lb.challengeToken
            + lb.md5Password
            + lb.challengeToken
            + lb.acID
            + lb.challengeToken
            + lb.ip
            + lb.challengeToken
            + lb.n
            + lb.challengeToken
            + lb.type
            + lb.challengeToken
            + lb.info

        return sha1Hex(pre)
    }
}
