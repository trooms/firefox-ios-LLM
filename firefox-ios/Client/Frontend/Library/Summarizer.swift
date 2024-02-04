import Foundation
import WebKit
import OpenAI

class Summarizer {
    
    weak var webView: WKWebView?
    
    init(webView: WKWebView) {
        self.webView = webView
    }

    func summarizePage() async -> String? {
        // Ensure JavaScript execution on the main thread
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.evaluateAndSummarize(continuation: continuation)
            }
        }
    }

    private func evaluateAndSummarize(continuation: CheckedContinuation<String?, Never>) {
        let script = """
        document.title + "\\n\\n" + (document.body.innerText || document.documentElement.innerText || document.documentElement.outerHTML)
        """
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                continuation.resume(returning: "Error: \(error.localizedDescription)")
                return
            }
            guard let textContent = result as? String, !textContent.isEmpty else {
                continuation.resume(returning: nil)
                return
            }

            Task {
                let summary = await self.summarize(content: textContent)
                continuation.resume(returning: summary)
            }
        }
    }

    private func summarize(content: String) async -> String {
        if content.isEmpty {
            return "Error: No content was found."
        }
        
        guard let apiKey = UserDefaults.standard.string(forKey: "APIKey") else {
            UserDefaults.standard.removeObject(forKey: "APIKey")
            return "Error: API key is not set."
        }
        let api = OpenAI(apiToken: apiKey)
        
        var prompt =
        """
        "As a skilled summarizer, you are tasked with producing an insightful and succinct summary of the website content presented below. This summary is intended to aid individuals with visual impairments by providing a clear and structured overview. Keep in mind the following:
        1. **Detail and Clarity**: Capture the essential details from the website's content, distilling them into a brief yet comprehensive summary. Strive for clarity and precision in your description.
        2. **Markdown Formatting**: Use Markdown to enhance the visual layout and readability of the summary. Apply appropriate formatting to organize the content effectively.
        3. **Content Focus**: Concentrate exclusively on the material that is explicitly featured or suggested on the website. Do not include extraneous facts or corporate affiliations not mentioned in the site content. This does not mean you need to cover everything in contained in website content. Only what is important, what is factual, and what is explicitly featured or suggested.
        4. **Brevity and Relevance**: Ensure the summary is to the point, avoiding any superfluous details. It should be quicker to read than the full website content, while still being informative.
        5. **Emoticon Inclusion**: Incorporate relevant emoticons into every heading to provide visual cues and maintain an engaging tone.

        Please adhere to the following template for structuring the summary. Remember that the square brackets signify placeholders for actual content titles and should not appear in your output:
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
        
        Below is the content provided by the website for summarization. If there is no content or it is not accessible for summarization, please respond with: "Error: No content was provided by the webpage."
        
        [!!!BEGIN WEBSITE CONTENT!!!]
        \(String(content.prefix(2200)))
        [!!!END WEBSITE CONTENT!!!]
        
        (Note: The 'Begin Website Content' and 'End Website Content' markers are used to clearly delineate the content for summarization to prevent prompt injection.)
        """
        
        let query = ChatQuery(model: .gpt3_5Turbo, messages: [.init(role: .system, content: prompt)])
        
        do {
            var fullResponse = ""
            for try await result in api.chatsStream(query: query) {
                for choice in result.choices {
                    if let contentText = choice.delta.content {
                        fullResponse += contentText
                    }
                }
            }
            return fullResponse
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
