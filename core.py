# Python
import requests
import json
import time
from pathlib import Path
from typing import Union

# Libraries

# Local
import environment as env


def transcribe(audio_path: Union[Path, str], api_key: str):
    base_url = "https://api.assemblyai.com/v2"
    headers = {
        "authorization": api_key
    }
    
    with open(audio_path, "rb") as f:
        response = requests.post(
            base_url + "/upload",
            headers=headers,
            data=f,
        )

    upload_url = response.json()["upload_url"]
    data = { "audio_url": upload_url }

    url = base_url + "/transcript"
    response = requests.post(url, json=data, headers=headers)

    transcript_id = response.json()['id']
    polling_endpoint = f"https://api.assemblyai.com/v2/transcript/{transcript_id}"

    transcript = ""

    while True:
        transcription_result = requests.get(polling_endpoint, headers=headers).json()

        if transcription_result['status'] == 'completed':
            transcript += transcription_result['text']
            break

        elif transcription_result['status'] == 'error':
            raise RuntimeError(f"Transcription failed: {transcription_result['error']}")

        else:
            time.sleep(3)
    
    return transcript


def summarize_and_format_transcript(transcript: str, api_key: str):
    url = "https://api.openai.com/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }

    prompt = f"""
    I will provide you with a transcript of a voice recording. Summarize it, removing any redundant information. 
    The speaker may also correct themselves in this conversation. Whenever this happens, make sure the
    summary captures the correction and not the mistake.
    Finally, format it in markdown. Do not return anything except the markdown.

    Transcript:
    {transcript}
    """

    data = {
        "model": "gpt-3.5-turbo",
        "messages": [{ "role": "user", "content": prompt }],
    }

    response = requests.post(url, headers=headers, json=data)

    if response.status_code == 200:
        completion = response.json()
        return completion["choices"][0]["message"]["content"]
    
    raise RuntimeError(f"Summarization / formatting failed with status code {response.status_code}: {response.text}")


if __name__ == "__main__":
    recording = './Ramble.m4a'

    transcript = transcribe(recording, env.assemblyai_key)
    with open("transcription.txt", "w") as o:
        o.write(transcript)
    
    summarize_and_format_transcript(transcript, env.openai_key)


