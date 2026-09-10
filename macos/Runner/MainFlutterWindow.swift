import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 桌面端默认给一个够宽、能显示「左列表 + 右详情」两栏的窗口。
    // 自适应断点是 840pt（见 lib/pages/widgets/responsive.dart 的 Breakpoints.twoPane），
    // 模板默认的 800x600 低于断点，启动时只会看到单列布局。
    self.setContentSize(NSSize(width: 1180, height: 780))
    // 允许缩得很窄以触发单列布局，但不允许小到控件挤成一团
    self.minSize = NSSize(width: 420, height: 520)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
