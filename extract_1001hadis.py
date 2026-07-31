import json
import re
from pathlib import Path

from pypdf import PdfReader


PDF_PATH = Path(r"C:\Users\Muhammet fatih\Downloads\1001hadis.pdf")
OUT_PATH = Path(r"C:\murakabe\1001hadis.json")


HEADER_FOOTER_PATTERNS = [
    re.compile(r"^\s*Fihrist’e dön\s*$", re.IGNORECASE),
    re.compile(r"^\s*KÜTÜB-İ SİTTE[’']DEN 1001 HADIS\s*$", re.IGNORECASE),
    re.compile(r"^\s*KÜTÜB-İ SİTTE[’']DEN 1001 HADİS\s*$", re.IGNORECASE),
]

SOURCE_KEYWORDS = [
    "buhari",
    "buharı",
    "buhârî",
    "müslim",
    "ebu davud",
    "ebû davud",
    "ebû dâvûd",
    "tirmizi",
    "tirmizî",
    "nesai",
    "nesâi",
    "ibn-i mace",
    "ibn mace",
    "ibn-i mâce",
    "mace",
    "mâlik",
    "ahmed",
]


def is_section_heading(line: str) -> bool:
    s = line.strip()
    if len(s) < 4:
        return False
    if any(ch.isdigit() for ch in s):
        return False
    letters = [ch for ch in s if ch.isalpha()]
    if not letters:
        return False
    # Turkish headings in the PDF are all caps; remove them when they drift
    # into the preceding hadis block during text extraction.
    return all(ch.upper() == ch for ch in letters)


