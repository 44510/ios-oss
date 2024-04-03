import KsApi
import Library
import Prelude
import UIKit

protocol PledgeCTAContainerViewDelegate: AnyObject {
  func pledgeCTAButtonTapped(with state: PledgeStateCTAType)
}

private enum Layout {
  enum Button {
    static let minHeight: CGFloat = 48.0
    static let minWidth: CGFloat = 98.0
  }

  enum RetryButton {
    static let minWidth: CGFloat = 120.0
  }

  enum ActivityIndicator {
    static let height: CGFloat = 30
  }
}

final class PledgeCTAContainerView: UIView {
  // MARK: - Properties

  private lazy var activityIndicator: UIActivityIndicatorView = {
    let indicator = UIActivityIndicatorView(frame: .zero)
      |> \.translatesAutoresizingMaskIntoConstraints .~ false
    indicator.startAnimating()
    return indicator
  }()

  private lazy var activityIndicatorContainerView: UIView = {
    UIView(frame: .zero)
      |> \.translatesAutoresizingMaskIntoConstraints .~ false
  }()

  private(set) lazy var pledgeCTAButton: UIButton = {
    UIButton(type: .custom)
      |> \.translatesAutoresizingMaskIntoConstraints .~ false
  }()

  private(set) lazy var retryButton: UIButton = {
    UIButton(type: .custom)
      |> \.translatesAutoresizingMaskIntoConstraints .~ false
  }()

  private lazy var retryDescriptionLabel: UILabel = { UILabel(frame: .zero) }()
  private lazy var retryStackView: UIStackView = { UIStackView(frame: .zero) }()

  private lazy var rootStackView: UIStackView = {
    UIStackView(frame: .zero)
      |> \.translatesAutoresizingMaskIntoConstraints .~ false
  }()

  private lazy var spacer: UIView = {
    UIView(frame: .zero)
      |> \.translatesAutoresizingMaskIntoConstraints .~ false
  }()

  private lazy var subtitleLabel: UILabel = { UILabel(frame: .zero) }()

  private lazy var watchesLabel: UILabel = { UILabel(frame: .zero) }()

  private lazy var titleAndSubtitleStackView: UIStackView = {
    UIStackView(frame: .zero)
      |> \.translatesAutoresizingMaskIntoConstraints .~ false
  }()

  private lazy var pledgeButtonAndWatchesStackView: UIStackView = {
    UIStackView(frame: .zero)
      |> \.translatesAutoresizingMaskIntoConstraints .~ false
  }()

  private lazy var titleLabel: UILabel = { UILabel(frame: .zero) }()

  private var projectSavedObserver: Any?

  weak var delegate: PledgeCTAContainerViewDelegate?

  private let viewModel: PledgeCTAContainerViewViewModelType = PledgeCTAContainerViewViewModel()

  // MARK: - Lifecycle

