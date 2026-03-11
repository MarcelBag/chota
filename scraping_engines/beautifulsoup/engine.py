import requests
from bs4 import BeautifulSoup
from scraping_engines.parsers.utils import clean_text

class BS4Engine:
    def __init__(self, url, headers=None):
        self.url = url
        self.headers = headers or {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        self.soup = None

    def fetch(self):
        try:
            response = requests.get(self.url, headers=self.headers, timeout=30)
            response.raise_for_status()
            self.soup = BeautifulSoup(response.text, 'html.parser')
            return True
        except Exception as e:
            print(f"Error fetching {self.url}: {e}")
            return False

    def extract_elements(self, selector, attribute=None):
        if not self.soup:
            return []
        
        elements = self.soup.select(selector)
        results = []
        for el in elements:
            if attribute:
                val = el.get(attribute)
            else:
                val = el.get_text()
            
            results.append(clean_text(val) if val else "")
        return results

    def get_title(self):
        if self.soup and self.soup.title:
            return self.soup.title.string
        return ""
