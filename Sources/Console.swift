import SwiftUI
import AppKit
import SwiftTerm

// SSH runs under a local PTY so keyboard input, terminal modes and resizing
// propagate to the remote login-node PTY.
@MainActor final class ARCConsole:NSObject,ObservableObject,@preconcurrency LocalProcessTerminalViewDelegate {
 @Published var running=false
 @Published var session="No session"
 let view=LocalProcessTerminalView(frame:NSRect(x:0,y:0,width:1000,height:500),font:NSFont.monospacedSystemFont(ofSize:14,weight:.regular),options:TerminalOptions(scrollback:5000))
 override init(){super.init();view.processDelegate=self;view.feed(text:"Connect to ARC, then choose Start login terminal.\r\n")}
 static func request(_ p:Profile)throws->String {
  try p.validate()
  return "exec env TERM=xterm-256color bash -il"
 }
 func start(profile:Profile,ssh:[String],target:String)throws {
  guard !running else{return}
  let command=try Self.request(profile)
  var env=ProcessInfo.processInfo.environment;env["TERM"]="xterm-256color"
  view.feed(text:"\r\nConnecting to login node \(target)\r\nLogin node is not for compute intensive jobs.\r\n")
  view.startProcess(executable:"/usr/bin/ssh",args:ssh+["-o","BatchMode=yes","-tt",target,"bash -lc "+shellQuote(command)],environment:env.map{"\($0.key)=\($0.value)"})
  guard view.process.running else{throw Failure(message:"Unable to start SSH terminal.")}
  running=true;session="\(target) · login-node shell";view.window?.makeFirstResponder(view)
 }
 func write(_ text:String){guard running else{return};view.send(txt:text)}
 func stop(){guard running else{return};view.terminate();session="Closing SSH session…"}
 func sizeChanged(source:LocalProcessTerminalView,newCols:Int,newRows:Int){}
 func setTerminalTitle(source:LocalProcessTerminalView,title:String){}
 func hostCurrentDirectoryUpdate(source:TerminalView,directory:String?){}
 func processTerminated(source:TerminalView,exitCode:Int32?){running=false;session="Session ended (SSH exit \(exitCode.map(String.init) ?? "unknown"))";view.feed(text:"\r\n[\(session)]\r\n")}
}

struct NativeTerminal:NSViewRepresentable {
 @ObservedObject var console:ARCConsole
 let dark:Bool
 func makeNSView(context:Context)->LocalProcessTerminalView{configure();return console.view}
 func updateNSView(_ view:LocalProcessTerminalView,context:Context){configure()}
 private func configure(){
  console.view.nativeForegroundColor=dark ? .white:.black
  console.view.nativeBackgroundColor=dark ? NSColor(calibratedWhite:0.04,alpha:1):.white
 }
}
