"""第 4b 步冒烟测试 —— 语音命令链（Vosk 离线命令词）。

前置：``pip install vosk`` + 模型（``python tools/download_vosk_model.py``）。

运行::

    python host/tests/smoke_test_voice.py

注意：命令词识别的**真值测试需真人录音**（F1 验收：词表内识别可靠、
端到端 ≤2s），本文件覆盖解析逻辑 + 管线连通 + 静音鲁棒性；
真实音频验收项在板端集成时人工执行（清单见测试末尾注释）。
"""

from __future__ import annotations

import sys
import wave
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "host"))

from app.voice.kws import (  # noqa: E402
    DEFAULT_MODEL_DIR,
    Command,
    ZhCommandKws,
    grammar_words,
    parse_zh_command,
)


def test_parse_grasp_with_object() -> None:
    for text, want in [("抓起香蕉", ("grasp", "banana")),
                       ("拿个苹果", ("grasp", "apple")),
                       ("捡瓶子", ("grasp", "bottle"))]:
        cmd = parse_zh_command(text)
        assert cmd is not None and cmd.action == want[0] and cmd.target == want[1], \
            f"{text} -> {cmd}"


def test_parse_release_stop_reset() -> None:
    assert parse_zh_command("放下").action == "release"
    assert parse_zh_command("松开").action == "release"
    assert parse_zh_command("停下").action == "stop"
    assert parse_zh_command("复位").action == "reset"


def test_parse_noncommand_returns_none() -> None:
    assert parse_zh_command("今天天气不错") is None
    assert parse_zh_command("") is None


def test_grammar_covers_commands() -> None:
    words = grammar_words()
    assert "抓" in words and "放" in words and "香蕉" in words and "苹果" in words
    assert len(words) == len(set(words)), "grammar words must be unique"


def test_vosk_pipeline_silent_wav() -> None:
    """模型加载 + wav 管线 + 静音鲁棒（输出空/无命令均视为通过）。"""
    assert DEFAULT_MODEL_DIR.exists(), "先运行 tools/download_vosk_model.py"
    kws = ZhCommandKws()
    # 生成 1s 静音 wav
    tmp = Path(__file__).with_name("_silence_16k.wav")
    with wave.open(str(tmp), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(16000)
        wf.writeframes(b"\x00\x00" * 16000)
    try:
        text = kws.transcribe_wav(tmp)
        cmd = kws.command_from_wav(tmp)
        assert isinstance(text, str)
        assert cmd is None, f"silence must not produce a command: {cmd}"
    finally:
        tmp.unlink(missing_ok=True)


def test_command_dataclass_contract() -> None:
    """Command 字段与 main.VoiceSource 契约一致（duck-typing）。"""
    c = Command("grasp", "banana")
    assert c.action == "grasp" and c.target == "banana"


# ---------------------------------------------------------------------------
# 板端集成人工验收清单（F1，真实音频）：
#   1. 词表内 15 类物品 × 3 人各说 5 遍，命令词识别率 ≥90%
#   2. "抓起X/放下/停/复位" 混说 20 句，无跨命令串扰
#   3. 端到端延迟（说完全部音节 → UI 出现指令）≤ 2s
#   4. 现场噪声（评委走动/交谈）下误触发 < 5%
# ---------------------------------------------------------------------------


def main() -> int:
    tests = [
        (name, fn)
        for name, fn in sorted(globals().items())
        if name.startswith("test_") and callable(fn)
    ]
    failures = 0
    for name, fn in tests:
        try:
            fn()
            print(f"  PASS  {name}")
        except Exception as exc:  # noqa: BLE001
            failures += 1
            print(f"  FAIL  {name}: {type(exc).__name__}: {exc}")
    total = len(tests)
    print(f"\n{total - failures}/{total} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
