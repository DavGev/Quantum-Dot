"""Build the canonical Ry data table and publication-ready vector figures.

The Wolfram Language script retains the original numerical workflow.  This
portable renderer is the source of the manuscript PDFs so their typography,
dimensions, and export behavior are reproducible without a front-end kernel.
"""

from __future__ import annotations

import csv
import math
import re
import shutil
from pathlib import Path
from typing import TypeAlias

from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
NUM = ROOT / "01-numerics"
FIG = ROOT / "03-figures"
PAPER_DATA = ROOT / "04-paper" / "latex" / "data"
PAPER_FIG = ROOT / "04-paper" / "latex" / "figures"

RY_MEV = 5.5638515646389
GEOMETRY_ORDER = [(5.0, 0.5), (5.0, 1.0), (5.0, 1.5), (5.0, 2.0),
                  (3.0, 1.0), (7.0, 1.0), (10.0, 1.0)]

HEADERS = [
    "a/rB", "c/rB", "alpha_X", "alpha", "beta", "gamma", "delta",
    "E_X^0 (Ry)", "Delta E_X (Ry)", "Delta E_X error (Ry)",
    "E_X (Ry)", "E_X error (Ry)",
    "E_XX^0 (Ry)", "Delta E_XX (Ry)", "Delta E_XX error (Ry)",
    "E_XX (Ry)", "E_XX error (Ry)",
    "E_bind = 2 E_X - E_XX (Ry)", "E_bind error (Ry)",
    "N_X", "N_X error", "M_X", "M_X error", "|M_X|^2",
    "|M_X|^2 error",
]


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as stream:
        return list(csv.DictReader(stream))


def number(value: str | float | int | None) -> float:
    if value is None or value == "":
        raise ValueError("Missing numeric value")
    return float(value)


def geometry(row: dict[str, str]) -> tuple[float, float]:
    return number(row.get("a/rB", row.get("a"))), number(row.get("c/rB", row.get("c")))


def parse_parameters(value: str) -> list[float]:
    text = value.strip().strip("{}")
    values = [float(item.strip()) for item in text.split(",")]
    if len(values) != 4:
        raise ValueError(f"XXFinalParameters must be {{alpha,beta,gamma,delta}}: {value}")
    return values


def first_key(row: dict[str, str], *keys: str) -> str:
    for key in keys:
        value = row.get(key, "")
        if value != "":
            return value
    raise KeyError(f"None of {keys} is present")


def recovered_integral_error(row: dict[str, str]) -> float:
    direct = row.get("reportedErrorEstimate", "")
    if direct:
        return float(direct)
    message = row.get("messageText", "")
    coefficient = re.search(r"and\s+([0-9.]+)\s+10", message)
    exponent = re.search(r"(?m)^\s*(-\d+)\s*$", message)
    if not coefficient or not exponent:
        raise ValueError(f"Cannot recover error estimate for {row.get('candidateKey')}")
    return float(coefficient.group(1)) * 10.0 ** int(exponent.group(1))


def ratio_error(numerator: float, numerator_error: float,
                denominator: float, denominator_error: float) -> float:
    ratio = numerator / denominator
    return abs(ratio) * math.sqrt(
        (numerator_error / numerator) ** 2
        + (denominator_error / denominator) ** 2
    )


def close(left: float, right: float, tolerance: float = 2e-12) -> bool:
    return abs(left - right) <= tolerance * max(1.0, abs(left), abs(right))


def selected_candidate(candidates: list[dict[str, str]], geom: tuple[float, float],
                       system: str, parameters: list[float], correction: float) -> dict[str, str]:
    matches: list[dict[str, str]] = []
    for row in candidates:
        if row["system"] != system or int(float(row["budget"])) != 2_000_000:
            continue
        row_geom = geometry(row)
        if not (close(row_geom[0], geom[0]) and close(row_geom[1], geom[1])):
            continue
        row_params = parse_parameters(row["parameters"]) if system == "XX" else [number(row["parameters"].strip("{}"))]
        if len(row_params) != len(parameters) or not all(close(x, y) for x, y in zip(row_params, parameters)):
            continue
        if not close(number(row["correctionRy"]), correction):
            continue
        matches.append(row)
    if not matches:
        raise LookupError(f"No retained {system} candidate for geometry {geom}")
    return matches[-1]


