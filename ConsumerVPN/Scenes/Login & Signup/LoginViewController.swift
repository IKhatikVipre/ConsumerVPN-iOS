//
//  LoginViewController.swift
//  ConsumerVPN
//
//  Created by WLVPN on 9/6/16.
//  Copyright © 2019 NetProtect. All rights reserved.
//

import UIKit
import VPNKit

class LoginViewController: UIViewController {
	
	var delegate: LoginFlowViewControllerDelegate!
	
	// MARK: - IBOutets and Variables
	@IBOutlet weak var usernameTextField: UITextField!
	@IBOutlet weak var usernameIconImageView: UIImageView!
	
	@IBOutlet weak var passwordTextField: UITextField!
	@IBOutlet weak var passwordIconImageView: UIImageView!
	
	@IBOutlet weak var bannerImageView: UIImageView!
	@IBOutlet weak var bannerImageTopConstraint: NSLayoutConstraint!
	
	@IBOutlet weak var loginControlsStackView: UIStackView!
	@IBOutlet weak var loginControlsStackViewTopConstraint: NSLayoutConstraint!
	
	@IBOutlet weak var forgotButton: UIButton!
	@IBOutlet weak var loginButton: CustomButton!
	@IBOutlet weak var signupButton: UIButton!
	
	// MARK: - Constraint Values
	
	// This controls how much space exists between the login controls and the banner
	private var loginControlsStackViewTopConstraintConstant: CGFloat = 90.0
	// This controls how much space exists between the top of the view and the banner
	private var bannerImageTopConstraintConstant: CGFloat = 50.0
	
	// This controls how much space exists between the top of the view and the banner,
	// as well as between the top of the login controls and the banner.
	// Warning: This value has been determined to be optimal for the smallest
	// suppored iOS device (currently the SE), so changing it is ill advised.
	private var smallViewTopConstraintTopConstant: CGFloat = 20.0
	
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .loginStatusBar
	}
	
	// MARK: - Lifecycle Methods
	
	override func viewDidLoad() {
		super.viewDidLoad()
		if #available(iOS 13.0, *) {
			self.isModalInPresentation = true
		}
		configureView()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		setNeedsStatusBarAppearanceUpdate()
	}
	
	private func configureView() {
		drawGradient()
		drawTriangles()
		
		bannerImageTopConstraint.constant = bannerImageTopConstraintConstant
		loginControlsStackViewTopConstraint.constant = loginControlsStackViewTopConstraintConstant
		
		usernameIconImageView.image = UIImage(named: "userIcon")?.withRenderingMode(.alwaysTemplate)
		usernameIconImageView.tintColor = .loginIconColor
		
		passwordIconImageView.image = UIImage(named: "lockIcon")?.withRenderingMode(.alwaysTemplate)
		passwordIconImageView.tintColor = .loginIconColor
		
		usernameTextField.attributedPlaceholder = NSAttributedString(string: LocalizedString.username, attributes: [NSAttributedString.Key.foregroundColor: UIColor.loginFieldText])
		usernameTextField.textColor = .loginFieldText
		
		passwordTextField.attributedPlaceholder = NSAttributedString(string: LocalizedString.password, attributes: [NSAttributedString.Key.foregroundColor: UIColor.loginFieldText])
		passwordTextField.textColor = .loginFieldText
		
		forgotButton.setTitleColor(.loginFieldText, for: .normal)
		forgotButton.isHidden = Theme.hideForgotPasswordButton
		
		loginButton.setTitleColor(.loginFieldText, for: .normal)
		loginButton.backgroundColor = .appWideTint
		
		signupButton.setTitleColor(.loginFieldText, for: .normal)
		signupButton.isHidden = Theme.hideSignUpButton
		
		bannerImageView.accessibilityIdentifier = AccessibilityIdentifier.bannerImage.rawValue
	}
	
	func drawGradient() {
		// Background gradient layer
		let gradient = CAGradientLayer()
		gradient.frame = view.frame
		gradient.colors = [UIColor.loginViewGradientTop.cgColor, UIColor.loginViewGradientMid.cgColor, UIColor.loginViewGradientBottom.cgColor]
		gradient.startPoint = CGPoint.zero
		gradient.endPoint = CGPoint(x: 0.15, y: 0.9)
		view.layer.insertSublayer(gradient, at: 0)
	}
	
	func drawTriangles() {
		// Taller triangle
		let startX: CGFloat = 0
		var startY: CGFloat = view.frame.size.height * 0.6
		var maxX: CGFloat = view.frame.size.width * 0.7
		let maxY: CGFloat = view.frame.size.height
		let tallTrianglePath = UIBezierPath()
		tallTrianglePath.move(to: CGPoint(x: startX, y: startY))
		tallTrianglePath.addLine(to: CGPoint(x: maxX, y: maxY))
		tallTrianglePath.addLine(to: CGPoint(x: startX, y: maxY))
		tallTrianglePath.addLine(to: CGPoint(x: startX, y: startY))
		tallTrianglePath.close()
		let tallTriangleLayer = CAShapeLayer()
		tallTriangleLayer.path = tallTrianglePath.cgPath
		tallTriangleLayer.fillColor = UIColor.loginViewTallTriangleBg.cgColor
		tallTriangleLayer.shadowColor = UIColor.black.cgColor
		tallTriangleLayer.shadowOffset = CGSize(width: 0.0, height: -10.0)
		tallTriangleLayer.shadowRadius = 16.0
		tallTriangleLayer.shadowOpacity = 0.6
		view.layer.insertSublayer(tallTriangleLayer, at: 1)
		
		// Short, wide triangle
		startY = view.frame.size.height * 0.8
		maxX = view.frame.size.width * 0.95
		let shortTrianglePath = UIBezierPath()
		shortTrianglePath.move(to: CGPoint(x: startX, y: startY))
		shortTrianglePath.addLine(to: CGPoint(x: maxX, y: maxY))
		shortTrianglePath.addLine(to: CGPoint(x: startX, y: maxY))
		shortTrianglePath.addLine(to: CGPoint(x: startX, y: startY))
		shortTrianglePath.close()
		let shortTriangleLayer = CAShapeLayer()
		shortTriangleLayer.path = shortTrianglePath.cgPath
		shortTriangleLayer.fillColor = UIColor.loginViewShortTriangleBg.cgColor
		shortTriangleLayer.shadowColor = UIColor(white: 0.08, alpha: 1.0).cgColor
		shortTriangleLayer.shadowOffset = CGSize(width: 0.0, height: -10.0)
		shortTriangleLayer.shadowRadius = 16.0
		shortTriangleLayer.shadowOpacity = 0.6
		view.layer.insertSublayer(shortTriangleLayer, at: 2)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		navigationController?.isNavigationBarHidden = true
		
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name: UIResponder.keyboardDidShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		// Stop listening for notifications
		NotificationCenter.default.removeObserver(self)
	}
	
	// MARK: - IBActions
	
	@IBAction func forgotLogin(sender: UIButton) {
		if let url = URL(string: Theme.forgotPasswordURL),
			UIApplication.shared.canOpenURL(url) {
			UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
		}
	}
	
	@IBAction func signUp(_ sender: Any) {
		delegate.signUpRequested(username: usernameTextField.text,
								 password: passwordTextField.text,
								 confirmPassword: nil,
								 from: self)
	}
	
	@IBAction func login(_ sender: UIButton) {
        ProgressSpinnerHelper.shared.showSpinner(on: self.view)
		delegate.signInRequested(username: usernameTextField.text,
								 password: passwordTextField.text,
								 from: self)
	}
	
	@IBAction func viewTapped(_ sender: UITapGestureRecognizer) {
		if usernameTextField.isFirstResponder {
			usernameTextField.resignFirstResponder()
		} else {
			passwordTextField.resignFirstResponder()
		}
	}
	
	/// This helper method takes in an error to be used in the description of an alert as to why the user couldn't log in
	/// or was forcibly logged out upon login failure notification
	///
	/// - Parameter error: The error describing why the login failure occurred
	fileprivate func presentAlert(withLocalizedErrorDescription localizedErrorDescription: String) {
		let alertController = UIAlertController(title: LocalizedString.loginErrorAlertTitle,
												message: localizedErrorDescription,
												preferredStyle: .alert)
		
		let okButton = UIAlertAction(title: LocalizedString.ok, style: .default, handler: nil)
		alertController.addAction(okButton)
		
		// present the alert to the user
		present(alertController, animated: true, completion: nil)
	}
}

