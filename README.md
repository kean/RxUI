# RxUI

RxUI is inspired by SwiftUI. RxUI goal is to improve the developer experience of using RxSwift by allowing you to concentrate on the business logic instead of the low-level reactive code.

- You can express your business logic in a natural way using plain Swift properties and methods
- It makes it much easier to debug your views and view models. You can set breakpoints and query any of your view model state.
- It’s beginner friendly. You don’t need to learn `combineLatest`, `withLatestFrom` and other complex stateful operators to use it.
- It is more efficient because you avoid creating massive observable chains

> **WARNING** This is proof of concept.

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
    private let model = LoginViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        // ... add views on screen ...

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
}
```

When you call `bind()` method that accepts `RxObservableObject` it automatically registers for its updates (`objectWillChange` property). When the object is changed, `refreshView()` is called automatically. `RxView` hooks into the display system such that `refreshView` called only once per one render cycle.

# License

RxUI is available under the MIT license. See the LICENSE file for more info.
