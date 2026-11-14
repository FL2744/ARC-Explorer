import Foundation
struct ProcessResult {let status:Int32,output:String,error:String}
enum Subprocess {
 static func run(_ executable:String,_ args:[String],input:Data?=nil,environment:[String:String]=[:],timeout:Double=240) async throws -> ProcessResult {
  try await withCheckedThrowingContinuation { continuation in
   DispatchQueue.global(qos:.userInitiated).async {
    let fm=FileManager.default;let dir=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    do {
     try fm.createDirectory(at:dir,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700]);defer{try? fm.removeItem(at:dir)}
     let out=dir.appendingPathComponent("out"),err=dir.appendingPathComponent("err")
     fm.createFile(atPath:out.path,contents:nil,attributes:[.posixPermissions:0o600]);fm.createFile(atPath:err.path,contents:nil,attributes:[.posixPermissions:0o600])
     let oh=try FileHandle(forWritingTo:out),eh=try FileHandle(forWritingTo:err);defer{try? oh.close();try? eh.close()}
     let p=Process();p.executableURL=URL(fileURLWithPath:executable);p.arguments=args;p.standardOutput=oh;p.standardError=eh
     var env=ProcessInfo.processInfo.environment;environment.forEach{env[$0]=$1};p.environment=env
     let pipe=Pipe();p.standardInput=pipe
     try p.run()
     let watchdog=DispatchWorkItem { if p.isRunning {p.terminate();DispatchQueue.global().asyncAfter(deadline:.now()+3){if p.isRunning {kill(p.processIdentifier,SIGKILL)}}} }
     DispatchQueue.global().asyncAfter(deadline:.now()+timeout,execute:watchdog)
     if let input {try pipe.fileHandleForWriting.write(contentsOf:input)}
     try pipe.fileHandleForWriting.close();p.waitUntilExit();watchdog.cancel()
     let result=ProcessResult(status:p.terminationStatus,output:String(decoding:try Data(contentsOf:out),as:UTF8.self),error:String(decoding:try Data(contentsOf:err),as:UTF8.self))
     continuation.resume(returning:result)
    } catch {continuation.resume(throwing:error)}
   }
  }
 }
}
