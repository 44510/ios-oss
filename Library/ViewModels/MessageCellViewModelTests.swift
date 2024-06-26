import Foundation
@testable import KsApi
import Library
import ReactiveExtensions_TestHelpers
import ReactiveSwift

internal final class MessageCellViewModelTests: TestCase {
  fileprivate let vm: MessageCellViewModelType = MessageCellViewModel()

  fileprivate let avatarURL = TestObserver<URL?, Never>()
  fileprivate let body = TestObserver<String, Never>()
  fileprivate let _name = TestObserver<String, Never>()
  fileprivate let timestamp = TestObserver<String, Never>()
  fileprivate let timestampAccessibilityLabel = TestObserver<String, Never>()
  fileprivate let messageSender = TestObserver<User, Never>()

  override func setUp() {
    super.setUp()

    self.vm.outputs.avatarURL.observe(self.avatarURL.observer)
    self.vm.outputs.name.observe(self._name.observer)
    self.vm.outputs.timestamp.observe(self.timestamp.observer)
    self.vm.outputs.timestampAccessibilityLabel.observe(self.timestampAccessibilityLabel.observer)
    self.vm.outputs.body.observe(self.body.observer)
    self.vm.outputs.messageSender.observe(self.messageSender.observer)
  }

  func testOutputs() {
    let message = Message.template
    self.vm.inputs.configureWith(message: message)

    self.avatarURL.assertValueCount(1)
    self._name.assertValues([message.sender.name])
    self.timestamp.assertValueCount(1)
    self.timestampAccessibilityLabel.assertValueCount(1)
    self.body.assertValues([message.body])
  }

  func testOutput_CellHeaderTapped_EmitsCellAuthor() {
    let message = Message.template
    withEnvironment(currentUser: .template) {
      self.vm.inputs.configureWith(message: message)
      self.messageSender.assertDidNotEmitValue()

      self.vm.inputs.cellHeaderTapped()

      self.messageSender
        .assertValue(message.sender)
    }
  }
}
