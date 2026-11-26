from PIL import Image, ImageDraw

width, height = 1024, 1024
img = Image.new("RGBA", (width, height), (255, 255, 255, 0))
d = ImageDraw.Draw(img)

# yellow circle
cx, cy, r = 512, 460, 310
bbox = [cx - r, cy - r, cx + r, cy + r]
d.ellipse(bbox, fill="#ffc107")

# green bottom shape (cubic bezier path approximated)
start = (22.574, 529.997)
line_end = (1001.427, 529.997)
curve1_cp1 = (988.781, 728.218)
curve1_cp2 = (773.405, 884.0)
curve1_end = (512.001, 884.0)
curve2_cp1 = (250.597, 884.0)
curve2_cp2 = (35.221, 728.218)
curve2_end = start

def cubic_bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return (
        u * u * u * p0[0]
        + 3 * u * u * t * p1[0]
        + 3 * u * t * t * p2[0]
        + t * t * t * p3[0],
        u * u * u * p0[1]
        + 3 * u * u * t * p1[1]
        + 3 * u * t * t * p2[1]
        + t * t * t * p3[1],
    )

points = [start, line_end]
for i in range(1, 51):
    t = i / 50
    points.append(cubic_bezier(line_end, curve1_cp1, curve1_cp2, curve1_end, t))
for i in range(1, 51):
    t = i / 50
    points.append(cubic_bezier(curve1_end, curve2_cp1, curve2_cp2, curve2_end, t))

d.polygon(points, fill="#004545")

# white star
star = [
    (512, 260),
    (712, 660),
    (640, 660),
    (512, 396),
    (384, 660),
    (312, 660),
]
d.polygon(star, fill="#ffffff")

img.save("images/AsumoLogoMark.png")
