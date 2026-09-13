#!/usr/bin/env python3
"""
Konwerter KML -> map_data.json dla gry "Heksagonalna Strategia Ekonomiczna".

Zasada odczytu ID heksa: nazwa Placemarka zaczyna się od identyfikatora
w formacie <LITERA(Y)><NUMER>, np. "A1", "D12", "H14", po którym opcjonalnie
występuje "/" lub "//" i opis (np. "A1 / Gazoport w Świnoujściu").

Konwersja ID -> współrzędne osiowe (axial):
    q = indeks litery kolumny (A=0, B=1, C=2, ...)
    r = numer wiersza - 1 (zero-indeksowany)

To bezpośrednio odzwierciedla siatkę, którą autor już ręcznie ustalił,
rozmieszczając pinezki w Google Earth (kolejne litery -> wschód,
kolejne numery -> południe).

Użycie:
    python3 convert_kml_to_json.py wejscie.kml wyjscie.json
"""

import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

NS = {
    "kml": "http://www.opengis.net/kml/2.2",
}

# Kolejność dopasowania ma znaczenie - pierwsze trafienie wygrywa.
TERRAIN_KEYWORDS = [
    ("protected_area", ["park narodowy", "park krajobrazowy", "park mużakowski",
                          "rezerwat"]),
    ("forest", ["las"]),
    ("city", ["miasto baza"]),
    ("agricultural", ["obszar rolniczy", "rolnicz"]),
]

RESOURCE_KEYWORDS = [
    ("gas", ["gazoport"]),
    ("copper", ["miedz", "miedź", "miedzi"]),
    ("coal", ["węgl", "wegl"]),
    ("uranium", ["uran"]),
    ("nickel", ["nikl"]),
    ("food", ["obszar rolniczy", "rolnicz"]),
]

ID_PATTERN = re.compile(r"^\s*([A-Za-z]+)\s*(\d+)")


def classify_terrain(label: str) -> str:
    lower = label.lower()
    for terrain, keywords in TERRAIN_KEYWORDS:
        for kw in keywords:
            if kw in lower:
                return terrain
    return "agricultural"  # domyślny typ, zgodnie z GDD (najliczniejszy w danych)


def classify_resource(label: str) -> str:
    lower = label.lower()
    for resource, keywords in RESOURCE_KEYWORDS:
        for kw in keywords:
            if kw in lower:
                return resource
    return "none"


def hex_id_to_axial(hex_id: str):
    match = ID_PATTERN.match(hex_id)
    if not match:
        return None
    letters, number = match.groups()
    letters = letters.upper()
    # Obsługa jednej litery (A-Z). Wielolitery (AA, AB...) na przyszłość,
    # gdyby siatka wykroczyła poza 26 kolumn.
    q = 0
    for ch in letters:
        q = q * 26 + (ord(ch) - ord("A") + 1)
    q -= 1
    r = int(number) - 1
    return q, r


def parse_kml(path: str):
    tree = ET.parse(path)
    root = tree.getroot()

    hexes = []
    duplicates = defaultdict(list)
    skipped = []

    for placemark in root.iter("{http://www.opengis.net/kml/2.2}Placemark"):
        name_el = placemark.find("kml:name", NS)
        coord_el = placemark.find(".//kml:coordinates", NS)

        if name_el is None or name_el.text is None:
            skipped.append({"reason": "brak nazwy", "raw": ET.tostring(placemark, encoding="unicode")[:120]})
            continue
        if coord_el is None or coord_el.text is None:
            skipped.append({"reason": "brak współrzędnych", "name": name_el.text})
            continue

        raw_name = name_el.text.strip()
        match = ID_PATTERN.match(raw_name)
        if not match:
            skipped.append({"reason": "nazwa bez identyfikatora hexa", "name": raw_name})
            continue

        hex_id = (match.group(1).upper() + match.group(2))
        axial = hex_id_to_axial(hex_id)
        if axial is None:
            skipped.append({"reason": "nie udało się przeliczyć ID na q/r", "name": raw_name})
            continue
        q, r = axial

        # Etykieta opisowa to część nazwy po ID (po "/" lub "//")
        label = raw_name[match.end():].lstrip("/ ").strip()

        lon_str, lat_str, *_ = coord_el.text.strip().split(",")
        lon, lat = float(lon_str), float(lat_str)

        terrain = classify_terrain(label if label else raw_name)
        resource = classify_resource(label if label else raw_name)

        hex_entry = {
            "id": hex_id,
            "q": q,
            "r": r,
            "lat": lat,
            "lon": lon,
            "terrain": terrain,
            "resource": resource,
            "resource_level": 100.0,
            "label_raw": label,
        }

        duplicates[hex_id].append(hex_entry)
        hexes.append(hex_entry)

    conflict_report = {hid: entries for hid, entries in duplicates.items() if len(entries) > 1}

    return hexes, conflict_report, skipped


def main():
    if len(sys.argv) != 3:
        print("Użycie: python3 convert_kml_to_json.py wejscie.kml wyjscie.json")
        sys.exit(1)

    in_path, out_path = sys.argv[1], sys.argv[2]
    hexes, conflicts, skipped = parse_kml(in_path)

    # Przy konflikcie ID (dwa Placemarki z tym samym identyfikatorem) --
    # zachowujemy WSZYSTKIE, ale nadajemy sufiks, żeby dane się nie nadpisały,
    # i głośno o tym informujemy. To błąd źródłowego KML do poprawienia ręcznie.
    id_counts = defaultdict(int)
    final_hexes = []
    for h in hexes:
        id_counts[h["id"]] += 1
        if id_counts[h["id"]] > 1:
            h["id"] = f'{h["id"]}_conflict{id_counts[h["id"]]}'
        final_hexes.append(h)

    output = {"hexes": final_hexes}

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"Zapisano {len(final_hexes)} heksów do {out_path}")

    if conflicts:
        print("\n⚠️  KONFLIKTY ID (ten sam identyfikator hexa użyty >1 raz w KML):")
        for hid, entries in conflicts.items():
            print(f"  - {hid}: {len(entries)} wystąpień")
            for e in entries:
                print(f"      • {e['label_raw']!r} @ ({e['lat']:.4f}, {e['lon']:.4f})")
        print("  -> Zapisane pod sufiksami _conflict2, _conflict3 itd. "
              "Popraw oryginalne ID w Google Earth, żeby każdy heks miał unikalny identyfikator.")

    if skipped:
        print(f"\nPominięto {len(skipped)} elementów (bez ID/współrzędnych):")
        for s in skipped:
            print(f"  - {s}")


if __name__ == "__main__":
    main()
