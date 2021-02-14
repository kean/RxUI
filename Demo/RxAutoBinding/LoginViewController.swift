//
//  ViewController.swift
//  RxAutoBinding
//
//  Created by Alexander Grebenyuk on 14.02.2021.
//

import UIKit
import RxSwift
import RxCocoa

final class LoginViewController: UIViewController, RxView {
    private let titleLabel = UILabel()
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView()

    private let viewModel = LoginViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        createView()

        disposeBag.insert(
            emailTextField.rx.text.bind(to: viewModel.$email),
            passwordTextField.rx.text.bind(to: viewModel.$password),
            loginButton.rx.tap.subscribe(onNext: viewModel.login)
        )

        bind(viewModel) // Automatically registers for update
    }

    /// `refreshView` gets called automatically whenever viewModel sends `objectWillChange` event
    func refreshView() {
        titleLabel.text = viewModel.loginButtonTitle
        viewModel.isLoading ? spinner.startAnimating() : spinner.stopAnimating()
        loginButton.isEnabled = !viewModel.isLoginButtonEnabled
    }

    private func createView() {
        emailTextField.borderStyle = .roundedRect
        passwordTextField.borderStyle = .roundedRect
        loginButton.setTitle("Login", for: .normal)

        let stack = UIStackView(arrangedSubviews: [titleLabel, emailTextField, passwordTextField, loginButton, spinner])
        stack.axis = .vertical
        stack.spacing = 8
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 200),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}

final class LoginViewModel: RxObservableObject {
    @RxPublished var email: String?
    @RxPublished var password: String?
    @RxPublished private(set) var isLoading = false

    var loginButtonTitle: String {
        "Welcome, \(email ?? "–")"
    }

    var isLoginButtonEnabled: Bool {
        isInputValid && !isLoading
    }

    var isInputValid: Bool {
        (email ?? "").isEmpty && (password ?? "").isEmpty
    }

    func login() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.isLoading = false
        }
    }
}

// MARK: - RxObservableObject

public protocol RxObservableObject: AnyObject {
    var objectWillChange: PublishRelay<Void> { get }
}

public extension RxObservableObject {
    var objectWillChange: PublishRelay<Void> {
        if let relay = objc_getAssociatedObject(self, &objectWillChangeAssociatedKey) as? PublishRelay<Void> {
            return relay
        }
        let relay = PublishRelay<Void>()
        registerPublishedProperties(objectWillChange: relay)
        objc_setAssociatedObject(self, &objectWillChangeAssociatedKey, relay, .OBJC_ASSOCIATION_RETAIN)
        return relay
    }
}

private extension RxObservableObject {
    func registerPublishedProperties(objectWillChange: PublishRelay<Void>) {
        let allPublished = Mirror(reflecting: self)
            .children
            .compactMap { $0.value as? RxPublishedProtocol }
        let disposeBag = getDisposeBag(for: self)
        for published in allPublished {
            published.publishedWillChange.bind(to: objectWillChange).disposed(by: disposeBag)
        }
    }
}

private func getDisposeBag(for object: AnyObject) -> DisposeBag {
    if let disposeBag = objc_getAssociatedObject(object, &disposeBagAssociatedKey) as? DisposeBag {
        return disposeBag
    }
    let disposeBag = DisposeBag()
    objc_setAssociatedObject(object, &disposeBagAssociatedKey, disposeBag, .OBJC_ASSOCIATION_RETAIN)
    return disposeBag
}

private var objectWillChangeAssociatedKey = "RxObservableObject.objectWillChange.AssociatedKey"
private var disposeBagAssociatedKey = "RxObservableObject.disposeBag.AssociatedKey"

// MARK: - RxPublished

/// A Driver, but you can also read the current value.
@propertyWrapper
public struct RxPublished<Value>: RxPublishedProtocol {
    private let relay: Relay
    var publishedWillChange: Observable<Void> { relay.relay.map { _ in () } }

    public init(wrappedValue: Value) {
        relay = .init(value: wrappedValue)
    }

    public var wrappedValue: Value {
        set { relay.value = newValue }
        get { relay.value }
    }

    public var projectedValue: Relay { relay }

    // An actual implementation. This is required to prevent simultaneous access
    // to `wrappedValue`.
    public final class Relay {
        let relay: BehaviorRelay<Value>

        public var value: Value {
            didSet {
                relay.accept(value)
            }
        }
        public var driver: Driver<Value> { relay.asDriver() }

        init(value: Value) {
            self.relay = .init(value: value)
            self.value = value
        }
    }
}

public extension ControlProperty {
    func bind(to relay: RxPublished<Element>.Relay) -> Disposable {
        subscribe(onNext: { relay.value = $0 })
    }
}

protocol RxPublishedProtocol {
    var publishedWillChange: Observable<Void> { get }
}

// MARK: - RxView

public protocol RxView: AnyObject {
    /// Gets called whenever the observable object changes.
    func refreshView()
}

public extension RxView {
    var disposeBag: DisposeBag {
        getDisposeBag(for: self)
    }
}

public extension RxView where Self: UIViewController {
    /// Observes `objectWillChange` and automatically called refresh.
    func bind(_ object: RxObservableObject) {
        let fakeView = hookIntoRenderSystem(container: view)
        _bind(object, self, fakeView)
    }
}

public extension RxView where Self: UIView {
    /// Observes `objectWillChange` and automatically called refresh.
    func bind(_ object: RxObservableObject) {
        _bind(object, self, self)
    }
}

private func _bind(_ object: RxObservableObject, _ view: RxView, _ fakeView: UIView) {
    let disposeBag = getDisposeBag(for: view)

    view.refreshView()
    object.objectWillChange
        .subscribe(onNext: { [weak fakeView] in fakeView?.setNeedsLayout() })
        .disposed(by: disposeBag)

    fakeView.rx.sentMessage(#selector(UIView.layoutSubviews))
        .subscribe(onNext: { [weak view] _ in view?.refreshView() })
        .disposed(by: disposeBag)
}

// The idea is to refresh the view with the new data only when the screen needs
// to be re-rendered. We use a fake view to avoid re-rendering actualy stuff that
// doesn't need re-layout.
private func hookIntoRenderSystem(container: UIView) -> UIView {
    if let fakeView = objc_getAssociatedObject(container, &fakeViewAssociatedKey) as? UIView {
        return fakeView
    }
    let fakeView = UIView()
    fakeView.isHidden = true
    container.addSubview(fakeView)
    objc_setAssociatedObject(container, &fakeViewAssociatedKey, fakeView, .OBJC_ASSOCIATION_RETAIN)
    return fakeView
}

private var fakeViewAssociatedKey = "RxView.fakeViewAssociatedKey.AssociatedKey"
