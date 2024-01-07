//
//  Core.swift
//  Ramble
//
//  Created by Benito Geordie on 12/31/23.
//

import Foundation


struct AssemblyAIUploadResponse: Decodable {
    let id: String
}


struct AssemblyAITranscriptionResponse: Decodable {
    let status: Optional<String>
    let text: Optional<String>
    let error: Optional<String>
}


func transcribe(audioURL: URL, apiKey: String) async throws -> String {
    let baseURL = "https://api.assemblyai.com/v2"
    let headers = ["Authorization": apiKey]
    
    // Upload audio
    var request = URLRequest(url: URL(string: baseURL + "/upload")!)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    
    let audioData: Data
    do {
        audioData = try Data(contentsOf: audioURL)
    } catch {
        // TODO: What is the best practice for throwing errors?
        print("Failed to read audio file: \(error)")
        return ""
    }
    
    let (uploadData, _) = try await URLSession.shared.upload(for: request, from: audioData)
    
    let uploadResponse = try JSONDecoder().decode([String: String].self, from: uploadData)
    let uploadURL = uploadResponse["upload_url"]!
    
    // Create transcription
    request = URLRequest(url: URL(string: baseURL + "/transcript")!)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    request.httpBody = try JSONEncoder().encode(["audio_url": uploadURL])
    
    let (transcriptData, _) = try await URLSession.shared.data(for: request)
    let transcriptResponse = try JSONDecoder().decode(AssemblyAIUploadResponse.self, from: transcriptData)
    
    // Poll for transcription status
    let pollingEndpoint = URL(string: baseURL + "/transcript/\(transcriptResponse.id)")!
    request = URLRequest(url: pollingEndpoint)
    request.httpMethod = "GET"
    request.allHTTPHeaderFields = headers
    
    var transcript = ""
    
    while true {
        let (pollingData, _) = try await URLSession.shared.data(for: request)
        let transcriptionResult = try JSONDecoder().decode(AssemblyAITranscriptionResponse.self, from: pollingData)
        
        if transcriptionResult.error != nil {
            print("Transcription failed: \(transcriptionResult.error ?? "Unknown error")")
            return ""
        } else if transcriptionResult.status == "completed" {
            transcript = transcriptionResult.text!
            break
        } else {
            try await Task.sleep(nanoseconds: 3000000000)
        }
    }
    
    return transcript
}


struct OpenAIRequestContent: Codable {
    let role: String
    let content: String
}


struct OpenAIRequestData: Codable {
    let model: String
    let messages: [OpenAIRequestContent]
}


struct OpenAICompletionMessage: Codable {
    let content: String
}


struct OpenAICompletionChoice: Codable {
    let message: OpenAICompletionMessage
}


struct OpenAICompletionResponse: Codable {
    let choices: [OpenAICompletionChoice]
}


struct OpenAICompletionError: Codable {
    let text: String
}


func summarizeAndFormat(transcript: String, apiKey: String) async throws -> String {
    let headers = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(apiKey)",
    ]
    
    let prompt = """
    I will provide you with a transcript of a voice recording. \
    Imagine you are the speaker. Summarize the transcript in a way that \
    will be most useful for you to review. \
    This means you should keep all details while keeping it organized. \
    Feel free to use headers, to-do lists, and other formatting tools where necessary. \
    The speaker may also correct themselves in the recording. Whenever this happens, \
    make sure the summary captures the correction and not the mistake. \
    Make it concise and write in first person, as if you are the one who spoke in the \
    recording; don't say "the speaker intends to do X", say "do X". \
    Finally, format it in markdown. Do not return anything except the markdown.
    If the transcript is empty or does not have anything substantive, the markdown \
    should just say "There was nothing substantive in the recording"
    
    Transcript:
    \(transcript)
    """
    
    let data: OpenAIRequestData = OpenAIRequestData(
        model: "gpt-3.5-turbo", 
        messages: [OpenAIRequestContent(
            role: "user",
            content: prompt
        )]
    )
    
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    request.httpBody = try JSONEncoder().encode(data)
    
    let (summaryData, summaryResponse) = try await URLSession.shared.data(for: request)
    let statusCode = (summaryResponse as! HTTPURLResponse).statusCode
    if statusCode == 200 {
        let completion = try JSONDecoder().decode(OpenAICompletionResponse.self, from: summaryData)
        return completion.choices[0].message.content
    }
    
    let errorData = try JSONDecoder().decode(OpenAICompletionError.self, from: summaryData)
    print("Summarization / formatting failed with status code \(statusCode): \(errorData.text)")
    return ""
}
