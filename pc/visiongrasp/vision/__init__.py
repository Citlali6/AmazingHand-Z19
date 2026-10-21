"""PC tabletop vision. Importing this module never opens a camera."""
from .camera import CameraProvider, SyntheticCamera
from .calibration import TableCalibrator
from .detector import BlockDetector, DetectorConfig

__all__ = ["CameraProvider", "SyntheticCamera", "TableCalibrator", "BlockDetector", "DetectorConfig"]
