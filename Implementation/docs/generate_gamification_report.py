# -*- coding: utf-8 -*-
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from xml.sax.saxutils import escape
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageDraw, ImageFont


DOCS_DIR = Path(__file__).resolve().parent
REPORT_PATH = DOCS_DIR / "vitamate_gamification_detailed_report_ar.docx"

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\arial.ttf",
    r"C:\Windows\Fonts\tahoma.ttf",
    r"C:\Windows\Fonts\calibri.ttf",
]

PRIMARY = "#6E35FF"
PRIMARY_DARK = "#3F1598"
SOFT = "#F5EFFF"
SUCCESS = "#DFF5E7"
WARNING = "#FFF0DC"
DANGER = "#FFE5E5"
TEXT = "#23113D"
MUTED = "#6B5A87"
LINE = "#B798FF"
WHITE = "#FFFFFF"


def load_font(size: int):
    for item in FONT_CANDIDATES:
        path = Path(item)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


TITLE_FONT = load_font(36)
BOX_FONT = load_font(24)
SMALL_FONT = load_font(20)
CAPTION_FONT = load_font(22)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font, max_width: int) -> str:
    words = text.split()
    if not words:
        return ""
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        trial = f"{current} {word}"
        width = draw.textbbox((0, 0), trial, font=font)[2]
        if width <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return "\n".join(lines)


def draw_box(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int, int, int],
    text: str,
    *,
    fill: str = WHITE,
    outline: str = LINE,
    font=BOX_FONT,
    text_fill: str = TEXT,
) -> None:
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=22, fill=fill, outline=outline, width=3)
    wrapped = wrap_text(draw, text, font, max_width=(x2 - x1) - 28)
    bbox = draw.multiline_textbbox((0, 0), wrapped, font=font, spacing=6, align="center")
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = x1 + ((x2 - x1) - tw) / 2
    ty = y1 + ((y2 - y1) - th) / 2
    draw.multiline_text((tx, ty), wrapped, font=font, fill=text_fill, spacing=6, align="center")


def draw_arrow(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    *,
    fill: str = PRIMARY_DARK,
    width: int = 5,
    head: int = 14,
) -> None:
    import math

    draw.line([start, end], fill=fill, width=width)
    x1, y1 = start
    x2, y2 = end
    dx = x2 - x1
    dy = y2 - y1
    if dx == 0 and dy == 0:
        return
    angle = math.atan2(dy, dx)
    left = (
        x2 - head * math.cos(angle - math.pi / 6),
        y2 - head * math.sin(angle - math.pi / 6),
    )
    right = (
        x2 - head * math.cos(angle + math.pi / 6),
        y2 - head * math.sin(angle + math.pi / 6),
    )
    draw.polygon([end, left, right], fill=fill)


def add_title(draw: ImageDraw.ImageDraw, title: str, width: int) -> None:
    bbox = draw.textbbox((0, 0), title, font=TITLE_FONT)
    tw = bbox[2] - bbox[0]
    draw.text(((width - tw) / 2, 26), title, font=TITLE_FONT, fill=PRIMARY_DARK)


