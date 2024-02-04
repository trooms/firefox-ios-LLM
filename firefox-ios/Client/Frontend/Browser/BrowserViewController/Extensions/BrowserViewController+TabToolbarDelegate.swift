// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Shared
import UIKit

extension BrowserViewController: TabToolbarDelegate, PhotonActionSheetProtocol {
    // MARK: Data Clearance CFR / Contextual Hint

    // Reset the CFR timer for the data clearance button to avoid presenting the CFR
    // In cases, such as if user navigates to homepage or if fire icon is not available

    func resetDataClearanceCFRTimer() {
        dataClearanceContextHintVC.stopTimer()
    }

    func configureDataClearanceContextualHint() {
        guard contentContainer.hasWebView, tabManager.selectedTab?.url?.displayURL?.isWebPage() == true else {
            resetDataClearanceCFRTimer()
            return
        }
        dataClearanceContextHintVC.configure(
            anchor: navigationToolbar.multiStateButton,
            withArrowDirection: topTabsVisible ? .up : .down,
            andDelegate: self,
            presentedUsing: { self.presentDataClearanceContextualHint() },
            andActionForButton: { },
            overlayState: overlayManager)
    }

    private func presentDataClearanceContextualHint() {
        present(dataClearanceContextHintVC, animated: true)
        UIAccessibility.post(notification: .layoutChanged, argument: dataClearanceContextHintVC)
    }