  override init(frame: CGRect) {
    super.init(frame: frame)

    self.configureSubviews()
    self.setupConstraints()
    self.bindViewModel()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Styles

  deinit {
    self.projectSavedObserver.doIfSome(NotificationCenter.default.removeObserver)
  }

  override func bindStyles() {
    super.bindStyles()

    _ = self
      |> \.layoutMargins .~ .init(all: Styles.grid(3))

    _ = self.layer
      |> checkoutLayerCardRoundedStyle
      |> \.backgroundColor .~ UIColor.ksr_white.cgColor
      |> \.shadowColor .~ UIColor.ksr_black.cgColor
      |> \.shadowOpacity .~ 0.12
      |> \.shadowOffset .~ CGSize(width: 0, height: -1.0)
      |> \.shadowRadius .~ CGFloat(1.0)
      |> \.maskedCorners .~ [
        CACornerMask.layerMaxXMinYCorner,
        CACornerMask.layerMinXMinYCorner
      ]

    let isAccessibilityCategory = self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory

    _ = self.retryButton
      |> greyButtonStyle
      |> UIButton.lens.title(for: .normal) %~ { _ in Strings.Retry() }

    _ = self.retryStackView
      |> retryStackViewStyle

    _ = self.retryDescriptionLabel
      |> retryDescriptionLabelStyle

    _ = self.titleAndSubtitleStackView
      |> titleAndSubtitleStackViewStyle

    _ = self.pledgeButtonAndWatchesStackView
      |> pledgeButtonAndWatchesStackViewStyle

    _ = self.rootStackView
      |> adaptableStackViewStyle(isAccessibilityCategory)

    _ = self.titleLabel
      |> titleLabelStyle

    _ = self.subtitleLabel
      |> subtitleLabelStyle

    _ = self.watchesLabel
      |> watchesLabelStyle

    _ = self.activityIndicator
      |> activityIndicatorStyle
  }

  // MARK: - View Model

  override func bindViewModel() {
    super.bindViewModel()

    self.viewModel.outputs.notifyDelegateCTATapped
      .observeForUI()
      .observeValues { [weak self] state in
        self?.delegate?.pledgeCTAButtonTapped(with: state)
      }

    self.viewModel.outputs.buttonStyleType
      .observeForUI()
      .observeValues { [weak self] buttonStyleType in
        _ = self?.pledgeCTAButton
          ?|> buttonStyleType.style
      }

    self.viewModel.outputs.prelaunchCTASaved
      .observeForUI()
      .observeValues { [weak self] isPrelaunch, saved, _ in
        guard isPrelaunch else { return }

        _ = self?.pledgeCTAButton
          ?|> saved ? prelaunchButtonSavedImageStyle : prelaunchButtonUnsavedImageStyle

        self?.watchesLabel.isHidden = !isPrelaunch
      }

    self.projectSavedObserver = NotificationCenter.default
      .addObserver(forName: Notification.Name.ksr_projectSaved, object: nil, queue: nil) { [weak self]
        notification in
          self?.viewModel.inputs.savedProjectFromNotification(
            project: notification.userInfo?["project"] as? Project
          )
      }

    self.activityIndicatorContainerView.rac.hidden = self.viewModel.outputs.activityIndicatorIsHidden
    self.pledgeCTAButton.rac.hidden = self.viewModel.outputs.pledgeCTAButtonIsHidden
    self.pledgeCTAButton.rac.title = self.viewModel.outputs.buttonTitleText
    self.retryStackView.rac.hidden = self.viewModel.outputs.retryStackViewIsHidden
    self.spacer.rac.hidden = self.viewModel.outputs.spacerIsHidden
    self.subtitleLabel.rac.text = self.viewModel.outputs.subtitleText
    self.titleAndSubtitleStackView.rac.hidden = self.viewModel.outputs.stackViewIsHidden
    self.titleLabel.rac.text = self.viewModel.outputs.titleText
    self.pledgeButtonAndWatchesStackView.rac.hidden = self.viewModel.outputs.pledgeCTAButtonIsHidden
    self.watchesLabel.rac.hidden = self.viewModel.outputs.watchesLabelIsHidden
    self.watchesLabel.rac.text = self.viewModel.outputs.watchesCountText
  }

  // MARK: - Configuration

  func configureWith(value: PledgeCTAContainerViewData) {
    self.viewModel.inputs.configureWith(value: value)
  }

  // MARK: Functions

  private func configureSubviews() {
    _ = (self.rootStackView, self)
      |> ksr_addSubviewToParent()
      |> ksr_constrainViewToEdgesInParent()

    _ = (self.activityIndicator, self.activityIndicatorContainerView)
      |> ksr_addSubviewToParent()

    _ = ([self.titleLabel, self.subtitleLabel], self.titleAndSubtitleStackView)
      |> ksr_addArrangedSubviewsToStackView()

    _ = ([self.pledgeCTAButton, self.watchesLabel], self.pledgeButtonAndWatchesStackView)
      |> ksr_addArrangedSubviewsToStackView()

    _ = ([self.retryDescriptionLabel, self.retryButton], self.retryStackView)
      |> ksr_addArrangedSubviewsToStackView()

    self.retryButton.setContentHuggingPriority(.required, for: .horizontal)

    _ = (
      [
        self.retryStackView,
        self.titleAndSubtitleStackView,
        self.spacer,
        self.pledgeButtonAndWatchesStackView,
        self.activityIndicatorContainerView
      ],
      self.rootStackView
    )
      |> ksr_addArrangedSubviewsToStackView()

    self.pledgeCTAButton.addTarget(
      self, action: #selector(self.pledgeCTAButtonTapped), for: .touchUpInside
    )
  }

  private func setupConstraints() {
    NSLayoutConstraint.activate([
      self.activityIndicator.centerXAnchor
        .constraint(equalTo: self.activityIndicatorContainerView.centerXAnchor),
      self.activityIndicator.centerYAnchor
        .constraint(equalTo: self.activityIndicatorContainerView.centerYAnchor),
      self.activityIndicatorContainerView.widthAnchor.constraint(equalTo: self.widthAnchor),
      self.activityIndicatorContainerView.heightAnchor.constraint(equalToConstant: Layout.Button.minHeight),
      self.activityIndicatorContainerView.centerXAnchor
        .constraint(equalTo: self.layoutMarginsGuide.centerXAnchor),
      self.activityIndicatorContainerView.centerYAnchor
        .constraint(equalTo: self.layoutMarginsGuide.centerYAnchor),
      self.pledgeCTAButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.Button.minHeight),
      self.pledgeCTAButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.Button.minWidth),
      self.retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.Button.minHeight),
      self.retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.RetryButton.minWidth)
    ])
  }

  @objc func pledgeCTAButtonTapped() {
    self.viewModel.inputs.pledgeCTAButtonTapped()
  }
}