def integral_record(integrals: list[dict[str, str]], candidate: dict[str, str],
                    label: str, expected_value: float) -> dict[str, str]:
    matches = [row for row in integrals
               if row["candidateKey"] == candidate["candidateKey"]
               and row["integral"] == label
               and close(number(row["value"]), expected_value)]
    if not matches:
        raise LookupError(f"Missing {label} record for {candidate['candidateKey']}")
    return matches[-1]


def build_rows() -> tuple[list[dict[str, float]], dict[str, float]]:
    a5_summary = read_csv(NUM / "main-state-raw-pattern-search-a5-c1-summary.csv")
    remaining_summary = read_csv(NUM / "main-state-raw-pattern-search-remaining-summary.csv")
    production = {geometry(row): row for row in read_csv(NUM / "main-state-production-summary-Ry.csv")}
    mev_final = {geometry(row): row for row in read_csv(NUM / "main-state-final-summary-meV.csv")}

    a5_candidates = read_csv(NUM / "main-state-raw-pattern-search-a5-c1-candidates.csv")
    a5_integrals = read_csv(NUM / "main-state-raw-pattern-search-a5-c1-integrals.csv")
    remaining_candidates = read_csv(NUM / "main-state-raw-pattern-search-remaining-candidates.csv")
    remaining_integrals = read_csv(NUM / "main-state-raw-pattern-search-remaining-integrals.csv")
    for row in a5_candidates + a5_integrals:
        row["a"], row["c"] = "5", "1"

    summaries: dict[tuple[float, float], tuple[dict[str, str], str]] = {
        (5.0, 1.0): (a5_summary[0], "a5")
    }
    summaries.update({geometry(row): (row, "remaining") for row in remaining_summary})

    rows: list[dict[str, float]] = []
    for geom in GEOMETRY_ORDER:
        summary, source_group = summaries[geom]
        alpha_x = number(summary["XBestAlpha"])
        x_correction = number(first_key(summary, "XCorrectionRy", "XBestCorrectionRy"))
        xx_parameters = parse_parameters(summary["XXFinalParameters"])
        xx_correction = number(first_key(summary, "XXCorrectionRy", "XXFinalCorrectionRy"))

        candidates = a5_candidates if source_group == "a5" else remaining_candidates
        integrals = a5_integrals if source_group == "a5" else remaining_integrals
        x_candidate = selected_candidate(candidates, geom, "X", [alpha_x], x_correction)
        xx_candidate = selected_candidate(candidates, geom, "XX", xx_parameters, xx_correction)

        x_norm = number(x_candidate["norm"])
        x_numerator = number(x_candidate["numeratorRy"])
        xx_norm = number(xx_candidate["norm"])
        xx_numerator = number(xx_candidate["numeratorRy"])
        x_norm_record = integral_record(integrals, x_candidate, "normDenominator", x_norm)
        x_num_record = integral_record(integrals, x_candidate, "coulombNumerator", x_numerator)
        xx_norm_record = integral_record(integrals, xx_candidate, "normDenominator", xx_norm)
        xx_num_record = integral_record(integrals, xx_candidate, "hamiltonianNumerator", xx_numerator)
        x_norm_error = recovered_integral_error(x_norm_record)
        x_error = ratio_error(x_numerator, recovered_integral_error(x_num_record),
                              x_norm, x_norm_error)
        xx_error = ratio_error(xx_numerator, recovered_integral_error(xx_num_record),
                               xx_norm, recovered_integral_error(xx_norm_record))

        if source_group == "remaining":
            if not close(x_error, number(summary["XRoughErrorRy"]), 5e-8):
                raise AssertionError(f"X error mismatch at {geom}")
            if not close(xx_error, number(summary["XXRoughErrorRy"]), 5e-8):
                raise AssertionError(f"XX error mismatch at {geom}")

        e_x0 = number(production[geom]["E_X^0 (Ry)"])
        e_xx0 = number(production[geom]["E_XX^0 (Ry)"])
        e_x = e_x0 + x_correction
        e_xx = e_xx0 + xx_correction
        e_bind = 2.0 * x_correction - xx_correction
        e_bind_error = math.sqrt((2.0 * x_error) ** 2 + xx_error ** 2)
        # Preserve the already-finalized dimensionless optical block exactly.
        # Its central norm is independently checked against the retained X
        # candidate above; the meV columns are never used to build energy data.
        optical = mev_final[geom]
        if not close(x_norm, number(optical["N_X"]), 2e-12):
            raise AssertionError(f"Retained X norm and optical summary disagree at {geom}")
        n_x = number(optical["N_X"])
        n_x_error = number(optical["N_X error"])
        m_x = number(optical["M_X"])
        m_x_error = number(optical["M_X error"])
        m_x2 = number(optical["|M_X|^2"])
        m_x2_error = number(optical["|M_X|^2 error"])

        row = {
            "a/rB": geom[0], "c/rB": geom[1], "alpha_X": alpha_x,
            "alpha": xx_parameters[0], "beta": xx_parameters[1],
            "gamma": xx_parameters[2], "delta": xx_parameters[3],
            "E_X^0 (Ry)": e_x0, "Delta E_X (Ry)": x_correction,
            "Delta E_X error (Ry)": x_error, "E_X (Ry)": e_x,
            "E_X error (Ry)": x_error, "E_XX^0 (Ry)": e_xx0,
            "Delta E_XX (Ry)": xx_correction, "Delta E_XX error (Ry)": xx_error,
            "E_XX (Ry)": e_xx, "E_XX error (Ry)": xx_error,
            "E_bind = 2 E_X - E_XX (Ry)": e_bind,
            "E_bind error (Ry)": e_bind_error,
            "N_X": n_x, "N_X error": n_x_error,
            "M_X": m_x, "M_X error": m_x_error,
            "|M_X|^2": m_x2, "|M_X|^2 error": m_x2_error,
        }
        rows.append(row)

    identity_residuals: list[float] = []
    conversion_residuals: list[float] = []
    energy_map = [
        ("E_X (Ry)", "E_X (meV)"),
        ("E_X error (Ry)", "E_X error (meV)"),
        ("E_XX (Ry)", "E_XX (meV)"),
        ("E_XX error (Ry)", "E_XX error (meV)"),
        ("E_bind = 2 E_X - E_XX (Ry)", "E_bind = 2 E_X - E_XX (meV)"),
        ("E_bind error (Ry)", "E_bind error (meV)"),
    ]
    optical_identity_residuals: list[float] = []
    for row in rows:
        geom = (row["a/rB"], row["c/rB"])
        identity_residuals.extend([
            row["E_X (Ry)"] - row["E_X^0 (Ry)"] - row["Delta E_X (Ry)"],
            row["E_XX (Ry)"] - row["E_XX^0 (Ry)"] - row["Delta E_XX (Ry)"],
            row["E_XX^0 (Ry)"] - 2.0 * row["E_X^0 (Ry)"],
            row["E_bind = 2 E_X - E_XX (Ry)"]
            - (2.0 * row["Delta E_X (Ry)"] - row["Delta E_XX (Ry)"]),
            row["E_bind = 2 E_X - E_XX (Ry)"]
            - (2.0 * row["E_X (Ry)"] - row["E_XX (Ry)"]),
        ])
        for ry_key, mev_key in energy_map:
            conversion_residuals.append(row[ry_key] * RY_MEV - number(mev_final[geom][mev_key]))
        optical_identity_residuals.extend([
            row["M_X"] - 1.0 / math.sqrt(row["N_X"]),
            row["|M_X|^2"] - 1.0 / row["N_X"],
            row["M_X error"] - 0.5 * row["M_X"] * row["N_X error"] / row["N_X"],
            row["|M_X|^2 error"] - row["|M_X|^2"] * row["N_X error"] / row["N_X"],
        ])

    unique_geometries = {(row["a/rB"], row["c/rB"]) for row in rows}
    axial = sorted((row for row in rows if close(row["a/rB"], 5.0)), key=lambda row: row["c/rB"])
    lateral = sorted((row for row in rows if close(row["c/rB"], 1.0)), key=lambda row: row["a/rB"])
    assert len(rows) == len(unique_geometries) == 7
    assert [row["c/rB"] for row in axial] == [0.5, 1.0, 1.5, 2.0]
    assert [row["a/rB"] for row in lateral] == [3.0, 5.0, 7.0, 10.0]
    assert (5.0, 1.0) in {(row["a/rB"], row["c/rB"]) for row in axial}
    assert (5.0, 1.0) in {(row["a/rB"], row["c/rB"]) for row in lateral}
    checks = {
        "max_identity_residual_Ry": max(abs(value) for value in identity_residuals),
        "max_meV_crosscheck_residual": max(abs(value) for value in conversion_residuals),
        "max_optical_identity_residual": max(abs(value) for value in optical_identity_residuals),
    }
    return rows, checks