def create_flow_overview(path: Path) -> None:
    img = Image.new("RGB", (1800, 1120), WHITE)
    draw = ImageDraw.Draw(img)
    add_title(draw, "VitaMate Points Flow", 1800)
    draw_box(
        draw,
        (70, 140, 360, 255),
        "User action\nlog water / meal / steps / activity / sleep / medication",
        fill=SOFT,
    )
    draw_box(
        draw,
        (420, 110, 790, 285),
        "Tracker services\nWaterLoggingService\nActivityService\nStepsService\nSleepLoggingService\nNutritionLoggingService",
        fill="#F8F6FF",
    )
    draw_box(
        draw,
        (850, 110, 1180, 285),
        "Rule layer\nfixed rewards\nformula-based rewards\npenalties\ndiff-based scoring",
        fill="#F8F6FF",
    )
    draw_box(draw, (1240, 145, 1500, 250), "PointsService", fill=SUCCESS)
    draw_box(draw, (1560, 145, 1730, 250), "UserScore\nRepository", fill=SUCCESS)
    draw_box(draw, (1340, 380, 1610, 505), "UserScore\ntotal_points + level", fill=WARNING)
    draw_box(draw, (990, 645, 1260, 760), "add_points()\npositive delta", fill=SUCCESS)
    draw_box(draw, (1370, 645, 1640, 760), "deduct_points()\nnegative delta", fill=DANGER)
    draw_box(
        draw,
        (1100, 885, 1530, 1010),
        "Level update\nlevel = floor(total_points / 1000) + 1\n(recomputed on add only)",
        fill=SOFT,
    )
    draw_arrow(draw, (360, 197), (420, 197))
    draw_arrow(draw, (790, 197), (850, 197))
    draw_arrow(draw, (1180, 197), (1240, 197))
    draw_arrow(draw, (1500, 197), (1560, 197))
    draw_arrow(draw, (1645, 250), (1490, 380))
    draw_arrow(draw, (1475, 505), (1125, 645))
    draw_arrow(draw, (1475, 505), (1505, 645))
    draw_arrow(draw, (1125, 760), (1245, 885))
    draw_arrow(draw, (1505, 760), (1390, 885))

    notes = [
        (80, 365, "Examples of rules:"),
        (80, 405, "+5 water log"),
        (80, 445, "+5 activity log"),
        (80, 485, "steps => max(1, floor(steps/1000)*5)"),
        (80, 525, "meal => +5 or -5 depending on calorie target"),
        (80, 565, "sleep => +10 if >= 90% of goal"),
        (80, 605, "medication / chronic => positive and negative deltas"),
    ]
    for x, y, text in notes:
        font = CAPTION_FONT if text.endswith(":") else SMALL_FONT
        color = PRIMARY_DARK if text.endswith(":") else MUTED
        draw.text((x, y), text, font=font, fill=color)
    img.save(path)


def create_sequence(path: Path) -> None:
    width, height = 1800, 1080
    img = Image.new("RGB", (width, height), WHITE)
    draw = ImageDraw.Draw(img)
    add_title(draw, "Sequence: How a Tracker Action Becomes Score", width)
    actors = [
        (130, "User"),
        (420, "Feature Service"),
        (740, "PointsService"),
        (1030, "Repository"),
        (1320, "UserScore"),
        (1600, "UI / ReadModel"),
    ]
    top = 120
    bottom = 960
    for x, label in actors:
        draw_box(draw, (x - 80, top, x + 80, top + 60), label, fill=SOFT, font=SMALL_FONT)
        draw.line((x, top + 60, x, bottom), fill=LINE, width=3)

    def message(y: int, src: int, dst: int, text: str, color: str = PRIMARY_DARK) -> None:
        draw_arrow(draw, (src, y), (dst, y), fill=color, width=4, head=12)
        bbox = draw.textbbox((0, 0), text, font=SMALL_FONT)
        tw = bbox[2] - bbox[0]
        tx = min(src, dst) + abs(dst - src) / 2 - tw / 2
        draw.rectangle((tx - 8, y - 28, tx + tw + 8, y - 2), fill=WHITE)
        draw.text((tx, y - 26), text, font=SMALL_FONT, fill=color)

    message(240, 130, 420, "1) user logs tracker event")
    message(330, 420, 740, "2) service selects reward / penalty formula")
    message(420, 740, 1030, "3) get_or_create_for_user(user)")
    message(510, 1030, 1320, "4) fetch UserScore")
    message(600, 740, 1320, "5) add_points() or deduct_points()", color="#9A1B1B")
    message(690, 1320, 1320, "6) save total_points and maybe level", color=PRIMARY)
    message(780, 420, 1600, "7) publish health-state event")
    message(870, 1600, 420, "8) UI refreshes points / daily estimate / motivation", color="#1A7B56")
    img.save(path)