// MARK: - Keyboard Notifications
extension LoginViewController {
	/// This function is called when the `KeyboardDidShow` notification is posted and will move content up
	///
	/// - Parameter notification: `userInfo` property contains information on the keyboard
	@objc func keyboardDidShow(notification: NSNotification) {
		guard let info = notification.userInfo,
			let keyboardInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
		
		let keyboardSize = keyboardInfo.cgRectValue
		let loginButtonFrame = loginControlsStackView.convert(loginButton.frame, to: view)
		
		if keyboardSize.intersects(loginButtonFrame) {
			loginControlsStackViewTopConstraint.constant = smallViewTopConstraintTopConstant
			bannerImageTopConstraint.constant = smallViewTopConstraintTopConstant
			UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
				self.view.layoutIfNeeded()
			}, completion: nil)
		}
	}
	
	/// This function is called when the `KeyboardWillHide` notification is posted and will move the content back to the original position
	///
	/// - Parameter notification: `userInfo` property contains information on the keyboard
	@objc func keyboardWillHide(notification: NSNotification) {
		loginControlsStackViewTopConstraint.constant = loginControlsStackViewTopConstraintConstant
		bannerImageTopConstraint.constant = bannerImageTopConstraintConstant
		UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
			self.view.layoutIfNeeded()
		}, completion: nil)
	}
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if usernameTextField === textField {
			passwordTextField.becomeFirstResponder()
		} else {
			textField.resignFirstResponder()
			delegate.signInRequested(username: usernameTextField.text,
									 password: passwordTextField.text,
									 from: self)
		}
		return true
	}
}

// MARK: - StoryboardInstantiable
extension LoginViewController: StoryboardInstantiable {
	static var storyboardName: String {
		return "Login"
	}
	
	class func build(with delegate: LoginFlowViewControllerDelegate) -> LoginViewController {
		let loginVC = instantiateInitial()
		loginVC.delegate = delegate
		return loginVC
	}
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
