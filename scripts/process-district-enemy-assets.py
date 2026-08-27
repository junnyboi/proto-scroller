from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Final

from PIL import Image

ROOT: Final = Path("/home/ubuntu/workspace/proto-scroller")
SOURCES: Final = ROOT / "docs/story-concepts/production-sources/chimera-variants"
CONCEPTS: Final = ROOT / "docs/concepts/district-enemies"
RUNTIME: Final = ROOT / "game/art/city/enemies/archetypes"


@dataclass(frozen=True)
class EnemyArtJob:
    number: int
    slug: str
    runtime_dimension: int

    @property
    def source(self) -> Path:
        return SOURCES / f"{self.number:02d}-{self.slug}-source.png"

    @property
    def concept(self) -> Path:
        return CONCEPTS / f"{self.number:02d}-{self.slug}.png"

    @property
    def runtime(self) -> Path:
        runtime_number = self.number + 26
        return RUNTIME / f"{runtime_number:02d}-{self.slug}.png"


JOBS: Final = (
    EnemyArtJob(1, "covenant-warden", 320),
    EnemyArtJob(2, "mercy-recovery-cart", 384),
    EnemyArtJob(3, "testament-kite", 384),
    EnemyArtJob(4, "receivership-ambulance", 448),
    EnemyArtJob(5, "intake-shepherd", 320),
    EnemyArtJob(6, "evacuation-litter", 384),
    EnemyArtJob(7, "rainvault-pressure-ward", 448),
    EnemyArtJob(8, "balcony-recall-beacon", 384),
    EnemyArtJob(9, "memorial-usher", 320),
    EnemyArtJob(10, "glassback-double", 384),
    EnemyArtJob(11, "recall-lantern", 384),
    EnemyArtJob(12, "marquee-anesthetist", 448),
    EnemyArtJob(13, "suture-marshal", 320),
    EnemyArtJob(14, "mercy-raker", 384),
    EnemyArtJob(15, "revetment-ward", 448),
    EnemyArtJob(16, "triage-kite", 448),
    EnemyArtJob(17, "privy-chirurgeon", 320),
    EnemyArtJob(18, "laureate-courser", 384),
    EnemyArtJob(19, "ninefold-witness", 384),
    EnemyArtJob(20, "regency-conservator", 448),
)


def remove_magenta_artifacts(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, old_alpha = pixels[x, y]
            if old_alpha <= 0:
                continue
            dominance = float(min(red, blue) - green)
            if dominance >= 125.0:
                chroma_alpha = 0
            elif dominance <= 38.0:
                chroma_alpha = 255
            else:
                chroma_alpha = round(255.0 * (125.0 - dominance) / 87.0)
            new_alpha = round(float(old_alpha) * float(chroma_alpha) / 255.0)
            if new_alpha <= 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if new_alpha < old_alpha and chroma_alpha > 0:
                ratio = float(chroma_alpha) / 255.0
                clean_red = int(max(0.0, min(255.0, (red - (1.0 - ratio) * 255.0) / ratio)))
                clean_green = int(max(0.0, min(255.0, green / ratio)))
                clean_blue = int(max(0.0, min(255.0, (blue - (1.0 - ratio) * 255.0) / ratio)))
                pixels[x, y] = (clean_red, clean_green, clean_blue, new_alpha)
            else:
                pixels[x, y] = (red, green, blue, new_alpha)
    return rgba


def remove_tiny_alpha_noise(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    # A median pass only on alpha removes isolated generation crumbs without blurring color.
    cleaned_alpha = alpha.filter(Image.Filter.MedianFilter(size=3)) if False else alpha
    # Explicitly discard near-transparent edge noise; the source antialiasing remains above 12.
    cleaned_alpha = cleaned_alpha.point(lambda value: 0 if value <= 12 else value)
    image.putalpha(cleaned_alpha)
    return image


def trim_and_scale(image: Image.Image, max_dimension: int, padding: int) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("No nontransparent sprite pixels found")
    cropped = image.crop(bbox)
    canvas = Image.new(
        "RGBA",
        (cropped.width + padding * 2, cropped.height + padding * 2),
        (0, 0, 0, 0),
    )
    canvas.alpha_composite(cropped, (padding, padding))
    scale = min(1.0, float(max_dimension) / float(max(canvas.width, canvas.height)))
    if scale < 1.0:
        canvas = canvas.resize(
            (max(1, round(canvas.width * scale)), max(1, round(canvas.height * scale))),
            Image.Resampling.LANCZOS,
        )
    return canvas


def save_png(image: Image.Image, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, format="PNG", optimize=True)
    alpha_minimum, alpha_maximum = image.getchannel("A").getextrema()
    if alpha_minimum != 0 or alpha_maximum == 0:
        raise RuntimeError(f"Invalid transparency in {output}")


def process(job: EnemyArtJob) -> None:
    if not job.source.exists():
        raise FileNotFoundError(job.source)
    master = remove_tiny_alpha_noise(remove_magenta_artifacts(Image.open(job.source)))
    concept = trim_and_scale(master, 1100, 30)
    runtime = trim_and_scale(master, job.runtime_dimension, 16)
    save_png(concept, job.concept)
    save_png(runtime, job.runtime)
    print(
        f"processed {job.source.relative_to(ROOT)} -> "
        f"{job.concept.relative_to(ROOT)}, {job.runtime.relative_to(ROOT)}"
    )


def main() -> None:
    for job in JOBS:
        process(job)


if __name__ == "__main__":
    main()
