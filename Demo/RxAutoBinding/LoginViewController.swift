//
//  ViewController.swift
//  RxAutoBinding
//
//  Created by Alexander Grebenyuk on 14.02.2021.
//

import UIKit
import RxSwift
import RxCocoa

// TODO: setup local package correctly
final class LoginViewController: UIViewController, RxView {
    private let titleLabel = UILabel()
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView()

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

    /// `refreshView` gets called automatically whenever viewModel sends `objectWillChange` event
    func refreshView() {
        titleLabel.text = model.loginButtonTitle
        model.isLoading ? spinner.startAnimating() : spinner.stopAnimating()
        loginButton.isEnabled = model.isLoginButtonEnabled
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
        !(email ?? "").isEmpty && !(password ?? "").isEmpty
    }

    func login() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.isLoading = false
        }
    }
}
