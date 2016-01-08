# KZLinkedConsole

![](/logs.gif?raw=true)

Ever wondered which part of your application logged the message you just saw in console?

Wonder no more, instead just click on it to jump to the culprit. Simple as that.

## Installation

Download the source, build the Xcode project and restart Xcode. 
The plugin will automatically be installed in ~/Library/Application Support/Developer/Shared/Xcode/Plug-ins. To uninstall, just remove the plugin from there (and restart Xcode).

### Alcatraz

This plugin can be installed using Alcatraz. Search for KZLinkedConsole in Alcatraz.

## Details

If a console logs a **fileName.extension:123** that name turns into a clickable hyperlink that will open the specific file and highlight the line.

That way you can either use your own logging mechanism and just add this simple prefix, e.g.
~~~swift
func logMessage(message: String, filename: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
    print("\((filename as NSString).lastPathComponent):\(line) \(function):\r\(message)")
}
~~~

## Integration with popular loggers

- [XCGLogger](https://github.com/DaveWoodCom/XCGLogger) is supported out of the box.
- [SwiftyBeaver](https://github.com/skreutzberger/SwiftyBeaver) is supported out of the box.
- [QorumLogs](https://github.com/goktugyil/QorumLogs) after enable KZLinkedConsoleSupportEnabled flag.  
~~~swift
QorumLogs.KZLinkedConsoleSupportEnabled = true
~~~
- [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) supported, with a log formatter printing **fileName.extension:123**, here's my log formatter for it:

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

## More info
Read more about creation of this plugin on [my blog](http://merowing.info/2015/12/writing-xcode-plugin-in-swift/)

[Follow me on twitter for more useful iOS stuff](http://twitter.com/merowing_)
