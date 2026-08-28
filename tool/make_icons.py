# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow>=11"]
# ///
"""Generates the PWA icons of the shopping list app: `uv run tool/make_icons.py`.

The art is a checklist sheet on the theme's primary color: the same
#3B6939 the manifest and the Material theme use. Drawn at 1024 and
downscaled, so every size keeps clean edges.
"""

from pathlib import Path

from PIL import Image, ImageDraw

GREEN = (59, 105, 57, 255)  # #3B6939, AppTheme.light.colorScheme.primary.
# Changing the theme seed means rerunning this — web_assets_test only checks
# the manifest color, not the pixels.
WHITE = (255, 255, 255, 255)
SIZE = 1024
WEB = Path(__file__).resolve().parent.parent / "web"


def draw_sheet(draw: ImageDraw.ImageDraw, scale: float, simple: bool) -> None:
    """Draws the checklist sheet centered, scaled by `scale` around the center."""

    def sx(value: float) -> float:
        return SIZE / 2 + (value - SIZE / 2) * scale

    def box(x0: float, y0: float, x1: float, y1: float, radius: float, fill):
        draw.rounded_rectangle(
            [sx(x0), sx(y0), sx(x1), sx(y1)], radius=radius * scale, fill=fill
        )

    box(232, 152, 792, 872, 56, WHITE)  # the sheet

    if simple:  # favicon: two thick lines survive 32 pixels, six do not
        for y in (400, 624):
            box(340, y - 46, 684, y + 46, 46, GREEN)
        return

    for index, y in enumerate((350, 512, 674)):
        box(320, y - 42, 404, y + 42, 20, GREEN)  # the checkbox
        box(452, y - 30, 704, y + 30, 30, GREEN)  # the line
        if index == 0:  # only the first item is ticked
            draw.line(
                [(sx(338), sx(352)), (sx(358), sx(376)), (sx(388), sx(324))],
                fill=WHITE,
                width=int(22 * scale),
                joint="curve",
            )


def render(scale: float, simple: bool = False) -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), GREEN)
    draw_sheet(ImageDraw.Draw(image), scale, simple)
    return image


def save(image: Image.Image, path: Path, size: int) -> None:
    image.resize((size, size), Image.LANCZOS).save(path)
    print(f"{path.relative_to(WEB.parent)} — {size}x{size}")


# Full bleed: iOS and Android apply their own mask over the square.
plain = render(scale=1.0)
save(plain, WEB / "icons/Icon-192.png", 192)
save(plain, WEB / "icons/Icon-512.png", 512)

# Maskable: everything meaningful has to fit the safe circle, 80% of the
# side — the launcher may crop the rest.
maskable = render(scale=0.62)
save(maskable, WEB / "icons/Icon-maskable-192.png", 192)
save(maskable, WEB / "icons/Icon-maskable-512.png", 512)

save(render(scale=1.0, simple=True), WEB / "favicon.png", 32)
