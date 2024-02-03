import UIKit

class SummaryView: UIView {

    private let textView = UITextView()
    private let closeButton = UIButton()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        applyStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 10
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 5

        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        // Add constraints
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            textView.leftAnchor.constraint(equalTo: leftAnchor, constant: 10),
            textView.rightAnchor.constraint(equalTo: rightAnchor, constant: -10),
            textView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -10),
            
            closeButton.leftAnchor.constraint(equalTo: leftAnchor, constant: 10),
            closeButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -10),
            closeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func applyStyle() {
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        closeButton.setTitleColor(.blue, for: .normal)
    }

    func displaySummary(_ summary: String) {
        if #available(iOS 15.0, *) {
            do {
                let attributedString = try AttributedString(markdown: summary)
                let nsAttributedString = NSAttributedString(attributedString)
                textView.attributedText = nsAttributedString
            } catch {
                textView.text = summary // Fallback to plain text
            }
        } else {
            textView.text = summary
        }
    }

    @objc private func closeButtonTapped() {
        removeFromSuperview()
    }
}
