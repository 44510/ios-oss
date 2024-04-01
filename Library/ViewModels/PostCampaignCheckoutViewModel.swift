import Foundation
import KsApi
import PassKit
import Prelude
import ReactiveSwift
import Stripe

public struct PostCampaignCheckoutData: Equatable {
  public let project: Project
  public let rewards: [Reward]
  public let selectedQuantities: SelectedRewardQuantities
  public let bonusAmount: Double?
  public let total: Double
  public let shipping: PledgeShippingSummaryViewData?
  public let refTag: RefTag?
  public let context: PledgeViewContext
  public let checkoutId: String
}

public struct PostCampaignPaymentAuthorizationData: Equatable {
  public let project: Project
  public let hasNoReward: Bool
  public let subtotal: Double
  public let bonus: Double
  public let shipping: Double
  public let total: Double
  public let merchantIdentifier: String
}

public struct PaymentSourceValidation {
  public let paymentIntentClientSecret: String
  public let selectedCardStripeCardId: String?
  public let requiresConfirmation: Bool
}

public protocol PostCampaignCheckoutViewModelInputs {
  func configure(with data: PostCampaignCheckoutData)
  func confirmPaymentSuccessful(clientSecret: String)
  func creditCardSelected(source: PaymentSourceSelected, paymentMethodId: String, isNewPaymentMethod: Bool)
  func goToLoginSignupTapped()
  func pledgeDisclaimerViewDidTapLearnMore()
  func submitButtonTapped()
  func termsOfUseTapped(with: HelpType)
  func userSessionStarted()
  func viewDidLoad()
  func applePayButtonTapped()
  func paymentAuthorizationDidAuthorizePayment(
    paymentData: (displayName: String?, network: String?, transactionIdentifier: String)
  )
  func paymentAuthorizationViewControllerDidFinish()
  func stripeTokenCreated(token: String?, error: Error?) -> PKPaymentAuthorizationStatus
}

public protocol PostCampaignCheckoutViewModelOutputs {
  var configurePaymentMethodsViewControllerWithValue: Signal<PledgePaymentMethodsValue, Never> { get }
  var configurePledgeRewardsSummaryViewWithData: Signal<
    (PostCampaignRewardsSummaryViewData, Double?, PledgeSummaryViewData),
    Never
  > { get }
  var configurePledgeViewCTAContainerView: Signal<PledgeViewCTAContainerViewData, Never> { get }
  var configureStripeIntegration: Signal<StripeConfigurationData, Never> { get }
  var goToLoginSignup: Signal<(LoginIntent, Project, Reward?), Never> { get }
  var paymentMethodsViewHidden: Signal<Bool, Never> { get }
  var showErrorBannerWithMessage: Signal<String, Never> { get }
  var showWebHelp: Signal<HelpType, Never> { get }
  var validateCheckoutSuccess: Signal<PaymentSourceValidation, Never> { get }
  var goToApplePayPaymentAuthorization: Signal<PostCampaignPaymentAuthorizationData, Never> { get }
  var checkoutComplete: Signal<ThanksPageData, Never> { get }
  var checkoutError: Signal<ErrorEnvelope, Never> { get }
}

public protocol PostCampaignCheckoutViewModelType {
  var inputs: PostCampaignCheckoutViewModelInputs { get }
  var outputs: PostCampaignCheckoutViewModelOutputs { get }
}

