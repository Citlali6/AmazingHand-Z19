"""Dependency and API inspection only. Never construct an SDK controller."""
import importlib.metadata
import inspect
import json
import platform


def main() -> None:
    import cv2
    import numpy
    from roarm_sdk.roarm import roarm
    methods = ("feedback_get", "joints_angle_get", "pose_ctrl", "gripper_angle_ctrl")
    print(json.dumps({
        "python": platform.python_version(), "opencv": cv2.__version__,
        "numpy": numpy.__version__, "sdk_distribution": importlib.metadata.version("roarm_sdk"),
        "sdk_constructor": str(inspect.signature(roarm)),
        "methods": {name: str(inspect.signature(getattr(roarm, name))) for name in methods},
        "hardware": "NOT OPENED; ROARM NOT TESTED",
    }, indent=2))


if __name__ == "__main__":
    main()