def create_level_logic(path: Path) -> None:
    width, height = 1600, 760
    img = Image.new("RGB", (width, height), WHITE)
    draw = ImageDraw.Draw(img)
    add_title(draw, "Level Logic", width)
    draw.text((110, 120), "Persistent score model:", font=CAPTION_FONT, fill=PRIMARY_DARK)
    draw_box(draw, (110, 165, 540, 295), "UserScore\ntotal_points\nlevel", fill=SOFT)
    draw_box(draw, (630, 175, 1100, 285), "new_level = floor(total_points / 1000) + 1", fill=WARNING)
    draw_arrow(draw, (540, 230), (630, 230))
    draw.text((110, 350), "Thresholds:", font=CAPTION_FONT, fill=PRIMARY_DARK)
    segments = [
        ("Level 1", "0 - 999 pts", "#F3EEFF"),
        ("Level 2", "1000 - 1999 pts", "#E6F8EC"),
        ("Level 3", "2000 - 2999 pts", "#FFF5E6"),
        ("Level 4", "3000 - 3999 pts", "#FDE8F3"),
    ]
    x = 110
    y = 410
    w = 320
    for label, rng, fill in segments:
        draw_box(draw, (x, y, x + w, y + 150), f"{label}\n{rng}", fill=fill)
        x += w + 25
    draw.text(
        (110, 620),
        "Important current behavior: deduct_points() lowers total_points but does not recompute level downward.",
        font=SMALL_FONT,
        fill="#A14500",
    )
    img.save(path)


def create_ui_flow(path: Path) -> None:
    width, height = 1760, 980
    img = Image.new("RGB", (width, height), WHITE)
    draw = ImageDraw.Draw(img)
    add_title(draw, "Motivation and UI Projection Flow", width)
    draw_box(draw, (90, 170, 410, 290), "UserScore\npoints + level", fill=WARNING)
    draw_box(draw, (90, 420, 410, 565), "HealthConstraintEngine\nestimate_day_points()", fill=SOFT)
    draw_box(draw, (90, 680, 410, 800), "MedicationAdherenceService\npoints_for_day()", fill=SOFT)
    draw_box(
        draw,
        (560, 300, 1010, 455),
        "HealthStateProjectionService\ntracker_points_estimate\npoints_estimate = tracker estimate + medication points",
        fill=SUCCESS,
    )
    draw_box(
        draw,
        (1120, 300, 1440, 455),
        "ReadModelService\nhome_overview\nactivity_summary\nprogress_history",
        fill=SUCCESS,
    )
    draw_box(
        draw,
        (1260, 620, 1640, 840),
        "Frontend motivation surfaces\nHome: points / level / daily_points\nActivity: points_estimate / local movement points\nStats: gamification and history points",
        fill=SOFT,
    )
    draw_arrow(draw, (410, 230), (560, 350))
    draw_arrow(draw, (410, 495), (560, 380))
    draw_arrow(draw, (410, 740), (560, 410))
    draw_arrow(draw, (1010, 380), (1120, 380))
    draw_arrow(draw, (1280, 455), (1410, 620))
    draw.text(
        (560, 520),
        "Stored score and daily estimate are related but not identical.",
        font=SMALL_FONT,
        fill=PRIMARY_DARK,
    )
    img.save(path)


