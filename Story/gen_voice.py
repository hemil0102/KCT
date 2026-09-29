"""탐정 호랑이 대사 음성 만들기 (Supertonic, 무료·오픈소스, 이 Mac 안에서 실행)

- 처음 한 번은 모델(약 수백 MB)을 Hugging Face 에서 내려받는다. 그다음부터는 인터넷 없이 된다.
- 결과: voice/<id>.m4a  (HTML 이 이 폴더를 자동으로 찾아 쓴다)
- 목소리 고르기: voice_samples/M1~M5.m4a 를 들어 보고 마음에 드는 것을 VOICE 로 다시 실행.
    VOICE=M3 ./make_voice.command
"""
import json, os, subprocess, sys
from pathlib import Path
import numpy as np
from supertonic import TTS

HERE = Path(__file__).resolve().parent
VOICE = os.environ.get("VOICE", "M1")          # M1~M5 남성, F1~F5 여성
PITCH = float(os.environ.get("PITCH", "0.93"))  # 1보다 작으면 굵고 낮은 목소리 (호랑이 느낌)
SPEED = float(os.environ.get("SPEED", "0.95"))  # 최종 말 빠르기 (어머니용으로 조금 천천히)

def to_m4a(wav: np.ndarray, sr: int, out: Path):
    import soundfile as sf
    tmp = out.with_suffix(".wav")
    sf.write(str(tmp), wav, sr)
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "96000", str(tmp), str(out)], check=True)
    tmp.unlink()

def tiger(tts, style, text):
    # 빠르게 합성한 뒤 늘려서 재생하면 속도는 SPEED, 음높이는 PITCH 배가 된다
    wav, _ = tts.synthesize(text, voice_style=style, lang="ko", speed=SPEED / PITCH, total_steps=10)
    wav = np.asarray(wav, dtype=np.float32).squeeze()
    n = int(len(wav) / PITCH)
    wav = np.interp(np.linspace(0, len(wav) - 1, n), np.arange(len(wav)), wav).astype(np.float32)
    peak = float(np.max(np.abs(wav))) or 1.0
    return wav / peak * 0.89

def main():
    lines = json.loads((HERE / "lines.json").read_text(encoding="utf-8"))
    tts = TTS(auto_download=True)
    sr = tts.sample_rate
    samples = HERE / "voice_samples"; samples.mkdir(exist_ok=True)
    first = lines[0]["text"]
    for v in ["M1", "M2", "M3", "M4", "M5"]:
        out = samples / f"{v}.m4a"
        if not out.exists():
            to_m4a(tiger(tts, tts.get_voice_style(v), first), sr, out)
    print(f"목소리 견본: {samples}  (M1~M5)")
    style = tts.get_voice_style(VOICE)
    vdir = HERE / "voice"; vdir.mkdir(exist_ok=True)
    for i, ln in enumerate(lines, 1):
        to_m4a(tiger(tts, style, ln["text"]), sr, vdir / f"{ln['id']}.m4a")
        print(f"[{i}/{len(lines)}] {ln['id']}  {ln['text']}")
    (vdir / "_voice.txt").write_text(f"voice={VOICE} pitch={PITCH} speed={SPEED}\n", encoding="utf-8")
    print(f"완료: {vdir}  (voice={VOICE}, pitch={PITCH}, speed={SPEED})")

if __name__ == "__main__":
    main()
