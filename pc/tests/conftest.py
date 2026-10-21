"""Offline tests forbid actual serial and camera access by default."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pytest


@pytest.fixture(autouse=True)
def no_physical_io(monkeypatch):
    def forbidden(*args, **kwargs):
        raise AssertionError("Offline test attempted physical device access")
    import serial
    import cv2
    monkeypatch.setattr(serial.Serial, "open", forbidden)
    monkeypatch.setattr(cv2, "VideoCapture", forbidden)
