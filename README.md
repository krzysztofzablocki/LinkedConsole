# KZLinkedConsole

![](/logs.gif?raw=true)

Ever wondered which part of your application logged the message you just saw in console?

Wonder no more, instead just click on it to jump to the culprit. Simple as that.

## Instalation

Download the source, build the Xcode project and restart Xcode. 
The plugin will automatically be installed in ~/Library/Application Support/Developer/Shared/Xcode/Plug-ins. To uninstall, just remove the plugin from there (and restart Xcode).

### Alcatraz

This plugin can be installed using Alcatraz. Search for KZLinkedConsole in Alcatraz.

## Details

If a console logs a **fileName.extension:XX** that name turns into a clickable hyperlink that will open the specific file and highlight the line.

That way you can either use your own logging mechanism and just add this simple prefix, e.g.
~~~swift
func logMessage(message: String, filename: String = __FILE__, line: Int = __LINE__, func: String = __FUNCTION__) {
    print("\(filename.lastPathComponent):\(line) \(func):\r\(message)")
}
~~~

or if you use [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) you can use my custom formatter for some really nice logs.

Swift version (Objective-C version is part of [KZBootstrap](https://github.com/krzysztofzablocki/KZBootstrap)):
~~~swift
import Foundation
import CocoaLumberjack.DDDispatchQueueLogFormatter

class KZFormatter: DDDispatchQueueLogFormatter {

  lazy var formatter: NSDateFormatter = {
      let dateFormatter = NSDateFormatter()
      dateFormatter.formatterBehavior = .Behavior10_4
      dateFormatter.dateFormat = "HH:mm:ss.SSS"
      return dateFormatter
  }()

  override func formatLogMessage(logMessage: DDLogMessage!) -> String {
      let dateAndTime = formatter.stringFromDate(logMessage.timestamp)

      var logLevel: String
      let logFlag = logMessage.flag
      if logFlag.contains(.Error) {
          logLevel = "ERR"
      } else if logFlag.contains(.Warning){
          logLevel = "WRN"
      } else if logFlag.contains(.Info) {
          logLevel = "INF"
      } else if logFlag.contains(.Debug) {
          logLevel = "DBG"
      } else if logFlag.contains(.Verbose) {
          logLevel = "VRB"
      } else {
          logLevel = "???"
      }

      let formattedLog = "\(dateAndTime) |\(logLevel)| \((logMessage.file as NSString).lastPathComponent):\(logMessage.line): ( \(logMessage.function) ): \(logMessage.message)"
      return formattedLog;
  }
}
~~~

Read more about creation of this plugin on [my blog](http://localhost:1313/2015/12/writing-xcode-plugin-in-swift/)