import UIKit
import SwiftUI
import MarkdownUI
import Combine

class SummaryViewController: UIViewController {
    private let regenerateButton = UIButton()
    private let lockButton = UIButton()
    private var hostingController: UIHostingController<MarkdownContentView>?
    
    private var summaryUpdates = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var markdownViewModel = MarkdownViewModel()
    private let summaryQueue = OperationQueue()
    
    var summarizer: Summarizer?
    
    @MainActor private var isSummarizing = false {
        didSet {
            regenerateButton.isEnabled = isSummarizing
            setupToolbar()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        summaryQueue.maxConcurrentOperationCount = 1
        setupNavigationBar()
        setupToolbar()
        summaryUpdates
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.appendSummaryText(text)
            }
            .store(in: &cancellables)
        
    }
    
    private func setupNavigationBar() {
        navigationItem.title = "Site Summary"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closeButtonTapped))
    }
    
    func setupToolbar() {
        view.backgroundColor = UIColor.systemGroupedBackground
        navigationController?.isToolbarHidden = false
        
        let regenerateIcon = UIBarButtonItem(image: UIImage(systemName: "arrow.2.circlepath"), style: .plain, target: self, action: #selector(regenerateSummary))
        regenerateIcon.isEnabled = !isSummarizing
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let lockIcon = UIBarButtonItem(image: UIImage(systemName: "lock"), style: .plain, target: self, action: #selector(promptForAPIKey))
        
        toolbarItems = [lockIcon, flexibleSpace, regenerateIcon]
        navigationController?.toolbar.barTintColor = .white
    }
    
    func appendSummaryText(_ text: String) {
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]

            let operation = BlockOperation()
            operation.addExecutionBlock { [weak self, weak operation] in
                // Check for cancellation before appending text
                guard let strongSelf = self, let operation = operation, !operation.isCancelled else { return }
                
                DispatchQueue.main.async {
                    if !operation.isCancelled {
                        strongSelf.markdownViewModel.markdownText.append(character)
                        strongSelf.displaySummary()
                    }
                }

                // Responsive delay
                let endTime = Date().addingTimeInterval(0.01)
                while Date() < endTime {
                    if operation.isCancelled { break }
                    RunLoop.current.run(mode: .default, before: endTime)
                }
            }

            summaryQueue.addOperation(operation)
            index = text.index(after: index)
        }
    }
    
    func displaySummary() {
        if hostingController == nil {
            let markdownContentView = MarkdownContentView(viewModel: markdownViewModel)
            let hostingController = UIHostingController(rootView: markdownContentView)
            self.hostingController = hostingController
            hostingController.view.backgroundColor = .clear
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            addChild(hostingController)
            view.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
            hostingController.didMove(toParent: self)
        }
    }
    
    func setIsSummarizing(summarizing: Bool) {
        isSummarizing = summarizing
    }
    
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func regenerateSummary() {
        guard !isSummarizing else { return }

        isSummarizing = true
        markdownViewModel.markdownText = ""
        summaryQueue.cancelAllOperations()
        summaryQueue.waitUntilAllOperationsAreFinished()
        
        let summaryStream = summarizer!.summarizePage()
        
        Task {
            do {
                for try await update in summaryStream {
                    appendSummaryText(update)
                }
                isSummarizing = false
            } catch {
                self.isSummarizing = false
                let alertController = UIAlertController(title: "Error", message: "Error regenerating response. Did you enter your API key in correctly?", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: .default){ _ in
                    self.dismiss(animated: true, completion: nil)
                })
                present(alertController, animated: true)
            }
        }
    }
    
    @objc private func promptForAPIKey() {
        let alertController = UIAlertController(title: "Enter Your OpenAI API Key", message: nil, preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "API Key"
            textField.text = UserDefaults.standard.string(forKey: "APIKey")
        }
        
        let confirmAction = UIAlertAction(title: "Done", style: .default) { [weak alertController] _ in
            guard let alertController = alertController,
                  let apiKey = alertController.textFields?.first?.text, !apiKey.isEmpty else {
                return
            }
            UserDefaults.standard.set(apiKey, forKey: "APIKey")
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }

}

struct MarkdownContentView: View {
    @ObservedObject var viewModel: MarkdownViewModel
    var theme: Theme = .basic // You can change the theme as needed

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Markdown(viewModel.markdownText)
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

class MarkdownViewModel: ObservableObject {
    @Published var markdownText: String = ""
}


