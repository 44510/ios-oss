@testable import Kickstarter_Framework
@testable import KsApi
import Library
import Prelude
import SnapshotTesting
import XCTest

internal final class SettingsViewControllerTests: TestCase {
  override func setUp() {
    super.setUp()
    UIView.setAnimationsEnabled(false)
  }

  override func tearDown() {
    UIView.setAnimationsEnabled(true)
    super.tearDown()
  }

  func testView() {
    let currentUser = User.template

    combos(Language.allLanguages, [Device.phone4_7inch, Device.phone5_8inch, Device.pad])
      .forEach { language, device in
        withEnvironment(
          apiService: MockService(fetchUserSelfResponse: currentUser),
          currentUser: currentUser,
          language: language
        ) {
          let vc = SettingsViewController.instantiate()
          let (parent, _) = traitControllers(device: device, orientation: .portrait, child: vc)

          self.scheduler.run()

          assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)_device_\(device)")
        }
      }
  }

  func testView_isFollowingOn() {
    let currentUser = User.template
      |> \.social .~ true

    Language.allLanguages.forEach { language in
      withEnvironment(
        apiService: MockService(fetchUserSelfResponse: currentUser),
        currentUser: currentUser,
        language: language
      ) {
        let vc = SettingsViewController.instantiate()

        let (parent, _) = traitControllers(device: .phone4_7inch, orientation: .portrait, child: vc)

        self.scheduler.run()

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)")
      }
    }
  }

  func testView_isFollowingOff() {
    let currentUser = User.template
      |> \.social .~ false

    Language.allLanguages.forEach { language in
      withEnvironment(
        apiService: MockService(fetchUserSelfResponse: currentUser),
        currentUser: currentUser,
        language: language
      ) {
        let vc = SettingsViewController.instantiate()

        let (parent, _) = traitControllers(
          device: .phone4_7inch,
          orientation: .portrait,
          child: vc
        )

        self.scheduler.run()

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)")
      }
    }
  }
}