def write_csv(rows: list[dict[str, float]]) -> None:
    target = NUM / "main-state-final-summary-Ry.csv"
    PAPER_DATA.mkdir(parents=True, exist_ok=True)
    with target.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream, quoting=csv.QUOTE_NONNUMERIC, lineterminator="\n")
        writer.writerow(HEADERS)
        for row in rows:
            writer.writerow([row[key] for key in HEADERS])
    shutil.copyfile(target, PAPER_DATA / target.name)
    if target.read_bytes() != (PAPER_DATA / target.name).read_bytes():
        raise AssertionError("The two canonical Ry CSV copies differ")


# Vector chart renderer -----------------------------------------------------

BLUE = "#0072B2"
ORANGE = "#D55E00"
GREEN = "#009E73"
PURPLE = "#CC79A7"
SKY = "#56B4E9"
BLACK = "#111111"
GRID = "#D6D6D6"

LabelSpan: TypeAlias = tuple[str, str, float, float]
RichLabel: TypeAlias = list[LabelSpan]


def roman(text: str, scale: float = 1.0, rise: float = 0.0) -> LabelSpan:
    return text, "TimesNewRoman", scale, rise


def italic(text: str, scale: float = 1.0, rise: float = 0.0) -> LabelSpan:
    return text, "TimesNewRoman-Italic", scale, rise


