import asyncio
from scraping_engines.beautifulsoup.engine import BS4Engine
from scraping_engines.playwright.engine import PlaywrightEngine
from .models import ScrapingResult

def scrape_website(url, engine_type='bs4', selector='body'):
    if engine_type == 'bs4':
        engine = BS4Engine(url)
        if engine.fetch():
            data = engine.extract_elements(selector)
            title = engine.get_title()
            result = ScrapingResult.objects.create(
                url=url,
                title=title,
                content=" ".join(data),
                engine='bs4'
            )
            return result
    elif engine_type == 'playwright':
        engine = PlaywrightEngine(url)
        # Playwright is async, so we'd need to handle it properly in a production Django setup (e.g. via Celery)
        # For now, we provide a basic synchronous wrapper for demonstration if needed, 
        # but the core logic is in the PlaywrightEngine class.
        pass
    return None
