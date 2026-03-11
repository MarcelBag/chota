from django.db import models

class ScrapingResult(models.Model):
    url = models.URLField()
    title = models.CharField(max_length=500, blank=True, null=True)
    content = models.TextField(blank=True, null=True)
    engine = models.CharField(max_length=50, choices=[('bs4', 'BeautifulSoup'), ('playwright', 'Playwright')])
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.url} ({self.engine})"
