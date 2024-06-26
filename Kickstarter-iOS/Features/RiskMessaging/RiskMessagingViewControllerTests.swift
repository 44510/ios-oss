@testable import Kickstarter_Framework
@testable import Library
import Prelude
import SnapshotTesting
import UIKit

final class RiskMessagingViewControllerTests: TestCase {
  override func setUp() {
    super.setUp()
    UIView.setAnimationsEnabled(false)
  }

  override func tearDown() {
    UIView.setAnimationsEnabled(true)
    super.tearDown()
  }

  func testView_PortraitOrientation() {
    combos(Language.allLanguages, [Device.phone4_7inch, Device.phone5_8inch, Device.pad]).forEach {
      language, device in
      withEnvironment(language: language, locale: .init(identifier: language.rawValue)) {
        let vc = RiskMessagingViewController()
        let (parent, _) = traitControllers(device: device, orientation: .portrait, child: vc)

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)_device_\(device)")
      }
    }
  }

  func testView_LandscapeOrientation() {
    combos(Language.allLanguages, [Device.phone4_7inch, Device.phone5_8inch, Device.pad]).forEach {
      language, device in
      withEnvironment(language: language, locale: .init(identifier: language.rawValue)) {
        let vc = RiskMessagingViewController()
        let (parent, _) = traitControllers(device: device, orientation: .landscape, child: vc)

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)_device_\(device)")
      }
    }
  }
}
