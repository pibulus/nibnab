import Foundation

enum NibAI {
    private static let defaultModel = "gemini-2.5-flash"

    /// Sends a prompt to Gemini Flash API and returns the generated text.
    static func generateText(prompt: String, apiKey: String) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "NibAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing API Key"])
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(defaultModel):generateContent?key=\(trimmedKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "NibAI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 1000
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NibAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response from Gemini API"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "NibAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw NSError(domain: "NibAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response"])
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Suggests 1–2 relevant tags, anchored to the user's existing tag vocabulary to prevent drift.
    static func suggestTags(for text: String, existingTags: [String], apiKey: String) async -> [String] {
        let tagListString = existingTags.isEmpty ? "None yet" : existingTags.joined(separator: ", ")
        let prompt = """
        You are a concise tagging engine for a minimalist clipboard and screenshot notebook.
        Existing tag vocabulary: [\(tagListString)]

        Task: Analyze the following text or OCR snippet and assign 1 to 2 hashtags.
        RULES:
        1. STRONGLY prefer selecting tags from the existing tag vocabulary if they fit.
        2. If no existing tag fits, create a new short, punchy hashtag in lowercase (e.g. #bug, #research, #visuals).
        3. Output ONLY the hashtags separated by spaces (e.g. "#ideas #terminal"). Nothing else.

        Content:
        \(text)
        """

        do {
            let result = try await generateText(prompt: prompt, apiKey: apiKey)
            return NibTag.tags(in: result)
        } catch {
            return []
        }
    }

    /// Cleans and formats raw OCR or messy copied text into clean Markdown.
    static func cleanOCR(text: String, apiKey: String) async throws -> String {
        let prompt = """
        Clean up this OCR extracted text or messy snippet into clean, beautifully formatted Markdown.
        - Fix broken linebreaks, OCR typos, and formatting glitches.
        - Preserve code blocks if it is code.
        - Keep the content authentic and do not add conversational preamble.
        - Output ONLY the formatted text.

        Text:
        \(text)
        """
        return try await generateText(prompt: prompt, apiKey: apiKey)
    }

    /// Summarizes the clip into 2–3 punchy bullet points.
    static func summarizeToBullets(text: String, apiKey: String) async throws -> String {
        let prompt = """
        Summarize the following text or OCR note into 2 to 3 concise, punchy bullet points.
        Output ONLY the bullet points starting with "- ".

        Text:
        \(text)
        """
        return try await generateText(prompt: prompt, apiKey: apiKey)
    }
}
