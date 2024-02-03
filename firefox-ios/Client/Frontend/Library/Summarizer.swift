import Foundation
import WebKit
import OpenAI

class Summarizer {
    
    weak var webView: WKWebView?
    
    init(webView: WKWebView) {
        self.webView = webView
    }

    func summarizePage() async -> String? {
        let script = """
        document.title + "\\n\\n" + (document.body.innerText || document.documentElement.innerText || document.documentElement.outerHTML)
        """
        do {
            let result = try await webView?.evaluateJavaScript(script)
            guard let textContent = result as? String, !textContent.isEmpty else {
                return nil
            }
            return await summarize(content: textContent)
        } catch {
            return nil
        }
    }


    private func summarize(content: String) async -> String {
        if (content == "") {
            return "Error: No content was found"
        }
        
        guard let apiKey = UserDefaults.standard.string(forKey: "APIKey") else {
            UserDefaults.standard.removeObject(forKey: "APIKey")
            return ""
        }
        let api = OpenAI(apiToken: apiKey)

        let prompt = 
"""
As a professional summarizer, create a concise and comprehensive summary of the provided website while adhering to these guidelines:
1. Craft a summary that is detailed, concise, in-depth, and complex, while maintaining clarity and conciseness. You are helping someone who is blind.
2. Format the summary in clean markdown, as the text will be displayed this way.
3. Only summarize the content, and do not reference any instructions I have given you.
By following this optimized prompt, you will generate an effective summary that encapsulates the essence of the given text in a clear, concise, and reader-friendly manner.


Site: 
\(content)
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