def sub_roman(text: str) -> LabelSpan:
    return roman(text, 0.72, -0.20)


def sub_italic(text: str) -> LabelSpan:
    return italic(text, 0.72, -0.20)


def superscript(text: str) -> LabelSpan:
    return roman(text, 0.72, 0.45)


def rich_width(label: RichLabel, size: float) -> float:
    return sum(pdfmetrics.stringWidth(text, font, size * scale)
               for text, font, scale, _ in label)


def draw_rich_label(c: canvas.Canvas, label: RichLabel, x: float, y: float,
                    size: float, align: str = "left") -> None:
    width = rich_width(label, size)
    cursor = x - width / 2 if align == "center" else x - width if align == "right" else x
    c.setFillColor(BLACK)
    for text, font, scale, rise in label:
        span_size = size * scale
        c.setFont(font, span_size)
        c.drawString(cursor, y + size * rise, text)
        cursor += pdfmetrics.stringWidth(text, font, span_size)


def geometry_axis(variable: str) -> RichLabel:
    return [italic(variable), roman(" / "), roman("r"), sub_roman("B")]


def energy_label(subscript: str) -> RichLabel:
    return [italic("E"), sub_italic(subscript), roman(", Ry")]


def binding_label() -> RichLabel:
    return [italic("E"), sub_roman("bind"), roman(", Ry")]


def delta_energy_label(subscript: str, coefficient: str = "") -> RichLabel:
    spans: RichLabel = []
    if coefficient:
        spans.append(roman(coefficient + " "))
    spans.extend([roman("\u0394"), italic("E"), sub_italic(subscript)])
    return spans


def parameter_label(symbol: str, subscript: str = "") -> RichLabel:
    spans = [roman(symbol)]
    if subscript:
        spans.append(sub_italic(subscript))
    return spans


def overlap_label() -> RichLabel:
    return [roman("|"), italic("M"), sub_italic("X"), roman("|"), superscript("2")]


def lifetime_label(subscript: str) -> RichLabel:
    return [roman("\u03c4"), sub_italic(subscript)]


def register_fonts() -> None:
    fonts = Path("C:/Windows/Fonts")
    pdfmetrics.registerFont(TTFont("TimesNewRoman", str(fonts / "times.ttf")))
    pdfmetrics.registerFont(TTFont("TimesNewRoman-Italic", str(fonts / "timesi.ttf")))
    pdfmetrics.registerFont(TTFont("TimesNewRoman-Bold", str(fonts / "timesbd.ttf")))


def nice_ticks(low: float, high: float, count: int = 5) -> list[float]:
    span = high - low
    raw = span / max(count - 1, 1)
    power = 10.0 ** math.floor(math.log10(raw))
    scaled = raw / power
    step = (1.0 if scaled <= 1.0 else 2.0 if scaled <= 2.0 else 2.5 if scaled <= 2.5 else 5.0 if scaled <= 5.0 else 10.0) * power
    start = math.ceil(low / step - 1e-12) * step
    ticks = []
    value = start
    while value <= high + step * 1e-9:
        ticks.append(0.0 if abs(value) < step * 1e-10 else value)
        value += step
    return ticks


