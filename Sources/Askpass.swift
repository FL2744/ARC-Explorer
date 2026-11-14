import AppKit
let app=NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps:true)
let prompt=CommandLine.arguments.dropFirst().joined(separator:" ")
let alert=NSAlert();alert.messageText="ARC-Explorer · SSH authentication";alert.informativeText=prompt
let confirmation=prompt.lowercased().contains("yes/no") || prompt.lowercased().contains("fingerprint")
if confirmation {
 alert.addButton(withTitle:"Accept host key");alert.addButton(withTitle:"Cancel")
 if alert.runModal() == .alertFirstButtonReturn {print("yes")} else {exit(1)}
} else {
 let field=NSSecureTextField(frame:NSRect(x:0,y:0,width:420,height:26));field.placeholderString="Password, key passphrase, or verification response"
 alert.accessoryView=field;alert.addButton(withTitle:"Continue");alert.addButton(withTitle:"Cancel");alert.window.initialFirstResponder=field
 if alert.runModal() == .alertFirstButtonReturn {print(field.stringValue)} else {exit(1)}
}
