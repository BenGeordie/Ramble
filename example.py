from api import transcribe, summarize_and_format_transcript
import environment as env

if __name__ == "__main__":
    recording = "examples/Ramble.m4a"

    transcript = transcribe(recording, env.assemblyai_key)
    with open("examples/transcript.txt", "w") as o:
        o.write(transcript)

    with open("examples/summary.md", "w") as o:
        o.write(summarize_and_format_transcript(transcript, env.openai_key))
