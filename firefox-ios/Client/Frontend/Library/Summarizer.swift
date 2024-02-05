import Foundation
import WebKit
import OpenAI

class Summarizer {
    
    weak var webView: WKWebView?
    
    init(webView: WKWebView) {
        self.webView = webView
    }

    func summarizePage() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            DispatchQueue.main.async {
                self.evaluateAndSummarize { result in
                    switch result {
                    case .success(let content):
                        Task {
                            await self.summarize(content: content, continuation: continuation)
                        }
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }

    private func evaluateAndSummarize(completion: @escaping (Result<String, Error>) -> Void) {
        let script = """
        document.title + "\\n\\n" + (document.body.innerText || document.documentElement.innerText || document.documentElement.outerHTML)
        """
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let textContent = result as? String, !textContent.isEmpty else {
                completion(.failure(SummarizationError.emptyContent))
                return
            }
            completion(.success(textContent))
        }
    }

    private func summarize(content: String, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        if content.isEmpty {
            continuation.finish(throwing: SummarizationError.emptyContent)
            return
        }
        
        guard let apiKey = UserDefaults.standard.string(forKey: "APIKey") else {
            continuation.finish(throwing: SummarizationError.apiKeyNotSet)
            return
        }

        
        let api = OpenAI(apiToken: apiKey)
        
        let prompt =
        """
        "As a skilled summarizer, you are tasked with producing an insightful and succinct summary of the website content presented below. This summary is intended to aid individuals with visual impairments by providing a clear and structured overview. Keep in mind the following:
        1. **Detail and Clarity**: Capture the essential details from the website's content, distilling them into a brief yet comprehensive summary. Strive for clarity and precision in your description.
        2. **Markdown Formatting**: Use Markdown to enhance the visual layout and readability of the summary. Apply appropriate formatting to organize the content effectively.
        3. **Content Focus**: Concentrate exclusively on the material that is explicitly featured or suggested on the website. Do not include extraneous facts or corporate affiliations not mentioned in the site content. This does not mean you need to cover everything in contained in website content. Only what is important, what is factual, and what is explicitly featured or suggested.
        4. **Brevity and Relevance**: Ensure the summary is to the point, avoiding any superfluous details. It should be quicker to read than the full website content, while still being informative.
        5. **Emoticon Inclusion**: Incorporate relevant emoticons into every heading to provide visual cues and maintain an engaging tone.

        Please adhere to the following template for structuring the summary. Remember that the square brackets signify placeholders for actual content titles and should not appear in your output, and that the emojis are place holders (but please provide emojis for each subheading):
        ```markdown
        # [Title/Name of Website or Main Headline🌟]
        ---
        [Short introduction or overview of the website's purpose or main theme.]

        ## [Subheading/Core Topic or Offering 1 📘]
        [Description or key points about the first core topic or offering.]

        ## [Subheading:/Core Topic or Offering 2 🚀]
        [Description or key points about the second core topic or offering.]
        
        ## [Subheading/Core Topic or Offering n 🔍]
        [Description or key points about the nth core topic or offering.]
        ...
        
        You may add further depth with additional subheadings and use Markdown elements like bullet points or lists to organize the information clearly. Your aim is to make the summary as readable and user-friendly as possible while being creative and engaging. Use your own emiticons and number of subheading to ensure brevity.
        
        If there is no content or it is not accessible for summarization, please respond with: "Error: No content was provided by the webpage."
        
        """
        let query = ChatQuery(model: .gpt3_5Turbo, messages: [
            .init(role: .system, content: prompt),
            .init(role: .user, content: content)
        ])
        
        do {
            for try await result in api.chatsStream(query: query) {
                for choice in result.choices {
                    if let contentText = choice.delta.content {
                        // Send updates to the update handler on the main thread
                        continuation.yield(contentText)
                    }
                }
            }
            continuation.finish()
        } catch {
            continuation.finish(throwing: "Error: \(error.localizedDescription)")
        }
    }
}

enum SummarizationError: Error {
    case emptyContent
    case apiKeyNotSet
}