def create_chronic_flow(path: Path) -> None:
    width, height = 1760, 980
    img = Image.new("RGB", (width, height), WHITE)
    draw = ImageDraw.Draw(img)
    add_title(draw, "Chronic / Medication Points with Audit Trail", width)
    draw_box(draw, (80, 170, 410, 310), "Medication dose status\nTaken on time / Late / Missed / Skipped", fill=SOFT)
    draw_box(draw, (80, 390, 410, 530), "Daily restriction evaluation\n>= 80% => +5\n< 50% => -3", fill=SOFT)
    draw_box(draw, (80, 610, 410, 750), "Health indicator reading\nnormal => +5\ncritical => +1", fill=SOFT)
    draw_box(
        draw,
        (560, 320, 980, 480),
        "ConditionPointsEvaluator\ncalculates desired_points\ncomputes points_diff\napplies streak bonuses",
        fill=SUCCESS,
    )
    draw_box(draw, (1110, 230, 1450, 360), "PointsService\nadd / deduct delta", fill=WARNING)
    draw_box(
        draw,
        (1110, 520, 1450, 650),
        "ConditionPointsAudit\nreason + explanation + metadata",
        fill="#FDE8F3",
    )
    draw_box(draw, (1490, 320, 1680, 455), "UserScore", fill=WARNING)
    draw_arrow(draw, (410, 240), (560, 360))
    draw_arrow(draw, (410, 460), (560, 400))
    draw_arrow(draw, (410, 680), (560, 440))
    draw_arrow(draw, (980, 380), (1110, 295))
    draw_arrow(draw, (980, 430), (1110, 585))
    draw_arrow(draw, (1450, 295), (1490, 360))
    draw.text(
        (1120, 700),
        "This is the most traceable points path in the current system.",
        font=SMALL_FONT,
        fill=PRIMARY_DARK,
    )
    img.save(path)


def emu_from_px(px: int) -> int:
    return int(px / 96 * 914400)


def paragraph(
    text: str,
    *,
    bold: bool = False,
    size: int = 24,
    align: str = "right",
    bidi: bool = True,
    color: str | None = None,
    font_name: str = "Arial",
) -> str:
    escaped = escape(text)
    ppr_bits: list[str] = []
    if bidi:
        ppr_bits.append("<w:bidi/>")
    if align:
        ppr_bits.append(f'<w:jc w:val="{align}"/>')
    ppr_xml = f"<w:pPr>{''.join(ppr_bits)}</w:pPr>" if ppr_bits else ""

    rpr_bits = [f'<w:rFonts w:ascii="{font_name}" w:hAnsi="{font_name}" w:cs="{font_name}"/>']
    if bold:
        rpr_bits.append("<w:b/>")
    if bidi:
        rpr_bits.append("<w:rtl/>")
    if size:
        rpr_bits.append(f'<w:sz w:val="{size}"/><w:szCs w:val="{size}"/>')
    if color:
        rpr_bits.append(f'<w:color w:val="{color}"/>')
    rpr_bits.append('<w:lang w:bidi="ar-SA" w:val="en-US"/>')
    rpr_xml = f"<w:rPr>{''.join(rpr_bits)}</w:rPr>"
    return f'<w:p>{ppr_xml}<w:r>{rpr_xml}<w:t xml:space="preserve">{escaped}</w:t></w:r></w:p>'


def image_paragraph(rel_id: str, name: str, width_px: int, height_px: int, docpr_id: int) -> str:
    cx = emu_from_px(width_px)
    cy = emu_from_px(height_px)
    return f"""
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r>
        <w:drawing>
          <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
            <wp:extent cx="{cx}" cy="{cy}"/>
            <wp:docPr id="{docpr_id}" name="{escape(name)}"/>
            <wp:cNvGraphicFramePr>
              <a:graphicFrameLocks noChangeAspect="1" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"/>
            </wp:cNvGraphicFramePr>
            <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                  <pic:nvPicPr>
                    <pic:cNvPr id="0" name="{escape(name)}"/>
                    <pic:cNvPicPr/>
                  </pic:nvPicPr>
                  <pic:blipFill>
                    <a:blip r:embed="{rel_id}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                    <a:stretch><a:fillRect/></a:stretch>
                  </pic:blipFill>
                  <pic:spPr>
                    <a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>
                    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                  </pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>
    """


def page_break() -> str:
    return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'


