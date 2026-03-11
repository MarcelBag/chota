import asyncio
from playwright.async_api import async_playwright
from scraping_engines.parsers.utils import clean_text

class PlaywrightEngine:
    def __init__(self, url, wait_until='networkidle'):
        self.url = url
        self.wait_until = wait_until
        self.content = None

    async def fetch(self):
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()
            try:
                await page.goto(self.url, wait_until=self.wait_until)
                self.content = await page.content()
                await browser.close()
                return True
            except Exception as e:
                print(f"Error fetching {self.url} with Playwright: {e}")
                await browser.close()
                return False

    async def extract_elements(self, selector, attribute=None):
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()
            try:
                await page.goto(self.url, wait_until=self.wait_until)
                elements = await page.query_selector_all(selector)
                results = []
                for el in elements:
                    if attribute:
                        val = await el.get_attribute(attribute)
                    else:
                        val = await el.inner_text()
                    
                    results.append(clean_text(val) if val else "")
                
                await browser.close()
                return results
            except Exception as e:
                print(f"Error extracting with Playwright: {e}")
                await browser.close()
                return []
