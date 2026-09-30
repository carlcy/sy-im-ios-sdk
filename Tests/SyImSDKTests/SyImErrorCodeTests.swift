import XCTest
@testable import SyImSDK

final class SyImErrorCodeTests: XCTestCase {
    func testCodesMatchBackendAndAndroid() {
        XCTAssertEqual(SyImErrorCode.imNotEnabled, 3001)
        XCTAssertEqual(SyImErrorCode.quotaMau, 3003)
        XCTAssertEqual(SyImErrorCode.quotaMessages, 3004)
        XCTAssertEqual(SyImErrorCode.trialRetired, 4003)
        XCTAssertEqual(SyImErrorCode.sensitiveRejected, 4005)
        XCTAssertEqual(SyImErrorCode.contentRejected, 4006)
        XCTAssertEqual(SyImErrorCode.credentialSuspended, 4031)
        XCTAssertEqual(SyImErrorCode.credentialRevoked, 4032)
        XCTAssertEqual(SyImErrorCode.credentialExpired, 4033)
        XCTAssertEqual(SyImErrorCode.rateLimited, 4290)
    }

    private func failure(_ http: Int, _ json: [String: Any]) -> SyImError? {
        do {
            try SyImErrorCode.check(httpStatus: http, json: json)
            return nil
        } catch let e as SyImError {
            return e
        } catch {
            return nil
        }
    }

    func testSuccessPasses() throws {
        try SyImErrorCode.check(httpStatus: 200, json: ["code": 0, "data": [:]])
        try SyImErrorCode.check(httpStatus: 200, json: [:])
    }

    func testBusinessCodeSurfaced() {
        let e = failure(200, ["code": 4006, "msg": "内容审核拒绝"])
        XCTAssertEqual(e?.code, 4006)
        XCTAssertTrue(SyImErrorCode.isContentRejected(e?.code ?? 0))
        XCTAssertEqual(e?.errorDescription, "[4006] 内容审核拒绝")
        XCTAssertTrue(SyImErrorCode.isCredentialBlocked(failure(200, ["code": 4032, "msg": "x"])?.code ?? 0))
        if case .controlPlane(_, let http, _)? = e { XCTAssertEqual(http, 200) } else { XCTFail() }
    }

    func testHttpErrorWithoutBodyUsesStatus() {
        XCTAssertEqual(failure(429, [:])?.code, 429)
        XCTAssertEqual(failure(429, ["code": 4290, "msg": "too many"])?.code, SyImErrorCode.rateLimited)
    }
}