def clean_lines(block: str) -> str:
    lines = []
    for raw in block.splitlines():
        line = raw.strip()
        if not line:
            continue
        if any(pat.match(line) for pat in HEADER_FOOTER_PATTERNS):
            continue
        if re.fullmatch(r"\d{1,3}", line):
            continue
        if is_section_heading(line):
            continue
        lines.append(line)

    text = " ".join(lines)
    for header in (
        "KÜTÜBİSİTTE'DEN 1001 HADİS",
        "KÜTÜBİSİTTE’DEN 1001 HADİS",
        "KÜTÜB-İSİTTE'DEN 1001 HADİS",
        "KÜTÜB-İSİTTE’DEN 1001 HADİS",
    ):
        text = text.replace(header, " ")
    text = re.sub(r"Fihrist’e dön", " ", text, flags=re.IGNORECASE)
    text = re.sub(r"KÜTÜB-İ\s*SİTTE[’']DEN 1001 HAD[İI]S", " ", text, flags=re.IGNORECASE)
    text = re.sub(r"KÜTÜBİSİTTE[’']DEN 1001 HAD[İI]S", " ", text, flags=re.IGNORECASE)
    text = re.sub(r"K[^\s]{3,50}\s+1001\s+HAD[^\s]{0,10}", " ", text)
    text = re.sub(r"(\w)-\s+(\w)", r"\1\2", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def normalize_source(source: str) -> str:
    s = source.strip()
    s = re.sub(r"\brivayet (etmişlerdir|etmiştir|etmiş)\b", "", s, flags=re.IGNORECASE)
    s = re.sub(r"\bhadis (hasendir|sahihtir)\b", "", s, flags=re.IGNORECASE)
    replacements = {
        "Buhari": "Buhârî",
        "Buharı": "Buhârî",
        "Buhârı": "Buhârî",
        "Ebu Davud": "Ebû Dâvûd",
        "Ebû Davud": "Ebû Dâvûd",
        "Tirmizi": "Tirmizî",
        "Nesai": "Nesâî",
        "Nesâi": "Nesâî",
        "İbn-i Mace": "İbn-i Mâce",
        "Ibn-i Mace": "İbn-i Mâce",
    }
    for old, new in replacements.items():
        s = re.sub(old, new, s, flags=re.IGNORECASE)
    s = re.sub(r"\s+ve\s+", ", ", s, flags=re.IGNORECASE)
    s = re.sub(r"\s*;\s*", ", ", s)
    s = re.sub(r"\s*,\s*", ", ", s)
    s = re.sub(r"\s+", " ", s).strip(" .,-")
    return s


def split_source(text: str) -> tuple[str, str]:
    # Prefer a final parenthetical citation, the dominant pattern in the PDF.
    matches = list(re.finditer(r"\(([^()]*)\)\s*$", text))
    if matches:
        m = matches[-1]
        candidate = m.group(1).strip()
        if any(k in candidate.lower() for k in SOURCE_KEYWORDS):
            return text[: m.start()].strip(), normalize_source(candidate)

    # First hadis has a prose citation rather than a simple parenthesis.
    lower = text.lower()
    if "sahihayn" in lower and "buhari" in lower and "müslim" in lower:
        return text, "Buhârî, Müslim"

    return text, ""


def final_clean(text: str) -> str:
    text = re.sub(r"K[^\s]{3,50}\s+1001\s+HAD[^\s]{0,10}", " ", text)
    text = fix_split_letters(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def strip_narrator_intro(text: str) -> str:
    # Drop the biographical/narrator lead-in: "... rivayet edilmiştir:".
    text = re.sub(
        r"^.*?\brivayet\s*(?:edilmi\s*ştir|olunmuştur)\s*[:;.]?\s*",
        "",
        text,
        count=1,
        flags=re.IGNORECASE,
    )

    # After that lead-in, many entries still have a short formula before the
    # actual quoted hadis. Remove it when a quote immediately follows.
    text = re.sub(
        r"^(?:Resûlüllah|Resûlüllâh|Resûlullah|Allah Resulü|Allah Resûlü|Peygamber(?:imiz)?(?:\s*\([^)]*\))?)"
        r"[^\"“”]*?(?:şöyle\s+(?:buyurdu|buyurmuştur|buyurmuş|söyledi)|söylerken\s+duydum)\s*[:;]?\s*",
        "",
        text,
        count=1,
        flags=re.IGNORECASE,
    )

    # If a remaining companion/context sentence precedes the quoted hadis,
    # keep the hadis text itself.
    text = text.replace("''", '"')
    quote_positions = [pos for pos in (text.find('"'), text.find("“")) if pos != -1]
    if quote_positions:
        first_quote = min(quote_positions)
        lead = text[:first_quote]
        if "(r.a)" in lead or "şöyle" in lead.lower() or "Resûl" in lead or "Resul" in lead:
            text = text[first_quote:]

    text = re.sub(r"\s*Hadisin sıhhatinde.*$", "", text, flags=re.IGNORECASE)
    return strip_outer_quotes(text.strip())


def strip_outer_quotes(text: str) -> str:
    text = text.replace("''", '"')
    pairs = [('"', '"'), ("“", "”"), ("'", "'")]
    for left, right in pairs:
        if text.startswith(left) and text.endswith(right):
            return text[1:-1].strip()
    return text


def fix_split_letters(text: str) -> str:
    letters = "A-Za-zÇĞİÖŞÜçğıöşüÂÎÛâîû"
    tr_letters = "ÇĞİÖŞÜçğıöşüÂÎÛâîû"

    # Common non-Turkish-letter splits that appear throughout this PDF.
    suffixes = (
        "dir|dır|dur|dür|tir|tır|tur|tür|"
        "di|dı|du|dü|ti|tı|tu|tü|"
        "lar|ler|ları|leri|lardan|lerden|"
        "nlar|nler|"
        "nın|nin|nun|nün|na|ne|ni|nı|nu|nü|"
        "ın|in|un|ün|"
        "ı|i|u|ü|n|"
        "dan|den|tan|ten|"
        "erin|arın|"
        "mış|miş|muş|müş|"
        "mak|mek|acak|ecek|yor|"
        "ği|ğı|eti|"
        "ğinde|ğında|klerinde|klarında|kların|klerin"
    )

    stopwords = {
        "da",
        "de",
        "ve",
        "veya",
        "ile",
        "bir",
        "her",
        "o",
        "bu",
        "şu",
        "ne",
        "nasıl",
        "sonra",
        "önce",
        "göre",
        "gibi",
        "için",
        "olan",
        "olup",
        "arasında",
        "yanında",
        "hakkında",
        "sonunda",
        "başında",
        "yola",
    }

    def join_before_turkish(match: re.Match) -> str:
        prev, nxt = match.group(1), match.group(2)
        nxt_lower = nxt.lower()
        if prev.lower() in stopwords or nxt_lower.startswith(("şey", "şöyle")):
            return f"{prev} {nxt}"
        if len(nxt) <= 2 and not re.fullmatch(r"[ıiuü]r|[ıiuü]n|[ıiuü]m|[ıiuü]z|[ıiuü]l|ğ[ıiuü]", nxt, re.IGNORECASE):
            return f"{prev} {nxt}"
        return prev + nxt

    # PDF extraction often inserts a space just before Turkish letters:
    # "ki şiye", "vard ır", "Resul üne".
    text = re.sub(fr"\b([{letters}]+)\s+([{tr_letters}][{letters}]*)\b", join_before_turkish, text)
    text = re.sub(fr"(?<=[{letters}])\s+(?=(?:{suffixes})\b)", "", text, flags=re.IGNORECASE)

    # Small root splits seen repeatedly in the PDF.
    text = re.sub(r"\bçı\s+kar", "çıkar", text, flags=re.IGNORECASE)
    text = re.sub(r"\b(malı|malı)\s*veya\b", r"\1 veya", text, flags=re.IGNORECASE)
    replacements = {
        "kastıylayolaçıkarlar": "kastıyla yola çıkarlar",
        "kastıylayola çıkarlar": "kastıyla yola çıkarlar",
        "çar şı": "çarşı",
        "sava şa": "savaşa",
        "edememi şöyle": "edememiş öyle",
        "edememişöyle": "edememiş öyle",
        "rivayetteşöyle": "rivayette şöyle",
        "daşöyle": "da şöyle",
        "malıveya": "malı veya",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)

    # Tidy spaces around hyphenated parenthetical clarifications.
    text = re.sub(r"\s*-\s*", " -", text)
    return text


def main() -> None:
    reader = PdfReader(str(PDF_PATH))
    # Hadis text starts on printed page 5; after page 435 the PDF is index.
    full_text = "\n".join((page.extract_text() or "") for page in reader.pages[4:435])
    matches = list(re.finditer(r"(?m)^\s*(\d{1,4})\s*-", full_text))

    records = []
    for idx, match in enumerate(matches):
        start = match.end()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(full_text)
        raw = full_text[start:end]
        if idx == len(matches) - 1:
            index_start = raw.find("\nİHLAS VE SAMİMİ NİYET")
            if index_start != -1:
                raw = raw[:index_start]
        text = clean_lines(raw)
        text = final_clean(text)
        text, source = split_source(text)
        text = strip_narrator_intro(text)
        text = final_clean(text)
        records.append(
            {
                "id": idx + 1,
                "arabic": "",
                "text": text,
                "source": source,
            }
        )

    OUT_PATH.write_text(json.dumps(records, ensure_ascii=False, indent=4), encoding="utf-8")
    print(f"wrote {len(records)} records to {OUT_PATH}")
    print(f"arabic characters in source PDF text: {len(re.findall(r'[\u0600-\u06FF]', full_text))}")


if __name__ == "__main__":
    main()
