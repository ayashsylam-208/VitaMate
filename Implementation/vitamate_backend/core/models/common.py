import re
import unicodedata


def normalize_food_search_text(value):
    if value is None:
        return ""
    text = unicodedata.normalize("NFKC", str(value)).casefold()
    text = "".join(ch for ch in text if unicodedata.category(ch) != "Mn")
    text = re.sub(r"[^\w\s]+", " ", text, flags=re.UNICODE)
    return re.sub(r"\s+", " ", text).strip()