public class PostCampaignCheckoutViewModel: PostCampaignCheckoutViewModelType,
  PostCampaignCheckoutViewModelInputs,
  PostCampaignCheckoutViewModelOutputs {
  public init() {
    let initialData = Signal.combineLatest(
      self.configureWithDataProperty.signal,
      self.viewDidLoadProperty.signal
    )
    .map(first)
    .skipNil()

    let context = initialData.map(\.context)
    let checkoutId = initialData.map(\.checkoutId)
    let baseReward = initialData.map(\.rewards).map(\.first)

    let configurePaymentMethodsData = Signal.merge(
      initialData,
      initialData.takeWhen(self.userSessionStartedSignal)
    )

    self.configurePaymentMethodsViewControllerWithValue = configurePaymentMethodsData
      .compactMap { data -> PledgePaymentMethodsValue? in
        guard let user = AppEnvironment.current.currentUser else { return nil }
        guard let reward = data.rewards.first else { return nil }

        return (user, data.project, reward, data.context, data.refTag, data.total, .paymentIntent)
      }

    self.goToLoginSignup = initialData.takeWhen(self.goToLoginSignupSignal)
      .map { (LoginIntent.backProject, $0.project, $0.rewards.first) }

    let isLoggedIn = Signal.merge(initialData.ignoreValues(), self.userSessionStartedSignal)
      .map { _ in AppEnvironment.current.currentUser }
      .map(isNotNil)

    self.configurePledgeViewCTAContainerView = Signal.combineLatest(
      isLoggedIn,
      context
    )
    .map { isLoggedIn, context in
      PledgeViewCTAContainerViewData(
        isLoggedIn: isLoggedIn,
        isEnabled: true, // Pledge button never needs to be disabled on checkout page.
        context: context,
        willRetryPaymentMethod: false // Only retry in the `fixPaymentMethod` context.
      )
    }

    self.paymentMethodsViewHidden = Signal.combineLatest(isLoggedIn, context)
      .map { isLoggedIn, context in
        !isLoggedIn || context.paymentMethodsViewHidden
      }

    self.showWebHelp = Signal.merge(
      self.termsOfUseTappedSignal,
      self.pledgeDisclaimerViewDidTapLearnMoreSignal.mapConst(.trust)
    )

    self.configurePledgeRewardsSummaryViewWithData = initialData
      .compactMap { data in
        let rewardsData = PostCampaignRewardsSummaryViewData(
          rewards: data.rewards,
          selectedQuantities: data.selectedQuantities,
          projectCountry: data.project.country,
          omitCurrencyCode: data.project.stats.omitUSCurrencyCode,
          shipping: data.shipping
        )
        let pledgeData = PledgeSummaryViewData(
          project: data.project,
          total: data.total,
          confirmationLabelHidden: true
        )
        return (rewardsData, data.bonusAmount, pledgeData)
      }

    self.configureStripeIntegration = Signal.combineLatest(
      initialData,
      context
    )
    .filter { !$1.paymentMethodsViewHidden }
    .ignoreValues()
    .map { _ in
      (
        Secrets.ApplePay.merchantIdentifier,
        AppEnvironment.current.environmentType.stripePublishableKey
      )
    }

    // MARK: Validate Checkout Details On Submit

    let selectedCard = self.creditCardSelectedProperty.signal.skipNil()

    // MARK: - Validate Existing Cards

    /// Capture current users stored credit cards in the case that we need to validate an existing payment method
    let storedCardsEvent = initialData.ignoreValues()
      .switchMap { _ in
        AppEnvironment.current.apiService
          .fetchGraphUser(withStoredCards: true)
          .ksr_debounce(.seconds(1), on: AppEnvironment.current.scheduler)
          .map { envelope in (envelope, false) }
          .prefix(value: (nil, true))
          .materialize()
      }

    let storedCardsValues = storedCardsEvent.values()
      .filter(second >>> isFalse)
      .map(first)
      .skipNil()
      .map { $0.me.storedCards.storedCards }

    let selectedExistingCard = selectedCard.filter { (_, _, isNewPaymentMethod: Bool) in
      !isNewPaymentMethod
    }

    let newPaymentIntentForExistingCards = initialData
      .takeWhen(selectedExistingCard)
      .switchMap { initialData in
        let projectId = initialData.project.graphID
        let pledgeTotal = initialData.total

        return AppEnvironment.current.apiService
          .createPaymentIntentInput(input: CreatePaymentIntentInput(
            projectId: projectId,
            amountDollars: String(format: "%.2f", pledgeTotal),
            digitalMarketingAttributed: nil
          ))
          .materialize()
      }

    let paymentIntentClientSecretForExistingCards = newPaymentIntentForExistingCards.values()
      .map { $0.clientSecret }

    // Runs validation for pre-existing cards that were created with setup intents originally but require payment intents for late pledges.
    let validateCheckoutExistingCard = Signal
      .combineLatest(checkoutId, selectedCard, paymentIntentClientSecretForExistingCards, storedCardsValues)
      .takeWhen(self.submitButtonTappedProperty.signal)
      .filter { _, selectedCard, _, _ in
        selectedCard.isNewPaymentMethod == false
      }
      .switchMap { checkoutId, selectedExistingCreditCard, paymentIntentClientSecret, storedCards in
        let (_, paymentMethodId, _) = selectedExistingCreditCard
        let selectedStoredCard = storedCards.first { $0.id == paymentMethodId }
        let selectedCardStripeCardId = selectedStoredCard?.stripeCardId ?? ""

        return AppEnvironment.current.apiService
          .validateCheckout(
            checkoutId: checkoutId,
            paymentSourceId: selectedCardStripeCardId,
            paymentIntentClientSecret: paymentIntentClientSecret
          )
          .ksr_delay(AppEnvironment.current.apiDelayInterval, on: AppEnvironment.current.scheduler)
          .materialize()
      }

    let validateCheckoutExistingCardSuccess: Signal<PaymentSourceValidation, Never> = Signal
      .combineLatest(paymentIntentClientSecretForExistingCards, selectedCard, storedCardsValues)
      .takeWhen(validateCheckoutExistingCard.values())
      .map { paymentIntentClientSecret, selectedCard, storedCards in
        let (_, paymentMethodId, _) = selectedCard
        let selectedStoredCard = storedCards.first { $0.id == paymentMethodId }
        let selectedCardStripeCardId = selectedStoredCard?.stripeCardId ?? ""

        return PaymentSourceValidation(
          paymentIntentClientSecret: paymentIntentClientSecret,
          selectedCardStripeCardId: selectedCardStripeCardId,
          requiresConfirmation: true
        )
      }

    // MARK: - Validate New Cards

    // Runs validation for new cards that were created with payment intents.
    let validateCheckoutNewCard = Signal.combineLatest(checkoutId, selectedCard)
      .takeWhen(self.submitButtonTappedProperty.signal)
      .filter { _, selectedCard in
        selectedCard.isNewPaymentMethod == true
      }
      .switchMap { checkoutId, selectedNewCreditCard in
        let (paymentSource, paymentMethodId, _) = selectedNewCreditCard

        return AppEnvironment.current.apiService
          .validateCheckout(
            checkoutId: checkoutId,
            paymentSourceId: paymentMethodId,
            paymentIntentClientSecret: paymentSource.paymentIntentClientSecret!
          )
          .ksr_delay(AppEnvironment.current.apiDelayInterval, on: AppEnvironment.current.scheduler)
          .materialize()
      }

    let validateCheckoutNewCardSuccess: Signal<PaymentSourceValidation, Never> = selectedCard
      .takeWhen(validateCheckoutNewCard.values())
      .map { paymentSource, _, _ in PaymentSourceValidation(
        paymentIntentClientSecret: paymentSource.paymentIntentClientSecret!,
        selectedCardStripeCardId: nil,
        requiresConfirmation: false // Newly added cards are confirmed in PledgePaymentMethodsViewController
      ) }

    self.validateCheckoutSuccess = Signal
      .merge(validateCheckoutNewCardSuccess, validateCheckoutExistingCardSuccess)

    self.showErrorBannerWithMessage = Signal
      .merge(validateCheckoutExistingCard.errors(), validateCheckoutNewCard.errors())
      .map { _ in Strings.Something_went_wrong_please_try_again() }

    // MARK: ApplePay

    let paymentAuthorizationData: Signal<PostCampaignPaymentAuthorizationData, Never> = self
      .configureWithDataProperty
      .signal
      .skipNil()
      .map { (data: PostCampaignCheckoutData) -> PostCampaignPaymentAuthorizationData? in
        guard let firstReward = data.rewards.first else {
          // There should always be a reward - we create a special "no reward" reward if you make a monetary pledge
          return nil
        }

        return PostCampaignPaymentAuthorizationData(
          project: data.project,
          hasNoReward: firstReward.isNoReward,
          subtotal: firstReward.isNoReward ? firstReward.minimum : calculateAllRewardsTotal(
            addOnRewards: data.rewards,
            selectedQuantities: data.selectedQuantities
          ),
          bonus: data.bonusAmount ?? 0,
          shipping: data.shipping?.total ?? 0,
          total: data.total,
          merchantIdentifier: Secrets.ApplePay.merchantIdentifier
        )
      }
      .skipNil()

    self.goToApplePayPaymentAuthorization = paymentAuthorizationData
      .takeWhen(self.applePayButtonTappedSignal)

    let pkPaymentData = self.pkPaymentSignal
      .map { pkPayment -> PKPaymentData? in
        guard let displayName = pkPayment.displayName, let network = pkPayment.network else {
          return nil
        }

        return (displayName, network, pkPayment.transactionIdentifier)
      }

    let applePayParams = Signal.combineLatest(
      pkPaymentData.skipNil(),
      self.stripeTokenSignal.skipNil()
    )
    .map { paymentData, token in
      (
        paymentData.displayName,
        paymentData.network,
        paymentData.transactionIdentifier,
        token
      )
    }
    .map(ApplePayParams.init)

    // TODO: Real implementation
    applePayParams.observeValues { params in
      print("Got ApplePay params: \(params)")
    }

    // MARK: CompleteOnSessionCheckout

    let completeCheckoutWithCreditCardInput: Signal<GraphAPI.CompleteOnSessionCheckoutInput, Never> = Signal
      .combineLatest(self.confirmPaymentSuccessfulProperty.signal.skipNil(), checkoutId, selectedCard)
      .map { (
        clientSecret: String,
        checkoutId: String,
        selectedCard: (source: PaymentSourceSelected, paymentMethodId: String, isNewPaymentMethod: Bool)
      ) -> GraphAPI.CompleteOnSessionCheckoutInput in

      GraphAPI
        .CompleteOnSessionCheckoutInput(
          checkoutId: encodeToBase64("Checkout-\(checkoutId)"),
          paymentIntentClientSecret: clientSecret,
          paymentSourceId: selectedCard.isNewPaymentMethod ? nil : selectedCard.paymentMethodId,
          paymentSourceReusable: true,
          applePay: nil
        )
      }

    // TODO: Implement ApplePay
    // let completeCheckoutWithApplePay =

    let checkoutCompleteSignal = Signal
      .merge(
        completeCheckoutWithCreditCardInput
        // completeCheckoutWithApplePayInput
      )
      .switchMap { input in
        AppEnvironment.current.apiService.completeOnSessionCheckout(input: input).materialize()
      }

    let thanksPageData = Signal.combineLatest(initialData, baseReward)
      .map { initialData, baseReward -> ThanksPageData? in
        guard let reward = baseReward else { return nil }

        return (initialData.project, reward, nil, initialData.total)
      }

    self.checkoutComplete = thanksPageData.skipNil()
      .takeWhen(checkoutCompleteSignal.signal.values())
      .map { $0 }

    self.checkoutError = checkoutCompleteSignal.signal.errors()
  }

  // MARK: - Inputs

  private let configureWithDataProperty = MutableProperty<PostCampaignCheckoutData?>(nil)
  public func configure(with data: PostCampaignCheckoutData) {
    self.configureWithDataProperty.value = data
  }

  private let confirmPaymentSuccessfulProperty = MutableProperty<String?>(nil)
  public func confirmPaymentSuccessful(clientSecret: String) {
    self.confirmPaymentSuccessfulProperty.value = clientSecret
  }

  private let creditCardSelectedProperty =
    MutableProperty<(source: PaymentSourceSelected, paymentMethodId: String, isNewPaymentMethod: Bool)?>(nil)
  public func creditCardSelected(
    source: PaymentSourceSelected,
    paymentMethodId: String,
    isNewPaymentMethod: Bool
  ) {
    self.creditCardSelectedProperty.value = (source, paymentMethodId, isNewPaymentMethod)
  }

  private let (goToLoginSignupSignal, goToLoginSignupObserver) = Signal<Void, Never>.pipe()
  public func goToLoginSignupTapped() {
    self.goToLoginSignupObserver.send(value: ())
  }

  private let (pledgeDisclaimerViewDidTapLearnMoreSignal, pledgeDisclaimerViewDidTapLearnMoreObserver)
    = Signal<Void, Never>.pipe()
  public func pledgeDisclaimerViewDidTapLearnMore() {
    self.pledgeDisclaimerViewDidTapLearnMoreObserver.send(value: ())
  }

  private let submitButtonTappedProperty = MutableProperty(())
  public func submitButtonTapped() {
    self.submitButtonTappedProperty.value = ()
  }

  private let (termsOfUseTappedSignal, termsOfUseTappedObserver) = Signal<HelpType, Never>.pipe()
  public func termsOfUseTapped(with helpType: HelpType) {
    self.termsOfUseTappedObserver.send(value: helpType)
  }

  private let (userSessionStartedSignal, userSessionStartedObserver) = Signal<Void, Never>.pipe()
  public func userSessionStarted() {
    self.userSessionStartedObserver.send(value: ())
  }

  private let viewDidLoadProperty = MutableProperty(())
  public func viewDidLoad() {
    self.viewDidLoadProperty.value = ()
  }

  private let (applePayButtonTappedSignal, applePayButtonTappedObserver) = Signal<Void, Never>.pipe()
  public func applePayButtonTapped() {
    self.applePayButtonTappedObserver.send(value: ())
  }

  private let (pkPaymentSignal, pkPaymentObserver) = Signal<(
    displayName: String?,
    network: String?,
    transactionIdentifier: String
  ), Never>.pipe()
  public func paymentAuthorizationDidAuthorizePayment(paymentData: (
    displayName: String?,
    network: String?,
    transactionIdentifier: String
  )) {
    self.pkPaymentObserver.send(value: paymentData)
  }

  private let (paymentAuthorizationDidFinishSignal, paymentAuthorizationDidFinishObserver)
    = Signal<Void, Never>.pipe()
  public func paymentAuthorizationViewControllerDidFinish() {
    self.paymentAuthorizationDidFinishObserver.send(value: ())
  }

  private let (stripeTokenSignal, stripeTokenObserver) = Signal<String?, Never>.pipe()
  private let (stripeErrorSignal, stripeErrorObserver) = Signal<Error?, Never>.pipe()
  private let createApplePayBackingStatusProperty = MutableProperty<PKPaymentAuthorizationStatus>(.failure)

  public func stripeTokenCreated(token: String?, error: Error?) -> PKPaymentAuthorizationStatus {
    self.stripeTokenObserver.send(value: token)
    self.stripeErrorObserver.send(value: error)

    return self.createApplePayBackingStatusProperty.value
  }

  // MARK: - Outputs

  public let configurePaymentMethodsViewControllerWithValue: Signal<PledgePaymentMethodsValue, Never>
  public let configurePledgeRewardsSummaryViewWithData: Signal<(
    PostCampaignRewardsSummaryViewData,
    Double?,
    PledgeSummaryViewData
  ), Never>
  public let configurePledgeViewCTAContainerView: Signal<PledgeViewCTAContainerViewData, Never>
  public let configureStripeIntegration: Signal<StripeConfigurationData, Never>
  public let goToLoginSignup: Signal<(LoginIntent, Project, Reward?), Never>
  public let paymentMethodsViewHidden: Signal<Bool, Never>
  public let showErrorBannerWithMessage: Signal<String, Never>
  public let showWebHelp: Signal<HelpType, Never>
  public let validateCheckoutSuccess: Signal<PaymentSourceValidation, Never>
  public let goToApplePayPaymentAuthorization: Signal<PostCampaignPaymentAuthorizationData, Never>
  public let checkoutComplete: Signal<ThanksPageData, Never>
  public let checkoutError: Signal<ErrorEnvelope, Never>

  public var inputs: PostCampaignCheckoutViewModelInputs { return self }
  public var outputs: PostCampaignCheckoutViewModelOutputs { return self }
}