def build_report() -> None:
    with TemporaryDirectory() as tmp_dir:
        tmp = Path(tmp_dir)
        diagram_specs = [
            ("diagram_points_flow.png", create_flow_overview),
            ("diagram_sequence.png", create_sequence),
            ("diagram_level_logic.png", create_level_logic),
            ("diagram_ui_flow.png", create_ui_flow),
            ("diagram_chronic_flow.png", create_chronic_flow),
        ]

        diagrams: list[dict[str, object]] = []
        for file_name, builder in diagram_specs:
            image_path = tmp / file_name
            builder(image_path)
            with Image.open(image_path) as img:
                diagrams.append(
                    {
                        "file_name": file_name,
                        "path": image_path,
                        "width": img.size[0],
                        "height": img.size[1],
                    }
                )

        body: list[str] = []
        body.append(
            paragraph(
                "تقرير تفصيلي لنظام Gamification وآلية احتساب النقاط في VitaMate",
                bold=True,
                size=34,
                color="3F1598",
            )
        )
        body.append(
            paragraph(
                "هذا التقرير يجمع الشرحين الأخيرين: الشرح التفصيلي لقواعد النقاط في كل قسم، وشرح مخططات UML و Flow التي توضح كيف تنتقل النقاط من الحدث اليومي حتى تصل إلى UserScore ثم تنعكس كتحفيز في الواجهة.",
                size=24,
            )
        )
        body.append(
            paragraph(
                f"تاريخ الإنشاء: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
                size=22,
                color="6B5A87",
            )
        )

        body.append(paragraph("1. الصورة العامة للنظام", bold=True, size=28, color="3F1598"))
        body.append(
            paragraph(
                "المصدر الحقيقي للـ gamification هو جدول UserScore. هذا الجدول يخزن total_points و level فقط لكل مستخدم. جميع الإضافات والخصومات تمر عبر PointsService، والذي يجلب سجل المستخدم من UserScoreRepository ثم يطبق add_points أو deduct_points.",
                size=24,
            )
        )
        body.append(
            paragraph(
                "معادلة المستوى الحالية بسيطة: level = floor(total_points / 1000) + 1. لذلك فإن 0 إلى 999 نقطة تعني Level 1، و1000 إلى 1999 نقطة تعني Level 2، وهكذا.",
                size=24,
            )
        )
        body.append(
            paragraph(
                "ملاحظة مهمة: عند الخصم يتم إنقاص total_points ومنعها من النزول تحت الصفر، لكن المستوى لا يعاد حسابه نزولاً. هذا يعني أن المستوى في التطبيق الحالي تصاعدي فقط.",
                size=24,
                color="A14500",
            )
        )
        body.append(image_paragraph("rId2", "Overall points flow", int(diagrams[0]["width"]), int(diagrams[0]["height"]), 1))
        body.append(
            paragraph(
                "شكل 1: التدفق العام للنقاط من حدث المستخدم حتى تحديث UserScore.",
                size=20,
                align="center",
                color="6B5A87",
            )
        )

        body.append(paragraph("2. كيف تصل النقاط إلى UserScore", bold=True, size=28, color="3F1598"))
        body.append(
            paragraph(
                "كل حدث يبدأ من خدمة وظيفية مرتبطة بميزة محددة مثل الماء، النشاط، الخطوات، النوم، التغذية، العادات، الأدوية، أو الحالات المزمنة. هذه الخدمة تطبق قاعدة النقاط المناسبة، ثم تستدعي PointsService. بعد ذلك يجلب PointsService سجل المستخدم الحالي أو ينشئه إذا لم يكن موجوداً، ثم يضيف أو يخصم النقاط ويكتب total_points وربما level.",
                size=24,
            )
        )
        body.append(
            paragraph(
                "بعد تحديث النقاط، تنشر الخدمة حدثاً إلى طبقة Health State. هذا الحدث لا يغير UserScore مرة ثانية، لكنه يطلب تحديث الملخصات و read models حتى تظهر القيم الجديدة في Home و Activity و Stats وغيرها من الواجهات.",
                size=24,
            )
        )
        body.append(image_paragraph("rId3", "Sequence diagram", int(diagrams[1]["width"]), int(diagrams[1]["height"]), 2))
        body.append(
            paragraph(
                "شكل 2: Sequence مبسط يوضح كيف تتحول العملية اليومية إلى نقاط ثم إلى تحديث واجهة المستخدم.",
                size=20,
                align="center",
                color="6B5A87",
            )
        )

        body.append(paragraph("3. قواعد احتساب النقاط حسب القسم", bold=True, size=28, color="3F1598"))
        rule_lines = [
            "• الماء: كل WaterLog جديد يمنح +5 نقاط. التحديث أو الحذف لا يسحب النقاط الحالية.",
            "• النشاط البدني: كل ActivityLog جديد يمنح +5 نقاط. في Live Workout لا توجد نقاط عند start؛ النقاط تأتي عند finish لأن الجلسة تتحول إلى ActivityLog.",
            "• الخطوات: المعادلة هي max(1, floor(steps_count / 1000) * 5). ولكن الخدمة تطبقها على العدد الكلي الحالي لليوم عند كل log_steps، وليس على الزيادة فقط.",
            "• النوم: إذا كان أول SleepLog في ذلك اليوم يحقق 90% أو أكثر من هدف النوم، يحصل المستخدم على +10 نقاط.",
            "• التغذية: بعد كل MealLog جديد، يجمع النظام سعرات اليوم كلها. إذا كانت ضمن الهدف يضيف +5، وإذا تجاوزت الهدف يخصم -5.",
            "• العادات غير الصحية: يوجد +2 للتسجيل، +3 إذا بقي المستخدم ضمن الحد، +4 إذا سجل healthy replacement، و +5 إذا تحسن عن baseline. بعض هذه الأحداث تمنح مرة لكل log وبعضها مرة لكل يوم.",
            "• الأدوية: taken_on_time = +3، taken_late = +1، missed = -2، skipped = 0، و skipped بدون سبب = -1.",
            "• الحالات المزمنة: تقييم الالتزام اليومي قد يعطي +5 أو -3، والقراءة الصحية قد تعطي +5 أو +1 إذا كانت critical، كما توجد مكافآت streak للأدوية وللسلوك الآمن.",
        ]
        for line in rule_lines:
            body.append(paragraph(line, size=24))

        body.append(paragraph("4. تفاصيل المستوى Level", bold=True, size=28, color="3F1598"))
        body.append(
            paragraph(
                "الـ Level لا يعتمد على daily_points ولا على health score. المستوى يعتمد فقط على total_points المخزنة داخل UserScore. كل 1000 نقطة كاملة ترفع المستوى بمقدار 1.",
                size=24,
            )
        )
        body.append(image_paragraph("rId4", "Level logic", int(diagrams[2]["width"]), int(diagrams[2]["height"]), 3))
        body.append(
            paragraph(
                "شكل 3: منطق المستوى الحالي المعتمد على total_points فقط.",
                size=20,
                align="center",
                color="6B5A87",
            )
        )

        body.append(paragraph("5. stored score مقابل daily estimate", bold=True, size=28, color="3F1598"))
        body.append(
            paragraph(
                "هناك فرق أساسي بين النقاط الحقيقية المخزنة وبين النقاط اليومية المعروضة في الواجهة. total_points و level هما المخزون الدائم. أما daily_points أو points_estimate فهي قراءة تحفيزية يومية مشتقة من حالة اليوم الحالية.",
                size=24,
            )
        )
        body.append(
            paragraph(
                "معادلة estimate_day_points الحالية تضيف: +5 إذا يوجد ماء، +نقاط الخطوات إذا كانت steps أكبر من صفر، +5 إذا يوجد نشاط، +5 أو -5 حسب هدف السعرات، و +10 إذا تحقق هدف النوم بنسبة 90% أو أكثر. ثم تضاف medication_points لتكوين points_estimate اليومي.",
                size=24,
            )
        )
        body.append(
            paragraph(
                "لهذا قد ترى في الواجهة أرقاماً مثل points أو daily_points أو points_estimate أو حتى Daily Health Score، وهذه ليست قيماً متطابقة دائماً.",
                size=24,
            )
        )
        body.append(image_paragraph("rId5", "UI motivation flow", int(diagrams[3]["width"]), int(diagrams[3]["height"]), 4))
        body.append(
            paragraph(
                "شكل 4: كيف تُبنى القيم التحفيزية اليومية في طبقة projections ثم تُعرض في Home و Activity و Stats.",
                size=20,
                align="center",
                color="6B5A87",
            )
        )

        body.append(paragraph("6. التحفيز في الواجهة", bold=True, size=28, color="3F1598"))
        body.append(
            paragraph(
                "في Home Overview تُعرض ثلاثة مستويات مختلفة من التحفيز: points الكلية من UserScore، و level من UserScore، و daily_points من projection اليومي. في Activity تُعرض points_estimate الخاصة باليوم أو تقدير محلي مبسط حسب الخطوات والأنشطة المسجلة. في Stats و Progress تُعرض gamification totals بالإضافة إلى history points_estimate لكل يوم.",
                size=24,
            )
        )
        body.append(
            paragraph(
                "أما Daily Health Score في Home فهو ليس UserScore، بل مزيج من healthScore المحسوب من activity و hydration و nutrition و sleep مضافاً إليه dailyPoints ثم مقيد بين 0 و 100. لذلك يجب عدم الخلط بين Health Score و Gamification Points.",
                size=24,
                color="A14500",
            )
        )

        body.append(paragraph("7. مسار الحالات المزمنة والأدوية", bold=True, size=28, color="3F1598"))
        body.append(
            paragraph(
                "هذا هو المسار الأكثر نضجاً وتعقيداً في النظام الحالي. هنا لا تتم الإضافة أو الخصم بشكل ثابت فقط، بل يتم حساب desired_points أولاً، ثم طرح points_applied القديمة للحصول على points_diff. بهذه الطريقة إذا تغيرت حالة الجرعة أو أعيد تقييم اليوم، يتم ضبط النقاط بناءً على الفرق وليس بإعادة جمع النقاط من الصفر بلا رقابة.",
                size=24,
            )
        )
        body.append(
            paragraph(
                "الميزة الإضافية هنا أن كل تغيير يُسجل في ConditionPointsAudit مع السبب والشرح والـ metadata، لذلك يمكن تتبع لماذا زادت أو نقصت النقاط في هذا الجزء تحديداً.",
                size=24,
            )
        )
        body.append(image_paragraph("rId6", "Chronic points flow", int(diagrams[4]["width"]), int(diagrams[4]["height"]), 5))
        body.append(
            paragraph(
                "شكل 5: مسار نقاط الأدوية والحالات المزمنة مع audit trail وتطبيق deltas و streak bonuses.",
                size=20,
                align="center",
                color="6B5A87",
            )
        )

        body.append(paragraph("8. نقاط القوة والسلوك الحالي الذي يجب الانتباه له", bold=True, size=28, color="3F1598"))
        caveats = [
            "• النظام الحالي واضح وبسيط في الماء والنشاط والنوم، وهذا يسهل فهمه للمستخدم.",
            "• chronic و medication يقدمان أفضل نموذج لأنهما يستخدمان diff-based scoring و audit trail.",
            "• steps قد تعطي نقاطاً متكررة إذا تم عمل sync أكثر من مرة على نفس الإجمالي اليومي، لأن المنح يتم على المجموع الحالي لا على الزيادة فقط.",
            "• meal points تُطبق مع كل إضافة وجبة بحسب إجمالي السعرات الحالي، لذلك يمكن أن تحصل إضافات وخصومات متعددة في نفس اليوم.",
            "• update و delete في بعض الأقسام لا يقومان بسحب النقاط القديمة، لذلك total_points لا تعكس دائماً reconciliation كاملاً.",
            "• level لا يهبط عند الخصم، وهذا يجعل المستوى تصاعدياً فقط في التطبيق الحالي.",
            "• بعض طبقات العرض قد تُظهر نقطة خطوات دنيا مختلفة عن score المخزن بسبب اختلاف صياغة القاعدة بين backend و read model و frontend المحلي.",
        ]
        for line in caveats:
            body.append(paragraph(line, size=24))

        body.append(paragraph("الخلاصة", bold=True, size=28, color="3F1598"))
        body.append(
            paragraph(
                "آلية gamification في VitaMate تقوم على فصلين: مخزون حقيقي دائم داخل UserScore، وطبقة عرض يومية تحفيزية تعتمد على points_estimate و daily_points. النقاط تأتي من خدمات التتبع المختلفة، تمر عبر PointsService، ثم تحفظ في UserScore، وبعدها تنعكس على الواجهة عبر read models و projections. أقوى مسار حالياً هو chronic و medication لأنه يطبق فروق النقاط ويحتفظ بسجل تفسير كامل، بينما بقية الأقسام أبسط لكنها تحتاج مستقبلاً إلى reconciliation أدق لتجنب التكرار أو التناقضات بين الواجهة والمخزون الحقيقي.",
                size=24,
            )
        )

        body.append(page_break())
        body.append(paragraph("Appendix: Diagram Notes", bold=True, size=28, bidi=False, align="left", color="3F1598"))
        appendix = [
            "Figure 1: Overall points flow from user action to UserScore.",
            "Figure 2: Sequence of score update from feature service to UI refresh.",
            "Figure 3: Level thresholds and current level recomputation behavior.",
            "Figure 4: Motivation and projection flow for points and daily estimates.",
            "Figure 5: Chronic and medication scoring path with audit trail.",
        ]
        for line in appendix:
            body.append(paragraph(line, size=22, bidi=False, align="left"))

        document_xml = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
  xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
  xmlns:o="urn:schemas-microsoft-com:office:office"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
  xmlns:v="urn:schemas-microsoft-com:vml"
  xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:w10="urn:schemas-microsoft-com:office:word"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
  xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml"
  xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
  xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
  xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
  xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
  mc:Ignorable="w14 wp14 w15">
  <w:body>
    {''.join(body)}
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="850" w:bottom="1134" w:left="850" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>"""

        styles_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:rPr>
      <w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>
      <w:lang w:bidi="ar-SA" w:val="en-US"/>
    </w:rPr>
  </w:style>
</w:styles>"""

        now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        core_xml = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>VitaMate Gamification Detailed Report</dc:title>
  <dc:creator>OpenAI Codex</dc:creator>
  <cp:lastModifiedBy>OpenAI Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>"""

        app_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Office Word</Application>
</Properties>"""

        content_types_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>"""

        root_rels_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>"""

        rel_entries = [
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        ]
        for index, item in enumerate(diagrams, start=2):
            rel_entries.append(
                f'<Relationship Id="rId{index}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/{item["file_name"]}"/>'
            )
        doc_rels_xml = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            + "".join(rel_entries)
            + "</Relationships>"
        )

        with ZipFile(REPORT_PATH, "w", ZIP_DEFLATED) as archive:
            archive.writestr("[Content_Types].xml", content_types_xml)
            archive.writestr("_rels/.rels", root_rels_xml)
            archive.writestr("docProps/core.xml", core_xml)
            archive.writestr("docProps/app.xml", app_xml)
            archive.writestr("word/document.xml", document_xml)
            archive.writestr("word/styles.xml", styles_xml)
            archive.writestr("word/_rels/document.xml.rels", doc_rels_xml)
            for item in diagrams:
                archive.write(item["path"], f'word/media/{item["file_name"]}')


if __name__ == "__main__":
    build_report()
    print(REPORT_PATH)