// MARK: - Styles

private let activityIndicatorStyle: ActivityIndicatorStyle = { activityIndicator in
  activityIndicator
    |> \.color .~ UIColor.ksr_support_400
    |> \.hidesWhenStopped .~ true
}

private func adaptableStackViewStyle(_ isAccessibilityCategory: Bool) -> (StackViewStyle) {
  return { (stackView: UIStackView) in
    let spacing: CGFloat = (isAccessibilityCategory ? Styles.grid(1) : 0)

    return stackView
      |> \.alignment .~ .center
      |> \.axis .~ NSLayoutConstraint.Axis.horizontal
      |> \.isLayoutMarginsRelativeArrangement .~ true
      |> \.layoutMargins .~ UIEdgeInsets.init(topBottom: Styles.grid(3), leftRight: Styles.grid(3))
      |> \.spacing .~ spacing
  }
}

private let subtitleLabelStyle: LabelStyle = { label in
  label
    |> \.font .~ UIFont.ksr_caption1().bolded
    |> \.textColor .~ UIColor.ksr_support_400
    |> \.numberOfLines .~ 0
}

private let titleAndSubtitleStackViewStyle: StackViewStyle = { stackView in
  stackView
    |> \.axis .~ NSLayoutConstraint.Axis.vertical
    |> \.isLayoutMarginsRelativeArrangement .~ true
    |> \.spacing .~ Styles.gridHalf(1)
}

private let pledgeButtonAndWatchesStackViewStyle: StackViewStyle = { stackView in
  stackView
    |> \.axis .~ NSLayoutConstraint.Axis.vertical
    |> \.isLayoutMarginsRelativeArrangement .~ true
    |> \.spacing .~ Styles.grid(1)
}

private let titleLabelStyle: LabelStyle = { label in
  label
    |> \.font .~ UIFont.ksr_callout().bolded
    |> \.numberOfLines .~ 0
}

private let retryStackViewStyle: StackViewStyle = { stackView in
  stackView
    |> \.axis .~ .horizontal
    |> \.alignment .~ .center
    |> \.spacing .~ Styles.grid(3)
    |> \.isLayoutMarginsRelativeArrangement .~ true
}

private let retryDescriptionLabelStyle: LabelStyle = { label in
  label
    |> \.textAlignment .~ .left
    |> \.font .~ .ksr_headline()
    |> \.lineBreakMode .~ .byWordWrapping
    |> \.numberOfLines .~ 0
    |> \.text %~ { _ in Strings.Content_isnt_loading_right_now() }
}

private let prelaunchButtonUnsavedImageStyle: ButtonStyle = { button in
  button
    |> UIButton.lens.image(for: .normal) .~ image(named: "icon--heart-outline")
    |> UIButton.lens.tintColor .~ .ksr_white
    |> UIButton.lens.imageEdgeInsets .~ .init(top: 0, left: 0, bottom: 0, right: 10.0)
    |> UIButton.lens.titleColor(for: .normal) .~ .ksr_white
    |> UIButton.lens.backgroundColor(for: .normal) .~ .ksr_black
    |> UIButton.lens.titleColor(for: .highlighted) .~ .ksr_white
    |> UIButton.lens.backgroundColor(for: .highlighted) .~ .ksr_black
}

private let prelaunchButtonSavedImageStyle: ButtonStyle = { button in
  button
    |> baseButtonStyle
    |> UIButton.lens.titleLabel.font .~ UIFont.boldSystemFont(ofSize: 16)
    |> UIButton.lens.image(for: .normal) .~ image(named: "icon--heart")
    |> UIButton.lens.imageEdgeInsets .~ .init(top: 0, left: 0, bottom: 0, right: 10.0)
    |> UIButton.lens.titleColor(for: .normal) .~ .ksr_black
    |> UIButton.lens.layer.borderColor .~ UIColor.ksr_support_300.cgColor
    |> UIButton.lens.layer.borderWidth .~ 1.0
    |> UIButton.lens.backgroundColor(for: .normal) .~ .ksr_white
    |> UIButton.lens.titleColor(for: .normal) .~ .ksr_black
    |> UIButton.lens.titleColor(for: .highlighted) .~ .ksr_black
    |> UIButton.lens.backgroundColor(for: .highlighted) .~ .ksr_white
}

private let watchesLabelStyle: LabelStyle = { label in
  label
    |> \.font .~ UIFont.ksr_caption1()
    |> \.textColor .~ UIColor.ksr_support_700
    |> \.numberOfLines .~ 1
    |> \.textAlignment .~ .center
}