def tick_text(value: float) -> str:
    if abs(value) >= 10:
        return f"{value:.0f}"
    if abs(value) >= 1:
        return f"{value:.1f}".rstrip("0").rstrip(".")
    return f"{value:.2f}".rstrip("0").rstrip(".")


def marker(c: canvas.Canvas, shape: str, x: float, y: float, size: float, color: str) -> None:
    c.saveState()
    c.setFillColor(color)
    c.setStrokeColor(color)
    c.setLineWidth(0.7)
    if shape == "circle":
        c.circle(x, y, size, stroke=1, fill=1)
    elif shape == "square":
        c.rect(x - size, y - size, 2 * size, 2 * size, stroke=1, fill=1)
    elif shape == "diamond":
        path = c.beginPath(); path.moveTo(x, y + size * 1.25); path.lineTo(x + size, y); path.lineTo(x, y - size * 1.25); path.lineTo(x - size, y); path.close()
        c.drawPath(path, stroke=1, fill=1)
    elif shape == "triangle":
        path = c.beginPath(); path.moveTo(x, y + size * 1.25); path.lineTo(x + size * 1.1, y - size); path.lineTo(x - size * 1.1, y - size); path.close()
        c.drawPath(path, stroke=1, fill=1)
    else:
        path = c.beginPath(); path.moveTo(x, y - size * 1.25); path.lineTo(x + size * 1.1, y + size); path.lineTo(x - size * 1.1, y + size); path.close()
        c.drawPath(path, stroke=1, fill=1)
    c.restoreState()


def draw_panel(c: canvas.Canvas, box: tuple[float, float, float, float],
               x_values: list[float], series: list[dict],
               x_label: RichLabel, y_label: RichLabel,
               y_range: tuple[float, float], panel_label: str,
               x_ticks: list[float] | None = None, zero_line: bool = False,
               fill_between: tuple[int, int, str] | None = None) -> None:
    x0, y0, width, height = box
    xmin, xmax = min(x_values), max(x_values)
    xpad = 0.04 * (xmax - xmin)
    xmin, xmax = xmin - xpad, xmax + xpad
    ymin, ymax = y_range
    sx = lambda value: x0 + (value - xmin) / (xmax - xmin) * width
    sy = lambda value: y0 + (value - ymin) / (ymax - ymin) * height

    c.saveState()
    c.setStrokeColor(BLACK); c.setLineWidth(0.55)
    c.rect(x0, y0, width, height, stroke=1, fill=0)
    yticks = nice_ticks(ymin, ymax, 5)
    for value in yticks:
        y = sy(value)
        c.setStrokeColor(GRID); c.setLineWidth(0.25); c.line(x0, y, x0 + width, y)
        c.setStrokeColor(BLACK); c.setLineWidth(0.45)
        c.line(x0, y, x0 + 3.0, y); c.line(x0 + width - 3.0, y, x0 + width, y)
        c.setFont("TimesNewRoman", 7.6); c.drawRightString(x0 - 5.0, y - 2.5, tick_text(value))
    ticks = x_ticks if x_ticks is not None else x_values
    for value in ticks:
        x = sx(value)
        c.setStrokeColor(BLACK); c.setLineWidth(0.45)
        c.line(x, y0, x, y0 + 3.0); c.line(x, y0 + height - 3.0, x, y0 + height)
        c.setFont("TimesNewRoman", 7.6); c.drawCentredString(x, y0 - 12.0, tick_text(value))
    if zero_line and ymin < 0 < ymax:
        c.setDash(3, 2); c.setStrokeColor("#777777"); c.setLineWidth(0.55)
        c.line(x0, sy(0.0), x0 + width, sy(0.0)); c.setDash()

    if fill_between is not None:
        first, second, color = fill_between
        points_a = list(zip(x_values, series[first]["y"]))
        points_b = list(zip(reversed(x_values), reversed(series[second]["y"])))
        path = c.beginPath()
        path.moveTo(sx(points_a[0][0]), sy(points_a[0][1]))
        for xv, yv in points_a[1:] + points_b:
            path.lineTo(sx(xv), sy(yv))
        path.close()
        c.setFillColor(color)
        if hasattr(c, "setFillAlpha"):
            c.setFillAlpha(0.24)
        c.drawPath(path, stroke=0, fill=1)
        if hasattr(c, "setFillAlpha"):
            c.setFillAlpha(1.0)

    for spec in series:
        points = [(sx(xv), sy(yv)) for xv, yv in zip(x_values, spec["y"])]
        c.setStrokeColor(spec["color"]); c.setLineWidth(1.15); c.setDash()
        path = c.beginPath(); path.moveTo(*points[0])
        for point in points[1:]: path.lineTo(*point)
        c.drawPath(path, stroke=1, fill=0)
        errors = spec.get("error")
        if errors is not None:
            c.setLineWidth(0.65)
            for (px, _), value, error in zip(points, spec["y"], errors):
                low, high = sy(value - error), sy(value + error)
                c.line(px, low, px, high); c.line(px - 2.5, low, px + 2.5, low); c.line(px - 2.5, high, px + 2.5, high)
        for px, py in points:
            marker(c, spec["marker"], px, py, 2.25, spec["color"])

    c.setFillColor(BLACK)
    draw_rich_label(c, x_label, x0 + width / 2, y0 - 25.0, 8.6, "center")
    c.saveState(); c.translate(x0 - 36.0, y0 + height / 2); c.rotate(90)
    draw_rich_label(c, y_label, 0, 0, 8.6, "center"); c.restoreState()
    panel_spans = [italic(panel_label[:-1]), roman(panel_label[-1:])]
    draw_rich_label(c, panel_spans, x0 - 53.0, y0 + height + 8.0, 10.5)
    c.restoreState()


