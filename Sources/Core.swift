import Foundation
import AppKit
import Security
import WebKit

func shellQuote(_ s:String)->String { "'"+s.replacingOccurrences(of:"'",with:"'\"'\"'")+"'" }
func pretty(_ obj:Any)->String { guard let data=try? JSONSerialization.data(withJSONObject:obj,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]) else{return String(describing:obj)};return String(decoding:data,as:UTF8.self) }
struct Failure:LocalizedError {let message:String;var errorDescription:String?{message}}
struct Cluster:Identifiable {let name:String;let hosts:[String];var id:String{name}}
let clusters=[Cluster(name:"TinkerCliffs",hosts:["tinkercliffs1.arc.vt.edu","tinkercliffs2.arc.vt.edu"]),Cluster(name:"Falcon",hosts:["falcon1.arc.vt.edu","falcon2.arc.vt.edu"]),Cluster(name:"Owl",hosts:["owl1.arc.vt.edu","owl2.arc.vt.edu","owl3.arc.vt.edu"])]
struct Profile:Codable,Identifiable,Equatable {
 var id=UUID().uuidString,name="TinkerCliffs",host="tinkercliffs1.arc.vt.edu",user="",identity="",auth="SSH key",account="",partition="",workspace="~/arc-explorer"
 var port=22,cpus=4,memory=16,gpus=1,walltime="01:00:00"
 func validate() throws {
  for value in [host,user] {guard value.range(of:"^[A-Za-z0-9_][A-Za-z0-9_.-]*$",options:.regularExpression) != nil else{throw Failure(message:"Enter a valid hostname and PID.")}}
  guard (1...65535).contains(port) else{throw Failure(message:"SSH port must be 1–65535.")}
  if auth == "SSH key" && !identity.isEmpty && !FileManager.default.fileExists(atPath:NSString(string:identity).expandingTildeInPath){throw Failure(message:"SSH key file does not exist.")}
 }
 var sshAuth:[String] {
  if auth == "Password + Duo" {return ["-o","PubkeyAuthentication=no","-o","PreferredAuthentications=keyboard-interactive,password"]}
  return identity.isEmpty ? [] : ["-i",NSString(string:identity).expandingTildeInPath,"-o","IdentitiesOnly=yes"]
 }
}
struct Settings:Codable {var profiles:[Profile];var selected:String;var appearance="Light";var apiBase="https://llm-api.arc.vt.edu/api/v1";var model="";var bookmarks:[Bookmark]=[]}
struct Bookmark:Codable,Identifiable {var id=UUID().uuidString;var name:String;var url:String}
struct RemoteFile:Identifiable {var id:String;var name:String;var directory:Bool;var size:Int;var modified:String;var link:Bool}
struct RemoteJob:Identifiable {var id:String;var name:String;var partition:String;var state:String;var elapsed:String;var limit:String;var reason:String}
struct SectionText:Identifiable {var id=UUID();var title:String;var text:String;var ok:Bool}
struct CommandEntry:Identifiable {let title:String;let command:String;let help:String;var id:String{title}}
let commandLibrary:[CommandEntry]=[
 .init(title:"Cluster partitions",command:"sinfo -o '%P %a %l %D %t %G'",help:"Availability, time limits, node states and GPU resources on this cluster."),
 .init(title:"My queued jobs",command:"squeue -u \"$USER\"",help:"Pending and running jobs, including pending reasons."),
 .init(title:"Today's job history",command:"sacct -X -u \"$USER\" -S today --format=JobID,JobName,State,Elapsed,ExitCode",help:"Completed, failed and cancelled jobs."),
 .init(title:"My allocations",command:"sacctmgr show assoc where user=\"$USER\" format=Cluster,Account,Partition,QOS",help:"Allocation accounts and associations; cluster policy may restrict access."),
 .init(title:"Available modules",command:"module -t avail 2>&1",help:"Discover software installed by ARC."),
 .init(title:"Loaded modules",command:"module list 2>&1",help:"Modules loaded in a fresh login shell."),
 .init(title:"Storage and quota",command:"df -h \"$HOME\"; quota -s",help:"Filesystem capacity and your quota, where supported."),
 .init(title:"Python and CUDA modules",command:"module spider Python 2>&1; module spider CUDA 2>&1",help:"Find available toolchain versions before configuring a compute job.")]

// Keys are never serialized into workspace settings or sent to SSH.
enum KeyStore {
 static func load(_ account:String)->String {
  let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"edu.vt.arc-explorer",kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
  var value:CFTypeRef?;guard SecItemCopyMatching(q as CFDictionary,&value)==errSecSuccess,let data=value as? Data else{return ""};return String(decoding:data,as:UTF8.self)
 }
 static func save(_ value:String,account:String)throws {
  let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"edu.vt.arc-explorer",kSecAttrAccount as String:account]
  let code=SecItemUpdate(q as CFDictionary,[kSecValueData as String:Data(value.utf8)] as CFDictionary)
  if code==errSecItemNotFound {var n=q;n[kSecValueData as String]=Data(value.utf8);let r=SecItemAdd(n as CFDictionary,nil);guard r==errSecSuccess else{throw Failure(message:"Keychain save failed (\(r)).")}}
  else if code != errSecSuccess {throw Failure(message:"Keychain save failed (\(code)).")}
 }
}
final class APITransport:NSObject,URLSessionTaskDelegate {
 // Never forward a bearer token across a redirect to another service.
 func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
 func request(base:String,path:String,key:String,body:[String:Any]?=nil) async throws -> [String:Any] {
  guard let baseURL=URL(string:base),baseURL.scheme=="https",baseURL.host != nil,baseURL.user==nil,baseURL.password==nil,baseURL.query==nil,baseURL.fragment==nil else{throw Failure(message:"Use an HTTPS API base URL without credentials, query or fragment.")}
  let url=baseURL.appendingPathComponent(path)
  var req=URLRequest(url:url);req.timeoutInterval=120;req.setValue("Bearer "+key,forHTTPHeaderField:"Authorization")
  if let body{req.httpMethod="POST";req.setValue("application/json",forHTTPHeaderField:"Content-Type");req.httpBody=try JSONSerialization.data(withJSONObject:body)}
  let session=URLSession(configuration:.ephemeral,delegate:self,delegateQueue:nil);defer{session.finishTasksAndInvalidate()}
  let (data,response)=try await session.data(for:req)
  guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else{throw Failure(message:"ARC API returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0). Check the endpoint, VPN, key and model access.")}
  guard let obj=try JSONSerialization.jsonObject(with:data) as? [String:Any] else{throw Failure(message:"Unexpected API response.")};return obj
 }
}
