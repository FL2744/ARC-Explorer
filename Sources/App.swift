import SwiftUI
import AppKit
import WebKit
import UniformTypeIdentifiers

@MainActor final class ExplorerDelegate:NSObject,NSApplicationDelegate {
 weak var workspace:Workspace?
 func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply{guard workspace?.confirmDiscardRemote() ?? true,workspace?.confirmEndTerminal() ?? true else{return .terminateCancel};workspace?.save();return .terminateNow}
 func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
}
@main struct ExplorerApp:App {
 @NSApplicationDelegateAdaptor(ExplorerDelegate.self) var delegate
 @StateObject var state=Workspace()
 var body:some Scene {
  WindowGroup {MainView().environmentObject(state).onAppear{delegate.workspace=state}.frame(minWidth:1100,minHeight:740).preferredColorScheme(state.appearance=="Dark" ? .dark : .light)}
   .defaultSize(width:1360,height:900)
   .commands {CommandGroup(replacing:.newItem){};CommandGroup(after:.saveItem){Button(state.tab == "Files" ? "Save ARC file":"Save workspace"){if state.tab == "Files"{state.saveRemoteFile()}else{state.save()}}.keyboardShortcut("s")};CommandGroup(replacing:.help){Button("ARC documentation"){state.openWeb("https://www.docs.arc.vt.edu")};Button("Ask ARC LLM"){state.tab="Models + help"}}}
 }
}
struct MonochromeActionStyle:ButtonStyle {
 @Environment(\.colorScheme) var scheme
 @Environment(\.isEnabled) var enabled
 func makeBody(configuration:Configuration)->some View {
  configuration.label.foregroundStyle(scheme == .dark ? Color.black:Color.white)
   .padding(.horizontal,12).padding(.vertical,6)
   .background(scheme == .dark ? Color.white:Color.black,in:RoundedRectangle(cornerRadius:6))
   .opacity(enabled ? (configuration.isPressed ? 0.75:1):0.4)
 }
}
struct Panel<Content:View>:View {
 var title:String;@ViewBuilder var content:Content
 var body:some View {GroupBox{VStack(alignment:.leading,spacing:12){Text(title.uppercased()).font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(1.4);content}.padding(8).frame(maxWidth:.infinity,alignment:.leading)}}
}
struct LabeledField:View {
 var label:String;@Binding var value:String
 var body:some View{HStack{Text(label).foregroundStyle(.secondary).frame(width:135,alignment:.leading);TextField(label,text:$value).textFieldStyle(.roundedBorder)}}
}
struct LogView:View {
 var text:String
 var body:some View{ScrollView([.vertical,.horizontal]){Text(text.isEmpty ? "Nothing to display yet.":text).font(.system(size:12,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.topLeading).padding(12)}.background(.primary.opacity(0.025),in:RoundedRectangle(cornerRadius:8))}
}
struct MainView:View {
 @EnvironmentObject var s:Workspace
 var group:Int {switch s.tab{case "Connection":return 0;case "Overview","Allocations","Files":return 1;case "Submit job","Jobs","Software":return 2;case "Sessions","Terminal":return 3;default:return 4}}
 var groupBinding:Binding<Int>{Binding(get:{group},set:{s.tab=["Connection","Overview","Submit job","Terminal","Models + help"][$0]})}
 var body:some View {
  VStack(spacing:0){header;Divider();HStack(spacing:0){if s.tab != "Terminal"{sidebar;Divider()};VStack(alignment:.leading,spacing:18){
   Picker("Workspace",selection:groupBinding){Text("01  Connection").tag(0);Text("02  Resources").tag(1);Text("03  Jobs + software").tag(2);Text("04  Sessions").tag(3);Text("05  Help").tag(4)}.pickerStyle(.segmented)
   if group==1 {Picker("Resources",selection:$s.tab){Text("Availability").tag("Overview");Text("Allocation usage").tag("Allocations");Text("Remote files").tag("Files")}.pickerStyle(.segmented)}
   if group==2 {Picker("Compute workspace",selection:$s.tab){Text("GPU request + script").tag("Submit job");Text("Jobs + results").tag("Jobs");Text("Install / update code").tag("Software")}.pickerStyle(.segmented)}
   if group==3 {Picker("Sessions",selection:$s.tab){Text("Web / Jupyter").tag("Sessions");Text("Terminal").tag("Terminal")}.pickerStyle(.segmented)}
   if group==4 {Picker("Help tools",selection:$s.tab){Text("ARC LLM assistant").tag("Models + help");Text("Command reference").tag("Commands")}.pickerStyle(.segmented)}
   Group{switch s.tab {
    case "Connection":ConnectionView()
    case "Overview":OverviewView()
    case "Allocations":AllocationView()
    case "Jobs":JobsView()
    case "Submit job":SubmitView()
    case "Files":FilesView()
    case "Sessions":SessionsView()
    case "Terminal":ConsoleView(console:s.terminal)
    case "Software":SoftwareView()
    case "Models + help":HelpView()
    default:CommandsView()
   }}.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
  }.padding(22)}}.background(s.appearance=="Dark" ? Color.black:Color.white).foregroundStyle(.primary)
  .alert("ARC-Explorer",isPresented:Binding(get:{!s.error.isEmpty},set:{if !$0{s.error=""}})){Button("OK"){s.error=""}}message:{Text(s.error)}
  .onChange(of:s.tab){_,new in guard s.connected,!s.busy else{return};if new=="Jobs"{s.refreshJobs()};if new=="Files" && s.files.isEmpty{s.browse()}}
 }
 var header:some View {
  HStack(alignment:.top){
   VStack(alignment:.leading,spacing:3){HStack(alignment:.firstTextBaseline,spacing:10){Text("ARC").font(.system(size:48,weight:.black)).tracking(-2.5);Text("Explorer").font(.system(size:28,weight:.light))};Text("CONNECT → REQUEST RESOURCES → COMPUTE → EXPLORE").font(.system(size:9,design:.monospaced)).tracking(1.4)}
   Spacer(minLength:20)
   VStack(alignment:.trailing,spacing:10){HStack(spacing:7){Circle().fill(s.connected ? Color.green:Color.gray).frame(width:7,height:7);Text(s.connected ? s.profile.name.uppercased()+" CONNECTED":"OFFLINE").font(.system(size:10,design:.monospaced));if s.busy{ProgressView().controlSize(.small)}};Text(s.status).font(.system(size:11,design:.monospaced)).lineLimit(3).multilineTextAlignment(.trailing).frame(maxWidth:400,minHeight:32);Picker("Appearance",selection:$s.appearance){Text("Light").tag("Light");Text("Dark").tag("Dark")}.pickerStyle(.segmented).labelsHidden().frame(width:145).onChange(of:s.appearance){s.save()}}
  }.padding(24)
 }
 func label(_ text:String)->some View{Text(text).font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(1.4)}
 var sidebar:some View {
  ScrollView{VStack(alignment:.leading,spacing:14){label("RESOURCE LIBRARY")
   ScrollView{VStack(alignment:.leading,spacing:4){ForEach(s.profiles){p in Button{s.selectProfile(p.id)}label:{VStack(alignment:.leading,spacing:4){Text(p.name).font(.system(size:13,weight:.medium));Text(p.host).font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(10).background(p.id==s.profile.id ? Color.primary.opacity(0.08):Color.clear)}.buttonStyle(.plain).disabled(s.connected || s.busy)}}}.frame(minHeight:70,maxHeight:160)
   HStack{Menu("New"){ForEach(clusters){c in ForEach(c.hosts,id:\.self){host in Button(c.name+" · "+host){s.addProfile(c.name,host);s.tab="Connection"}}};Button("Custom host"){s.addProfile("Custom cluster","");s.tab="Connection"}}.disabled(s.connected || s.busy);Button("Save"){s.save()}}
   VStack(alignment:.leading,spacing:12){label("CURRENT GPU REQUEST");HStack(alignment:.firstTextBaseline){Text(String(s.profile.gpus)).font(.system(size:42,weight:.light));Text(s.profile.gpus==1 ? "GPU":"GPUs").font(.system(size:11,design:.monospaced))};Text(s.profile.partition.isEmpty ? "Choose a GPU partition":s.profile.partition).font(.system(size:10,design:.monospaced));Text("\(s.profile.cpus) CPUs · \(s.profile.memory) GB · \(s.profile.walltime)").font(.system(size:10,design:.monospaced));Button("Edit resource request"){s.tab="Submit job"}}.padding(12).frame(maxWidth:.infinity,alignment:.leading).overlay(Rectangle().stroke(.gray.opacity(0.25)))
   Text("GPU requests wait for Slurm. Compute runs on the assigned node, never on the login node.").font(.system(size:11)).foregroundStyle(.secondary)
   label("ARC SERVICES")
   VStack(alignment:.leading,spacing:7){Button("Jupyter / Open OnDemand"){s.openWeb("https://ood.arc.vt.edu")};Button("Allocation usage"){s.tab="Allocations"};Button("Cluster dashboards"){s.openWeb("https://dashboard.arc.vt.edu/dashboards?kiosk")};Button("Documentation"){s.openWeb("https://www.docs.arc.vt.edu")}}.font(.system(size:11))
   Spacer(minLength:10)
   Button("Local files…"){NSWorkspace.shared.open(s.support)}.font(.system(size:11))
   Text("MACOS 15+ · SSH + SLURM\nGPU COMPUTE ON ARC\nEXPERIMENTAL RESEARCH SOFTWARE").font(.system(size:9,design:.monospaced)).lineSpacing(5).foregroundStyle(.secondary)
  }.padding(20)}.frame(width:245)
 }
}
struct ConnectionView:View {
 @EnvironmentObject var s:Workspace
 var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){
  Text("One workspace for ARC.").font(.system(size:25,weight:.semibold))
  Text("Connect with your VT credentials, inspect availability and allocation usage, then request GPU resources. SSH and Duo prompts open in native dialogs.").font(.system(size:13)).foregroundStyle(.secondary)
  Panel(title:"Saved connections"){
   HStack{Picker("Profile",selection:Binding(get:{s.profile.id},set:{s.selectProfile($0)})){ForEach(s.profiles){p in Text(p.name+" · "+p.host).tag(p.id)}}.disabled(s.connected || s.busy);Menu("Add cluster"){ForEach(clusters){c in ForEach(c.hosts,id:\.self){host in Button(c.name+" · "+host){s.addProfile(c.name,host)}}};Button("Custom host"){s.addProfile("Custom cluster","")}}.disabled(s.connected || s.busy)}
   Text("Profiles are independent. Disconnect before switching clusters. Availability is queried live after connecting; it is not a reservation.").font(.caption).foregroundStyle(.secondary)
  }
  Panel(title:"SSH connection"){
   VStack(spacing:12){LabeledField(label:"Connection name",value:$s.profile.name);LabeledField(label:"Login host",value:$s.profile.host);LabeledField(label:"VT PID",value:$s.profile.user);HStack{Text("SSH port").frame(width:135,alignment:.leading).foregroundStyle(.secondary);TextField("Port",value:$s.profile.port,format:.number).textFieldStyle(.roundedBorder)}
    Picker("Authentication",selection:$s.profile.auth){Text("SSH key / agent").tag("SSH key");Text("Password + Duo").tag("Password + Duo")}.pickerStyle(.segmented)
    if s.profile.auth=="SSH key"{HStack{LabeledField(label:"Private key path",value:$s.profile.identity);Button("Choose…"){let panel=NSOpenPanel();panel.showsHiddenFiles=true;panel.directoryURL=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh");if panel.runModal() == .OK,let url=panel.url{s.profile.identity=url.path}}}}
    LabeledField(label:"ARC workspace",value:$s.profile.workspace)
   }.disabled(s.connected || s.busy)
   HStack{Button(s.connected ? "Disconnect":"Connect to ARC"){if s.connected{s.disconnect()}else{s.connect()}}.buttonStyle(MonochromeActionStyle()).disabled(s.busy);Button("Save profile"){s.save()}.disabled(s.busy);Spacer();Text("Use the VT VPN off campus").font(.caption).foregroundStyle(.secondary)}
   Text("SSH passphrases and Duo responses appear in native dialogs. ARC-Explorer never saves them. Leave the key path blank to use your SSH agent.").font(.caption).foregroundStyle(.secondary)
  }
  Panel(title:"How this workspace runs"){Text("SSH connects to the login node for lightweight scheduler queries and file navigation. Compute workloads and package installation use explicit GPU resources. The Login Node Terminal is for lightweight commands. A queued job has not started computing yet.").font(.callout);HStack{Button("Request GPU job"){s.tab="Submit job"};Button("Open OnDemand"){s.openWeb("https://ood.arc.vt.edu")};Button("ARC documentation"){s.openWeb("https://www.docs.arc.vt.edu")}}}
 }.padding(.bottom,4)}}
}
struct OverviewView:View {
 @EnvironmentObject var s:Workspace
 var body:some View{ScrollView{VStack(spacing:20){
  HStack{Button("Refresh live availability"){s.refreshOverview()}.disabled(!s.connected || s.busy);Button("All-cluster dashboards"){s.openWeb("https://dashboard.arc.vt.edu/dashboards?kiosk")};Spacer();Text(s.profile.host).font(.caption).foregroundStyle(.secondary)}
  if s.overview.isEmpty{Panel(title:"Connect to explore"){Text("Connect to TinkerCliffs, Falcon, Owl or a custom host. Inspect GPU partitions and your allocations here before submitting work.");Button("Connection settings"){s.tab="Connection"}}}
  ForEach(s.overview){section in Panel(title:section.title){if !section.ok{Text("Unavailable on this cluster").font(.caption).foregroundStyle(.secondary)};LogView(text:section.text).frame(minHeight:100,maxHeight:300)}}
 }.padding(.bottom,4)}}
}
struct AllocationView:View {
 @EnvironmentObject var s:Workspace
 var body:some View{ScrollView{VStack(spacing:20){
  Panel(title:"Allocation usage"){
   LabeledField(label:"Slurm allocation",value:$s.profile.account)
   HStack{DatePicker("Jobs from",selection:$s.usageStart,displayedComponents:.date);DatePicker("through",selection:$s.usageEnd,displayedComponents:.date);Spacer()}
   HStack{Button("Check allocation usage"){s.refreshAllocation()}.disabled(!s.connected || s.busy);Button("Allocation portal"){s.openWeb("https://coldfront.arc.vt.edu")}}
   Text("ARC’s getusage and quota reports keep their own reporting periods. The date filter applies to the job table only. Slurm fair-share usage is not a remaining balance; account-wide records depend on your permissions.").font(.caption).foregroundStyle(.secondary)
  }
  ForEach(s.allocation){section in Panel(title:section.title){if !section.ok{Text("The cluster could not provide this report.").font(.caption)};LogView(text:section.text).frame(minHeight:160,maxHeight:350)}}
 }.padding(.bottom,4)}}
}
struct ResourceView:View {
 @EnvironmentObject var s:Workspace
 var body:some View{VStack(spacing:12){
  LabeledField(label:"Allocation",value:$s.profile.account);LabeledField(label:"GPU partition",value:$s.profile.partition);LabeledField(label:"Wall time",value:$s.profile.walltime)
  HStack(spacing:24){Stepper("GPUs: \(s.profile.gpus)",value:$s.profile.gpus,in:1...8);Stepper("CPUs: \(s.profile.cpus)",value:$s.profile.cpus,in:1...256);Stepper("Memory: \(s.profile.memory) GB",value:$s.profile.memory,in:1...2048)}
  LabeledField(label:"Working directory",value:$s.workdir)
  Text("The partition must offer GPUs. Check Overview for actual partition names and limits. This requests resources; queue time depends on availability and your allocation.").font(.caption).foregroundStyle(.secondary)
 }}
}
struct SubmitView:View {
 @EnvironmentObject var s:Workspace
 @State var confirm=false
 var body:some View{ScrollView{VStack(spacing:20){
  Panel(title:"1 · Request GPU resources"){ResourceView()}
  Panel(title:"2 · Script to run on the compute node"){
   TextEditor(text:$s.script).font(.system(size:12,design:.monospaced)).frame(minHeight:240).overlay(RoundedRectangle(cornerRadius:5).stroke(.primary.opacity(0.15)))
   HStack{Button("Open script…"){let p=NSOpenPanel();if p.runModal() == .OK,let u=p.url{do{s.script=try String(contentsOf:u,encoding:.utf8)}catch{s.error=error.localizedDescription}}};Menu("Save script…"){Button("Save to this Mac…"){s.saveScriptLocal()};Button("Save to ARC…"){s.saveScriptARC()}.disabled(!s.connected || s.busy);Button("Save workspace draft"){s.save();s.status="Script draft saved in this workspace."}};Spacer();Button("Submit GPU job…"){confirm=true}.buttonStyle(MonochromeActionStyle()).disabled(!s.connected || s.busy)}
   Text("Save script writes a reusable file on this Mac or ARC; it does not submit a job. GPU settings are configured separately above. Load the modules or environment your code needs in this script.").font(.caption).foregroundStyle(.secondary)
  }
  if !s.submission.isEmpty{Panel(title:"Submission receipt"){LogView(text:s.submission).frame(height:150);HStack{Button("View jobs"){s.tab="Jobs";s.refreshJobs()};Button("Read log"){s.readJobLog()}.disabled(s.busy)}}}
 }.padding(.bottom,4)}.confirmationDialog("Submit this script to \(s.profile.name)?",isPresented:$confirm,titleVisibility:.visible){Button("Submit \(s.profile.gpus)-GPU job"){s.submit()}}message:{Text("Account: \(s.profile.account)\nPartition: \(s.profile.partition)\n\(s.profile.cpus) CPUs · \(s.profile.memory) GB · \(s.profile.walltime)\nThis consumes allocation service units while running.")}}
}
struct JobsView:View {
 @EnvironmentObject var s:Workspace
 @State var confirmCancel=false
 var body:some View{VStack(alignment:.leading,spacing:14){
  HStack{Button("Refresh"){s.refreshJobs()}.disabled(!s.connected || s.busy);Button("Job details"){if let id=s.selectedJob{s.jobDetails(id)}}.disabled(s.selectedJob==nil || s.busy);Button("Cancel selected job…",role:.destructive){confirmCancel=true}.disabled(s.selectedJob==nil || s.busy);Spacer();Text("Refreshes every 30 seconds while visible").font(.caption).foregroundStyle(.secondary)}
  Table(s.jobs,selection:$s.selectedJob){TableColumn("Job",value:\.id).width(min:75,ideal:90);TableColumn("Name",value:\.name);TableColumn("Partition",value:\.partition);TableColumn("State",value:\.state);TableColumn("Elapsed",value:\.elapsed);TableColumn("Node / pending reason",value:\.reason)}.frame(minHeight:180)
  HStack{Text("JOB DETAILS / LOG").font(.system(size:11,design:.monospaced));Spacer();TextField("Remote job.log path",text:$s.jobLogPath).textFieldStyle(.roundedBorder);Button("Read log"){s.readJobLog()}.disabled(!s.connected || s.busy || s.jobLogPath.isEmpty)}
  LogView(text:s.jobDetail).frame(minHeight:150,maxHeight:250)
  Text("TODAY’S ACCOUNTING").font(.system(size:11,design:.monospaced));LogView(text:s.history).frame(minHeight:100,maxHeight:200)
 }.padding(.bottom,4).confirmationDialog("Cancel this Slurm job?",isPresented:$confirmCancel,titleVisibility:.visible){Button("Cancel job \(s.selectedJob ?? "")",role:.destructive){if let id=s.selectedJob{s.cancelJob(id)}}}message:{Text("The running computation will stop. Files already written remain on ARC.")}}
}
struct FilesView:View {
 @EnvironmentObject var s:Workspace
 var selected:RemoteFile?{s.files.first(where:{$0.id==s.selectedFile})}
 var body:some View{VStack(spacing:14){
  HStack{Button("Home"){s.browse("~")};Button("Up"){s.browse((s.remotePath as NSString).deletingLastPathComponent)};TextField("Remote directory",text:$s.remotePath).textFieldStyle(.roundedBorder).onSubmit{s.browse()};Button("Go"){s.browse()};Button("Upload…"){s.upload()}}.disabled(!s.connected || s.busy)
  HSplitView{
   Table(s.files,selection:$s.selectedFile){TableColumn("Name"){f in Label(f.name,systemImage:f.directory ? "folder":f.link ? "link":"doc")};TableColumn("Bytes"){f in Text(f.directory ? "—":String(f.size)).monospacedDigit()}.width(80);TableColumn("Modified",value:\.modified).width(150)}.frame(minWidth:350)
   VStack(alignment:.leading){HStack{Button("Open / edit"){if let f=selected{s.viewFile(f)}};Button("Download…"){if let f=selected{s.downloadFile(f)}}.disabled(selected?.directory != false)}.disabled(selected==nil || s.busy);Divider()
    Text(s.editorPath.isEmpty ? "Open a UTF-8 text file to edit.":s.editorPath).font(.system(size:11,design:.monospaced)).textSelection(.enabled)
    HStack{Text(s.editorDirty ? "Modified · not saved to ARC":"No unsaved changes").font(.caption);Spacer();Button("Reload"){s.openRemoteFile(s.editorPath)}.disabled(s.busy || !s.connected || s.editorPath.isEmpty || s.editorConnection != s.fileConnection);Button("Save to ARC"){s.saveRemoteFile()}.disabled(!s.canSaveRemote)}
    TextEditor(text:$s.editorText).font(.system(size:12,design:.monospaced)).disableAutocorrection(true).disabled(s.editorPath.isEmpty || s.busy).overlay(Rectangle().stroke(.gray.opacity(0.2)))
   }.frame(minWidth:300)
  }
  HStack{Button("New text file…"){s.newRemoteFile()}.disabled(!s.connected || s.busy);TextField("New folder name",text:$s.folderName).textFieldStyle(.roundedBorder).frame(maxWidth:250);Button("Create folder"){s.mkdir()}.disabled(!s.connected || s.busy);Spacer();Button("Large transfers / file manager"){s.openWeb("https://ood.arc.vt.edu")}}
  Text("Up to 5,000 directory entries. UTF-8 editor: 1 MiB; checks for remote changes before saving. Transfers here: 8 MB; use Open OnDemand or SFTP for larger files. Uploads never overwrite existing files.").font(.caption).foregroundStyle(.secondary)
 }.padding(.bottom,4)}
}
struct SoftwareView:View {
 @EnvironmentObject var s:Workspace
 var body:some View{ScrollView{VStack(spacing:20){
  Panel(title:"Install or update source code"){
   Picker("Source",selection:$s.repoProvider){Text("GitHub").tag("GitHub");Text("Hugging Face").tag("Hugging Face")}.pickerStyle(.segmented)
   LabeledField(label:"Repository",value:$s.repo);LabeledField(label:"Revision (optional)",value:$s.revision);LabeledField(label:"Destination on ARC",value:$s.destination)
   Text("Use owner/repository. Public repositories work directly; private repositories require credentials configured on ARC. Git updates require a clean checkout and fast-forward history. Hugging Face repositories require Git LFS. No repository setup script is run automatically.").font(.caption).foregroundStyle(.secondary)
   Button("Prepare GPU installation job"){s.previewInstall()}.disabled(!s.connected || s.busy)
   if !s.installPreview.isEmpty{LogView(text:s.installPreview).frame(height:220);HStack{Button("Review script + GPU resources"){s.useInstall()};Menu("Save script…"){Button("Save to this Mac…"){s.saveScriptLocal(s.installPreview)};Button("Save to ARC…"){s.saveScriptARC(s.installPreview)}.disabled(!s.connected || s.busy)}}}
  }
  Panel(title:"Software already installed by ARC"){
   Button("List available modules"){s.modules()}.disabled(!s.connected || s.busy);LogView(text:s.moduleText).frame(height:250)
   Text("Use a module’s documented load command in a job script. Desktop applications, IDEs and Jupyter are also available through Open OnDemand.").font(.caption).foregroundStyle(.secondary)
  }
 }.padding(.bottom,4)}}
}
struct HelpView:View {
 @EnvironmentObject var s:Workspace
 var body:some View{ScrollView{VStack(spacing:20){
  Panel(title:"ARC-hosted LLM API"){
   LabeledField(label:"API base URL",value:$s.apiBase).onChange(of:s.apiBase){s.apiKey="";s.modelIDs=[];s.model=""}
   HStack{Text("API key").frame(width:135,alignment:.leading).foregroundStyle(.secondary);SecureField("ARC personal API key",text:$s.apiKey).textFieldStyle(.roundedBorder);Button("Load Keychain"){s.loadKey()};Button("Save to Keychain"){s.saveKey()}}
   HStack{Button("Get API key"){s.openWeb("https://llm.arc.vt.edu")};Button("Fetch available models"){s.loadModels()}.disabled(s.busy);Spacer()}
   LabeledField(label:"Model ID",value:$s.model)
   if !s.modelIDs.isEmpty{Picker("Hosted models",selection:$s.model){ForEach(s.modelIDs,id:\.self){Text($0).tag($0)}}}
   Text("Model availability is loaded from the API, not a hardcoded list. Get your key at llm.arc.vt.edu → Settings → Account → API keys. The assistant sends only your question and a general ARC help instruction to the endpoint shown above; no files, job logs or SSH credentials are attached automatically.").font(.caption).foregroundStyle(.secondary)
  }
  Panel(title:"Ask for help"){
   TextEditor(text:$s.question).font(.body).frame(height:120).overlay(RoundedRectangle(cornerRadius:5).stroke(.primary.opacity(0.15)))
   HStack{Button("Ask ARC LLM"){s.ask()}.buttonStyle(MonochromeActionStyle()).disabled(s.busy);Button("Clear"){s.question="";s.answer=""};Spacer();Text("Advice only · commands are never executed").font(.caption).foregroundStyle(.secondary)}
   if !s.answer.isEmpty{Text(s.answer).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}
  }
 }.padding(.bottom,4)}}
}
struct CommandsView:View {
 @EnvironmentObject var s:Workspace
 var body:some View{ScrollView{VStack(spacing:18){
  Text("A reference library for ARC. Copy commands into your own workflow or add them to a GPU job script. Live monitoring is available in Overview, Allocations and Jobs.").foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
  ForEach(commandLibrary){entry in Panel(title:entry.title){Text(entry.help).font(.callout).foregroundStyle(.secondary);Text(entry.command).font(.system(size:12,design:.monospaced)).textSelection(.enabled);HStack{Button("Copy"){NSPasteboard.general.clearContents();NSPasteboard.general.setString(entry.command,forType:.string)};Button("Use in GPU job"){s.script=entry.command;s.tab="Submit job"}}}}
 }.padding(.bottom,4)}}
}
struct SessionsView:View {
 @EnvironmentObject var s:Workspace
 @State var showTools=false
 @State var confirmShell=false
 var body:some View{VStack(spacing:12){
  HStack{Button{if s.web.canGoBack{s.web.goBack()}}label:{Image(systemName:"chevron.left")};Button{s.web.reload()}label:{Image(systemName:"arrow.clockwise")};TextField("Session URL",text:$s.webAddress).textFieldStyle(.roundedBorder).onSubmit{s.openWeb()};Button("Open"){s.openWeb()};Button("System browser"){if let url=URL(string:s.webAddress),["https","http"].contains(url.scheme ?? ""){NSWorkspace.shared.open(url)}}}
  HStack{Menu("ARC services / bookmarks"){ForEach(s.bookmarks){b in Button(b.name){s.openWeb(b.url)}}};Button("Jupyter / interactive apps"){s.openWeb("https://ood.arc.vt.edu")};Button("Built-in terminal"){s.tab="Terminal"}.disabled(!s.connected || s.busy);Spacer();Toggle("Session tools",isOn:$showTools).toggleStyle(.button)}
  if showTools{
   VStack(alignment:.leading,spacing:10){
    Text("Jupyter: sign in to Open OnDemand, choose Jupyter under Interactive Apps, review resources, and launch. Open a running session in this browser. If VT sign-in rejects an embedded browser, use System browser.").font(.caption).foregroundStyle(.secondary)
    HStack{TextField("Bookmark name",text:$s.bookmarkName).textFieldStyle(.roundedBorder);Button("Bookmark URL"){s.bookmark()}}
    Divider()
    Text("CONNECT TO AN EXISTING COMPUTE-NODE WEB APP").font(.system(size:10,design:.monospaced))
    HStack{TextField("Assigned compute node",text:$s.tunnelNode);TextField("Remote port",text:$s.tunnelRemotePort).frame(width:100);TextField("Local port",text:$s.tunnelLocalPort).frame(width:100);Button(s.tunnelSpec.isEmpty ? "Open tunnel":"Close tunnel"){if s.tunnelSpec.isEmpty{s.forward()}else{s.closeForward()}}.disabled(!s.connected || s.busy)}.textFieldStyle(.roundedBorder)
    Text("For a web service already running in your Slurm job and reachable from the login node. The local listener is restricted to 127.0.0.1. Closing a tunnel does not cancel the GPU job.").font(.caption).foregroundStyle(.secondary)
   }.padding(14).background(.primary.opacity(0.04),in:RoundedRectangle(cornerRadius:10))
  }
  if !s.webStatus.isEmpty{Text(s.webStatus).font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)}
  EmbeddedBrowser(workspace:s).frame(maxWidth:.infinity,maxHeight:.infinity).clipShape(RoundedRectangle(cornerRadius:10))
 }.padding(.bottom,4).onAppear{if s.web.url==nil{s.openWeb()}}.confirmationDialog("Start an interactive GPU session in Terminal?",isPresented:$confirmShell,titleVisibility:.visible){Button("Request GPU session"){s.interactive()};Button("Edit resource request"){s.tab="Submit job"}}message:{Text("\(s.profile.account) · \(s.profile.partition)\n\(s.profile.gpus) GPU(s), \(s.profile.cpus) CPUs, \(s.profile.memory) GB, \(s.profile.walltime).\nThe shell starts on a compute node after allocation. Exit it when finished to release resources.")}}
}
struct EmbeddedBrowser:NSViewRepresentable {
 @ObservedObject var workspace:Workspace
 func makeCoordinator()->Coordinator{Coordinator(workspace)}
 func makeNSView(context:Context)->WKWebView{workspace.web.navigationDelegate=context.coordinator;workspace.web.uiDelegate=context.coordinator;return workspace.web}
 func updateNSView(_ view:WKWebView,context:Context){}
 class Coordinator:NSObject,WKNavigationDelegate,WKUIDelegate {
  var s:Workspace
  init(_ s:Workspace){self.s=s}
  func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){s.webAddress=webView.url?.absoluteString ?? s.webAddress;s.webStatus=""}
  func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error){s.webStatus=error.localizedDescription+" · Try System browser if site authentication requires it."}
  func webView(_ webView:WKWebView,decidePolicyFor action:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void){guard let url=action.request.url else{decisionHandler(.cancel);return};decisionHandler(["http","https","about"].contains(url.scheme ?? "") ? .allow:.cancel)}
  func webView(_ webView:WKWebView,createWebViewWith configuration:WKWebViewConfiguration,for action:WKNavigationAction,windowFeatures:WKWindowFeatures)->WKWebView?{if action.targetFrame==nil,let url=action.request.url,["http","https"].contains(url.scheme ?? ""){webView.load(action.request)};return nil}
 }
}

