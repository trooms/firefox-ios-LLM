import UIKit
import SwiftUI
import MarkdownUI

class SummaryViewController: UIViewController {
    private let regenerateButton = UIButton()
    private let lockButton = UIButton()
    private var hostingController: UIHostingController<MarkdownContentView>?
    
    var summaryText: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // setupView()
        // applyStyle()
        displaySummary(summaryText)
        setupNavigationBar()
        setupToolbar()
    }
    
    private func setupNavigationBar() {
        navigationItem.title = "Site Summary"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closeButtonTapped))
    }
    
    private func setupToolbar() {
        view.backgroundColor = UIColor.systemGroupedBackground
        navigationController?.isToolbarHidden = false

        let regenerateIcon = UIBarButtonItem(image: UIImage(systemName: "arrow.2.circlepath"), style: .plain, target: self, action: #selector(regenerateSummary))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let lockIcon = UIBarButtonItem(image: UIImage(systemName: "lock"), style: .plain, target: self, action: #selector(promptForAPIKey))

        toolbarItems = [lockIcon, flexibleSpace, regenerateIcon]
        navigationController?.toolbar.barTintColor = .white
    }

    func setSummaryText(_ text: String) {
        self.summaryText = text
    }

    func displaySummary(_ summary: String) {
        // Remove the existing hosting controller if it exists
        if let existingHostingController = hostingController {
            existingHostingController.willMove(toParent: nil)
            existingHostingController.view.removeFromSuperview()
            existingHostingController.removeFromParent()
        }

        // Create a new hosting controller with the MarkdownContentView
        let markdownContentView = MarkdownContentView(markdownText: summary)
        let newHostingController = UIHostingController(rootView: markdownContentView)
        self.hostingController = newHostingController

        // Set the background color of the hosting controller's view to clear
        newHostingController.view.backgroundColor = .clear
        
        // Ensure that the SwiftUI view uses all the available space
        newHostingController.view.frame = self.view.bounds

        // Add as child view controller
        addChild(newHostingController)
        newHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newHostingController.view)

        // Setup constraints to match the SummaryViewController's view
        NSLayoutConstraint.activate([
            newHostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            newHostingController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            newHostingController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            newHostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Notify the child view controller
        newHostingController.didMove(toParent: self)
    }


    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func regenerateSummary() {
        // TODO: Code to regenerate the summary
        dismiss(animated: true, completion: nil)
    }
        
    @objc private func promptForAPIKey() {
        // TODO: Code to prompt for API key
        dismiss(animated: true, completion: nil)
    }
}

struct MarkdownContentView: View {
    let markdownText: String
    var theme: Theme = .basic // You can change the theme as needed

    var body: some View {
        ScrollView { // Ensures that content can scroll if it's too long
            VStack(alignment: .leading, spacing: 0) {
                Markdown(markdownText)
                    .markdownTheme(theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.leading, .trailing, .bottom], 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.all)
    }
}