    func tabToolbarDidPressHome(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        updateZoomPageBarVisibility(visible: false)
        userHasPressedHomeButton = true
        let page = NewTabAccessors.getHomePage(self.profile.prefs)
        if page == .homePage, let homePageURL = HomeButtonHomePageAccessors.getHomePage(self.profile.prefs) {
            tabManager.selectedTab?.loadRequest(PrivilegedRequest(url: homePageURL) as URLRequest)
        } else if let homePanelURL = page.url {
            tabManager.selectedTab?.loadRequest(PrivilegedRequest(url: homePanelURL) as URLRequest)
        }
        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .home)
    }

    // Presents alert to clear users private session data
    func tabToolbarDidPressFire(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let alert = UIAlertController(
            title: .Alerts.FeltDeletion.Title,
            message: .Alerts.FeltDeletion.Body,
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(
            title: .Alerts.FeltDeletion.CancelButton,
            style: .cancel,
            handler: { [weak self] _ in
                self?.privateBrowsingTelemetry.sendDataClearanceTappedTelemetry(didConfirm: false)
            }
        )

        let deleteDataAction = UIAlertAction(
            title: .Alerts.FeltDeletion.ConfirmButton,
            style: .destructive,
            handler: { [weak self] _ in
                self?.privateBrowsingTelemetry.sendDataClearanceTappedTelemetry(didConfirm: true)
                self?.closePrivateTabsAndOpenNewPrivateHomepage()
                self?.showDataClearanceConfirmationToast()
            }
        )

        alert.addAction(deleteDataAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    private func closePrivateTabsAndOpenNewPrivateHomepage() {
        tabManager.removeTabs(tabManager.privateTabs)
        tabManager.selectTab(tabManager.addTab(isPrivate: true))
    }

    private func showDataClearanceConfirmationToast() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            SimpleToast().showAlertWithText(
                .FirefoxHomepage.FeltDeletion.ToastTitle,
                bottomContainer: self.contentContainer,
                theme: self.themeManager.currentTheme
            )
        }
    }

    func tabToolbarDidPressLibrary(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
    }

    func tabToolbarDidPressBack(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        updateZoomPageBarVisibility(visible: false)
        tabManager.selectedTab?.goBack()
    }

    func tabToolbarDidLongPressBack(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        handleTabToolBarDidLongPressForwardOrBack()
    }

    func tabToolbarDidPressForward(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        updateZoomPageBarVisibility(visible: false)
        tabManager.selectedTab?.goForward()
    }

    func tabToolbarDidLongPressForward(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        handleTabToolBarDidLongPressForwardOrBack()
    }

    private func handleTabToolBarDidLongPressForwardOrBack() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        if CoordinatorFlagManager.isBackForwardListShownFromCoordaintorEnabled {
            navigationHandler?.showBackForwardList()
        } else {
            showBackForwardList()
        }
    }

    func tabToolbarDidPressBookmarks(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        showLibrary(panel: .bookmarks)
    }

    func tabToolbarDidPressAddNewTab(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        tabManager.selectTab(tabManager.addTab(nil, isPrivate: isPrivate))
        focusLocationTextField(forTab: tabManager.selectedTab)
        overlayManager.openNewTab(url: nil,
                                  newTabSettings: NewTabAccessors.getNewTabPage(profile.prefs))
    }

    func tabToolbarDidPressMenu(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        // Ensure that any keyboards or spinners are dismissed before presenting the menu
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        // Logs homePageMenu or siteMenu depending if HomePage is open or not
        let isHomePage = tabManager.selectedTab?.isFxHomeTab ?? false
        let eventObject: TelemetryWrapper.EventObject = isHomePage ? .homePageMenu : .siteMenu
        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: eventObject)
        let menuHelper = MainMenuActionHelper(profile: profile,
                                              tabManager: tabManager,
                                              buttonView: button,
                                              toastContainer: contentContainer)
        menuHelper.delegate = self
        menuHelper.sendToDeviceDelegate = self
        menuHelper.navigationHandler = navigationHandler

        updateZoomPageBarVisibility(visible: false)
        menuHelper.getToolbarActions(navigationController: navigationController) { actions in
            let shouldInverse = PhotonActionSheetViewModel.hasInvertedMainMenu(
                trait: self.traitCollection,
                isBottomSearchBar: self.isBottomSearchBar
            )
            let viewModel = PhotonActionSheetViewModel(
                actions: actions,
                modalStyle: .popover,
                isMainMenu: true,
                isMainMenuInverted: shouldInverse
            )
            self.presentSheetWith(viewModel: viewModel, on: self, from: button)
        }
    }
    
    func tabToolbarDidPressSummarize(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let userDefaults = UserDefaults.standard
        if let _ = userDefaults.string(forKey: "APIKey") {
            guard let webView = tabManager.selectedTab?.webView else {
                presentAlert(title: "Oh no!", message: "This website has no content or blocked the summary request")
                return
            }

            showLoadingMessage()
            let summarizer = Summarizer(webView: webView)
            Task {
                if let summary = await summarizer.summarizePage() {
                    dismissLoadingMessage()
                    if summary.isEmpty {
                        alertIncorrectAPIKey()
                    } else if (summary.starts(with: "Error")) {
                        presentAlert(title: "Error", message: summary, allowAPIKeyUpdate: true)
                    }else {
                        dismissLoadingMessage()
                        self.showSummary(summary)
                    }
                } else {
                    presentAlert(title: "Error", message: "Failed to summarize the page.", allowAPIKeyUpdate: true)
                }
            }
        } else {
            promptForAPIKey()
        }
        
        func presentAlert(title: String, message: String, allowAPIKeyUpdate: Bool = false) {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

            // OK action
            alertController.addAction(UIAlertAction(title: "OK", style: .default))

            // Update API Key action
            if allowAPIKeyUpdate {
                let updateAction = UIAlertAction(title: "UPDATE API KEY", style: .default) { _ in
                    promptForAPIKey()
                }
                alertController.addAction(updateAction)
            }

            present(alertController, animated: true)
        }
        
        func promptForAPIKey() {
            let alertController = UIAlertController(title: "Enter API Key", message: "Please enter your ChatGPT API key to proceed.", preferredStyle: .alert)

            alertController.addTextField { textField in
                textField.placeholder = "API Key"
            }

            let confirmAction = UIAlertAction(title: "Confirm", style: .default) { [weak self, weak alertController] _ in
                guard let apiKey = alertController?.textFields?.first?.text, !apiKey.isEmpty else { return }
                UserDefaults.standard.set(apiKey, forKey: "APIKey")
                self?.tabToolbarDidPressSummarize(tabToolbar, button: button)
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)

            present(alertController, animated: true)
        }

        func alertIncorrectAPIKey() {
            let alertController = UIAlertController(title: "Invalid API Key", message: "The API key provided seems to be incorrect. Please enter a valid API key.", preferredStyle: .alert)

            alertController.addTextField { textField in
                textField.placeholder = "API Key"
            }

            let updateAction = UIAlertAction(title: "Update", style: .default) { [weak self, weak alertController] _ in
                guard let newApiKey = alertController?.textFields?.first?.text, !newApiKey.isEmpty else { return }
                UserDefaults.standard.set(newApiKey, forKey: "APIKey")
                self?.tabToolbarDidPressSummarize(tabToolbar, button: button)
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

            alertController.addAction(updateAction)
            alertController.addAction(cancelAction)

            present(alertController, animated: true)
        }
    }



    func tabToolbarDidPressTabs(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        updateZoomPageBarVisibility(visible: false)
        let isPrivateTab = tabManager.selectedTab?.isPrivate ?? false
        let segmentToFocus = isPrivateTab ? TabTrayPanelType.privateTabs : TabTrayPanelType.tabs
        showTabTray(focusedSegment: segmentToFocus)
        TelemetryWrapper.recordEvent(
            category: .action,
            method: .press,
            object: .tabToolbar,
            value: .tabView
        )
    }

    func getTabToolbarLongPressActionsForModeSwitching() -> [PhotonRowActions] {
        guard let selectedTab = tabManager.selectedTab else { return [] }
        let count = selectedTab.isPrivate ? tabManager.normalTabs.count : tabManager.privateTabs.count
        let infinity = "\u{221E}"
        let tabCount = (count < 100) ? count.description : infinity

        func action() {
            let result = tabManager.switchPrivacyMode()
            if result == .createdNewTab, self.newTabSettings == .blankPage {
                focusLocationTextField(forTab: tabManager.selectedTab)
            }
        }

        let privateBrowsingMode = SingleActionViewModel(title: .KeyboardShortcuts.PrivateBrowsingMode,
                                                        iconString: "nav-tabcounter",
                                                        iconType: .TabsButton,
                                                        tabCount: tabCount) { _ in
            action()
        }.items

        let normalBrowsingMode = SingleActionViewModel(title: .KeyboardShortcuts.NormalBrowsingMode,
                                                       iconString: "nav-tabcounter",
                                                       iconType: .TabsButton,
                                                       tabCount: tabCount) { _ in
            action()
        }.items

        if let tab = self.tabManager.selectedTab {
            return tab.isPrivate ? [normalBrowsingMode] : [privateBrowsingMode]
        }
        return [privateBrowsingMode]
    }

    func getMoreTabToolbarLongPressActions() -> [PhotonRowActions] {
        let newTab = SingleActionViewModel(title: .KeyboardShortcuts.NewTab,
                                           iconString: StandardImageIdentifiers.Large.plus,
                                           iconType: .Image) { _ in
            let shouldFocusLocationField = self.newTabSettings == .blankPage
            self.overlayManager.openNewTab(url: nil, newTabSettings: self.newTabSettings)
            self.openBlankNewTab(focusLocationField: shouldFocusLocationField, isPrivate: false)
        }.items

        let newPrivateTab = SingleActionViewModel(title: .KeyboardShortcuts.NewPrivateTab,
                                                  iconString: StandardImageIdentifiers.Large.plus,
                                                  iconType: .Image) { _ in
            let shouldFocusLocationField = self.newTabSettings == .blankPage
            self.overlayManager.openNewTab(url: nil, newTabSettings: self.newTabSettings)
            self.openBlankNewTab(focusLocationField: shouldFocusLocationField, isPrivate: true)
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .newPrivateTab, value: .tabTray)
        }.items

        let closeTab = SingleActionViewModel(title: .KeyboardShortcuts.CloseCurrentTab,
                                             iconString: StandardImageIdentifiers.Large.cross,
                                             iconType: .Image) { _ in
            if let tab = self.tabManager.selectedTab {
                self.tabManager.removeTab(tab)
                self.updateTabCountUsingTabManager(self.tabManager)
            }
        }.items

        if let tab = self.tabManager.selectedTab {
            return tab.isPrivate ? [newPrivateTab, closeTab] : [newTab, closeTab]
        }
        return [newTab, closeTab]
    }

    func tabToolbarDidLongPressTabs(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        guard self.presentedViewController == nil else { return }
        var actions: [[PhotonRowActions]] = []
        actions.append(getTabToolbarLongPressActionsForModeSwitching())
        actions.append(getMoreTabToolbarLongPressActions())

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        let viewModel = PhotonActionSheetViewModel(
            actions: actions,
            closeButtonTitle: .CloseButtonTitle,
            modalStyle: .overCurrentContext
        )
        presentSheetWith(viewModel: viewModel, on: self, from: button)
    }

    func showBackForwardList() {
        if let backForwardList = tabManager.selectedTab?.webView?.backForwardList {
            let backForwardViewController = BackForwardListViewController(
                profile: profile,
                backForwardList: backForwardList
            )
            backForwardViewController.tabManager = tabManager
            backForwardViewController.browserFrameInfoProvider = self
            backForwardViewController.modalPresentationStyle = .overCurrentContext
            backForwardViewController.backForwardTransitionDelegate = BackForwardListAnimator()
            self.present(backForwardViewController, animated: true, completion: nil)
        }
    }

    func tabToolbarDidPressSearch(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        focusLocationTextField(forTab: tabManager.selectedTab)
    }
}