struct ConsoleView:View {
 @EnvironmentObject var s:Workspace
 @ObservedObject var console:ARCConsole
 @State private var confirmStart=false
 @State private var confirmStop=false
 var body:some View {
  VStack(alignment:.leading,spacing:12){
   Panel(title:"Login Node Terminal"){
    Text("Login node is not for compute intensive jobs.").foregroundStyle(Color.red).font(.callout)
    Text(s.target).font(.system(size:11,design:.monospaced))
    HStack{Button("Start login terminal…"){confirmStart=true}.disabled(!s.connected || s.busy || console.running);Button("Interrupt (Ctrl-C)"){console.write("\u{0003}")}.disabled(!console.running);Button("Exit shell"){console.write("exit\n")}.disabled(!console.running);Button("Close session…"){confirmStop=true}.disabled(!console.running);Spacer();Text(console.session).font(.caption)}
   }
   NativeTerminal(console:console,dark:s.appearance == "Dark").frame(maxWidth:.infinity,maxHeight:.infinity).frame(minHeight:400).overlay(Rectangle().stroke(.gray.opacity(0.2)))
   Text("Click the terminal to type at the prompt. Use arrow keys for history, Tab for completion, and Ctrl-C to interrupt. Copy and paste with Command-C / Command-V. Compute-intensive work belongs in Jobs + software.").font(.caption).foregroundStyle(.secondary)

  }.confirmationDialog("Open a terminal on the login node?",isPresented:$confirmStart,titleVisibility:.visible){Button("Start login terminal"){s.startTerminal()}}message:{Text(s.target)}
  .confirmationDialog("Close the SSH terminal connection?",isPresented:$confirmStop,titleVisibility:.visible){Button("Close session",role:.destructive){console.stop()}}message:{Text("This closes the login-node shell connection.")}
 }
}
