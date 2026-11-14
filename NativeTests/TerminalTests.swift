import XCTest
import SwiftTerm
@testable import ARC_Explorer

final class TerminalTests:XCTestCase {
 @MainActor func testLoginRequest() async throws {
  var p=Profile();p.user="testuser";p.account="";p.partition="";p.gpus=0
  XCTAssertEqual(try ARCConsole.request(p),"exec env TERM=xterm-256color bash -il")
  p.host="host; touch bad";XCTAssertThrowsError(try ARCConsole.request(p))
 }
 func testPTYInputAndWindowSize() {
  let done=expectation(description:"PTY command responds")
  let delegate=PTYProbe(done:done)
  let process=LocalProcess(delegate:delegate)
  process.startProcess(executable:"/bin/bash",args:["--noprofile","--norc","-c","test -t 0 || exit 2; stty size; IFS= read -r line; printf 'RECEIVED:%s\\n' \"$line\""],environment:["TERM=xterm-256color","PATH=/usr/bin:/bin"])
  XCTAssertTrue(process.running)
  process.send(data:Array("direct terminal input\n".utf8)[...])
  wait(for:[done],timeout:10)
  XCTAssertTrue(delegate.text.contains("42 140"),delegate.text)
  XCTAssertTrue(delegate.text.contains("RECEIVED:direct terminal input"),delegate.text)
  process.terminate()
 }
}
final class PTYProbe:LocalProcessDelegate {
 let done:XCTestExpectation
 var text=""
 init(done:XCTestExpectation){self.done=done}
 func getWindowSize()->winsize{winsize(ws_row:42,ws_col:140,ws_xpixel:0,ws_ypixel:0)}
 func dataReceived(slice:ArraySlice<UInt8>){text+=String(decoding:slice,as:UTF8.self)}
 func processTerminated(_ source:LocalProcess,exitCode:Int32?){done.fulfill()}
}
