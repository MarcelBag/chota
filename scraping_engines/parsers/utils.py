import re

def clean_text(text):
    if not text:
        return ""
    # Remove extra whitespaces
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def extract_domain(url):
    from urllib.parse import urlparse
    parsed_uri = urlparse(url)
    return '{uri.scheme}://{uri.netloc}/'.format(uri=parsed_uri)
