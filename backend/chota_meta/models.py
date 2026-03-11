from django.db import models

class SingletonModel(models.Model):
    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        self.pk = 1
        super(SingletonModel, self).save(*args, **kwargs)

    @classmethod
    def load(cls):
        obj, created = cls.objects.get_or_create(pk=1)
        return obj

class PlatformSettings(SingletonModel):
    platform_name = models.CharField(max_length=255, default='Chota')
    platform_logo = models.ImageField(upload_to='meta/logos/', blank=True, null=True)
    support_email = models.EmailField(default='support@tuunganes.com')
    default_language = models.CharField(max_length=10, default='en', choices=[('en', 'English'), ('fr', 'French'), ('sw', 'Swahili')])
    maintenance_mode = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.platform_name} Settings"

class ScrapingLimits(SingletonModel):
    max_requests_per_minute = models.PositiveIntegerField(default=60)
    max_pages_per_job = models.PositiveIntegerField(default=100)
    max_concurrent_jobs = models.PositiveIntegerField(default=5)
    default_delay_seconds = models.PositiveIntegerField(default=1)

    def __str__(self):
        return "Scraping Limits"

class ProxyConfig(models.Model):
    proxy_host = models.CharField(max_length=255)
    proxy_port = models.PositiveIntegerField()
    username = models.CharField(max_length=255, blank=True, null=True)
    password = models.CharField(max_length=255, blank=True, null=True)
    enabled = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.proxy_host}:{self.proxy_port}"

class FeatureFlag(models.Model):
    name = models.CharField(max_length=100, unique=True)
    enabled = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.name} ({'Enabled' if self.enabled else 'Disabled'})"

class UserPlan(models.Model):
    name = models.CharField(max_length=100, unique=True)
    max_jobs = models.PositiveIntegerField(default=10)
    max_datasets = models.PositiveIntegerField(default=5)
    max_requests_per_day = models.PositiveIntegerField(default=1000)

    def __str__(self):
        return self.name
