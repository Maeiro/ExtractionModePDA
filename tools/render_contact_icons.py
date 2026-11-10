"""Render original contact insignia from simple vector shapes; requires Pillow."""
from pathlib import Path

from PIL import Image, ImageDraw


OUT = Path(__file__).resolve().parents[1] / "42/media/ui/ExtractionModePDA"
COLORS = {"dr_layne": "#3cddd0", "franklin_porch": "#e1b64f", "silas_mercer": "#ae80df",
          "sgt_major_graves": "#ec6266", "elias_vance": "#65b6e8", "generic": "#86c6ac"}
SCALE = 4


def render(contact, accent):
    image = Image.new("RGBA", (128*SCALE, 128*SCALE))
    d = ImageDraw.Draw(image)

    def points(values):
        return [(round(x*SCALE), round(y*SCALE)) for x, y in values]

    def line(values, color=accent, width=3):
        d.line(points(values), fill=color, width=width*SCALE, joint="curve")

    def poly(values, fill):
        d.polygon(points(values), fill=fill)

    def box(rect, fill, outline=None, radius=0):
        coords = tuple(round(v*SCALE) for v in rect)
        d.rounded_rectangle(coords, radius=radius*SCALE, fill=fill, outline=outline, width=2*SCALE)

    def circle(x, y, r, fill, outline=None):
        d.ellipse(((x-r)*SCALE, (y-r)*SCALE, (x+r)*SCALE, (y+r)*SCALE), fill=fill, outline=outline, width=3*SCALE)

    rim = [(64,4),(111,29),(119,85),(88,119),(40,119),(9,85),(17,29),(64,4)]
    poly(rim, "#101c22")
    line(rim, accent, 3)
    inner = [(64,13),(104,35),(110,82),(84,110),(44,110),(18,82),(24,35),(64,13)]
    line(inner, "#38474c", 1)
    for x in (37,57,77):
        line([(x,110),(x+10,110)], accent, 2)
    white, dark = "#ebe7d8", "#152128"
    if contact == "dr_layne":
        box((29,43,99,89), dark, accent, 4)
        line([(31,67),(44,67),(51,52),(61,81),(70,61),(78,67),(97,67)], white, 3)
        poly([(75,26),(85,26),(85,33),(92,33),(92,43),(85,43),(85,50),(75,50),(75,43),(68,43),(68,33),(75,33)], accent)
        line([(52,91),(52,97),(78,97),(78,91)], accent, 3)
    elif contact == "franklin_porch":
        poly([(34,35),(49,35),(56,72),(24,72)], accent)
        poly([(79,35),(94,35),(104,72),(72,72)], accent)
        box((48,45,80,60), accent, radius=3)
        circle(40,76,20,dark,accent); circle(88,76,20,dark,accent)
        circle(40,76,12,"#263b43",white); circle(88,76,12,"#263b43",white)
        line([(32,72),(39,66)],white,2); line([(80,72),(87,66)],white,2)
    elif contact == "silas_mercer":
        poly([(27,46),(67,30),(101,46),(61,63)],accent)
        poly([(27,50),(59,67),(59,98),(27,80)],"#67517e")
        poly([(64,67),(101,50),(101,81),(64,98)],"#84649c")
        line([(47,40),(81,57),(81,87)],white,3)
        box((47,66,74,88),dark,white,3)
        d.arc(tuple(v*SCALE for v in (51,53,70,76)),180,360,fill=white,width=3*SCALE)
        circle(61,76,3,accent)
    elif contact == "sgt_major_graves":
        line([(45,29),(60,22),(80,27),(86,44)],white,2)
        box((35,36,66,79),dark,white,6); box((62,43,93,87),dark,accent,6)
        circle(50,43,2,white); circle(77,50,2,accent)
        line([(41,59),(50,66),(59,59)],accent,3)
        line([(68,65),(77,72),(86,65)],white,3)
        line([(42,91),(64,102),(86,91)],accent,4)
    elif contact == "elias_vance":
        poly([(53,27),(77,27),(77,38),(72,38),(72,57),(94,89),(90,96),(38,96),(34,89),(58,57),(58,38),(53,38)],white)
        poly([(57,67),(73,67),(87,89),(42,89)],accent)
        circle(61,79,3,dark); circle(72,86,2,dark)
        line([(86,29),(101,39),(96,56)],accent,2)
        for x,y in [(86,29),(101,39),(96,56)]: circle(x,y,4,dark,accent)
    else:
        box((35,40,93,96),dark,accent,5)
        line([(45,40),(38,24)],white,3)
        box((46,51,81,65),"#2c584e",white,2)
        for y in (75,81,87): line([(46,y),(68,y)],accent,2)
        circle(80,82,5,white)
        d.arc(tuple(v*SCALE for v in (75,23,105,52)),270,350,fill=white,width=2*SCALE)
    return image.resize((128,128),Image.Resampling.LANCZOS)


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    for contact, accent in COLORS.items():
        render(contact,accent).save(OUT / f"Contact_{contact}.png")
    print(f"Rendered {len(COLORS)} original emblems in {OUT}")
