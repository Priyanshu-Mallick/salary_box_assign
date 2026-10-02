import asyncio
import hashlib
import math
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from .domain import DomainError, FaceDecision


class OpenCvFaceVerifier:
    """YuNet detection/alignment and SFace 1:1 cosine matching adapter."""

    def __init__(
        self,
        detector_path: str,
        recognizer_path: str,
        *,
        cosine_threshold: float = 0.45,
        consistency_threshold: float = 0.45,
    ) -> None:
        detector_file = Path(detector_path)
        recognizer_file = Path(recognizer_path)
        if not detector_file.is_file() or not recognizer_file.is_file():
            raise RuntimeError("Pinned YuNet and SFace model files are required")
        try:
            import cv2
        except ImportError as error:
            raise RuntimeError("Install the backend face dependency group") from error
        self._cv2: Any = cv2
        self._detector = cv2.FaceDetectorYN.create(
            str(detector_file), "", (320, 320), 0.9, 0.3, 5000
        )
        self._recognizer = cv2.FaceRecognizerSF.create(str(recognizer_file), "")
        self._cosine_threshold = cosine_threshold
        self._consistency_threshold = consistency_threshold
        self.model_id = f"sface:{hashlib.sha256(recognizer_file.read_bytes()).hexdigest()}"
        self._lock = asyncio.Lock()

    async def enrol(self, images: Sequence[bytes]) -> FaceDecision:
        if len(images) != 3:
            raise DomainError("INVALID_IMAGE_COUNT", "Exactly three images are required", 422)
        async with self._lock:
            embeddings = [await asyncio.to_thread(self._extract, content) for content in images]
        for left in range(len(embeddings)):
            for right in range(left + 1, len(embeddings)):
                if self._cosine(embeddings[left], embeddings[right]) < self._consistency_threshold:
                    raise DomainError(
                        "INCONSISTENT_FACES",
                        "The enrolment captures do not appear to show the same person",
                        422,
                    )
        dimension = len(embeddings[0])
        centroid = [sum(vector[index] for vector in embeddings) / 3 for index in range(dimension)]
        template = self._normalize(centroid)
        return FaceDecision(True, self._pack(template))

    async def verify(self, enrolled_template: bytes, image: bytes) -> FaceDecision:
        enrolled = self._unpack(enrolled_template)
        async with self._lock:
            probe = await asyncio.to_thread(self._extract, image)
        score = self._cosine(enrolled, probe)
        return FaceDecision(
            score >= self._cosine_threshold,
            score=score,
            threshold=self._cosine_threshold,
        )

    def _extract(self, content: bytes) -> list[float]:
        import numpy as np

        if not content or len(content) > 2 * 1024 * 1024:
            raise DomainError("INVALID_IMAGE", "Image size is invalid", 422)
        raw = np.frombuffer(content, dtype=np.uint8)
        image = self._cv2.imdecode(raw, self._cv2.IMREAD_COLOR)
        if image is None:
            raise DomainError("INVALID_IMAGE", "Image could not be decoded", 422)
        height, width = image.shape[:2]
        if width <= 0 or height <= 0 or width * height > 4_000_000:
            raise DomainError("INVALID_IMAGE", "Image dimensions are invalid", 422)
        self._detector.setInputSize((width, height))
        _, faces = self._detector.detect(image)
        count = 0 if faces is None else len(faces)
        if count == 0:
            raise DomainError("NO_FACE", "No face was detected", 422)
        if count != 1:
            raise DomainError("MULTIPLE_FACES", "Only one face may be present", 422)
        face = faces[0]
        if face[2] < 160 or face[3] < 160:
            raise DomainError("LOW_QUALITY", "Move closer to the camera", 422)
        aligned = self._recognizer.alignCrop(image, face)
        grayscale = self._cv2.cvtColor(aligned, self._cv2.COLOR_BGR2GRAY)
        luminance = float(grayscale.mean())
        sharpness = float(self._cv2.Laplacian(grayscale, self._cv2.CV_64F).var())
        if luminance < 45 or luminance > 210:
            raise DomainError("LOW_QUALITY", "Use more even lighting", 422)
        if sharpness < 80:
            raise DomainError("LOW_QUALITY", "Hold the camera steady and try again", 422)
        features = self._recognizer.feature(aligned).flatten().astype(float).tolist()
        return self._normalize(features)

    @staticmethod
    def _normalize(values: Sequence[float]) -> list[float]:
        if not values or any(not math.isfinite(value) for value in values):
            raise DomainError("INVALID_EMBEDDING", "Face embedding is invalid", 422)
        norm = math.sqrt(sum(value * value for value in values))
        if norm <= 1e-12:
            raise DomainError("INVALID_EMBEDDING", "Face embedding is invalid", 422)
        return [value / norm for value in values]

    @staticmethod
    def _cosine(left: Sequence[float], right: Sequence[float]) -> float:
        if len(left) != len(right):
            raise DomainError("MODEL_INCOMPATIBLE", "Face model versions are incompatible", 409)
        return sum(a * b for a, b in zip(left, right, strict=True))

    @staticmethod
    def _pack(values: Sequence[float]) -> bytes:
        import struct

        return struct.pack(f"<{len(values)}f", *values)

    @staticmethod
    def _unpack(content: bytes) -> list[float]:
        import struct

        if len(content) != 128 * 4:
            raise DomainError("MODEL_INCOMPATIBLE", "Face template has the wrong dimension", 409)
        return list(struct.unpack("<128f", content))