// MARK: - ToolbarActionMenuDelegate
extension BrowserViewController: ToolBarActionMenuDelegate {
    func updateToolbarState() {
        updateToolbarStateForTraitCollection(view.traitCollection)
    }

    func showViewController(viewController: UIViewController) {
        presentWithModalDismissIfNeeded(viewController, animated: true)
    }

    func showToast(message: String, toastAction: MenuButtonToastAction) {
        switch toastAction {
        case .removeBookmark:
            let viewModel = ButtonToastViewModel(labelText: message,
                                                 buttonText: .UndoString,
                                                 textAlignment: .left)
            let toast = ButtonToast(viewModel: viewModel,
                                    theme: themeManager.currentTheme) { [weak self] isButtonTapped in
                guard let strongSelf = self, let currentTab = strongSelf.tabManager.selectedTab else { return }
                isButtonTapped ? strongSelf.addBookmark(
                    url: currentTab.url?.absoluteString ?? "",
                    title: currentTab.title
                ) : nil
            }
            show(toast: toast)
        default:
            SimpleToast().showAlertWithText(message,
                                            bottomContainer: contentContainer,
                                            theme: themeManager.currentTheme)
        }
    }

    func showFindInPage() {
        updateFindInPageVisibility(visible: true)
    }

    func showCustomizeHomePage() {
        navigationHandler?.show(settings: .homePage)
    }