def draw_legend(c: canvas.Canvas, items: list[dict], y: float, width: float = 535.0) -> None:
    item_widths = [rich_width(item["label"], 8.3) + 42 for item in items]
    total = sum(item_widths)
    x = (width - total) / 2
    for item, item_width in zip(items, item_widths):
        c.setStrokeColor(item["color"]); c.setLineWidth(1.1); c.line(x, y, x + 19, y)
        marker(c, item["marker"], x + 9.5, y, 2.0, item["color"])
        draw_rich_label(c, item["label"], x + 25, y - 2.7, 8.3)
        x += item_width


def save_two_panel(path: Path, left: dict, right: dict, legend: list[dict] | None = None,
                   fill: bool = False) -> None:
    page = (535.0, 220.0 if legend else 199.0)
    c = canvas.Canvas(str(path), pagesize=page, pageCompression=1)
    c.setTitle(path.stem)
    bottom = 45.0 if legend else 35.0
    height = 145.0
    draw_panel(c, (55, bottom, 190, height), **left,
               fill_between=(0, 1, SKY) if fill else None)
    draw_panel(c, (315, bottom, 190, height), **right,
               fill_between=(0, 1, SKY) if fill else None)
    if legend:
        draw_legend(c, legend, 15.0)
    c.showPage(); c.save()


