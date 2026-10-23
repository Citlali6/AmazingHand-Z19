# PC tabletop vision — Issue #8

Issue #33 adds independent ≥5-point measurement reports, labelled click input,
live calibration capture and a separate table→base PLAN PREVIEW. Start with
[the camera operation card](../../../docs/lab/2026-10-22/ISSUE33_CAMERA_CARD.md).
Live targets now require passing independent checks; four-point fit residuals
alone do not establish accuracy. The supplied board design is 500×400 mm with
a 400×300 mm inner ROI and 20 mm grid; physical scale verification is still required.
No physical camera calibration or grasp was performed in #33 development.

Implemented: latest-only threaded camera capture, source-labelled synthetic frames,
HSV red/blue contour candidates, image-to-table-mm calibration and manual tools.
These are colour/shape rules, not a trained detector or a guarantee of graspability.
No module opens a device at import. No serial, SDK, motors or FPGA are used.

`MOCK TESTED`: synthetic images and injected captures only. **PC CAMERA NOT VERIFIED**:
SIM1319-HD720P has not been opened through OpenCV in this development task.
Reported device names/resolutions/fps cannot be inferred from the board silk screen.
Robot-base XYZ, grasp Z and physical reachability remain uncalibrated/`None`.

## Run from the repository root

Use the shared `visiongrasp` Conda environment from #14; do not install the mixed
root requirements or another editable copy from a parallel worktree.

```powershell
conda activate visiongrasp
python -m pytest -c pc/pyproject.toml pc/tests
python pc/scripts/camera_probe.py --headless --seconds 3
python pc/scripts/camera_probe.py --seconds 30
```

The probe defaults to `SYNTHETIC / NO ROBOT`. On-site, select the external camera
index after closing Windows Camera/Teams/other programs. Only the operator runs:

```powershell
python pc/scripts/camera_probe.py --live --index 1 --backend dshow --width 1280 --height 720 --seconds 60 --tune
python pc/scripts/camera_probe.py --live --index 1 --backend msmf --width 640 --height 480 --seconds 60
```

`1` is an example, **not a verified SIM1319 device index**. The log shows requested
backend/size, actual backend, dimensions from received arrays, backend-reported fps,
accepted-frame measured fps, first usable frame time, repeated frames and failures.
Measured fps counts distinct accepted images, not promised hardware throughput.
Use `--config path/to/rules.json` for persisted DetectorConfig fields. `--tune`
provides H, S, V and area trackbars; tuning is not silently saved. JSON ranges use
OpenCV hue 0–179 and S/V 0–255; two intervals cover red hue wrap.

Logs use unique names under ignored `output/pc/issue8/`; no images/private footage
are saved. Exit is 0 after at least one usable frame, 2 when no usable frame arrives.
`q`/ESC closes windows and releases capture. Failures after a usable frame remain
in health logs; inspect the log rather than interpreting exit 0 as continuous uptime.

## Calibration: measured table plane only

Fix the camera, focus, zoom, crop, orientation and table before calibration.
Pixel `(0,0)` is top-left with u right and v down. Choose and physically mark the
table origin, +X/+Y directions and measured distances in **mm**. The convex hull of
measured points is the permitted table workspace. A homography estimates no Z.

Example **synthetic numeric test**, not physical measurements:

```json
{
  "source": "SYNTHETIC",
  "frame_wh_px": [640, 480],
  "image_points": [[20,20],[620,20],[620,460],[20,460]],
  "table_points": [[0,0],[300,0],[300,220],[0,220]]
}
```

For these points `(320,240) px → (150,110) mm`; `(1,1)` is outside workspace.
Save actual measured correspondences in a new JSON file under `output/pc/issue8/`,
with `source: LIVE_PC_UVC` for a real-camera calibration. Never relabel synthetic
test points as a real calibration. At least four distinct noncollinear pairs are
required. More than four measured/check points are recommended: four fitting
points alone always have nearly zero training residual and do **not** prove accuracy.

```powershell
python pc/scripts/calibrate_table.py --points output/pc/issue8/measured-points.json --output output/pc/issue8/table-v1.json
python pc/scripts/camera_probe.py --live --index 1 --backend dshow --width 1280 --height 720 --calibration output/pc/issue8/table-v1.json
```

Alternatively, manually supply a consented image and click four measured corners
in order **origin, +X, opposite, +Y**. Distances below are command examples and must
be replaced by measured physical dimensions:

```powershell
python pc/scripts/calibrate_table.py --image output/pc/issue8/table.png --source LIVE_PC_UVC --table-width-mm 300 --table-height-mm 220 --output output/pc/issue8/table-v2.json
```

The tool does not open a camera. Calibration files include source, version, image
size, paired measurements, matrix, maximum/RMS fit error and an ID. Existing files
are never overwritten. Source/size mismatch, optional session mismatch, workspace
exclusion, stale/future timestamps or absent calibration produce **invalid** targets
with reasons and `table_xy_mm=None`. Loading recomputes the transform and checks
metadata/error. Outliers exceeding `--max-error-mm` are rejected, not silently
discarded. Moving/replacing the camera or changing crop/zoom/rotation requires new
calibration even if resolution is unchanged. The software cannot detect that move.

## API for #18

```python
from visiongrasp.contracts import VisionSource
from visiongrasp.vision import SyntheticCamera, CameraProvider, BlockDetector, TableCalibrator

camera = SyntheticCamera(width=640, height=480)
# Physical API, ONLY manually authorized on-site:
# camera = CameraProvider(index=1, backend="dshow", width=1280, height=720)
packet = camera.read_latest()  # FramePacket | None; nonblocking
detector = BlockDetector()  # optional DetectorConfig, max_age_s=.5
targets = detector.detect(packet) if packet is not None else []
# Fit only measured or explicitly synthetic points; source is required to match:
# table = TableCalibrator.fit(pixel_points, table_mm_points, packet.frame_wh_px,
#                             source=packet.source)
# targets = detector.detect(packet, table)
camera.close()
```

`read_latest()` returns a copy of the newest accepted packet, possibly the same
ID/timestamp on successive UI polls. Consumers identify frames by `(session,id)`;
they must not treat polling as new acquisition or repeatedly submit one action.
Default freshness is .5 s, configurable. Exact repeated capture bytes do not renew
packet time/ID; after three repeats health is `REPEATED_FRAME`, suppressing targets.
This conservative rule can reject a perfectly static scene; it diagnoses a suspected
freeze, not proof of a driver fault. Real sensors usually have pixel noise. Verify
and tune on-site. Black frames, failed reads and timeout withhold any old packet.

Capture starts in one worker, not the GUI thread. There is no automatic reopen.
After unplug/plug, close and explicitly recreate the provider. A Windows backend
may ignore read-timeout properties; `health` still reports `TIMEOUT`, reads remain
nonblocking, and close attempts release plus a bounded join. A blocked driver may
retain its daemon worker until the backend/OS call returns; do not create multiple
providers for the same device. Serial/motor ownership is unaffected.

## On-site checks still required

- Select SIM1319, verify actual dimensions/fps and first-frame time for DSHOW/MSMF.
- Empty desk, wrong colour, glare, partial occlusion, block rotations/backgrounds;
  tune HSV, area/aspect/fill rules without claiming general object recognition.
- Camera occupied, Windows privacy access denied, wrong index, dark lens,
  unplug/replug and stall: no valid target; log errors and explicitly reopen.
- Measure calibration error on independent points and at table edges; record
  actual samples/error, do not use training fit error alone as acceptance.
- Real arm/base calibration and any motor commands remain future authorized work.
