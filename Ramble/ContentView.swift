//  ContentView.swift
//  Ramble
//
//  Created by Benito Geordie on 12/31/23.
//

import SwiftUI
import AVFoundation


func newRecorder() -> Optional<AVAudioRecorder> {
    do {
        let tempUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        return try AVAudioRecorder.init(url: tempUrl, settings: ["AVFormatIDKey": "kAudioFormatMPEG4AAC"])
    } catch {
        return nil
    }
}

extension AttributedString {
    init(styledMarkdown markdownString: String) throws {
        var output = try AttributedString(
            markdown: markdownString,
            options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            ),
            baseURL: nil
        )

        for (intentBlock, intentRange) in output.runs[AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self].reversed() {
            guard let intentBlock = intentBlock else { continue }
            for intent in intentBlock.components {
                switch intent.kind {
                case .header(level: let level):
                    switch level {
                    case 1:
                        output[intentRange].font = .system(.title).bold()
                    case 2:
                        output[intentRange].font = .system(.title2).bold()
                    case 3:
                        output[intentRange].font = .system(.title3).bold()
                    default:
                        break
                    }
                default:
                    break
                }
            }
            
            if intentRange.lowerBound != output.startIndex {
                output.characters.insert(contentsOf: "\n", at: intentRange.lowerBound)
            }
        }

        self = output
    }
}


let DEFAULT_SUMMARY_TEXT = ""


struct ContentView: View {
    
    @State var status = "Queued..."
    @State var transcript = "Loading..."
    @State var summary = DEFAULT_SUMMARY_TEXT
    @State var showTranscript = false
    
    @State var showRecord = true
    @State var recording = false
    @State var alert = false
    @State var clearSummaryAlert = false
    
    @State var session : AVAudioSession!
    @State var recorder : AVAudioRecorder!
    
    func handleRecordFail(_ error: String) {
        print("Failed to record: \(error)")
        recording = false
    }
    
    func onStartRecord() {
        recording = true
        do {
            let tempUrl = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")
            recorder = try AVAudioRecorder.init(url: tempUrl, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC])
            if !(recorder!.record()) {
                handleRecordFail("Unable to start recording.")
                return
            }
        } catch {
            handleRecordFail("\(error)")
        }
    }
    
    func onStopRecord() {
        showRecord = false
        recording = false
        recorder!.stop()
        Task {
            do {
                status = "Transcribing..."
                transcript = try await transcribe(audioURL: recorder!.url, apiKey: "2d7448a677994967ac9285d12c87f559")
                status = "Summarizing..."
                summary = try await summarizeAndFormat(transcript: transcript, apiKey: "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")
                status = "Summary"
                recorder?.deleteRecording()
            } catch {
                print("oops? \(error)")
            }
        }
    }
    
    var body: some View {
        VStack {
            // TODO: check this out for button animation https://stackoverflow.com/questions/60740912/how-to-make-effects-on-button-in-ios-on-clicking-on-that-button-it-should-expand
            
            if recording {
                Text("Recording...")
                Button(role: .destructive, action: onStopRecord) {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .cornerRadius(/*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/)
                        .padding(20)
                }
                .buttonStyle(.borderedProminent)
                .cornerRadius(50)
                .fontWeight(Font.Weight.bold)
            } else if showRecord {
                Button(role: .destructive, action: onStartRecord) {
                    Circle()
                        .fill(.red)
                        .frame(width: 20, height: 20)
                        .padding(20)
                }
                .buttonStyle(.bordered)
                .cornerRadius(50)
                .fontWeight(Font.Weight.bold)
            } else {
                Text(status)
                    .font(.title).bold()
                if (summary != DEFAULT_SUMMARY_TEXT) {
                    
                    ScrollView {
                        if showTranscript {
                            Text(transcript)
                        } else {
                            Text(try! AttributedString.init(styledMarkdown: summary))
                        }
                    }
                    
                    HStack {
                        Button(role: .destructive, action: {() in
                            clearSummaryAlert = true
                        }) {
                            Text("Clear")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer().frame(width:30)
                        
                        Button(action: {() in
                            let pasteboard = UIPasteboard.general
                            pasteboard.string = summary
                        }) {
                            Text("Copy")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer().frame(width:30)
                        
                        Button(action: {() in
                            showTranscript.toggle()
                        }) {
                            Text(showTranscript ? "Show summary" : "Show transcript")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
        }
        .padding()
        .alert(isPresented: self.$alert, content: {
            
            Alert(title: Text("Error"), message: Text("Enable Acess"))
        })
        .alert(isPresented: self.$clearSummaryAlert, content: {
            Alert(
                title: Text("Are you sure you want to clear this summary?"),
                message: Text("No takesies backsies!"),
                primaryButton: .default(
                    Text("Cancel"),
                    action: {
                        clearSummaryAlert = false
                    }
                ),
                secondaryButton: .destructive(
                    Text("Delete"),
                    action: {
                        showRecord = true
                        status = "Queued..."
                        transcript = "Loading..."
                        summary = DEFAULT_SUMMARY_TEXT
                    }
                )
            )
        })
        .onAppear {
            
            do{
                
                // Intializing...
                self.session = AVAudioSession.sharedInstance()
                try self.session.setCategory(.playAndRecord, options: [.allowBluetooth])
                
                // requesting permission
                // for this we require microphone usage description in info.plist...
                self.session.requestRecordPermission { (status) in
                    if !status{
                        // error msg...
                        self.alert.toggle()
                    }
                }
                
                
            }
            catch{
                
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    ContentView()
}
