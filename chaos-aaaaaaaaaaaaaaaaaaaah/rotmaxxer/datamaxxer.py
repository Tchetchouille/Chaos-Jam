import requests
from bs4 import BeautifulSoup
import re
import time
import random
from urllib.parse import quote

HEADERS = {
    "User-Agent": "Mozilla/5.0"
}

# ------------------------
# FETCH
# ------------------------
def fetch(url):
    try:
        r = requests.get(url, headers=HEADERS, timeout=10)
        r.raise_for_status()
        return r.text
    except:
        return ""


# ------------------------
# WORD EXTRACTION
# ------------------------
def extract_words(html):
    soup = BeautifulSoup(html, "html.parser")
    text = soup.get_text(" ")

    # extract raw words
    words = re.findall(r"\b[a-zA-Z]{4,20}\b", text)

    return words


# ------------------------
# BRAINROT FILTER
# ------------------------
def is_brainrot_word(w):
    w = w.lower()

    # reject obvious junk
    blacklist = {
        "wiki","admin","active","edit","login","search",
        "home","page","with","from","this","that","have",
        "your","about","there","they","them"
    }
    if w in blacklist:
        return False

    # must contain many vowels (brainrot vibe)
    if sum(c in "aeiou" for c in w) < 2:
        return False

    # must end in italian-ish or brainrot-ish suffix
    if not re.search(r"(ino|ini|ello|etta|etto|azzo|uzzo|uccio|alero|ala|ero|oro|ito)$", w):
        return False

    # avoid super short/common
    if len(w) < 5:
        return False

    return True


# ------------------------
# SCRAPE SITE
# ------------------------
def scrape_site(url):
    html = fetch(url)
    words = extract_words(html)

    results = set()

    for w in words:
        if is_brainrot_word(w):
            results.add(w.capitalize())

    return results


# ------------------------
# YOUTUBE TITLES
# ------------------------
def scrape_youtube(query, pages=3):
    results = set()

    for i in range(pages):
        url = f"https://www.youtube.com/results?search_query={quote(query)}&page={i+1}"
        html = fetch(url)

        titles = re.findall(r'"title":{"runs":\[{"text":"([^"]+)"', html)

        for t in titles:
            words = re.findall(r"\b[a-zA-Z]{4,20}\b", t)
            for w in words:
                if is_brainrot_word(w):
                    results.add(w.capitalize())

        time.sleep(1)

    return results


# ------------------------
# SYNTHETIC GENERATION (single word)
# ------------------------
def generate_synthetic(words, n=10000):
    syllables = set()

    # break into chunks
    for w in words:
        parts = re.findall(r"[bcdfghjklmnpqrstvwxyz]*[aeiou]+", w.lower())
        syllables.update(parts)

    synthetic = set()

    suffixes = ["ino","ini","ello","etta","etto","azzo","uzzo","uccio","ero"]

    for _ in range(n):
        length = random.randint(2, 4)
        w = "".join(random.choice(list(syllables)) for _ in range(length))

        w += random.choice(suffixes)

        if is_brainrot_word(w):
            synthetic.add(w.capitalize())

    return synthetic


# ------------------------
# MAIN
# ------------------------
def main():
    all_words = set()

    sites = [
        "https://www.playbrainrot.org/en/characters/",
        "https://steal-a-brainrot.org/brainrots",
        "https://steal-brainrot.co/characters/",
    ]

    for s in sites:
        print(f"Scraping {s}")
        all_words |= scrape_site(s)
        time.sleep(1)

    # YouTube (big boost)
    queries = ["brainrot", "italian brainrot", "tralalero"]
    for q in queries:
        print(f"YouTube: {q}")
        all_words |= scrape_youtube(q, pages=3)

    print(f"[+] Real words: {len(all_words)}")

    # synthetic
    synthetic = generate_synthetic(all_words, n=15000)

    print(f"[+] Synthetic: {len(synthetic)}")

    final = all_words | synthetic

    print(f"[+] TOTAL: {len(final)}")

    with open("brainrot_words.txt", "w") as f:
        for w in sorted(final):
            f.write(w + "\n")

    print("Saved to brainrot_words.txt")


if __name__ == "__main__":
    main()