    func showWallpaperSettings() {
        navigationHandler?.show(settings: .wallpaper)
    }

    func showCreditCardSettings() {
        navigationHandler?.show(settings: .creditCard)
    }

    func showZoomPage(tab: Tab) {
        updateZoomPageBarVisibility(visible: true)
    }

    func showSignInView(fxaParameters: FxASignInViewParameters) {
        presentSignInViewController(fxaParameters.launchParameters,
                                    flowType: fxaParameters.flowType,
                                    referringPage: fxaParameters.referringPage)
    }
    
    func showSummary(_ summary: String) {
        let summaryVC = SummaryViewController()
        summaryVC.setSummaryText(summary)
        // Use .pageSheet for iOS 13+ style presentation
        summaryVC.modalPresentationStyle = .pageSheet
        if let sheet = summaryVC.sheetPresentationController {
            // If you want to show a portion of the underlying content
            sheet.detents = [.medium()] // Or use .large() for more content exposure
            sheet.prefersGrabberVisible = true // If you want to show the grabber
        }
        let navigationController = UINavigationController(rootViewController: summaryVC)
        present(navigationController, animated: true, completion: nil)
    }

    
    func showLoadingMessage() {
        let alert = UIAlertController(title: nil, message: "Generating site summary...\n\n", preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()

        alert.view.addSubview(loadingIndicator)
        alert.view.heightAnchor.constraint(equalToConstant: 95).isActive = true

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])

        present(alert, animated: true, completion: nil)
    }

    func dismissLoadingMessage(completion: (() -> Void)? = nil) {
        dismiss(animated: false) {
            completion?()
        }
    }

}