def generate_figures(rows: list[dict[str, float]]) -> list[Path]:
    axial = sorted((row for row in rows if close(row["a/rB"], 5.0)),
                   key=lambda row: row["c/rB"])
    lateral = sorted((row for row in rows if close(row["c/rB"], 1.0)),
                     key=lambda row: row["a/rB"])
    c_values = [row["c/rB"] for row in axial]
    a_values = [row["a/rB"] for row in lateral]

    energy_spec = lambda scan: [{
        "y": [r["E_XX (Ry)"] for r in scan],
        "error": [r["E_XX error (Ry)"] for r in scan],
        "color": BLUE, "marker": "circle",
    }]
    energy_path = FIG / "Main-E_XX-Ry.pdf"
    save_two_panel(
        energy_path,
        dict(x_values=c_values, series=energy_spec(axial),
             x_label=geometry_axis("c"), y_label=energy_label("XX"),
             y_range=(0.0, 95.0), panel_label="a)", x_ticks=c_values),
        dict(x_values=a_values, series=energy_spec(lateral),
             x_label=geometry_axis("a"), y_label=energy_label("XX"),
             y_range=(19.8, 22.1), panel_label="b)", x_ticks=a_values),
    )

    bind_spec = lambda scan: [{
        "y": [r["E_bind = 2 E_X - E_XX (Ry)"] for r in scan],
        "error": [r["E_bind error (Ry)"] for r in scan],
        "color": BLUE, "marker": "circle",
    }]
    binding_path = FIG / "Main-Binding-Energy-Ry.pdf"
    save_two_panel(
        binding_path,
        dict(x_values=c_values, series=bind_spec(axial),
             x_label=geometry_axis("c"), y_label=binding_label(),
             y_range=(-0.025, 0.305), panel_label="a)",
             x_ticks=c_values, zero_line=True),
        dict(x_values=a_values, series=bind_spec(lateral),
             x_label=geometry_axis("a"), y_label=binding_label(),
             y_range=(-0.025, 0.290), panel_label="b)",
             x_ticks=a_values, zero_line=True),
    )

    def correction_spec(scan: list[dict[str, float]]) -> list[dict]:
        return [
            {"y": [2 * r["Delta E_X (Ry)"] for r in scan],
             "error": [2 * r["Delta E_X error (Ry)"] for r in scan],
             "color": BLUE, "marker": "circle"},
            {"y": [r["Delta E_XX (Ry)"] for r in scan],
             "error": [r["Delta E_XX error (Ry)"] for r in scan],
             "color": ORANGE, "marker": "square"},
        ]

    correction_legend = [
        {"label": delta_energy_label("X", "2"),
         "color": BLUE, "marker": "circle"},
        {"label": delta_energy_label("XX"),
         "color": ORANGE, "marker": "square"},
    ]
    correction_path = FIG / "Main-Correlation-Corrections-Ry.pdf"
    save_two_panel(
        correction_path,
        dict(x_values=c_values, series=correction_spec(axial),
             x_label=geometry_axis("c"),
             y_label=[roman("correlation correction, Ry")],
             y_range=(-7.05, -3.05), panel_label="a)", x_ticks=c_values),
        dict(x_values=a_values, series=correction_spec(lateral),
             x_label=geometry_axis("a"),
             y_label=[roman("correlation correction, Ry")],
             y_range=(-5.85, -3.80), panel_label="b)", x_ticks=a_values),
        legend=correction_legend, fill=True,
    )

    overlap_spec = lambda scan: [{
        "y": [r["|M_X|^2"] for r in scan],
        "error": [r["|M_X|^2 error"] for r in scan],
        "color": BLUE, "marker": "circle",
    }]
    overlap_path = FIG / "Main-Overlap.pdf"
    save_two_panel(
        overlap_path,
        dict(x_values=c_values, series=overlap_spec(axial),
             x_label=geometry_axis("c"), y_label=overlap_label(),
             y_range=(3.8, 9.0), panel_label="a)", x_ticks=c_values),
        dict(x_values=a_values, series=overlap_spec(lateral),
             x_label=geometry_axis("a"), y_label=overlap_label(),
             y_range=(4.0, 11.7), panel_label="b)", x_ticks=a_values),
    )

    parameter_path = FIG / "Main-Variational-Parameters.pdf"
    c = canvas.Canvas(str(parameter_path), pagesize=(535.0, 390.0),
                      pageCompression=1)
    c.setTitle(parameter_path.stem)
    alpha_styles = [
        ("alpha_X", BLUE, "circle", parameter_label("\u03b1", "X")),
        ("alpha", ORANGE, "square", parameter_label("\u03b1")),
        ("beta", GREEN, "diamond", parameter_label("\u03b2")),
    ]
    gd_styles = [
        ("gamma", PURPLE, "triangle", parameter_label("\u03b3")),
        ("delta", SKY, "down", parameter_label("\u03b4")),
    ]

    def param_spec(scan: list[dict[str, float]], styles: list[tuple]) -> list[dict]:
        return [{"y": [r[key] for r in scan], "color": color,
                 "marker": shape} for key, color, shape, _ in styles]

    draw_panel(c, (55, 235, 190, 120), c_values,
               param_spec(axial, alpha_styles), geometry_axis("c"),
               [roman("variational parameter")], (0.0, 0.85), "a)", c_values)
    draw_panel(c, (315, 235, 190, 120), a_values,
               param_spec(lateral, alpha_styles), geometry_axis("a"),
               [roman("variational parameter")], (0.0, 0.85), "b)", a_values)
    draw_legend(c, [{"label": label, "color": color, "marker": shape}
                    for _, color, shape, label in alpha_styles], 205.0)
    draw_panel(c, (55, 58, 190, 120), c_values,
               param_spec(axial, gd_styles), geometry_axis("c"),
               [roman("variational parameter")], (1.70, 3.20), "c)", c_values)
    draw_panel(c, (315, 58, 190, 120), a_values,
               param_spec(lateral, gd_styles), geometry_axis("a"),
               [roman("variational parameter")], (1.70, 3.20), "d)", a_values)
    draw_legend(c, [{"label": label, "color": color, "marker": shape}
                    for _, color, shape, label in gd_styles], 18.0)
    c.showPage()
    c.save()

    vacuum_permittivity = 8.8541878128e-12
    elementary_charge = 1.602176634e-19
    reduced_planck = 1.054571817e-34
    speed_of_light = 2.99792458e8
    free_electron_mass = 9.1093837015e-31
    gaas_gap_ev = 1.5192
    gaas_electron_mass = 0.067 * free_electron_mass
    gaas_kane_energy_ev = 22.71
    gaas_relative_permittivity = 12.8

    def optical_row(row: dict[str, float]) -> dict[str, float]:
        excitation_ev = gaas_gap_ev + (RY_MEV / 1000.0) * row["E_X (Ry)"]
        oscillator = gaas_kane_energy_ev / excitation_ev * row["|M_X|^2"]
        tau_x = 1.0e12 * (
            2.0 * math.pi * vacuum_permittivity * gaas_electron_mass
            * speed_of_light ** 3 * reduced_planck ** 2
        ) / (
            math.sqrt(gaas_relative_permittivity) * elementary_charge ** 2
            * (excitation_ev * elementary_charge) ** 2 * oscillator
        )
        relative_error = math.hypot(
            ((RY_MEV / 1000.0) * row["E_X error (Ry)"]) / excitation_ev,
            row["|M_X|^2 error"] / row["|M_X|^2"],
        )
        return {"tau_X": tau_x, "tau_XX": tau_x / 4.0,
                "tau_X_error": tau_x * relative_error,
                "tau_XX_error": tau_x * relative_error / 4.0}

    axial_optical = [optical_row(row) for row in axial]
    lateral_optical = [optical_row(row) for row in lateral]

    def lifetime_spec(scan: list[dict[str, float]]) -> list[dict]:
        return [
            {"y": [r["tau_X"] for r in scan],
             "error": [r["tau_X_error"] for r in scan],
             "color": BLUE, "marker": "circle"},
            {"y": [r["tau_XX"] for r in scan],
             "error": [r["tau_XX_error"] for r in scan],
             "color": ORANGE, "marker": "square"},
        ]

    lifetime_path = FIG / "Main-Lifetimes.pdf"
    lifetime_legend = [
        {"label": lifetime_label("X"), "color": BLUE, "marker": "circle"},
        {"label": lifetime_label("XX"), "color": ORANGE, "marker": "square"},
    ]
    save_two_panel(
        lifetime_path,
        dict(x_values=c_values, series=lifetime_spec(axial_optical),
             x_label=geometry_axis("c"),
             y_label=[roman("radiative lifetime, ps")],
             y_range=(0.0, 2.75), panel_label="a)", x_ticks=c_values),
        dict(x_values=a_values, series=lifetime_spec(lateral_optical),
             x_label=geometry_axis("a"),
             y_label=[roman("radiative lifetime, ps")],
             y_range=(0.0, 2.95), panel_label="b)", x_ticks=a_values),
        legend=lifetime_legend,
    )

    outputs = [energy_path, binding_path, correction_path, overlap_path,
               parameter_path, lifetime_path]
    PAPER_FIG.mkdir(parents=True, exist_ok=True)
    for path in outputs:
        shutil.copyfile(path, PAPER_FIG / path.name)
        if path.read_bytes() != (PAPER_FIG / path.name).read_bytes():
            raise AssertionError(f"Figure copy differs: {path.name}")
    return outputs


def main() -> None:
    register_fonts()
    rows, checks = build_rows()
    write_csv(rows)
    outputs = generate_figures(rows)
    print(f"rows={len(rows)} unique_geometries={len({(r['a/rB'], r['c/rB']) for r in rows})}")
    print(f"max_identity_residual_Ry={checks['max_identity_residual_Ry']:.3e}")
    print(f"max_meV_crosscheck_residual={checks['max_meV_crosscheck_residual']:.3e}")
    print(f"max_optical_identity_residual={checks['max_optical_identity_residual']:.3e}")
    print("outputs:")
    for path in outputs:
        print(path)


if __name__ == "__main__":
    main()
