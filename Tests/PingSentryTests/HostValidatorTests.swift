import Foundation
import Testing
@testable import PingSentry

@Suite("HostValidator Tests")
struct HostValidatorTests {

    @Test("Valid IPv4 addresses use ping4")
    func testValidIPv4() {
        let hosts = ["1.1.1.1", "8.8.8.8", "127.0.0.1", "192.168.1.254"]
        for host in hosts {
            let res = HostValidator.validate(host)
            #expect(res.isValid == true)
            #expect(res.executable == .ping4)
            #expect(res.errorMessageKey == nil)
        }
    }

    @Test("Valid Hostnames use ping4")
    func testValidHostnames() {
        let hosts = ["google.com", "one.one.one.one", "router.local", "my-nas.lan"]
        for host in hosts {
            let res = HostValidator.validate(host)
            #expect(res.isValid == true)
            #expect(res.executable == .ping4)
            #expect(res.errorMessageKey == nil)
        }
    }

    @Test("Valid IPv6 literals use ping6")
    func testValidIPv6() {
        let hosts = ["::1", "2001:4860:4860::8888", "fe80::1%en0", "2606:4700:4700::1111"]
        for host in hosts {
            let res = HostValidator.validate(host)
            #expect(res.isValid == true)
            #expect(res.executable == .ping6)
            #expect(res.errorMessageKey == nil)
        }
    }

    @Test("Reject empty host")
    func testEmptyHost() {
        let res = HostValidator.validate("   ")
        #expect(res.isValid == false)
        #expect(res.errorMessageKey == "settings.host_empty")
    }

    @Test("Reject host starting with dash")
    func testLeadingDash() {
        let res = HostValidator.validate("-c 5")
        #expect(res.isValid == false)
        #expect(res.errorMessageKey == "settings.host_invalid")
    }

    @Test("Reject shell characters and spaces inside host")
    func testInvalidCharacters() {
        let invalids = [
            "1.1.1.1; rm -rf",
            "host name.com",
            "google.com && echo hi",
            "host`whoami`",
            "1.1.1.1|ls",
            "host$var"
        ]
        for inv in invalids {
            let res = HostValidator.validate(inv)
            #expect(res.isValid == false)
            #expect(res.errorMessageKey == "settings.host_invalid")
        }
    }
}
