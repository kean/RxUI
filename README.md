# RxAutoBinding

Proof of concept auto-binding for RxSwift. RxAutoBinding is inspired by SwiftUI and significantly reduces boilerplate typically associated with RxSwift.

One of the major advantages of RxSwift is that it allows you to declare your business logic in a natural way using Swift method or properties. This means that it's easier to write, read, debug, *and* it's more efficient.

## RxObservableObject

You can think of `RxObservableObject` and `RxPublished` as analogs of SwiftUI `ObservableObject` and `Published`.

```swift
final class LoginViewModel: RxObservableObject {
    @RxPublished var email = ""
    @RxPublished var password = ""
    @RxPublished private(set) var isLoading = false

    var loginButtonTitle: String {
        "Welcome, \(email)"
    }

    var isLoginButtonEnabled: Bool {
        isInputValid && !isLoading
    }

    private var isInputValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    func login() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.isLoading = false
        }
    }
}
```

Each `RxObservableObject` has `objectWillChange` relay. The relay is generated automatically and is automatically bound to all properties marked with `@RxPublished` property wrapper. This all happens in runtime using reflection and associated objects.

## RxView

`RxView` is an analog of a SwiftUI `View`. There is, however, one crucial difference. In `UIKit`, views are expensive, can't recreate them each time. The is reflected in `RxView` design.

```swift
final class LoginViewController: UIViewController, RxView {
    // ... views ...

    private let model = LoginViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        createView()

        disposeBag.insert(
            emailTextField.rx.text.bind(to: model.$email),
            passwordTextField.rx.text.bind(to: model.$password),
            loginButton.rx.tap.subscribe(onNext: model.login)
        )

        bind(model) // Automatically registers for update
    }

    // Called automatically when model changes, but no more frequently than
    // once per render cycle.
    func refreshView() {
        titleLabel.text = model.loginButtonTitle
        model.isLoading ? spinner.startAnimating() : spinner.stopAnimating()
        loginButton.isEnabled = model.isLoginButtonEnabled
    }

    private func createView() {
        // ... add views on screen ...
    }
}
```

When you call `bind()` method that accepts `RxObservableObject` it automatically registers for its updates (`objectWillChange` property). When the object is changed, `refreshView()` is called automatically. `RxView` hooks into the display system such that `refreshView` called only once per one render cycle.

# License

RxAutoBinding is available under the MIT license. See the LICENSE file for more info.

